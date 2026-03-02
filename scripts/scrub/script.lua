-- Script assembly
-- by: zgshnk -- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 zgshnk

local scr_scrub = require("scr_scrub")

function script.update(dt)
    local isStrut = false
    scr_scrub:draw(isStrut)
end
