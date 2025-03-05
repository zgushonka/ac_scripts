-- Hover mode
-- by: zgshnk v2.26 20250305. Licensed under CC BY-SA 4.0.
-- https://creativecommons.org/licenses/by-sa/4.0/

local data = ac.accessCarPhysics()
local baseHoverForce = const((car.mass - 42 * 3) * 9.8)
local carCTRL = {
    AccMult = 20000,
    BrakeMult = 1500,
    TurboLiftMult = 170,

    Steer = {
        Mult = 10,
        RollMult = 2.75
    }
}
local H = {
    FlyHeight = 1.95,
    LandingHeight = 0.55,
    Pid = {
        mult = 5500,
        kp = 0.75,
        ki = 0.35,
        kd = 0.65
    }
}
local ST = {
    FClamp = 10000, -- force clamp
    xPitchPid = {   --  Pitch   - data.up.z
        mult = 600,
        kp = 0.75,
        ki = 0.01,
        kd = 0.65
    },
    yYawPid = {     --  Yaw     - localAngularVelocity.y
        mult = 250,
        kp = 0.75,
        ki = 0.015,
        kd = 0.15
    },
    zRollPid = {    --  Roll    - data.up.x
        mult = 900,
        kp = 0.55,
        ki = 0.025,
        kd = 0.55
    }
}
local AIR = {
    resistScale = const(vec3(15, 5, 1):scale(-1)),
    resistMult = 11,
    brakeMult = 2
}
-- vec3(left, up, front)
local vec = {
    Up = vec3( 0, 1, 0),
    Dn = vec3( 0,-1, 0),
    Lf = vec3( 1, 0, 0),
    Rt = vec3(-1, 0, 0),
    Fr = vec3( 0, 0, 1),
    Bk = vec3( 0, 0,-1),
    All= vec3( 1, 1, 1),
}
local gDt = 0.003
local dt_inv = const(1 / gDt)
-- local steerLock_inv = const (1 / car.steerLock)
local SState = {
    DRIVE = 1,
    FLY  = 2,
    LANDING = 3,
    FALLING = 4
}

local Pid = {}
Pid.__index = Pid
function Pid:new(pidKs)
    local obj = {}
    setmetatable(obj, Pid)
    obj.kp = pidKs.kp
    obj.ki = pidKs.ki
    obj.kd = pidKs.kd
    obj.outMult = pidKs.mult
    -- state
    obj.integral = 0
    obj.prevEr = 0
    return obj
end
function Pid:reset()
    self.integral = 0
    self.prevEr = 0
end
function Pid:makeStep(err)
    self.integral = self.integral + err * gDt
    local dif = (err - self.prevEr) * dt_inv
    self.prevEr = err
    return (self.kp*err + self.ki*self.integral + self.kd*dif) * self.outMult
end
function Pid:setIntegralLimit(lowLimit)
    self.integral = math.max(lowLimit, self.integral)
end

local FlyCtrl = {}
FlyCtrl.__index = FlyCtrl
function FlyCtrl:new(pitchCtrl, yawCtrl, rollCtrl, hoverCtrl, flyEngine)
    local obj = {}
    setmetatable(obj, FlyCtrl)
    obj.pitchCtrl = pitchCtrl
    obj.yawCtrl = yawCtrl
    obj.rollCtrl = rollCtrl
    obj.hoverCtrl = hoverCtrl
    obj.fly = flyEngine
    -- 
    obj.trgPitch = 0
    obj.trgYaw = 0
    obj.trgRoll = 0
    obj.steerRoll = 0

    obj.flyPosYtoTrackStart = 0

    obj.pitchOffset = 0
    obj.baseHoveringAlt = 0
    obj.targetAltitude = 0
    obj.altFilterAlpha = 0.0009
    obj.altFilterAlphaN = 1 - 0.0009
    return obj
end
function FlyCtrl:resetAll()
    self.pitchCtrl:reset()
    self.yawCtrl:reset()
    self.rollCtrl:reset()
    self.hoverCtrl:reset()
end
function FlyCtrl:setHoveringAlt(newAlt)
    self.baseHoveringAlt = newAlt
