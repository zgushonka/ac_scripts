-- Prostir ext
-- by: zgshnk v1.42 20251124 -- SPDX-License-Identifier: MIT
-- Copyright (c) 2025 zgshnk

local chCount = 9
local con = ac.connect(
    {   ac.StructItem.key('zgshnk.prostir.'..car.index),
        rpm = ac.StructItem.float(),
        pos = ac.StructItem.array(ac.StructItem.vec3(),  chCount),
        vel = ac.StructItem.array(ac.StructItem.vec3(),  chCount),
        vol = ac.StructItem.array(ac.StructItem.float(), chCount),
        pit = ac.StructItem.array(ac.StructItem.float(), chCount),
    },
    false, ac.SharedNamespace.Shared
)
local function makeSoundGroup()
    local engineExt = "cars/"..car:id().."/engine_ext"
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
    local sound = ac.AudioEvent(cfg.name, cfg.rev or true, cfg.occ or true )
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

---@param sound ac.AudioEvent
local function proccessCh(sound, ch)
    proccessSound(sound, con.rpm,
        con.vel[ch],
        con.pos[ch],
        con.vol[ch] or 0,
        con.pit[ch] or 1
    )
end
local function proccess(allSounds)
    for ch = 1, #allSounds do
        -- local ch = 6
        local sound = allSounds[ch]
        proccessCh(sound, ch-1)
    end
end

local soundGroup, allSounds = {}, {}
local initDone = false
local function ext_prostir(dt)
    if initDone == false then
        soundGroup = makeSoundGroup()
        allSounds = loadSoundPack(soundGroup)
        initDone = true
    end
    proccess(allSounds)
end
return ext_prostir
