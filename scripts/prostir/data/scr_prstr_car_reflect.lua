-- Car reflect
-- by: zgshnk v1.40 20251111. Licensed under CC BY-NC-SA 4.0.
-- https://creativecommons.org/licenses/by-nc-sa/4.0/

local data = ac.accessCarPhysics()
local MAX_DIST = 35
local extCfg   = require("scr_prstr_cfg")
local VOL_Mult = extCfg.VolumeMult_otherCars
local chCount = 4
local con = ac.connect(
    {   ac.StructItem.key('zgshnk.car_sound_reflect.'..car.index),
        rpm = ac.StructItem.float(),
        pos = ac.StructItem.array(ac.StructItem.vec3() , chCount),
        vel = ac.StructItem.array(ac.StructItem.vec3() , chCount),
        vol = ac.StructItem.array(ac.StructItem.float(), chCount),
    },
    false, ac.SharedNamespace.Shared
)
local V = {
    zero = vec3(),
    side = vec3( 1, 0, 0),
    look = vec3( 0, 0, 1),
}

local posCar = {
    eng = vec3( 0.0, 0.0, -0.5),
    head= vec3():set(car.driverEyesPosition):add(car.graphicsOffset)
}

local function saveCh(ch, vel, pos, vol)
    con.vel[ch-1] = vel
    con.pos[ch-1] = pos
    con.vol[ch-1] = vol
end
local function resetCh(ch)
    con.vol[ch-1] = 0
end

local function resetVol()
    for i = 1, 4 do resetCh(i) end
end

local m_self_ws  = mat4x4()  -- self (physics) → world
local m_ws_self  = mat4x4()  -- world → self (physics)
local function refreshTransforms(myCar)
    m_self_ws:set(myCar.transform)
    m_ws_self:set(m_self_ws):inverseSelf()
end


local bCarWorldPos = vec3()
local bCarLocalPos, bCarLocalSide, bCarLocalLook = vec3(), vec3(), vec3()
local function updateOtherCarLocals(bCar)
    bCarWorldPos:set(bCar.position)
        :addScaled(bCar.up,-car.graphicsOffset.y)
    m_ws_self:transformPointTo(bCarLocalPos, bCarWorldPos)
    m_ws_self:transformVectorTo(bCarLocalLook, bCar.look)
    m_ws_self:transformVectorTo(bCarLocalSide, bCar.side)
end

local prevChPos = {}
local sndPosTmp, velTmp = vec3(), vec3()
local function calcVel(ch, sndPos)
    sndPosTmp:set(sndPos):sub(posCar.head)
    velTmp:set(sndPosTmp)
        :sub(prevChPos[ch])
        :scale(333)
    if velTmp:lengthSquared() > 100 then
        velTmp:set(0,0,0)
        -- self:resetFilters()
    end
    prevChPos[ch]:set(sndPosTmp)
    return velTmp
end


local othCarWallPosL = vec3()
local function updateOtherCarWall(bCar)
    local sideSign = bCarLocalPos.x > 0 and -1 or 1
    sideSign = sideSign * bCarLocalLook.z < 0 and -1 or 1
    local halfSide = sideSign * bCar.aabbSize.x * 0.5
    othCarWallPosL:set(bCarLocalPos)
        :addScaled(bCarLocalSide, halfSide)
end
local tmpReflPos = vec3()
local function reflectPosTo(out, engPos, otherCarPos, otherCarSide)
    tmpReflPos:set(engPos):sub(otherCarPos)
    local k = 2.0 * tmpReflPos:dot(otherCarSide)
    out:setScaled(otherCarSide, -k):add(engPos)
end
local reflSoundSidePos = vec3()
local function calcReflectSidePos(bCar)
    updateOtherCarWall(bCar)
    reflectPosTo(reflSoundSidePos,
        posCar.eng, othCarWallPosL, bCarLocalSide)
    return reflSoundSidePos
end

local othCarBumperPosL = vec3()
local function updateOtherCarBumper(bCar)
    local sideSign = bCarLocalPos.z > 0 and -1 or 1
    sideSign = sideSign * bCarLocalLook.z < 0 and -1 or 1
    local halfSide = sideSign * bCar.aabbSize.z * 0.5
    othCarBumperPosL:set(bCarLocalPos)
        :addScaled(bCarLocalLook, halfSide)
end
local reflSoundLookPos = vec3()
local function calcReflectLookPos(bCar)
    updateOtherCarBumper(bCar)
    reflectPosTo(reflSoundLookPos,
        posCar.eng, othCarBumperPosL, bCarLocalLook
    )
    return reflSoundLookPos
end


local otherCarLocalDir  = vec3()
local function calcMagnitude(bDir, bVec, exp)
    local dot = math.abs(bDir:dot(bVec))
    return dot^exp
end

local function limitAxle(vec, axle, size, scale)
    vec[axle] = math.clampN(
        vec[axle],
        bCarLocalPos[axle] - bCarLocalLook[axle] * size[axle] * scale,
        bCarLocalPos[axle] + bCarLocalLook[axle] * size[axle] * scale)
end

local function calcReflSound(ch, nearCar)
    local bCar = nearCar.car
    local bSize = bCar.aabbSize

    updateOtherCarLocals(bCar)
    local bDir = otherCarLocalDir:set(bCarLocalPos):normalize()

    local reflSoundSidePos1 = calcReflectSidePos(bCar)
    limitAxle(reflSoundSidePos1, 'z', bSize, 0.55)
    local volSide = calcMagnitude(bDir, bCarLocalSide, 2)

    local reflSoundLookPos2 = calcReflectLookPos(bCar)
    limitAxle(reflSoundSidePos1, 'x', bSize, 0.55)
    local volLook = calcMagnitude(bDir, bCarLocalLook, 10)

    local dotFront = math.abs(bDir:dot(V.look))
    local reflSoundPos = dotFront < 0.96
        and reflSoundSidePos1
        or  reflSoundLookPos2

    local realDist = math.distance(posCar.head, reflSoundPos)
    local vel = calcVel(ch, realDist)
    local vol = (volSide + volLook) * VOL_Mult
    saveCh(ch, vel, reflSoundPos, vol)
end

---@param carsNear ac.StateCar[]
local function reflectOn(carsNear)
    for i = 1, 1 do
        local aNearCar = carsNear[i]
        if aNearCar then
            calcReflSound(i, aNearCar)
        else
            resetCh(i)
        end
    end
end

local tmpPosW = vec3()
---@param myPos vec3
local function getCarsNear(myPos)
    local carsNear = {}
    for i, otherCar in ac.iterateCars() do
        if otherCar == nil then return end
        tmpPosW:set(otherCar.position)
            :addScaled(otherCar.up, -car.graphicsOffset.y)
        local dist = math.distance(myPos, tmpPosW)
        if otherCar ~= car and (dist < MAX_DIST) then
            local nearCar = { car = otherCar, dist = dist, }
            table.insert(carsNear, nearCar)
        end
    end
    table.sort(carsNear, function(a, b) return a.dist < b.dist end)
    return carsNear
end

local initDone = false
local function scr_prostir_cars(dt)
    if initDone == false then
        for i = 1, chCount do
            prevChPos[i] = vec3()
        end
        initDone = true
        return
    end
    if car.extraT or car.isAIControlled then
        resetVol()
    else
        refreshTransforms(data)
        con.rpm = data.rpm

        local carsNear = getCarsNear(data.position)
        reflectOn(carsNear)
    end
end
return scr_prostir_cars
