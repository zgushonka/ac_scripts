-- Sound engine assembly
-- by: zgshnk -- SPDX-License-Identifier: MIT
-- Copyright (c) 2025 zgshnk

local function run_sound(dt)
    require("scr_prstr")(dt)
    require("scr_prstr_aeropass")(dt)
    require("scr_prstr_car_reflect")(dt)
end
return run_sound
