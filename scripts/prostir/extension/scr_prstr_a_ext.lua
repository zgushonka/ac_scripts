-- Sound engine assembly
-- by: zgshnk -- SPDX-License-Identifier: MIT
-- Copyright (c) 2025 zgshnk

local scr_prstr_aeropass_ext    = require("scr_prstr_aeropass_ext")
local scr_prstr_ext             = require("scr_prstr_ext")
local scr_prstr_car_reflect_ext = require("scr_prstr_car_reflect_ext")

local function prstr_assembly_ext(dt)
    scr_prstr_aeropass_ext(dt)
    scr_prstr_ext(dt)
    scr_prstr_car_reflect_ext(dt)
end
return prstr_assembly_ext
