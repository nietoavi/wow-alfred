-- Core/Timer.lua — Alfred-Enchanting
-- C_Timer doesn't exist in TBC Classic. Simple multiplexer over the OnUpdate
-- of a hidden frame; the frame only runs while there are pending timers.
local _, A = ...
A.Timer = {}

local timerFrame = CreateFrame("Frame")
local timers = {}
timerFrame:Hide()
timerFrame:SetScript("OnUpdate", function(self, elapsed)
    for i = #timers, 1, -1 do
        timers[i].delay = timers[i].delay - elapsed
        if timers[i].delay <= 0 then
            local cb = timers[i].cb
            table.remove(timers, i)
            cb()
        end
    end
    if #timers == 0 then self:Hide() end
end)

function A.Timer.After(delay, func)
    table.insert(timers, { delay = delay, cb = func })
    timerFrame:Show()
end
