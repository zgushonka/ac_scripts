-- Wind sound
-- by: zgshnk v1.42 20251124 -- SPDX-License-Identifier: MIT
-- Copyright (c) 2025 zgshnk

local carid = car:id()

local chCount = 3
local con = ac.connect(
    {   ac.StructItem.key('zgshnk.aeropass.'..car.index),
        spd = ac.StructItem.array(ac.StructItem.float(), chCount),
        vol = ac.StructItem.array(ac.StructItem.float(), chCount),
        pos = ac.StructItem.array(ac.StructItem.vec3() , chCount),
    },
    false, ac.SharedNamespace.Shared
)

local function makeSoundGroup()
    local wind = "cars/"..carid.."/wind"
    local aCh = ac.AudioChannel.Wind
    -- local aCh = ac.AudioChannel.CarComponents
    return {
        cfg = {
            wind = {
                name = wind,
                rev = false, occ = false, aCh = aCh
            }
        }
    }
end
local function loadAudioEvent(cfg)
    local sound = ac.AudioEvent(cfg.name, cfg.rev or true, cfg.occ or true)
    sound:setVolumeChannel(cfg.aCh)
    sound.cameraInteriorMultiplier = 1
    sound.cameraExteriorMultiplier = 1
    sound.cameraTrackMultiplier = 0
    return sound
end
local function loadSoundPack(sg)
    local sounds = {}
    for i = 1, chCount do
        table.insert(sounds, loadAudioEvent(sg.cfg.wind))
    end
    return sounds
end

local dir = vec3()
---@param sound ac.AudioEvent
local function proccessSound(sound, pos, vol, spd)
    local isPlaying = vol > 0.0001
    if isPlaying then
        dir:setScaled(pos, -1):normalize()
        sound:setParam('speed', spd)
        sound:setPosition(pos, dir)
        sound.volume = vol
    end
    sound:resumeIf(isPlaying)
end
local function proccess(allSounds)
    for i = 1, #allSounds do
        local ci = i-1
        proccessSound(
            allSounds[i],
            con.pos[ci],
            con.vol[ci],
            con.spd[ci]
        )
    end
end

local soundGroup, allSounds = {}, {}
local initDone = false
local function ext_aeropass(dt)
    if initDone == false then
        soundGroup = makeSoundGroup()
        allSounds = loadSoundPack(soundGroup)
        initDone = true
    end
    proccess(allSounds)
end
return ext_aeropass
