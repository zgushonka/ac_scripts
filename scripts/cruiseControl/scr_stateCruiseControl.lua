-- Cruise control
-- by: zgshnk v2.14 20251016 -- SPDX-License-Identifier: MIT
-- Copyright (c) 2025 zgshnk

local data = ac.accessCarPhysics()

-- https://en.wikipedia.org/wiki/Proportional%E2%80%93integral%E2%80%93derivative_controller
-- only values to tune
local pid_config = const({
    p = 0.15,
    i = 0.1,
    d = 0.20,

    maxThrottle = 0.8,
    iMin = -0.1,
    iMax = 4.0,
    -- startSpeed = 70
})
----
local CControl = {}
function CControl:new(dt, pidCfg)
    local obj = {}
    self.__index = self
    setmetatable(obj, self)
    obj.kp = pidCfg.p
    obj.ki = pidCfg.i
    obj.kd = pidCfg.d

    obj.cfg = pidCfg
    -- const
    obj.speedStep = 10
    obj.minSpeed = 30
    obj.maxSpeed = 210
    obj.speedErrOffset = 0.0
    obj.limiterGasThreshold = 0.99
    obj.limiterGasAmp = 1.0
    obj.dt = dt
    obj.dt_inv = 1 / dt
    obj.thrAlpha = 0.005
    obj.thrAlphaN = 1 - obj.thrAlpha
    -- state
    obj.targetSpeed = pidCfg.startSpeed
    obj.integral = 0
    obj.prevError = 0
    obj.prevThrottle = 0
    return obj
end
function CControl:reset()
    self.integral = 0
    self.previousSpeed = 0
end

function CControl:updCruiseThrottle()
    if data.gear < 2 then return end
    local gas = self:_calcCruiseThrottle(data.gas, data.speedKmh)

    gas = math.clampN(gas, 0, 1) * self.cfg.maxThrottle
    gas = math.max(gas, data.gas)

    -- ac.debug('cc210 - cc gas', gas, 0, 1)
    ac.overrideGasInput(math.huge)
    data.gas = gas
end
function CControl:_calcCruiseThrottle(gasPedal, speed)
    local throttle = self:calcFilteredPID(speed)
    return math.max(throttle, gasPedal)
end

function CControl:updLimiterThrottle()
    local gas = self:_calcLimiterThrottle(data.gas, data.speedKmh)
    -- ac.debug('cc220 - li gas', gas, 0, 1)
    ac.overrideGasInput(math.huge)
    data.gas = gas
end
function CControl:_calcLimiterThrottle(gasPedal, speed)
    if self.limiterGasThreshold < gasPedal then return gasPedal end
    local throttle = self:calcFilteredPID(speed)
    return math.min(throttle, gasPedal * self.limiterGasAmp)
end

function CControl:calcFilteredPID(speed)
    -- return self:calcPID(speed)
    self.prevThrottle = self:calcPID(speed) * self.thrAlpha + self.prevThrottle * self.thrAlphaN
    -- local lim = 1
    -- ac.debug('160 - fpid', self.prevThrottle, -lim, lim)
    return self.prevThrottle
end
function CControl:setTargetSpeed(val)
    self.targetSpeed = val
    self.prevError = nil
end
function CControl:getTargetSpeed()
    if self.targetSpeed == nil then self:setTargetSpeed(self:_calcTargetSpeed(data.speedKmh)) end
    return self.targetSpeed
end

function CControl:calcPID(speed)
    local error = (self:getTargetSpeed() - speed) + self.speedErrOffset
    local p = self.kp * error
    local integral = self.integral + error * self.dt
    integral = math.clampN(integral, self.cfg.iMin, self.cfg.iMax)
    self.integral = integral
    local i = self.ki * self.integral
    local prevError = self.prevError or error
    local d = self.kd * (error - prevError) * self.dt_inv
    self.prevError = error

    -- local lim = 25
    -- ac.debug('cc110 - p', p, -lim, lim)
    -- ac.debug('cc120 - i', i, -lim, lim)
    -- ac.debug('cc122 - si', integral, self.iMin, lim)
    -- ac.debug('cc130 - d', d, -lim, lim)
    -- ac.debug('cc150 - pid', p + i + d, -lim, lim)
    -- ac.debug('cc310 - error', error, -50, 50)

    return p + i + d
end

function CControl:resetTargerBasedOnCurrent()
end
function CControl:_calcTargetSpeed(currentSpeed)
    local baseSpeed = math.ceil(currentSpeed / self.speedStep) * self.speedStep
    return math.max(baseSpeed, self.minSpeed)
end

function CControl:incTargetSpeed()
    local targetSpeed = self:getTargetSpeed() + self.speedStep
    targetSpeed = math.min(self.maxSpeed, targetSpeed)
    self:setTargetSpeed(targetSpeed)
end
function CControl:decTargetSpeed()
    local targetSpeed = self:getTargetSpeed() - self.speedStep
    targetSpeed = math.max(self.minSpeed, targetSpeed)
    self:setTargetSpeed(targetSpeed)
