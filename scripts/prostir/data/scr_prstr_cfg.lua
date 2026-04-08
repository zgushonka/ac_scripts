-- Sound volume config 718
-- by: zgshnk v1.40 2026 -- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 zgshnk

-- Tune these values to affect sound effect volume.

local cfg = {
    -- Base config
    -- sound from track walls. Low pitch.
    VolumeMult_Walls_Low     = 5,

    -- sound from track walls. High pitch.
    VolumeMult_Walls_High    = 2,

    -- sound from other cars.
    VolumeMult_otherCars     = 2,
    VolDownMult = 0,

    -- Car related data
    -- bottom sound volume at elevation level.
    VolDownLut = ac.DataLUT11.parse(
"(|0=0.0|0.37=0.0|0.39=0.2|0.44=0.4|0.50=0.7|1.00=1.00|10=1.0|)"),

    eng2Fr =  1.5,
    eng2Re = -1.0,
    eng     = vec3( 0.0, 0.10, -0.5),
    engDn   = vec3( 0.0,-0.10, -0.5),
    Pitch_Low = 0.5,
}
return cfg
