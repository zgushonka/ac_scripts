-- Turbolasers.
-- by: zgshnk v1.10 20251116. -- SPDX-License-Identifier: MIT
-- Copyright (c) 2025 zgshnk

local Color = {
    red    = rgbm(1.00, 0.05, 0.05, 1),
    green  = rgbm(0.05, 1.00, 0.05, 1),
}
local dt = const(1 / 333)

local LaserPulse = {}
function LaserPulse:new(input)
    local obj = {}
    self.__index = self
    setmetatable(obj, self)
    obj.pos = input.pos:clone()
    obj.look = input.look:clone()
    obj.dist = input.dist

    obj.start, obj.finish = vec3(), vec3()
    obj.progress = 0
    local dist_inv = 1 / input.dist
    obj.step = input.speed * dist_inv * dt
    obj.length = input.length * 100 * dist_inv * dt
    return  obj
end
function LaserPulse:run()
    self.progress = self.progress + self.step
    local startProgress = self.progress * self.dist
    self.start :set(self.pos):addScaled(self.look, startProgress)

    local finishProgress = math.max(0, self.progress - self.length) * self.dist
    self.finish:set(self.pos):addScaled(self.look, finishProgress)

    ac.drawDebugLine(self.start, self.finish, Color.green)
    local isDone = self.progress > 1
    return isDone
end

local beamIndex = 1
local function getXWingNextTurretPos()
    local pos = car.position:clone():addScaled(car.graphicsOffset, -1)
    if      beamIndex == 1 then beamIndex = beamIndex + 1
        pos:addScaled(car.side, 1):addScaled(car.up, 0.5)

    elseif  beamIndex == 2 then beamIndex = beamIndex + 1
        pos:addScaled(car.side, 1):addScaled(car.up,-0.5)

    elseif  beamIndex == 3 then beamIndex = beamIndex + 1
        pos:addScaled(car.side,-1):addScaled(car.up,-0.5)

    elseif  beamIndex == 4 then beamIndex = 1
        pos:addScaled(car.side,-1):addScaled(car.up, 0.5)
    end
    return pos
end

local function addBeamTo(beams)
    local newPulse = LaserPulse:new({
        pos = getXWingNextTurretPos(),
        look = car.look,
        dist = 300,     -- m
        speed = 150,    -- m/s
        length = 40     -- units
    })
    table.insert(beams, newPulse)
end

local latch = false
local roundPerSecond = const(4 * 0.75)
local cdClicks = const(math.round(1 / roundPerSecond / dt))
local cdCount = 0
local function putTurretFireTo(beams)
    if car.extraR then
        if latch == false then
            addBeamTo(beams)
            latch = true
        end
    end
    --  CoolDown
    if latch then
        if cdCount > cdClicks then
            cdCount = 0
            latch = false
        else
            cdCount = cdCount + 1
        end
    end
end

local function processBunchOf(beams)
    for i = 1, #beams do
        local pulse = beams[i]
        if pulse ~= nil then
            local thisBeamIsDone = pulse:run()
            if thisBeamIsDone then table.remove(beams, i) end
        end
    end
end

local beams = {}
local function script_turboLasers(_)
    putTurretFireTo(beams)
    processBunchOf(beams)
end
return script_turboLasers

-- ---@param params {
--     color: rgbm, 
--     colorConsistency: number, 
--     thickness: number, 
--     life: number, 
--     size: number, 
--     spreadK: number,
--     growK: number,
--     targetYVelocity: number
-- }|`{
--     color = rgbm(0.5, 0.5, 0.5, 0.5),
--     colorConsistency = 0.5,
--     thickness = 1,
--     life = 4,
--     size = 0.2,
--     spreadK = 1,
--     growK = 1,
--     targetYVelocity = 0
-- }` 
-- "Table with properties:
-- - `color` (`rgbm`): Smoke color with values from 0 to 1. 
--                      Alpha can be used to adjust thickness.
--                      Default alpha value: 0.5.
-- - `colorConsistency` (`number`): Defines how much color dissipates when smoke expands, 
--                      from 0 to 1. Default value: 0.5.
-- - `thickness` (`number`): How thick is smoke, from 0 to 1. Default value: 1.
-- - `life` (`number`): Smoke base lifespan in seconds. Default value: 4.
-- - `size` (`number`): Starting particle size in meters. Default value: 0.2.
-- - `spreadK` (`number`): How randomized is smoke spawn (mostly, speed and direction).
--                      Default value: 1.
-- - `growK` (`number`): How fast smoke expands. Default value: 1.
-- - `targetYVelocity` (`number`): Neutral vertical velocity.
--                      Set above zero for hot gasses and below zero for cold, 
--                      to collect at the bottom. Default value: 0."