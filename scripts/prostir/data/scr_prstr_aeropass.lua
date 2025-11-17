-- Aero pass
-- by: zgshnk v1.22 20251101. Licensed under CC BY-NC-SA 4.0.
-- https://creativecommons.org/licenses/by-nc-sa/4.0/

local data = ac.accessCarPhysics()

local HALF_RHO = const(0.5 * 1.225)  -- 0.5 * air density
local G_CONST  = const(9.81)

local zero = vec3()
local soundPos = vec3()
local chCount = 3
local con = ac.connect(
    {   ac.StructItem.key('zgshnk.aeropass.'..car.index),
        spd = ac.StructItem.array(ac.StructItem.float(), chCount),
        vol = ac.StructItem.array(ac.StructItem.float(), chCount),
        pos = ac.StructItem.array(ac.StructItem.vec3() , chCount),
    },
    false, ac.SharedNamespace.Shared
)

local function defaultConfig()
    local C = {
        gapMax         = 4.0,
        sep_b          = 1.0,
        sep_n          = 2.0,

        aLongFrac      = 0.45,
        epsEdge        = 0.03,

        yawForceFrac   = 0.03,

        s_bow          =  0.0,
        s_mid          =  0.0,
        s_wake         =  0.0,
        L_bow          =  3.0,
        L_corr         =  3.2,
        L_wake         =  2.0,

        w_bow           = 0.7,
        w_bowC          = 1.0,
        w_corr          = 0.5,
        w_wake          = 0.6,
        fScale          = 20.0,

        L_bowCouple     = 0.65,
        bowCoupleGain   = 1.5,
        bowCoupleGap0   = 2.5,
        bowCoupleGapPow = 2.0,
        qBowCoupleMult  = 0.6,

        mix = {
            bow  = { self = 0.6, other = 1.0 },
            corr = { self = 0.6, other = 0.6 },
            wake = { self = 0.2, other = 0.7 },
        },
        corrVenturiGamma = 0.15,
    }
    C.fxCap = C.yawForceFrac * car.mass * G_CONST * 50

    function C:refreshDerived()
        self.invTwoL2_bow       = 1 / (2 * self.L_bow^2)
        self.invTwoL2_corr      = 1 / (2 * self.L_corr^2)
        self.invTwoL2_wake      = 1 / (2 * self.L_wake^2)
        self.invTwoL2_bowCouple = 1 / (2 * self.L_bowCouple^2)
    end

    C:refreshDerived()
    return C
end

local function gauss_no_div(delta, invTwoL2)
    return math.exp(-(delta^2) * invTwoL2)
end

local m_self_ws  = mat4x4()  -- self (physics) → world
local m_ws_self  = mat4x4()  -- world → self (physics)
local function refreshTransforms(myCar)
  m_self_ws:set(myCar.transform)
  m_ws_self:set(m_self_ws):inverseSelf()
end

-- -  AeroPair  --------------------------------------------------------------
local AeroPair = {}
AeroPair.__index = AeroPair

function AeroPair.new(vec3_ctor, cfgOverride)
    local self = setmetatable({}, AeroPair)
    self.cfg   = cfgOverride or defaultConfig()
    self.sc = {
        forceTmp = vec3_ctor(),
        pointTmp = vec3_ctor(),
        M_ws_self= mat4x4(),
        otherPos = vec3_ctor(),
        otherVel = vec3_ctor(),
        otherSide= vec3_ctor(),
        otherLook= vec3_ctor(),
        otherUp  = vec3_ctor(),
    }
    return self
end

---@param size vec3
local calcK = function(size) return 0 end

---@param selfSize vec3
local function makeK_fromDims_baselined(selfSize)
    local AREF_FRONTAL      = selfSize.x * selfSize.y
    local AREF_SIDE         = selfSize.z * selfSize.y
    local INV_AREF_FRONTAL  = 1.0 / AREF_FRONTAL
    local INV_AREF_SIDE     = 1.0 / AREF_SIDE
    local SLENDER_REF       = selfSize.z / selfSize.x

    local wF, wS        = 0.80, 0.20
    local alpha, beta   = 1.30, 0.60
    local gammaSlender  = 0.04
    local kmin, kmax    = 0.85, 7.00

    ---@param size vec3
    return function(size)
        local W, H, L = size.x, size.y, size.z
        local Kf = ((W * H) * INV_AREF_FRONTAL) ^ alpha
        local Ks = ((L * H) * INV_AREF_SIDE   ) ^ beta
        local slender = L / W
        Ks = Ks * (1.0 + gammaSlender * (slender - SLENDER_REF))
        local K = wF * Kf + wS * Ks
        return math.clampN(K, kmin, kmax)
    end
end