end
function FlyCtrl:run(powerK, ss)
    local isUpSideDown = data.up.y < 0.2
    if isUpSideDown then
        self:resetAll()
        return
    end

    self:runHover(powerK, ss)
    self:runTurboLift(1 - data.clutch)
    self:runAccBrk(data.gas, data.brake)
    self:runPitch(self.pitchOffset)
    self:runYaw(data.steer)
    self:runRoll(data.steer)
    self:runAirResist(data.brake)
end
-- function FlyCtrl:getCustomAltitudeCorrection() -- returns value in meters
--     return 0
-- end
function FlyCtrl:getDefaultAltitudeCorrection(currentAlt) -- returns value in meters
        local speedHeight = math.saturate(data.localVelocity:length() * 0.02) * 2
        local addHoverAlt = math.max(0, currentAlt - self.baseHoveringAlt) * 0.25
        -- ac.debug("r120 - speedHeight", speedHeight, 0, 10)
        -- ac.debug("r122 - addHoverAlt", addHoverAlt)
        return addHoverAlt + speedHeight
end
function FlyCtrl:getReycastAlt()
    local distToGround = self:getReycastAltRaw()
    local isDistValid = (distToGround ~= -1)
    if isDistValid then
        self.flyPosYtoTrackStart = distToGround - car.position.y
        return distToGround
    else
        return car.position.y + self.flyPosYtoTrackStart
    end
end
local tempPos = vec3()
local tempYOffset = vec3(0, 0.5, 0)
function FlyCtrl:getReycastAltRaw()
    tempPos:set(car.position):add(tempYOffset)
    return physics.raycastTrack(tempPos, vec.Dn, 100)
end
function FlyCtrl:runHover(powerK, ss)  ------------------------------------------------------
    local newTargetAlt = self.baseHoveringAlt
    local currentAlt = self:getReycastAlt()

    -- ac.debug("r120 - currentAlt", currentAlt, -2, 25)
    if ss == SState.FLY then
        -- edit here to add custom hover fly height behaviour
        local defaultAlt = self:getDefaultAltitudeCorrection(currentAlt)
        local customAlt = 0 -- self:getCustomAltitudeCorrection()
        newTargetAlt = newTargetAlt + defaultAlt + customAlt
    end

    self.targetAltitude = newTargetAlt * self.altFilterAlpha
                 + self.targetAltitude * self.altFilterAlphaN
    -- ac.debug("r150 - self.targetAltitude", self.targetAltitude, 0, 20)

    local error = self.targetAltitude - currentAlt
    ac.debug("r220 - error", error)

    local ctrlForce = self.hoverCtrl:makeStep(error)
    -- ac.debug("r260 - ctrlForce", ctrlForce)
    self.hoverCtrl:setIntegralLimit(-0.1)
    -- ac.debug("r340 - integral", self.hoverCtrl.integral)

    ctrlForce = math.clampN(ctrlForce, -500, 20000)
    local force = baseHoverForce + ctrlForce
    force = force * powerK    -- smooth hover on/off

    -- ac.debug("r440 - force", force)
    self.fly:lift(force)
end
function FlyCtrl:runTurboLift(input)
    local clutch = math.max(0, input - 0.4)
    local force = (clutch * carCTRL.TurboLiftMult)^2
    -- ac.debug("r480 - runTurboLift", force)
    self.fly:turboLift(force)
end
function FlyCtrl:runAccBrk(gas, brake)
    local accF = gas * carCTRL.AccMult
    -- if car.extraB then accF = accF * 1.4 end -- fly booster
    local zM = math.clampN(data.localVelocity.z, 0, 4)
    local brakeF = brake * carCTRL.BrakeMult * zM -- reverse
    self.fly:accBrk(accF, brakeF)
end
function FlyCtrl:runPitch(offset)
    local current = data.look.y + offset
    local force = self.pitchCtrl:makeStep(-current)
    self.fly:pitch(force)
end
function FlyCtrl:runYaw(input)
    local steerTurn = self:steerSpeedMult(input) * carCTRL.Steer.Mult
    local current = steerTurn + data.localAngularVelocity.y * (1 + car.brake*0.5)
    local force = self.yawCtrl:makeStep(-current)
    self.fly:yaw(force)
end
function FlyCtrl:runRoll(input)
    local steerRoll = input * carCTRL.Steer.RollMult

    -- ac.debug("r580 - steerRoll", steerRoll, -1 , 1)
    local current = data.side.y - steerRoll
    local force = self.rollCtrl:makeStep(-current)
    self.fly:roll(force)
