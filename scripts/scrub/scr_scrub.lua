-- draw Scrub 
-- by: zgshnk v1.05 2026. -- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 zgshnk

local data = ac.accessCarPhysics()
local Color = {
    white  = rgbm(1.00, 1.00, 1.00, 1),
}
--
local kp0PosTmp, kp1PosTmp = vec3(), vec3()
local dirTmp, endPosTmp = vec3(), vec3()
--
local Scrub = {}
function Scrub:draw(isStrut)
    if self.kp1Coord == nil then
        self:_updateSuspValues()
        return
    end
    isStrut = isStrut or false
    local kp1Pos = self:_calcKp1Pos(isStrut)
    local kp0Pos = self:_calcKpPos(kp0PosTmp, self.kp0Coord, self.rimOffset)

    local dir = dirTmp:set(kp0Pos):sub(kp1Pos):normalize()
    local distToGround, groundPkPos = self:_castRay(kp1Pos, dir, 3)
    local endPos = endPosTmp:set(kp1Pos):addScaled(dir, distToGround)
    ac.drawDebugLine(kp1Pos, endPos, Color.white)

    local touchPos = data.wheels[ac.Wheel.FrontLeft].contactPoint

    ac.debug('c020 - kp1Pos', kp1Pos)
    ac.debug('c030 - kp0Pos', kp0Pos)
    ac.debug('c130 - kpGroundPos', groundPkPos)
    ac.debug('c140 - touchPos', touchPos)
end
local suspIniReader = require("scr_susp_ini_reader")
function Scrub:_updateSuspValues()
    self.kp0Coord, self.kp1Coord = suspIniReader:readKpCoord()

    self.wheelbase  = suspIniReader:readBasic('WHEELBASE')
    self.cog        = suspIniReader:readBasic('CG_LOCATION')

    self.frontBaseY = suspIniReader:readFront('BASEY')
    self.rimOffset  = suspIniReader:readFront('RIM_OFFSET')
    self.frontTrack = suspIniReader:readFront('TRACK')
end

function Scrub:_calcKp1Pos(isStrut)
    local kp1Pos = isStrut
        and self:_calcStrutKp1Pos(kp1PosTmp, self.kp1Coord)
        or self:_calcKpPos(kp1PosTmp, self.kp1Coord, self.rimOffset)
    return kp1Pos
end
function Scrub:_calcStrutKp1Pos(kpPos, kpCoord)
    local hubPos = data.position
        :addScaled(data.side, self.frontTrack * 0.5)
        :addScaled(data.up,   self.frontBaseY)
        :addScaled(data.look, self.wheelbase * (1-self.cog))
    kpPos:set(hubPos)
        :addScaled(data.side,-kpCoord.x)
        :addScaled(data.up,   kpCoord.y)
        :addScaled(data.look, kpCoord.z)
    return kpPos
end
function Scrub:_calcKpPos(kpPos, kpCoord, xOffset)
    local wheel = data.wheels[ac.Wheel.FrontLeft]
    local wheelPos = wheel.position
    kpPos:set(wheelPos)
        :addScaled(wheel.side, xOffset - kpCoord.x)
        :addScaled(wheel.up,   kpCoord.y)
        :addScaled(wheel.look, kpCoord.z)
    return kpPos
end
local touchPoint = vec3()
function Scrub:_castRay(worldPoint, dir, maxDist)
    local dist = physics.raycastTrack(worldPoint, dir, maxDist, touchPoint)
    return dist, touchPoint
end
return Scrub
