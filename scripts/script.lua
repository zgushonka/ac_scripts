-- Script assembly
-- by: zgshnk -- SPDX-License-Identifier: MIT
-- Copyright (c) 2025 zgshnk

function script.update(dt)

    require("scr_throttle_model")(dt)
    require("scr_prstr_a")(dt)
    require("scr_carium_start")(dt)
    require("scr_wiper_once")(dt)
    
    require("scr_turbo_lasers")(dt)
end