local whPos = vec3(0, 0, 0.1)
-- Convert other car’s to *my* local (physics) frame:
---@param myCar ac.StateCphysCar
---@param other ac.StateCar
function AeroPair:otherToSelfLocal(myCar, other)
    local M = m_ws_self
    M:transformPointTo(self.sc.otherPos, other.position)
    M:transformVectorTo(self.sc.otherVel,  other.velocity)
    M:transformVectorTo(self.sc.otherLook, other.look)
    M:transformVectorTo(self.sc.otherSide, other.side)
    M:transformVectorTo(self.sc.otherUp,   other.up)
    self.sc.otherLook:normalize()
    self.sc.otherSide:normalize()
    self.sc.otherUp:normalize()
end

local hubFPos = vec3()
local forceWhTmp = vec3()
---comment
---@param myCar ac.StateCphysCar
---@param mySize vec3
---@param other ac.StateCar
function AeroPair:step(myCar, mySize, other, windLocal)
    local cfg = self.cfg
    local sc = self.sc
    local otherSize = other.aabbSize
    self:otherToSelfLocal(myCar, other)

    local gapX = math.abs(sc.otherPos.x) - 0.5 * (mySize.x + otherSize.x)
    gapX = math.max(0.0, gapX)
    if gapX > cfg.gapMax then return end

    -- defaults: b = 1.0, n = 2.0
    local b, n = cfg.sep_b, cfg.sep_n

    local venturiGain = 1.0
    if cfg.corrVenturiGamma > 0.0 then
        local denom = gapX + b
        if denom > 1e-6 then
            local midWidth = 0.5 * (mySize.x + otherSize.x)
            local ratio = midWidth / denom
            venturiGain = 1.0 + cfg.corrVenturiGamma * ratio^2
        end
    end
    local lenScale = 1.15
    local selfHalfLen  = 0.5 * mySize.z * lenScale
    local halfLen  = 0.5 * otherSize.z  * lenScale
    local noseSign = (sc.otherLook.z >= 0) and 1 or -1

    local oZ = sc.otherPos.z
    local zMid     = oZ
    local zNose    = oZ + noseSign * halfLen
    local zTail    = oZ - noseSign * halfLen

    local G_bowCouple  = gauss_no_div( (zNose - selfHalfLen), cfg.invTwoL2_bowCouple )
    local gapFalloff   = 1.0 / (1.0 + (gapX / cfg.bowCoupleGap0)^cfg.bowCoupleGapPow)

    local qBowCoupleMult = cfg.qBowCoupleMult
    local qSelfZ  = (myCar.localVelocity.z - windLocal.z) - sc.otherVel.z * qBowCoupleMult
    local qOtherZ = (sc.otherVel.z - windLocal.z) - myCar.localVelocity.z * qBowCoupleMult

    local qBowCouple = cfg.bowCoupleGain * (2.0 * math.sqrt(qSelfZ^2 * qOtherZ^2)) * G_bowCouple * gapFalloff

    local myVel2 = myCar.localVelocity:lengthSquared()
    local otherVel2 = sc.otherVel:lengthSquared()
    local mix = cfg.mix

    local qBow  = HALF_RHO * (mix.bow.self  * myVel2 + mix.bow.other  * otherVel2)
    local qBowC = HALF_RHO * qBowCouple
    local qCorr = HALF_RHO * (mix.corr.self * myVel2 + mix.corr.other * otherVel2) * venturiGain
    local qWake = HALF_RHO * (mix.wake.self * myVel2 + mix.wake.other * otherVel2)

    local Kc = calcK(otherSize)
    local sepAtt = (b / (gapX + b))^n
    local Abow   = cfg.w_bow  * Kc * sepAtt * qBow
    local AbowC  = cfg.w_bowC * Kc * sepAtt * qBowC
    local Acorr  = cfg.w_corr * Kc * sepAtt * qCorr
    local Awake  = cfg.w_wake * Kc * sepAtt * qWake

    local Gb = gauss_no_div(zNose - cfg.s_bow,  cfg.invTwoL2_bow )
    local Gm = gauss_no_div(zMid  - cfg.s_mid,  cfg.invTwoL2_corr)
    local Gw = gauss_no_div(zTail - cfg.s_wake, cfg.invTwoL2_wake)

    local F_bow   =  Abow  * Gb
    local F_bowC  =  AbowC * Gb
    local F_corr  =  Acorr * Gm
    local F_wake  =  Awake * Gw
    local sideSign = (sc.otherPos.x >= 0) and 1 or -1

    local awaySign = -sideSign
    local Fx_bow   =  awaySign * F_bow
    local Fx_bowC  =  awaySign * F_bowC
    local Fx_corr  = -awaySign * F_corr
    local Fx_wake  = -awaySign * F_wake

    local Fx_total_abs = math.abs(Fx_bow) + math.abs(Fx_corr) + math.abs(Fx_wake)
    local Fx_cap       = cfg.Fx_cap or 10
    local scale = (Fx_total_abs > Fx_cap) and (Fx_cap / Fx_total_abs) or 1.0
    Fx_total_abs = Fx_total_abs + math.abs(Fx_bowC)

    Fx_bow, Fx_corr, Fx_wake = Fx_bow*scale, Fx_corr*scale, Fx_wake*scale
    Fx_bowC = Fx_bowC*scale

    local xEdge  = sideSign * (0.5*mySize.x - cfg.epsEdge)
    local yCP    = 0.0
    local zClamp = cfg.aLongFrac * mySize.z * 1.25

    local z_bow  = math.clampN(zNose, -zClamp, zClamp)
    local z_corr = math.clampN(zMid,  -zClamp, zClamp)
    local z_wake = math.clampN(zTail, -zClamp, zClamp)

    local pointTmp = sc.pointTmp
    local forceTmp = sc.forceTmp
    local fScale = cfg.fScale
    local fRange = Fx_cap

    soundPos:set(xEdge, yCP, z_bow)

    if Fx_bow ~= 0.0 then
        pointTmp:set(xEdge, yCP, z_bow)

        local Fx = Fx_bow
        forceTmp:set(Fx, math.abs(Fx) * 0.10, 0.0)
        forceTmp:scale(fScale)
        ac.addForce(pointTmp, true, forceTmp, true)
    end

    if Fx_bowC ~= 0.0 then
        pointTmp:set(xEdge, yCP, z_bow)

        local Fx = Fx_bowC
        forceTmp:set(Fx, -math.abs(Fx) * 0.25, -math.abs(Fx) * 0.1)
        forceTmp:scale(fScale)
        ac.addForce(pointTmp, true, forceTmp, true)
    end

    if Fx_corr ~= 0.0 then
        pointTmp:set(xEdge, yCP, z_corr)
        local Fx = Fx_corr
        forceTmp:set(Fx, -math.abs(Fx) * 0.12, 0.0)
        forceTmp:scale(fScale)
        ac.addForce(pointTmp, true, forceTmp, true)
    end

    if Fx_wake ~= 0.0 then
        pointTmp:set(xEdge, yCP, z_wake)
        local Fx = Fx_wake
        forceTmp:set(Fx, -math.abs(Fx) * 0.07, 0.0)
        forceTmp:scale(fScale)
        ac.addForce(pointTmp, true, forceTmp, true)
    end

    local wheel = ac.Wheel.FrontLeft
    if xEdge < 0 then wheel = ac.Wheel.FrontRight end

    local fw = (
        Fx_bow * 0.85
        + Fx_bowC
        + Fx_corr * 0.35
        + Fx_wake * 0.55
    ) * 4
    local fwr = 1350
    fw = math.clampN(fw, -fwr, fwr)

    local wheelObj = myCar.wheels[wheel]
    forceWhTmp:setScaled(wheelObj.side, fw)
    hubFPos:set(wheelObj.position):addScaled(wheelObj.look, 0.25)
    ac.addHubForce2(wheel, hubFPos, forceWhTmp, true, 2)
    return Fx_total_abs, soundPos
