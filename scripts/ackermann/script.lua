-- Script assembly
-- by: zgshnk -- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 zgshnk

local scr_ackermann          = require("scr_ackermann")

function script.update(dt)
    scr_ackermann:draw()
end
