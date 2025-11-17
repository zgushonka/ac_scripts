-- Turbolasers.
-- by: zgshnk v1.10 20251116. -- SPDX-License-Identifier: MIT
-- Copyright (c) 2025 zgshnk

local Color = {
    red    = rgbm(1.00, 0.05, 0.05, 1),
    green  = rgbm(0.05, 1.00, 0.05, 1),
}
local dt = const(1 / 333)
local data = ac.accessCarPhysics()

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
local xOff = 5.075
local yOff = 1.32
local zOff = 3.9
local function getXWingNextTurretPos()
    local pos = data.position:clone()
    if      beamIndex == 1 then beamIndex = beamIndex + 1
        pos:addScaled(data.side,  xOff)
            :addScaled(data.up,   yOff)
            :addScaled(data.look, zOff)

    elseif  beamIndex == 2 then beamIndex = beamIndex + 1
        pos:addScaled(data.side,  xOff)
            :addScaled(data.up,  -yOff)
            :addScaled(data.look, zOff)

    elseif  beamIndex == 3 then beamIndex = beamIndex + 1
        pos:addScaled(data.side, -xOff)
            :addScaled(data.up,  -yOff)
            :addScaled(data.look, zOff)

    elseif  beamIndex == 4 then beamIndex = 1
        pos:addScaled(data.side, -xOff)
            :addScaled(data.up,   yOff)
            :addScaled(data.look, zOff)
    end
    return pos
end

local function addBeamTo(beams)
    local newPulse = LaserPulse:new({
        pos = getXWingNextTurretPos(),
        look = data.look,
        dist = 550,     -- m
        speed = 450,    -- m/s
        length = 50     -- units
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
