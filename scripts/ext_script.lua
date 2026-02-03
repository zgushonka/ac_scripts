-- Script assembly
-- by: zgshnk 2026 -- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 zgshnk

function update(dt)
    if car.isAIControlled then return end
    require("scr_click")(dt)
    require("scr_718_clock")(dt)
    require("scr_mode_ind")(dt)
    require("scr_prstr_a_ext")(dt)
end
