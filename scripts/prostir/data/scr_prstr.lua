-- Prostir
-- by: zgshnk v1.40 20251111. Licensed under CC BY-NC-SA 4.0.
-- https://creativecommons.org/licenses/by-nc-sa/4.0/

local clr = {
    orange = rgbm(1.00, 0.60, 0.00, 1),
    red    = rgbm(1.00, 0.05, 0.05, 1),
    green  = rgbm(0.05, 1.00, 0.05, 1),
    blue   = rgbm(0.05, 0.05, 1.00, 1),
    yellow = rgbm(1.00, 1.00, 0.05, 1),
    purple = rgbm(1.00, 0.00, 1.00, 1),
    white  = rgbm(1.00, 1.00, 1.00, 0.9),
}
local data = ac.accessCarPhysics()
local MAX_DIST      = 25
local extCfg        = require("scr_prstr_cfg")
local VOL_Mult      = extCfg.VolumeMult_Walls_Low
local VOL_Mult_H    = extCfg.VolumeMult_Walls_High
local LowPosScale   = 2.0
local HighPosScale  = 0.05
local GasAlpha      = 0.45
local GasShift      = 0.00
local PITCH_low     = extCfg.Pitch_Low

local REFLLut       = ac.DataLUT11.parse("(|0=0.60|0.5=0.85|1=1.0|)")
local Pst           = 1.059463
local PITCHLut      = const(ac.DataLUT11.parse(
"(|0="..(Pst).."|3=1.0|"..(MAX_DIST * 2).."="..(1/Pst).."|)"))

local trackID = ac.getTrackID()
local isShuto = const(trackID == 'shuto_revival_project_beta')
-- ac.debug('map', trackID)

local V = {
    zero = vec3(),
    Up = vec3( 0, 1, 0),    Dn = vec3( 0,-1, 0),
    Lf = vec3( 1, 0, 0),    Rt = vec3(-1, 0, 0),
    Fr = vec3( 0, 0, 1),    Bk = vec3( 0, 0,-1),
}

local sideYVec  = vec3( 0,-0.015, 0)
local upVec     = vec3( 0, 0.35, 0)
local Vray = {
    Left        = V.Lf:clone():add(sideYVec):normalize(),
    LeftShuto   = V.Lf:clone(),
    LeftUp      = V.Lf:clone():add(upVec):normalize(),

    Right       = V.Rt:clone():add(sideYVec):normalize(),
    RightShuto  = V.Rt:clone(),
    RightUp     = V.Rt:clone():add(upVec):normalize(),

    Front       = V.Fr:clone(),
    Rear        = V.Bk:clone(),
    Down        = V.Dn:clone(),
}
local posCar = {
    eng     = extCfg.eng,
    engShuto= extCfg.engShuto,
    engDn   = extCfg.engDn,
    head    = vec3():set(car.driverEyesPosition):add(car.graphicsOffset)
}

local hX = const(car.aabbSize.x * 0.2) -- HalfSizeX
local eng2Fr = extCfg.eng2Fr
local eng2Re = extCfg.eng2Re

local srLeft_cfg = {
    ch      = 0, -- +1
    rayDir  = isShuto and Vray.LeftShuto or Vray.Left,
    rayUpDir= Vray.LeftUp,
    name    = "Left",
    color   = clr.blue,
    source  = isShuto and posCar.engShuto or nil,
    sourceOffset  = vec3( hX, 0.0, 0.0),
}
local srRight_cfg = {
    ch      = 2, -- +1
    rayDir  =  isShuto and Vray.RightShuto or Vray.Right,
    rayUpDir= Vray.RightUp,
    name    = "Right",
    color   = clr.green,
    source  = isShuto and posCar.engShuto or nil,
    sourceOffset  = vec3(-hX, 0.0, 0.0),
}
local srRear_cfg = {
    ch      = 4, -- +1
    volMult = VOL_Mult * 0.50,
    rayDir = Vray.Rear,
    name    = "Back",
    color   = clr.yellow,
    maxDist = MAX_DIST * 0.33,
    sourceOffset  = vec3(0, 0.0, eng2Re),
}
local srFront_cfg = {
    ch      = 6, -- +1
    volMult = VOL_Mult * 1.2,
    rayDir = Vray.Front,
    name    = "Front",
    color   = clr.yellow,
    maxDist = MAX_DIST * 0.33,
    sourceOffset  = vec3(0, 0.0, eng2Fr),
}
local srDown_cfg = {
    ch      = 8,
    volMult = extCfg.VolDownMult,
    source  = posCar.engDn,
    rayDir = Vray.Down,
    name    = "Down",
    color   = clr.white,
    volLut  = extCfg.VolDownLut,
    maxDist = MAX_DIST * 0.25,
}