end
function FlyCtrl:steerSpeedMult(input)
    return input * (0.7 + 0.3 * math.saturate(data.speedKmh * 0.03))
end
local tempV = const(vec3())
function FlyCtrl:runAirResist(brake)
    local brakeF = 1 + brake * AIR.brakeMult
    local sqFrX = self:calcAirFriction(data.localVelocity.x, 1)
    local sqFrY = self:calcAirFriction(data.localVelocity.y, 1)
    local sqFrZ = self:calcAirFriction(data.localVelocity.z, 1)
    tempV:set(sqFrX, sqFrY, sqFrZ)
        :mul(AIR.resistScale)
        :scale(AIR.resistMult)
        :scale(brakeF)
    self.fly:resist(tempV)
end
function FlyCtrl:clampF(force)
    return math.clampN(force, -ST.FClamp, ST.FClamp)
end
function FlyCtrl:calcAirFriction(v, d)
    return (v < 0) and -(v^2+d) or v^2+d
end

local y_off   =  0.10
local axleF_x =  0.80
local cog_y   = -0.035
local axleF_z =  1.493
local axleR_z = -0.915
local carP = { -- carPoints
    Ct = vec3(0, cog_y, 0),
    Top= vec3(0, y_off, 0),

    Ac  = vec3(0, -0.015, 0),
    Br  = vec3(0, -0.185, 0),

    Fr = vec3(       0, cog_y, axleF_z),
    Rr = vec3(       0, cog_y, axleR_z),
    Lt = vec3( axleF_x, cog_y,       0),
    Rt = vec3(-axleF_x, cog_y,       0)
}
local flyFV = const(vec3())

local FlyEngine = {}
FlyEngine.__index = FlyEngine
function FlyEngine:new()
    local obj = {}
    setmetatable(obj, FlyEngine)
    return obj
end
function FlyEngine:pitch(f)
    ac.addForce(carP.Fr, true, flyFV:setScaled(vec.Up, f), true)
    ac.addForce(carP.Rr, true, flyFV:setScaled(vec.Up,-f), true)
end
function FlyEngine:yaw(f)
    ac.addForce(carP.Fr, true, flyFV:setScaled(vec.Lf, f), true)
    ac.addForce(carP.Rr, true, flyFV:setScaled(vec.Rt, f), true)
end
function FlyEngine:roll(f)
    ac.addForce(carP.Lt, true, flyFV:setScaled(vec.Up, f), true)
    ac.addForce(carP.Rt, true, flyFV:setScaled(vec.Up,-f), true)
end
function FlyEngine:lift(f)
    local lf = math.clampN(f, -5000, 50000)
    ac.addForce(carP.Top, true, flyFV:setScaled(vec.Up, lf), false)
end
function FlyEngine:turboLift(f)
    ac.addForce(carP.Top, true, flyFV:setScaled(vec.Up, f), true)
end
function FlyEngine:accBrk(aF, bF)
    ac.addForce(carP.Ac, true, flyFV:setScaled(vec.Fr, aF), true)
    ac.addForce(carP.Br, true, flyFV:setScaled(vec.Bk, bF), true)
end
function FlyEngine:resist(fv)
    ac.addForce(carP.Ct, true, flyFV:set(vec.All):mul(fv), true)
end


------------------------------------------------------
local flyCtrl = {}
local sm = {}
local function debugOutput()
    ac.debug("a101 - extraA", car.extraA)
    ac.debug("c102 - carP.Ct", carP.Ct)

    ac.debug("c122 - sm.ss", sm.ss)
end
------------------------------------------------------

local Text = {
    title = "Hover Control",
    modeHover = "Hover mode",
    modeLanding = "Landing mode",
    altimeter = "Altitude",
    on = "On",
    off = "Off"
}
local function makeAltimeterLine()
    local height = math.round(flyCtrl:getReycastAlt(), 1)
    return string.format("%s: %0.1fm", Text.altimeter, height)
end
local function showAltitude()
    ac.setMessage(Text.title, makeAltimeterLine())
end
local function checkAltimeter(height)
    if     height <=  5 then if math.round(height, 1) % 0.1 == 0 then showAltitude() end
    elseif height <= 20 then if math.round(height)    %   5 == 0 then showAltitude() end
    else                     if math.round(height)    %  10 == 0 then showAltitude() end end