end
----
local StateMachine = {}
local SState = { -- autoShifterStates
    STANDBY = 1,
    CRUISE  = 2,
    LIMITER = 3
}
function StateMachine:new(cc)
    local obj = {}
    self.__index = self
    setmetatable(obj, self)
    obj.ss = SState.STANDBY
    obj.cc = cc
    obj.brakeThreshold = 0.025
    -- state
    obj.lastMode = SState.LIMITER
    obj.isBValid = true
    obj.c = {
        obj.doStandby,
        obj.doCruise,
        obj.doLimiter
    }
    return obj
end
function StateMachine:makeMove()
    local lss = self.ss
    local inStandbySt = lss == SState.STANDBY
    local inCruiseSt = lss == SState.CRUISE
    local inLimiterSt = lss == SState.LIMITER
    local inOnSt = inCruiseSt or inLimiterSt

    local isBraking = self.brakeThreshold < data.brake

    local isBValid = self.isBValid
    local onOffPressed = car.extraG and isBValid
    local speedPlusPressed = car.extraH and isBValid
    local speedMinusPressed = car.extraI and isBValid
    local modePressed = car.extraJ and isBValid
    self:checkButtonsLatch()
    local itsHappening = false --isBValid ~= self.isBValid

    if inStandbySt and onOffPressed then
        self:switchSs(self.lastMode)

    elseif inCruiseSt and isBraking then
        self.lastMode = SState.CRUISE
        self:switchSs(SState.STANDBY)

    elseif inOnSt and onOffPressed then
        self.lastMode = lss
        self:switchSs(SState.STANDBY)

    -- elseif inStandbySt and speedPlusPressed then
    --     self:switchSs(self.lastMode)

    elseif modePressed then
        if inStandbySt then
            local nextMode = self.lastMode == SState.CRUISE
                and SState.LIMITER or SState.CRUISE
            self.lastMode = nextMode
            itsHappening = true

        elseif inCruiseSt then
            self:switchSs(SState.LIMITER)

        elseif inLimiterSt then
            self:switchSs(SState.CRUISE)
        end

    elseif speedMinusPressed then
        self.cc:decTargetSpeed()

    elseif speedPlusPressed then
        self.cc:incTargetSpeed()
    end

    local stateChange = lss ~= self.ss
    if itsHappening or stateChange then self:showStatus() end
    if stateChange == false then self:doCases() end

    self:updateIndicator()
end
function StateMachine:switchSs(newSs)
    -- if newSs ~= self.ss then
        self.ss = newSs
    -- end
    -- if newSs ~= self.ss then self.ss = newSs ac.debug('011 - states', newSs, 1, 3) end
end
function StateMachine:checkButtonsLatch()
    if     car.extraG --| on/off
        or car.extraH --| +speed
        or car.extraI --| -speed
        or car.extraJ --| mode
    then self.isBValid = false
    else self.isBValid = true end
end
function StateMachine:updateIndicator()
    local lss = self.ss
    local inStandbySt = lss == SState.STANDBY
    local inCruiseSt  = lss == SState.CRUISE
    local inLimiterSt = lss == SState.LIMITER
    if inCruiseSt or inLimiterSt or (self.isBValid == false) then
        data.controllerInputs[40] = math.round(self.cc.targetSpeed or 0)
    elseif inStandbySt then
        data.controllerInputs[40] = 0
    end
end
function StateMachine:doCases()
    local method = self.c[self.ss]
    if method then method(self) end
end
function StateMachine:doStandby() self.cc:reset() end
function StateMachine:doCruise()  self.cc:updCruiseThrottle() end
function StateMachine:doLimiter() self.cc:updLimiterThrottle() end
local ccTxt = const({
    title = const("Cruise Control"),
    mCruise = const("Cruise"),
    mLimiter = const("Limiter"),
    units = const("km/h"),
    on = const('is On'),
    off = const('is OFF')
})
function StateMachine:showStatus()
    ac.setMessage(ccTxt.title, self:_makeStatusLine())
end
function StateMachine:_makeStatusLine()
    if self.ss == SState.STANDBY then
        local modeStr = self.lastMode == SState.CRUISE
            and ccTxt.mCruise or ccTxt.mLimiter
        return modeStr .." ".. ccTxt.off
    else
        local modeStr = (self.ss == SState.CRUISE)
            and ccTxt.mCruise or ccTxt.mLimiter
        return modeStr .." ".. ccTxt.on
    end

    -- return string.format("%s %s - %.0f%s", modeStr, ccTxt.on, self.cc.targetSpeed, ccTxt.units )
end
--- . --- . --- . --- . --- . --- . --- . --- . --- . --- . --- . --- . --- . ---
local smcc = {}
local function debugOutput()
    ac.debug('010 - ccss', smcc.ss)
end
local initDone = false
local function statecruisescript(dt)
    if initDone == false then
        local cc = CControl:new(dt, pid_config)
        smcc = StateMachine:new(cc)
        initDone = true
    end
    if smcc then smcc:makeMove() end
    -- debugOutput()
end
return statecruisescript