local Default_cfg = {
    source  = posCar.eng,
    maxDist = MAX_DIST,
    volLut  = nil,
    volMult = VOL_Mult,
    volMultH= VOL_Mult_H,
    color   = clr.red,
}

local chCount = 9
local con = ac.connect(
    {   ac.StructItem.key('zgshnk.prostir.'..car.index),
        rpm = ac.StructItem.float(),
        pos = ac.StructItem.array(ac.StructItem.vec3(),  chCount),
        vel = ac.StructItem.array(ac.StructItem.vec3(),  chCount),
        vol = ac.StructItem.array(ac.StructItem.float(), chCount),
        pit = ac.StructItem.array(ac.StructItem.float(), chCount),
    },
    false, ac.SharedNamespace.Shared
)

local Filter = {}
function Filter:new(alphaIn)
    local obj = {}
    self.__index = self
    setmetatable(obj, self)
    obj.s       = nil
    obj.alpha   = alphaIn or 0.22 -- 0.25212
    return  obj
end
function Filter:process(x)
    local s = self.s
    if s == nil then s = x; return s end
    s = s + self.alpha * (x - s)
    self.s = s
    return s
end
function Filter:reset()
    self.s = nil
end

local m_self_ws = mat4x4()  -- self (physics) → world
local m_ws_self = mat4x4()  -- world → self (physics)
local function refreshTransforms(myCar)
    m_self_ws:set(myCar.transform)
    m_ws_self:set(m_self_ws):inverseSelf()
end

--------------------------
local SoundRay = {}
function SoundRay:new(chCfg, defCfg)
    local obj = {}
    self.__index = self
    setmetatable(obj, self)

    obj.ch       = chCfg.ch       or -42
    obj.name     = chCfg.name     or "no name"
    obj.rayDir   = chCfg.rayDir
    obj.rayUpDir = chCfg.rayUpDir

    obj.source         = chCfg.source   or defCfg.source
    obj.sourceOffset   = chCfg.sourceOffset   or V.zero

    obj.corrSource = vec3():set(obj.source):add(obj.sourceOffset)

    obj.maxDist  = chCfg.maxDist  or defCfg.maxDist
    obj.volMult  = chCfg.volMult  or defCfg.volMult
    obj.volMultH = chCfg.volMultH or defCfg.volMultH
    obj.volLut   = chCfg.volLut   or defCfg.volLut
    obj.color    = chCfg.color    or defCfg.color

    obj.filterVol = Filter:new()

    local velAlpha = 0.05
    obj.fVelX = Filter:new(velAlpha)
    obj.fVelY = Filter:new(velAlpha)
    obj.fVelZ = Filter:new(velAlpha)

    obj.prevDist        = 0
    obj.scanedUpDist    = 0
    obj.worldPoint, obj.worldDir = vec3(), vec3()
    obj.sndPos, obj.sndPosH, obj.sndPosDn = vec3(), vec3(), vec3()

    obj.vel, obj.velSmooth, obj.velL       = vec3(), vec3(), vec3()
    obj.sndPosTmp, obj.prevSndPos = vec3(), vec3()
    obj.norm,      obj.point      = vec3(), vec3()
    obj.normLocal, obj.pointLocal = vec3(), vec3()

    obj.normUp,    obj.pointUp    = vec3(), vec3()
    obj.normUpLoc, obj.pointUpLoc = vec3(), vec3()
    return obj
