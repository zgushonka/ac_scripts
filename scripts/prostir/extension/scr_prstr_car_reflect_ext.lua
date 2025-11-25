-- Prostir ext reflect
-- by: zgshnk v1.42 20251124 -- SPDX-License-Identifier: MIT
-- Copyright (c) 2025 zgshnk

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


local carid = car:id()
local function makeSoundGroup()
    local engineExt = "cars/"..carid.."/engine_ext"
    -- local engineExtDirect = "cars/:own/engine_ext"
    local aCh = ac.AudioChannel.Engine
    -- local aCh = ac.AudioChannel.CarComponents
    return {
        cfg = {
            engExt = {
                name = engineExt,
                -- nameDirect = engineExtDirect,
                rev = true, occ = true, aCh = aCh
            }
        }
    }
end
local function loadAudioEvent(cfg)
    local sound = ac.AudioEvent(cfg.name, cfg.rev or true, cfg.occ or true)
    -- local sound = ac.AudioEvent(cfg.nameDirect, true)
    sound:setVolumeChannel(cfg.aCh)
    sound.cameraInteriorMultiplier = 1
    sound.cameraExteriorMultiplier = 1
    sound.cameraTrackMultiplier = 0
    return sound
end
local function loadSoundPack(sg)
    local sounds = {}
    for i = 1, chCount do
        table.insert(sounds, loadAudioEvent(sg.cfg.engExt))
    end
    return sounds
end

local dir = vec3()
---@param sound ac.AudioEvent
local function proccessSound(sound, rpm, vel, pos, vol, pit)
    local isPlaying = vol > 0.0001
    if isPlaying then
        dir:setScaled(pos, -1):normalize()
        sound:setParam('rpms', rpm)
            :setPosition(pos, dir, nil, vel)
        sound.volume = math.max(vol, 0.01)
        sound.pitch = pit
    end
    sound:resumeIf(isPlaying)
end


local function proccess(allSounds)
    for i = 1, #allSounds do
        local ci = i-1
        proccessSound(
            allSounds[i], con.rpm,
            con.vel[ci],
            con.pos[ci],
            con.vol[ci],
            1.015
        )
    end
end

local soundGroup, allSounds = {}, {}
local initDone = false
local function ext_prostir_cars(dt)
    if initDone == false then
        soundGroup = makeSoundGroup()
        allSounds = loadSoundPack(soundGroup)
        initDone = true
    end
    proccess(allSounds)
end
return ext_prostir_cars
