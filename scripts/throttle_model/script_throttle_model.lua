-- Throttle model. Based on Niels Heusinkveld explanation and JPG_18 hints.
-- by: zgshnk v2.20 20250304. Licensed under CC BY-SA 4.0.
-- https://creativecommons.org/licenses/by-sa/4.0/

local data = ac.accessCarPhysics()

local softLimiterEnabled = false
local softLimiterRPM = 4500

local limiter_inv = const(1 / data.rpmLimit)    -- let's avoid division operation if possible
local debugOutThrottle = 0

local function sigmoidSqrt(a, x)                -- sqrt based sigmoid
    local ax = a * x
    return ax / math.sqrt(1 + ax^2)
end
local function calcOutputThrottle(gas, rpm)
    local p = (1 - rpm * limiter_inv)
    local a = 0.1 * (1 + p * 75)
    return  (1 - gas) * sigmoidSqrt(a, gas) + gas
end
local function calcAndApplyThrottle(gas, rpm)
    local outThrottle = calcOutputThrottle(gas, rpm)
    debugOutThrottle = outThrottle
    ac.overrideGasInput(outThrottle)
end
local function softLimiter(gas, rpm)
    local isOnNeutral = car.gear == 0
    local isSlow = 5 < data.speedKmh
    local isAboveLimiter = softLimiterRPM < rpm
    if isOnNeutral
        and isSlow
        and isAboveLimiter
    then return 0 end
    return gas
end
local function debugOutput()
    ac.debug('tm101 data.rpm', data.rpm, 0, 8000)
    ac.debug('tm110 throttle in', data.gas, 0, 1)
    ac.debug('tm210 throttle out', debugOutThrottle, 0, 1)
    ac.debug('tm310 data.engineTorque', data.engineTorque, -100, 400)
end
local function script_throttleModel(dt)
    -- debugOutput()
    local inThrottle = data.gas
    if softLimiterEnabled then
        inThrottle = softLimiter(inThrottle, data.rpm)
    end
    calcAndApplyThrottle(inThrottle, data.rpm)
end
return script_throttleModel
