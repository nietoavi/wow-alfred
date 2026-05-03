-- Core/Minimap.lua — Alfred-Enchanting
-- Circular button anchored to the minimap. Left click: toggle main panel.
-- Shift+click: open Shopping List tab. Ctrl+click: open Config tab.
-- Drag: rotate around the minimap.
local _, A = ...
A.UI = A.UI or {}
A.UI.Minimap = {}

local minimapBtn

local function UpdateMinimapPosition()
    if not minimapBtn then return end
    local shared = A.DB.Shared()
    local angle = (shared and shared.minimapAngle) or 165
    local rad = math.rad(angle)
    local x = math.cos(rad) * 80  -- 80 = default Minimap radius
    local y = math.sin(rad) * 80
    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

A.UI.Minimap.UpdatePosition = UpdateMinimapPosition

function A.UI.Minimap.Create()
    if minimapBtn then return end
    if not Minimap then return end

    local btn = CreateFrame("Button", "AlfredEnchantingMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Icon (centered, slightly cropped to fit the ring)
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -5)
    icon:SetTexture("Interface\\Icons\\Trade_Engraving")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Minimap ring
    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Hover highlight
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    minimapBtn = btn
    UpdateMinimapPosition()

    -- Drag to rotate the position around the minimap
    btn:SetScript("OnDragStart", function(self) self.dragging = true end)
    btn:SetScript("OnDragStop",  function(self) self.dragging = false end)
    btn:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local mx, my = Minimap:GetCenter()
        if not mx then return end
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale() or 1
        px = px / scale
        py = py / scale
        local angle = math.deg(math.atan2(py - my, px - mx))
        local shared = A.DB.Shared()
        if shared then shared.minimapAngle = angle end
        UpdateMinimapPosition()
    end)

    btn:SetScript("OnClick", function(self, mouseBtn)
        if mouseBtn ~= "LeftButton" then return end
        local MP = A.UI.MainPanel
        -- Shift+click → open directly on the Shopping List tab
        if IsShiftKeyDown and IsShiftKeyDown() then
            A.Engine.SetSticky(true)
            MP.Show()
            if MP.ShowTab then MP.ShowTab("shopping") end
            return
        end
        -- Ctrl+click → open directly on the Config tab
        if IsControlKeyDown and IsControlKeyDown() then
            A.Engine.SetSticky(true)
            MP.Show()
            if MP.ShowTab then MP.ShowTab("config") end
            return
        end
        -- Plain click → toggle the main panel (default behavior)
        if MP.IsShown() then
            MP.Hide()
        else
            A.Engine.SetSticky(true)
            MP.Show()
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Alfred — Enchanting")
        local n = A.UI.MainPanel.GetCurrentStep()
        local total = A.UI.MainPanel.GetTotalSteps()
        local entry = A.UI.MainPanel.GetGuideEntry(n)
        if entry then
            GameTooltip:AddLine(string.format("|cffffd100Step %d/%d|r — %s", n, total, tostring(entry.spell)), 1, 1, 1, true)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffffffffClick|r — toggle main panel", 1, 1, 1, true)
        GameTooltip:AddLine("|cffffffffShift+click|r — Shopping List", 1, 1, 1, true)
        GameTooltip:AddLine("|cffffffffCtrl+click|r — Config", 1, 1, 1, true)
        GameTooltip:AddLine("|cffffffffDrag|r — move around the minimap", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function A.UI.Minimap.Show()
    if not minimapBtn then A.UI.Minimap.Create() end
    if minimapBtn then minimapBtn:Show() end
end

function A.UI.Minimap.Hide()
    if minimapBtn then minimapBtn:Hide() end
end
