-- Throttle model. Based on Niels Heusinkveld explanation and JPG_18 hints.
-- by: zgshnk v2.31 2026 -- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 zgshnk

local data = ac.accessCarPhysics()

local softLimiterEnabled = false
local softLimiterRPM = 6100

local limiter_inv = const(1 / data.rpmLimit)    -- let's avoid division operation if possible
local debugOutThrottle = 0

local function sigmoidSqrt(a, x)                -- sqrt based sigmoid
    local ax = a * x
    return ax / math.sqrt(1 + ax^2)
end
local function calcOutputThrottle(gas, rpm, exp)
    local p = (1 - rpm * limiter_inv)
    local a = 0.1 * (1 + p * exp)
    return  (1 - gas) * sigmoidSqrt(a, gas) + gas
end
local function getExp(gear)
    if gear == 0 then return 25 end
    if gear == 1 then return 20 end
    if gear == 2 then return 25 end -- gear 1
    if gear == 3 then return 30 end -- gear 2
    if gear == 4 then return 45 end -- gear 3
    return 65
end
local function calcAndApplyThrottle(gas, rpm)
    local exp = getExp(data.gear)
    local outThrottle = calcOutputThrottle(gas, rpm, exp)
    debugOutThrottle = outThrottle
    ac.overrideGasInput(outThrottle)
end
local function softLimiter(gas, rpm)
    local isSlow = data.speedKmh < 40
    local firstOrLess = data.gear < 3
    local isAboveLimiter = softLimiterRPM < rpm
    if --isOnNeutral and
        isSlow
        and firstOrLess
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
    if car.isAIControlled then
        ac.overrideGasInput(inThrottle)
        return
    end
    if softLimiterEnabled then
        inThrottle = softLimiter(inThrottle, data.rpm)
    end
    calcAndApplyThrottle(inThrottle, data.rpm)
end
return script_throttleModel
