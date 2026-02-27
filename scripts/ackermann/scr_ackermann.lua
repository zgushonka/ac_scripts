-- draw Ackermann geometry
-- by: zgshnk v1.01 2026. -- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 zgshnk

local data = ac.accessCarPhysics()
local Color = {
    white  = rgbm(1.00, 1.00, 1.00, 1),
    green  = rgbm(0.30, 1.00, 0.30, 1),
    blue   = rgbm(0.30, 0.30, 1.00, 1),
    orange = rgbm(1.00, 0.60, 0.00, 1),
}

--
Ackermann = {}
---@param rearOffsetMeters number
function Ackermann:draw(rearOffsetMeters)
    local dist = 25
    local offset = rearOffsetMeters or 0
    self:drawFrontWheels(dist)
    self:drawRearAxle(dist, offset)
end

---@param dist number
function Ackermann:drawFrontWheels(dist)
    self:drawWheel(ac.Wheel.FrontLeft, dist, Color.orange)
    self:drawWheel(ac.Wheel.FrontRight, dist, Color.white)
end

local ackFrTmp = vec3()
---@param wheelIndex ac.Wheel
---@param dist number
---@param color rgbm
function Ackermann:drawWheel(wheelIndex, dist, color)
    local wheel = data.wheels[wheelIndex]
    local startPos = wheel.position
    local endPos = ackFrTmp:set(startPos):addScaled(wheel.side, dist)
    endPos.y = startPos.y
    ac.drawDebugLine(startPos, endPos, color)
end

local ackDirTmp, ackRearEndTmp, ackRearStartTmp = vec3(), vec3(), vec3()
---@param dist number
---@param offset number
function Ackermann:drawRearAxle(dist, offset)
    local rearLPos = data.wheels[ac.Wheel.RearLeft].position
    local rearRPos = data.wheels[ac.Wheel.RearRight].position
    local dir = ackDirTmp:set(rearLPos):sub(rearRPos)
    local startPos = ackRearStartTmp:set(rearRPos)
    local endPos = ackRearEndTmp:set(rearLPos):addScaled(dir, dist)
    endPos.y = startPos.y

    startPos:addScaled(data.look, offset)
    endPos:addScaled(data.look, offset)

    ac.drawDebugLine(startPos, endPos, Color.green)
end
return Ackermann
