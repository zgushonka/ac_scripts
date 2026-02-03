-- Sound engine assembly
-- by: zgshnk 2026 -- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 zgshnk

local scr_prstr             = require("scr_prstr")
local scr_prstr_aeropass    = require("scr_prstr_aeropass")
local scr_prstr_car_reflect = require("scr_prstr_car_reflect")

local function run_sound(dt)
    scr_prstr(dt)
    scr_prstr_aeropass(dt)
    scr_prstr_car_reflect(dt)
end
return run_sound
