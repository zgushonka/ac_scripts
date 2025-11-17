-- Wipe windsheeld once.
-- by: zgshnk v1.01 20251030. -- SPDX-License-Identifier: MIT
-- Copyright (c) 2025 zgshnk

-- local data = ac.accessCarPhysics()

local waitSec = 0.3
local waitPeriod = const( math.round(waitSec * 333) )
local waitPeriodM1 = const( waitPeriod - 1 )

local cnt = 0
local function run_wiper(dt)                -- sqrt based sigmoid
    if car.extraS then
        cnt = waitPeriod
    end

    if cnt > 0 then
        if cnt == waitPeriodM1 then
            ac.setWiperMode(3)
        elseif cnt == 1 then
            ac.setWiperMode(0)
        end
        cnt = cnt - 1
    end
end
return run_wiper