end

local function sendSound(carSounds)
    for i = 1, 3 do
        local carSound = carSounds[i]
        if carSound then
            local carF = carSound.carForce or 0
            con.vol[i-1] = math.clampN(carF * 0.1, 0, 2) * 0.15
            con.spd[i-1] = carSound.totalSpeed
            con.pos[i-1] = carSound.soundPos
        else
            con.vol[i-1] = 0
        end
    end
end

local function resetSound(i)
    con.vol[i-1] = 0
end
local function resetSounds()
    for i = 1, 3 do resetSound(i) end
end

local tmpPosW = vec3()
local wind, windLocal = vec3(), vec3()

---comment
---@param ap any
---@param myCar ac.StateCphysCar
---@param mySize vec3
local function update(ap, myCar, mySize)
    local myPos = myCar.position
    refreshTransforms(myCar)

    ac.getWindVelocityTo(wind)
    m_ws_self:transformVectorTo(windLocal, wind)

    local carSounds = {}
    for i, otherCar in ac.iterateCars() do
        if otherCar == nil then return end

        tmpPosW:set(otherCar.position)
            :addScaled(otherCar.up, -car.graphicsOffset.y)
        local dist = math.distance(myPos, tmpPosW)

        if otherCar ~= car and (dist < 20) then
            local carF, carSoundPos = ap:step(myCar, mySize, otherCar, windLocal)
            local totalSpeed = (myCar.localVelocity:length()
                                + otherCar.velocity:length())
                                * 5
            local carSound = {
                    dist = dist,
                    carForce = carF,
                    soundPos = carSoundPos and vec3(carSoundPos) or zero,
                    totalSpeed = totalSpeed
                }
            table.insert(carSounds, carSound)
        end
    end
    table.sort(carSounds, function(a, b) return a.dist < b.dist end)
    sendSound(carSounds)
end

local ap, mySize = {}, {}
local initDone = false
local function run_aeroPass(dt)
    if initDone == false then
        if car.isAIControlled then return end
        ap = AeroPair.new(vec3)
        mySize = car.aabbSize
        calcK = makeK_fromDims_baselined(mySize)
        initDone = true
    end

    if car.extraT or car.isAIControlled then
        resetSounds()
    else
        update(ap, data, mySize)
    end
end
return run_aeroPass