end
local function makeHoverLine(mode, status)
    return string.format("%s: %s    Alt: %s", mode, status, makeAltimeterLine())
end
local function showHoverStatus(mode, status)
    ac.setMessage(Text.title, makeHoverLine(mode, status))
end

local hoverEnabledKey = const("zg_Hov_Enabled")

local StateMachine = {}
local timerSec = 1.5
local timerSec_inv = const(1 / timerSec)
function StateMachine:new(model)
    local obj = {}
    self.__index = self
    setmetatable(obj, self)
    obj.ss = SState.DRIVE
    obj.model = model
    obj.switchTime = 0
    obj.c = {
        obj.doDrive,
        obj.doFly,
        obj.doLand,
        obj.doFall
    }
    return obj
end
function StateMachine:startTimer() self.switchTime = os.clock() + timerSec end
function StateMachine:isTimerDone() return self.switchTime < os.clock() end
function StateMachine:switchingProgress()
    local timeLeft = self.switchTime - os.clock()
    return math.saturate(timeLeft * timerSec_inv)
end
function StateMachine:makeMove()
    local lss = self.ss
    local inDriveSt   = lss == SState.DRIVE
    local inFlySt     = lss == SState.FLY
    local inLandingSt = lss == SState.LANDING
    local inFallingSt = lss == SState.FALLING
    local inAirSt = inFlySt or inLandingSt

    local isFlyOn = car.extraA
    local onLand = self.model:getReycastAlt() < (H.LandingHeight + 0.2)

    if inDriveSt and isFlyOn then
        self.model:setHoveringAlt(H.FlyHeight)
        self:switchState(SState.FLY)
        ac.store(hoverEnabledKey, 1)
        self:startTimer()
        showHoverStatus(Text.modeHover, Text.on)

    elseif inFlySt and (isFlyOn == false) then
        self.model:setHoveringAlt(H.LandingHeight)
        self:switchState(SState.LANDING)
        showHoverStatus(Text.modeLanding, Text.on)

    elseif inLandingSt and isFlyOn then
        self.model:setHoveringAlt(H.FlyHeight)
        self:switchState(SState.FLY)
        showHoverStatus(Text.modeHover, Text.on)

    elseif inLandingSt and onLand then
        self:startTimer()
        self:switchState(SState.FALLING)
        showHoverStatus(Text.modeHover, Text.off)

    elseif inFallingSt and self:isTimerDone() then
        ac.store(hoverEnabledKey, 0)
        self:switchState(SState.DRIVE)
    end

    -- if inAirSt then
        -- checkAltimeter(car.cgHeight)
        -- local pressure = (G.shouldEnabled) and math.clampN(1-H.enCount, 0.5, 1) or 1
        -- ac.setTyreInflation(ac.Wheel.All, pressure)
    -- end

    local newGas = inFlySt and 0 or data.gas
    ac.overrideGasInput(newGas)

    local stateChange = lss ~= self.ss
    if stateChange == false then
        self:doCases()
    end
end
function StateMachine:switchState(newSs)
    self.ss = newSs
end
function StateMachine:doCases()
    local method = self.c[self.ss]
    if method then method(self) end
end
---------------------------------------------
function StateMachine:doDrive()
    self.model:resetAll()
end
function StateMachine:doFly()
    self.model.pitchOffset = 0.02
    local zeroToOne = 1 - self:switchingProgress()
    self.model:run(zeroToOne, self.ss)
end
function StateMachine:doLand()
    self.model.pitchOffset = 0.085
    self.model:run(1, self.ss)
end
function StateMachine:doFall()
    local oneToZero = self:switchingProgress()
    self.model:run(oneToZero, self.ss)
end
---------------------------------------------

local initDone = false
local function script_hoverMode(dt)
    if initDone == false then
        local pitchCtrl = Pid:new(ST.xPitchPid)
        local yawCtrl = Pid:new(ST.yYawPid)
        local rollCtrl = Pid:new(ST.zRollPid)
        local hoverCtrl = Pid:new(H.Pid)
        local flyEngine = FlyEngine:new()
        flyCtrl = FlyCtrl:new(pitchCtrl, yawCtrl, rollCtrl, hoverCtrl, flyEngine)
        sm = StateMachine:new(flyCtrl)
        initDone = true
    end
    sm:makeMove()

    debugOutput()
end
return script_hoverMode
