-- Script assembly
-- by: zgshnk -- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 zgshnk

local scr_prstr_a_ext   = require("scr_prstr_a_ext")

function update(dt)
    if car.isAIControlled then return end
    scr_prstr_a_ext(dt)
end
