-- Sound engine assembly
-- by: zgshnk v1.6 20241212 -- SPDX-License-Identifier: MIT
-- Copyright (c) 2025 zgshnk

local function prstr_assembly_ext(dt)
    require("scr_prstr_aeropass_ext")(dt)
    require("scr_prstr_ext")(dt)
    require("scr_prstr_car_reflect_ext")(dt)
end
return prstr_assembly_ext