end
function SoundRay:saveCh(ch, vel, pos, vol, pitch)
    con.vel[ch] = vel
    con.pos[ch] = pos
    con.vol[ch] = vol
    con.pit[ch] = pitch
end
function SoundRay:reset()
    con.vol[self.ch] = 0
    con.vol[self.ch+1] = 0
end
function SoundRay:resetFilters()
    self.fVelX:reset()
    self.fVelY:reset()
    self.fVelZ:reset()
end

local rpmPitchLowStart = 3000
local rpmPitchLowStart_inv = const( 1 / rpmPitchLowStart )
local function pitchLowFix(pitchIn)
    local rpmScale = 1 + math.max(rpmPitchLowStart * 1.2 - data.rpm, 0) * rpmPitchLowStart_inv
    return pitchIn * rpmScale
end
local sndDirTmp = vec3()
local yRange = 0.1
function SoundRay:calcAndSave2Ch(gas, tunnelMult, sideWind)
    local otherSideMult = tunnelMult or 1
    local source = self.corrSource

    local scanedDist = self:castRay(
        source, self.rayDir, self.maxDist,
        self.point, self.norm,
        self.pointLocal, self.normLocal
    )
    local ch = self.ch
    if scanedDist < 0 then
        con.vol[ch] = 0
        con.vol[ch+1] = 0
        return
    end

    self.normLocal.y = math.clampN(self.normLocal.y, -yRange, yRange) * 0.3
    self.normLocal:normalize()
    self:reflectPosTo(self.sndPosH, source, self.pointLocal, self.normLocal)
    sndDirTmp:set(self.sndPosH):sub(source):normalize()

    self.sndPos
        :set(self.sndPosH)
        :addScaled(sndDirTmp, 3)
        :addScaled(sndDirTmp, self.sndPosH:length() * LowPosScale)

    self.sndPos.y = self.sndPos.y * 0.33
    self.sndPos.z = self.sndPos.z * 0.33

    self.sndPosH:addScaled(sndDirTmp, HighPosScale)







    local refl = self:calcReflRatio(self.norm, data.side)
    local vol = self:calcVolSide(gas, refl)
        * self.volMult
        * otherSideMult

    local velH = self:calcVel(self.sndPosH)

    self.velSmooth:set(
        self.fVelX:process(velH.x),
        self.fVelY:process(velH.y),
        self.fVelZ:process(velH.z)
    )

    velH = self.velSmooth
    local velL = self.velL:set(self.velSmooth)
    if sideWind ~= nil then
        self.velL:addScaled(sideWind, 0.025)
    end

    local volH= self:calcVolSide(gas, refl)
        * self.volMultH
        -- * 0.25 * ( 3 + otherSideMult )

    if self.rayUpDir ~= nil then
        local scanedUpDist = self:castRay(
            source, self.rayUpDir, self.maxDist,
            self.pointUp, self.normUp,
            self.pointUpLoc, self.normUpLoc
        )
        self.scanedUpDist = scanedUpDist
        local upmult = 0.33
        if scanedUpDist > 0 then
            upmult = (scanedDist / (scanedUpDist * 0.93))
        end
        vol = vol * upmult
    end

    local pit = self:calcPitch(scanedDist, refl)
    local pitchLow = pit * PITCH_low
    pitchLow = pitchLowFix(pitchLow)

    self:saveCh(ch  , velL, self.sndPos , vol , pitchLow)
    self:saveCh(ch+1, velH, self.sndPosH, volH, pit)

end













function SoundRay:calcAndSaveVert(gas, sideMult)
    local otherSideMult = sideMult or 1
    local scanedDist = self:castRay(
        self.source, self.rayDir, self.maxDist,
        self.point, self.norm,
        self.pointLocal, self.normLocal
    )
    local ch = self.ch
    if scanedDist < 0 then
        con.vol[ch] = 0
        return
    end

    self:reflectPosTo(self.sndPosDn, self.source, self.pointLocal, self.normLocal)
    local vol = self:calcVolVert(gas, scanedDist)
        * self.volMult
        * otherSideMult


    local vel = self:calcVel(self.sndPosDn)
    self:saveCh(ch, vel, self.sndPosDn, vol, 0.66)
end

