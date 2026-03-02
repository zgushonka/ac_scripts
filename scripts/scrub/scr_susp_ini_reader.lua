-- suspension config reader 
-- by: zgshnk v1.02 2026. -- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 zgshnk

local Reader = {}
function Reader:readKpCoord()
    local frontInI = ac.INIConfig.carData(0, 'suspensions.ini').sections.FRONT
    local kp0 = self:_getKpVec(frontInI, 0)
    local kp1 = self:_getKpVec(frontInI, 1)
    ac.debug('r120 - kp0', kp0)
    ac.debug('r130 - kp1', kp1)
    return kp0, kp1
end
function Reader:readBasic(key)
    local basicInI = ac.INIConfig.carData(0, 'suspensions.ini').sections.BASIC
    local value = tonumber( basicInI[key][1] )
    ac.debug('r140 - basic.'..key, value)
    return value
end
function Reader:readFront(key)
    local basicInI = ac.INIConfig.carData(0, 'suspensions.ini').sections.FRONT
    local value = tonumber( basicInI[key][1] )
    ac.debug('r150 - front.'..key, value)
    return value
end

---@param frontInI table
---@param kpIndex number
function Reader:_getKpVec(frontInI, kpIndex)
    local kpString = self:_getKp(frontInI, kpIndex)
    if kpString == nil then return end
    local kpVec = vec3(
        tonumber(kpString[1]),
        tonumber(kpString[2]),
        tonumber(kpString[3])
    )
    return kpVec
end
function Reader:_getKp(frontInI, kpIndex)
    return self:_searchKpCoord(frontInI, kpIndex, "J", "_POS")
        or self:_searchKpCoord(frontInI, kpIndex, "DJ", "_POS_B")
end
function Reader:_searchKpCoord(frontInI, kpIndex, prefix, sufix)
    for i = 0, 10, 1 do
        local key = prefix..i.."_KP"
        local value = frontInI[key]
        if value ~= nil then
            local kp = tonumber( value[1] )
            if kp == kpIndex then
                return frontInI[prefix..i..sufix]
            end
        end
    end
    return nil
end
return Reader