function SoundRay:castRay(
    locPoint, dir, maxDist,
    point, norm, pointL, normL
)
    m_self_ws:transformPointTo(self.worldPoint, locPoint)
    m_self_ws:transformVectorTo(self.worldDir, dir)
    point:set(data.position)
    norm:set(V.zero)
    local dist =  physics.raycastTrack(
        self.worldPoint, self.worldDir,
        maxDist, point, norm)
    m_ws_self:transformPointTo(pointL, point)
    m_ws_self:transformVectorTo(normL, norm)
    return dist
end
function SoundRay:calcReflRatio(norm, reflDir)
    return math.abs( norm:dot(reflDir) )
end
local tmpReflPos = vec3()
function SoundRay:reflectPosTo(out, sourcePos, surfPoint, surfNorm)
    tmpReflPos:set(sourcePos):sub(surfPoint)
    local k = 2.0 * tmpReflPos:dot(surfNorm)
    out:setScaled(surfNorm, -k):add(sourcePos)
end
function SoundRay:calcPitch(dist, refl)
    local pitchMult = PITCHLut:get(dist)
    pitchMult = pitchMult + (2*data.gas - 1) * Pst * 0.05
    pitchMult = pitchMult * (refl*0.33 + 0.66)
    return pitchMult
end
function SoundRay:calcVolSide(gas, refl)
    local vol = gas * REFLLut:get(refl)
    return self.filterVol:process(vol)
end
function SoundRay:calcVolVert(gas, dist)
    local vol = self.volLut:get(dist)

    return self.filterVol:process(vol)
end

function SoundRay:calcVel(sndPos)
    self.sndPosTmp:set(sndPos):sub(posCar.head)
    self.vel:set(self.sndPosTmp)
        :sub(self.prevSndPos)
        :scale(333)
    if self.vel:lengthSquared() > 100 then
        self.vel:set(0,0,0)
        self:resetFilters()
    end
    self.prevSndPos:set(self.sndPosTmp)
    return self.vel
end
--------------------------

local SideMultLut = ac.DataLUT11.parse("(|0=1.2|5=1.3|9=1.3|14=1.1|15=1|20=1|100=1|)")

local wind, windLocal = vec3(), vec3()
local srLeft, srRight, srRear, srFront, srDown = {}, {}, {}, {}, {}
---@param myCar ac.StateCphysCar
local function calcProstir(myCar)
    refreshTransforms(myCar)

    local tunnelMult = 1
    if (srLeft.scanedUpDist > 0) and (srRight.scanedUpDist > 0) then
        local tunnelWide = srLeft.scanedUpDist + srRight.scanedUpDist
        tunnelMult = SideMultLut:get(tunnelWide)

    end


    local gas = (1 - GasAlpha) + myCar.gas * GasAlpha + GasShift
    ac.getWindVelocityTo(wind)
    m_ws_self:transformVectorTo(windLocal, wind)

    srLeft :calcAndSave2Ch(gas, tunnelMult, windLocal)
    srRight:calcAndSave2Ch(gas, tunnelMult, windLocal)

    srRear :calcAndSave2Ch(gas, tunnelMult, windLocal)
    srFront:calcAndSave2Ch(gas, tunnelMult, windLocal)
    srDown:calcAndSaveVert(gas)
end

local function resetAll()
    srLeft:reset()
    srRight:reset()
    srRear:reset()
    srFront:reset()
    srDown:reset()
end

local initDone = false
local function prostir(dt)
    if initDone == false then
        if car.isAIControlled then return end
        srLeft  = SoundRay:new(srLeft_cfg, Default_cfg)
        srRight = SoundRay:new(srRight_cfg,Default_cfg)
        srRear  = SoundRay:new(srRear_cfg, Default_cfg)
        srFront = SoundRay:new(srFront_cfg,Default_cfg)
        srDown  = SoundRay:new(srDown_cfg, Default_cfg)
        initDone = true
    end
    if car.extraT or car.isAIControlled then
        resetAll()
    else
        con.rpm = data.rpm
        calcProstir(data)
        -- ac.debug('000_Sound mod', 'On')
    end
end
return prostir
