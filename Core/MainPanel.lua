-- Core/MainPanel.lua — Alfred-Enchanting (Phase 5.2)
-- Artisan-style main panel: custom shell with header, Guide/Shopping List tabs,
-- skill progress bar, step rows with status badges, and a footer with the
-- secure cast button (our addition — Artisan has no direct cast).
--
-- Preserves 100% of the public API used by Engine/Slash/Minimap:
--   A.UI.MainPanel.Create / Show / Hide / IsShown / GetContainer / UpdateButton
--   A.UI.MainPanel.Refresh / SetStep / NextStep / PrevStep
--   A.UI.MainPanel.GetCurrentStep / GetTotalSteps / GetGuideEntry / GetKindColors
--   A.UI.MainPanel.GetSlotForSpell / GetItemForSlotKey / GetSlotLabel
--   A.UI.MainPanel.ApplyPin
--   AlfredEnchanting_RefreshGuide / AlfredEnchanting_UpdateButton (legacy globals)
local _, A = ...
A.UI = A.UI or {}
A.UI.MainPanel = {}

-- ============================================================================
-- Constants — minimalist dark palette (grayscale + 1 subtle accent)
-- ============================================================================
local C = {
    -- Primary / secondary / dim text
    white  = "|cffeaeaee",   -- primary text (near-white, unsaturated)
    gray   = "|cff9094a0",   -- secondary text (cool medium gray)
    dim    = "|cff5a5e68",   -- tertiary text / metadata
    -- Statuses (desaturated, no neon)
    green  = "|cff7fb87f",   -- ✓ (muted green)
    yellow = "|cffc8a070",   -- ⚠ (tobacco yellow)
    orange = "|cffc8966c",
    red    = "|cffc06868",   -- ✗ (muted red)
    -- Single accent (very subtle blue-gray), replaces cyan/purple/gold
    cyan   = "|cffa8b3c8",
    gold   = "|cffeaeaee",   -- gold ↦ primary white in this theme
    purple = "|cff8888a8",
    reset  = "|r",
}

local FRAME_W      = 520
local FRAME_H      = 600
local PAD          = 12
local HEADER_H     = 48
local ACCENT_H     = 2
local TOP_CHROME   = HEADER_H + ACCENT_H
local NAV_Y        = -(TOP_CHROME + 8)        -- nav row top
local TABS_Y       = -(TOP_CHROME + 40)       -- tabs row top
local BAR_Y        = -(TOP_CHROME + 72)       -- skill bar top
local CONTENT_Y    = -(TOP_CHROME + 100)      -- content panels top
local BAR_H        = 22
local FOOTER_H     = 140                       -- footer height (icon + spell + item + req + chips + Cast + status)
local CONTENT_BOTTOM = FOOTER_H + PAD

-- Desaturated kind badges — same medium gray for all, let the kind text speak
-- for itself. (The original neon colors broke the tone.)
local KIND_COLORS = {
    enchant = "ff9094a0",
    rod     = "ff9094a0",
    wand    = "ff9094a0",
    oil     = "ff9094a0",
    potion  = "ff9094a0",
    elixir  = "ff9094a0",
}

-- WoW tradeskill difficulty colors (orange/yellow/green/gray). Slightly toned
-- down from the in-game saturated values so they read on the dark theme.
local DIFFICULTY_COLORS = {
    orange = "|cffff8040",
    yellow = "|cffffd100",
    green  = "|cff40c040",
    gray   = "|cff808080",
}

-- ============================================================================
-- Module state
-- ============================================================================
local mainFrame             -- root frame
local currentTab = "guide"  -- "guide" | "shopping" | "config" | "trainer"
local prevTab = "guide"     -- last non-trainer tab; restored when trainer closes
local guidePanel, shoppingPanel, configPanel, trainerPanel
local skillBarTrack, skillBarFill, skillBarText
local navStepLabel, prevBtn, nextBtn, statusText
local tabGuide, tabShopping, tabConfig, tabTrainer
local castBtn, craft1Btn, macrosBtn         -- footer buttons (craft1Btn: single-craft, only for tradeskill kinds)
local footerIcon, footerIconTex             -- footer recipe icon (mirrors guide rows)
local footerSpellLabel, footerItemLabel, footerReqLabel, footerStatusLabel
local footerMatsContainer                   -- holds clickable material chip buttons
local selectedSlotKey = nil  -- slot the user marked for assignment via shift+click
local headerIcon, titleStr  -- header texture + title (refreshed when switching profession)
local profSwitcherBtn       -- caret/button next to the title that opens the profession menu

-- ============================================================================
-- Drawing helpers (TSM/Artisan style)
-- ============================================================================
local function MakeBorderLine(parent, side, r, g, b, a)
    local t = parent:CreateTexture(nil, "BORDER")
    -- Default border: very subtle so it doesn't pollute the design
    t:SetColorTexture(r or 0.16, g or 0.17, b or 0.20, a or 0.8)
    if side == "TOP" then
        t:SetHeight(1)
        t:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
        t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    elseif side == "BOTTOM" then
        t:SetHeight(1)
        t:SetPoint("BOTTOMLEFT",  parent, "BOTTOMLEFT",  0, 0)
        t:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    elseif side == "LEFT" then
        t:SetWidth(1)
        t:SetPoint("TOPLEFT",    parent, "TOPLEFT",    0, 0)
        t:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    elseif side == "RIGHT" then
        t:SetWidth(1)
        t:SetPoint("TOPRIGHT",    parent, "TOPRIGHT",    0, 0)
        t:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    end
    return t
end

local function MakeBox(parent)
    -- Outline a Frame with subtle 1px borders
    MakeBorderLine(parent, "TOP",    0.20, 0.22, 0.26, 0.7)
    MakeBorderLine(parent, "BOTTOM", 0.20, 0.22, 0.26, 0.7)
    MakeBorderLine(parent, "LEFT",   0.20, 0.22, 0.26, 0.7)
    MakeBorderLine(parent, "RIGHT",  0.20, 0.22, 0.26, 0.7)
end

-- Theme "accent" — was a cyan→purple gradient before, now a very subtle solid
-- line (blue-gray). Same signature, callers don't change.
local function ApplyGradient(tex)
    tex:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    tex:SetVertexColor(0.55, 0.60, 0.70, 0.85)
end

-- Flat button with 1px border and a subtle hover
local function MakeFlatButton(parent, label, w, h)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(w or 80, h or 22)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.14, 0.17, 0.23, 1.0)
    btn._bg = bg
    MakeBox(btn)
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("CENTER")
    lbl:SetText(label)
    lbl:SetTextColor(0.75, 0.85, 1.0, 1.0)
    btn._lbl = lbl
    btn:SetScript("OnEnter", function() btn._bg:SetColorTexture(0.22, 0.27, 0.36, 1.0) end)
    btn:SetScript("OnLeave", function() btn._bg:SetColorTexture(0.14, 0.17, 0.23, 1.0) end)
    btn:SetScript("OnDisable", function()
        btn._bg:SetColorTexture(0.08, 0.09, 0.12, 1.0)
        btn._lbl:SetTextColor(0.40, 0.42, 0.48, 1.0)
    end)
    btn:SetScript("OnEnable", function()
        btn._bg:SetColorTexture(0.14, 0.17, 0.23, 1.0)
        btn._lbl:SetTextColor(0.75, 0.85, 1.0, 1.0)
    end)
    return btn
end

-- TSM-style tab: dim text when inactive, white + gradient line when active
local function MakeTSMTab(parent, label, w)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(w or 138, 28)
    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0)
    tab._bg = bg
    local hl = tab:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.04)
    local lbl = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("CENTER", 0, 1)
    lbl:SetText(label)
    tab._lbl = lbl
    local accent = tab:CreateTexture(nil, "OVERLAY")
    accent:SetHeight(2)
    accent:SetPoint("BOTTOMLEFT",  tab, "BOTTOMLEFT",  4, 0)
    accent:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -4, 0)
    ApplyGradient(accent)
    accent:Hide()
    tab._accent = accent
    function tab:Activate()
        self._bg:SetColorTexture(0.13, 0.16, 0.22, 1.0)
        self._lbl:SetTextColor(1.0, 1.0, 1.0, 1.0)
        self._accent:Show()
    end
    function tab:Deactivate()
        self._bg:SetColorTexture(0, 0, 0, 0)
        self._lbl:SetTextColor(0.50, 0.55, 0.65, 1.0)
        self._accent:Hide()
    end
    tab:Deactivate()
    return tab
end

-- Secure button (SecureActionButtonTemplate only, without UIPanelButtonTemplate
-- which adds native textures that peek through on hover/click). The secure-click
-- dispatch is handled via a hidden proxy + SecureHandlerWrapScript inside
-- CreateMainFrame for castBtn — that's the reliable way to fire-on-click in
-- TBC Classic.
local function MakeFlatSecureButton(parent, name, label, w, h)
    local btn = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    btn:SetSize(w or 130, h or 26)
    -- Down + Up just in case — some builds expect both for the dispatch
    btn:RegisterForClicks("LeftButtonDown", "LeftButtonUp")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.13, 0.15, 0.18, 1.0)
    btn._bg = bg
    MakeBorderLine(btn, "TOP",    0.32, 0.36, 0.42, 0.9)
    MakeBorderLine(btn, "BOTTOM", 0.32, 0.36, 0.42, 0.9)
    MakeBorderLine(btn, "LEFT",   0.32, 0.36, 0.42, 0.9)
    MakeBorderLine(btn, "RIGHT",  0.32, 0.36, 0.42, 0.9)
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("CENTER")
    lbl:SetText(label)
    lbl:SetTextColor(0.92, 0.93, 0.95, 1.0)
    btn._lbl = lbl
    function btn:SetText(s) lbl:SetText(s) end
    btn:SetScript("OnEnter", function() btn._bg:SetColorTexture(0.20, 0.23, 0.28, 1.0) end)
    btn:SetScript("OnLeave", function() btn._bg:SetColorTexture(0.13, 0.15, 0.18, 1.0) end)
    btn:SetScript("OnDisable", function()
        btn._bg:SetColorTexture(0.08, 0.09, 0.11, 1.0)
        btn._lbl:SetTextColor(0.38, 0.40, 0.44, 1.0)
    end)
    btn:SetScript("OnEnable", function()
        btn._bg:SetColorTexture(0.13, 0.15, 0.18, 1.0)
        btn._lbl:SetTextColor(0.92, 0.93, 0.95, 1.0)
    end)
    return btn
end

-- ============================================================================
-- Lookup helpers (consumed by Slash, Engine, Minimap, RefreshGuide)
-- ============================================================================
function A.UI.MainPanel.GetSlotForSpell(spellName)
    if not spellName then return nil end
    local map = A.Profession.slotMap
    return map and map[spellName]
end

-- No fallback to defaults: if the user didn't assign anything, returns nil and
-- the macro shows "Configure item" until the user goes to the Config tab and
-- assigns one.
function A.UI.MainPanel.GetItemForSlotKey(slotKey)
    if not slotKey then return nil end
    local item = A.DB.GetSlotItem(slotKey)
    if item and item ~= "" then return item end
    return nil
end

function A.UI.MainPanel.GetSlotLabel(slotKey)
    local slots = A.Profession.slots
    if slots then
        for _, s in ipairs(slots) do
            if s.key == slotKey then return s.label end
        end
    end
    return slotKey or "?"
end

function A.UI.MainPanel.GetCurrentStep()
    local p = A.DB.Active()
    if not p then return 1 end
    local n = p.currentStep or 1
    if n < 1 then n = 1 end
    local data = A.Profession.data
    local total = (data and data.steps and #data.steps) or 1
    if n > total then n = total end
    -- If the persisted step landed on a header (e.g. data was edited), nudge
    -- forward to the next real step so the footer/macro never try to render
    -- a header as a recipe.
    while n <= total and data and data.steps and data.steps[n] and data.steps[n].kind == "header" do
        n = n + 1
    end
    if n > total then n = total end
    p.currentStep = n
    return n
end

function A.UI.MainPanel.GetTotalSteps()
    local data = A.Profession.data
    return (data and data.steps and #data.steps) or 0
end

function A.UI.MainPanel.GetGuideEntry(n)
    local data = A.Profession.data
    if data and data.steps and data.steps[n] then
        local s = data.steps[n]
        return {
            spell    = s.recipeName, kind = s.kind,
            range    = tostring(s.skillStart) .. "-" .. tostring(s.skillEnd),
            count    = s.quantity, optional = s.optional, notes = s.notes,
            skillStart   = s.skillStart, skillEnd = s.skillEnd,
            recipeName   = s.recipeName, quantity = s.quantity,
            materials    = s.materials, outputItemId = s.outputItemId, color = s.color,
        }
    end
    return nil
end

function A.UI.MainPanel.GetKindColors() return KIND_COLORS end

-- ============================================================================
-- Internal helpers
-- ============================================================================

-- Computes the "real status" of a step based on the player's current skill.
-- Returns one of: "done" | "now" | "next" | "alt" (optionals still relevant).
-- Important: if the skill has already passed skillEnd, the step is ALWAYS "done",
-- even if optional — an alt path that's already in the past is also completed.
local function ComputeStepStatus(step, currentSkill)
    if currentSkill and currentSkill > 0 and currentSkill >= step.skillEnd then
        return "done"
    end
    if step.optional then return "alt" end
    if not currentSkill or currentSkill == 0 then return "next" end
    if currentSkill >= step.skillStart then return "now" end
    return "next"
end

local function StatusBadge(status)
    -- Lowercase + muted colors. Status info is conveyed by ink density,
    -- not saturated hue.
    if status == "done" then return C.dim   .. "done" .. C.reset
    elseif status == "now"  then return C.white .. "now"  .. C.reset
    elseif status == "alt"  then return C.gray  .. "alt"  .. C.reset
    else                         return C.gray  .. "next" .. C.reset
    end
end

local function StatusBg(status, isSelected)
    -- No color tints by status. Only opacity/luminosity — all gray.
    -- The selected step is noticeably brighter (plus the side marker) so it
    -- stands out from steps that are merely "active by skill".
    if isSelected then
        return 0.20, 0.23, 0.28, 1.0
    end
    if status == "done" then return 0.05, 0.06, 0.07, 0.55
    elseif status == "now"  then return 0.10, 0.11, 0.13, 0.85
    elseif status == "alt"  then return 0.07, 0.08, 0.09, 0.55
    else                         return 0.07, 0.08, 0.09, 0.55
    end
end

-- ============================================================================
-- Render: Guide tab rows
-- ============================================================================
local function RenderGuideTab()
    if not guidePanel then return end
    local data = A.Profession.data
    if not data or not data.steps then return end

    -- Clear old child (Hide hides all its descendants)
    local old = guidePanel.scrollChild
    if old then old:Hide() end
    local child = CreateFrame("Frame", nil, guidePanel.scrollFrame)
    child:SetWidth(FRAME_W - PAD * 2 - 36)
    child:SetHeight(1)
    guidePanel.scrollFrame:SetScrollChild(child)
    guidePanel.scrollChild = child

    local currentSkill = select(1, A.Tradeskill.GetPlayerSkillRank()) or 0
    local selectedStep = A.UI.MainPanel.GetCurrentStep()
    local rowWidth = child:GetWidth()
    local totalH = 0

    for i, step in ipairs(data.steps) do
        -- Header row (kind == "header"): visual divider that groups the
        -- following steps. No icon, no badge, no click — just a strip with
        -- a label. The text comes from step.recipeName.
        if step.kind == "header" then
            local hRowH = 24
            local hRow = CreateFrame("Frame", nil, child)
            hRow:SetSize(rowWidth, hRowH)
            hRow:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -totalH)

            local hBg = hRow:CreateTexture(nil, "BACKGROUND")
            hBg:SetAllPoints()
            hBg:SetColorTexture(0.04, 0.05, 0.07, 0.95)

            -- Top + bottom hairlines so the band stands out from regular rows.
            local topLn = hRow:CreateTexture(nil, "ARTWORK")
            topLn:SetHeight(1)
            topLn:SetPoint("TOPLEFT",  hRow, "TOPLEFT",  0, 0)
            topLn:SetPoint("TOPRIGHT", hRow, "TOPRIGHT", 0, 0)
            topLn:SetColorTexture(0.20, 0.22, 0.30, 0.7)
            local botLn = hRow:CreateTexture(nil, "ARTWORK")
            botLn:SetHeight(1)
            botLn:SetPoint("BOTTOMLEFT",  hRow, "BOTTOMLEFT",  0, 0)
            botLn:SetPoint("BOTTOMRIGHT", hRow, "BOTTOMRIGHT", 0, 0)
            botLn:SetColorTexture(0.20, 0.22, 0.30, 0.7)

            local hLbl = hRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            hLbl:SetPoint("LEFT", hRow, "LEFT", 12, 0)
            hLbl:SetPoint("RIGHT", hRow, "RIGHT", -12, 0)
            hLbl:SetJustifyH("LEFT")
            hLbl:SetText(C.cyan .. (step.recipeName or "") .. C.reset)

            totalH = totalH + hRowH
        else

        local status = ComputeStepStatus(step, currentSkill)
        local isSelected = (i == selectedStep)

        -- Dynamic height based on content
        local hasNotes = step.notes and step.notes ~= ""
        local rowH = 50
        if hasNotes then rowH = rowH + 22 end

        -- Rows are SECURE so a click can additionally open the profession
        -- (when the active profession isn't enchanting and the tradeskill
        -- list isn't loaded yet). The macrotext is set by
        -- UpdateProfOpenerSecure; SetStep runs via HookScript alongside
        -- the secure dispatch.
        local row = CreateFrame("Button", nil, child, "SecureActionButtonTemplate")
        row:SetSize(rowWidth, rowH)
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -totalH)
        row:SetAttribute("type", "macro")
        UpdateProfOpenerSecure(row)

        -- Steps past the player's skill look disabled — reduced alpha affects
        -- all descendants (bg, icon, text) uniformly. Still clickable so the
        -- user can revisit one if needed.
        if status == "done" and not isSelected then
            row:SetAlpha(0.45)
        end

        -- Background
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(StatusBg(status, isSelected))

        -- Left marker (vertical bar) when the row is the selected step.
        -- 4px wide + subtle but clearly visible color over the lighter background.
        if isSelected then
            local marker = row:CreateTexture(nil, "ARTWORK")
            marker:SetWidth(4)
            marker:SetPoint("TOPLEFT",    row, "TOPLEFT",    0, 0)
            marker:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
            marker:SetTexture("Interface\\BUTTONS\\WHITE8X8")
            marker:SetVertexColor(0.85, 0.88, 0.95, 1.0)
        end

        -- Bottom separator line
        local sep = row:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  0, 0)
        sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        sep:SetColorTexture(0.18, 0.20, 0.26, 0.6)

        -- Tiny step number in the top-left corner
        local stepNum = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        stepNum:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -4)
        local sf, _, sflag = GameFontNormalSmall:GetFont()
        stepNum:SetFont(sf, 9, sflag)
        stepNum:SetTextColor(0.40, 0.43, 0.50)
        stepNum:SetText(tostring(i))

        -- Recipe icon (output item if present, fallback to spell icon)
        local iconTex = row:CreateTexture(nil, "ARTWORK")
        iconTex:SetSize(34, 34)
        iconTex:SetPoint("TOPLEFT", row, "TOPLEFT", 18, -8)
        iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        local iconPath
        if step.outputItemId then
            iconPath = select(10, GetItemInfo(step.outputItemId))
        end
        if not iconPath then iconPath = A.Spells.GetIcon(step.recipeName) end
        if not iconPath then iconPath = A.Profession.icon or "Interface\\Icons\\Trade_Engraving" end
        iconTex:SetTexture(iconPath)
        -- Desaturate + dim completed steps; the rest at 90% so the selected
        -- row (with marker) is the only point of maximum focus.
        if status == "done" then
            if iconTex.SetDesaturated then iconTex:SetDesaturated(true) end
            iconTex:SetVertexColor(0.50, 0.50, 0.50)
        elseif isSelected then
            iconTex:SetVertexColor(1.0, 1.0, 1.0)
        else
            iconTex:SetVertexColor(0.80, 0.82, 0.86)
        end

        -- (The recipe tooltip is wired on the row's OnEnter, below, so it
        -- covers the WHOLE row and clicks aren't absorbed by an overlay
        -- Button on top of the icon.)

        local textX = 60

        -- Line 1: badge + skill range + recipe name + (Nx) quantity
        -- Title color encodes "can you do this right now?":
        --   * past   (skill >= skillEnd)   → gray
        --   * future (skill < skillStart)  → red (can't cast yet)
        --   * now    (in range)            → WoW difficulty color (per step.color)
        local kindCol  = KIND_COLORS[step.kind or "enchant"] or "ffffd100"
        local skill    = currentSkill or 0
        local titleCol
        if skill >= step.skillEnd then
            titleCol = C.gray
        elseif skill < step.skillStart then
            titleCol = C.red
        else
            titleCol = DIFFICULTY_COLORS[step.color or "orange"] or C.white
        end
        local rangeStr = string.format("%d - %d", step.skillStart, step.skillEnd)
        local qtyStr   = step.quantity and ("  " .. C.dim .. tostring(step.quantity) .. "x" .. C.reset) or ""

        local line1 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        line1:SetPoint("TOPLEFT", row, "TOPLEFT", textX, -8)
        line1:SetPoint("RIGHT",   row, "RIGHT", -8, 0)
        line1:SetJustifyH("LEFT")
        line1:SetText(string.format("%s  %s%s%s  %s%s%s%s",
            StatusBadge(status),
            C.dim, rangeStr, C.reset,
            titleCol, step.recipeName, C.reset,
            qtyStr))

        -- Line 2: [KIND] badge + materials
        local matsStr = ""
        if step.materials and #step.materials > 0 then
            local parts = {}
            for _, m in ipairs(step.materials) do
                table.insert(parts, string.format("|c%s%dx %s|r", kindCol, m.quantity, m.name))
            end
            matsStr = table.concat(parts, "  ")
        end
        local line2 = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        line2:SetPoint("TOPLEFT", row, "TOPLEFT", textX, -28)
        line2:SetPoint("RIGHT",   row, "RIGHT", -8, 0)
        line2:SetJustifyH("LEFT")
        line2:SetTextColor(0.75, 0.78, 0.85)
        line2:SetText(string.format("|c%s[%s]|r  %s", kindCol, (step.kind or "?"):upper(), matsStr))

        -- Line 3: notes (gray)
        if hasNotes then
            local line3 = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            line3:SetPoint("TOPLEFT", row, "TOPLEFT", textX, -46)
            line3:SetPoint("RIGHT",   row, "RIGHT", -8, 0)
            line3:SetJustifyH("LEFT")
            line3:SetTextColor(0.55, 0.58, 0.65)
            line3:SetText("Note: " .. step.notes)
        end

        -- Click on the row → set as the selected step.
        -- Capture `i` and `step` by upvalue so the closure doesn't get
        -- confused with the loop's `i` when it executes later.
        -- HookScript so the secure dispatch (open profession via macrotext)
        -- still runs on TBC Classic; SetScript("OnClick") would replace
        -- the secure handler.
        local rowIdx, rowStep = i, step
        row:EnableMouse(true)
        row:RegisterForClicks("LeftButtonUp")
        row:HookScript("OnClick", function()
            A.UI.MainPanel.SetStep(rowIdx)
        end)
        row:SetScript("OnEnter", function(self)
            if not isSelected then
                bg:SetColorTexture(StatusBg(status, true))
            end
            -- Crafted-item tooltip (if applicable) when hovering ANY part of
            -- the row — including the icon.
            if rowStep.outputItemId then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. rowStep.outputItemId)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            if not isSelected then
                bg:SetColorTexture(StatusBg(status, false))
            end
            GameTooltip:Hide()
        end)

        totalH = totalH + rowH
        end  -- closes the `else` of the kind == "header" check
    end

    child:SetHeight(math.max(totalH, 1))
end

-- ============================================================================
-- Render: Shopping List tab — multi-column layout (Item / Need / Have / Buy /
-- Price ea.) plus an estimated total at the bottom. The list mixes two entry
-- kinds:
--   * Materials  — { id, name, count }
--   * Recipes    — { kind = "recipe", id, name, vendor, [req] }   (count = 1)
-- Recipes show below materials in a "Vendor recipes" section with a simpler
-- layout (vendor sub-line; no Buy/Price columns since they're vendor-bought).
--
-- Prices come from A.AHPrices.Get(itemId) — captured automatically when the
-- user clicks a row to AH-search. Items with no captured price show "—".
-- The bottom total sums (Buy × Price ea.) across materials with prices.
-- ============================================================================

-- Column geometry. Right edges are negative offsets from the row's right edge.
-- Each column reserves ~width characters of right-aligned space.
-- Layout (from name to right edge):
--   [Material .........] [Need] [Have] [Buy] [ Price ea. ] [   Total   ]
local COL_NEED_R   = -272
local COL_HAVE_R   = -228
local COL_BUY_R    = -184
local COL_PRICE_R  = -96   -- per-unit cost
local COL_TOTAL_R  = -8    -- Buy x Price, the rightmost (most-eye-catching) column
local COL_NAME_R   = -316  -- name's right edge sits just before Need

-- Coin-text helper: WoW's GetCoinTextureString already renders gold/silver/
-- copper icons inline. Falls back to plain "Ng Ms Kc" if unavailable.
local function FormatCoin(copper)
    if not copper or copper <= 0 then return nil end
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then return string.format("%dg %ds %dc", g, s, c) end
    if s > 0 then return string.format("%ds %dc", s, c) end
    return string.format("%dc", c)
end

local function RenderShoppingTab()
    if not shoppingPanel then return end

    local old = shoppingPanel.scrollChild
    if old then old:Hide() end
    local child = CreateFrame("Frame", nil, shoppingPanel.scrollFrame)
    child:SetWidth(FRAME_W - PAD * 2 - 36)
    child:SetHeight(1)
    shoppingPanel.scrollFrame:SetScrollChild(child)
    shoppingPanel.scrollChild = child

    local list = A.Profession.shoppingList or {}
    local rowWidth  = child:GetWidth()
    local rowH_mat  = 22
    -- Recipes need room for: name (may wrap to 2 lines for the longer formulas)
    -- + vendor sub-line (which itself wraps for vendors with H/A pairs +
    -- limited-supply notes) + padding. 68px covers the worst-case row.
    local rowH_rec  = 68
    -- Alt rows need extra height because the name carries the path label
    -- in parentheses ("Dreamfoil (Major Mana Potion, 17x)") and wraps to a
    -- second line on most realms. The extra 4px at the bottom acts as a
    -- visual gap between consecutive alt rows.
    local rowH_alt  = 42
    local sectionH  = 22
    local totalH    = 0

    -- Top hint
    local topHeader = CreateFrame("Frame", nil, child)
    topHeader:SetSize(rowWidth, 18)
    topHeader:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    local topBg = topHeader:CreateTexture(nil, "BACKGROUND")
    topBg:SetAllPoints()
    topBg:SetColorTexture(0.09, 0.10, 0.12, 0.9)
    local topLbl = topHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    topLbl:SetPoint("LEFT", topHeader, "LEFT", 8, 0)
    topLbl:SetText(string.format(
        "%sclick = AH (captures price) | shift+click = chat | right-click = Wowhead%s",
        C.dim, C.reset))
    totalH = totalH + 20

    if #list == 0 then
        local empty = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        empty:SetPoint("TOPLEFT", child, "TOPLEFT", 12, -(totalH + 12))
        empty:SetTextColor(0.6, 0.6, 0.6)
        empty:SetText("Shopping list is empty.")
        child:SetHeight(totalH + 40)
        return
    end

    -- Column header row for materials (Item / Need / Have / Buy / Price ea.)
    local function MakeColumnHeader()
        local h = CreateFrame("Frame", nil, child)
        h:SetSize(rowWidth, 18)
        h:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -totalH)
        local function Col(text, rightOffset, width)
            local f = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            f:SetPoint("RIGHT", h, "RIGHT", rightOffset, 0)
            f:SetWidth(width)
            f:SetJustifyH("RIGHT")
            f:SetTextColor(0.55, 0.58, 0.65)
            f:SetText(text)
        end
        local nameLbl = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameLbl:SetPoint("LEFT", h, "LEFT", 8, 0)
        nameLbl:SetTextColor(0.55, 0.58, 0.65)
        nameLbl:SetText("Material")
        Col("Need",      COL_NEED_R,  36)
        Col("Have",      COL_HAVE_R,  36)
        Col("Buy",       COL_BUY_R,   36)
        Col("Price ea.", COL_PRICE_R, 80)
        Col("Total",     COL_TOTAL_R, 80)
        local sep = h:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetPoint("BOTTOMLEFT",  h, "BOTTOMLEFT",  0, 0)
        sep:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 0)
        sep:SetColorTexture(0.20, 0.22, 0.30, 0.5)
        totalH = totalH + 18
    end

    -- Section header (small label with separator above)
    local function MakeSectionHeader(label)
        local h = CreateFrame("Frame", nil, child)
        h:SetSize(rowWidth, sectionH)
        h:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -totalH)
        local hb = h:CreateTexture(nil, "BACKGROUND")
        hb:SetAllPoints()
        hb:SetColorTexture(0.09, 0.10, 0.12, 0.9)
        local sep = h:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetPoint("TOPLEFT",  h, "TOPLEFT",  0, 0)
        sep:SetPoint("TOPRIGHT", h, "TOPRIGHT", 0, 0)
        sep:SetColorTexture(0.20, 0.22, 0.30, 0.5)
        local lbl = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", h, "LEFT", 8, 0)
        lbl:SetText(C.gray .. label .. C.reset)
        totalH = totalH + sectionH + 2
    end

    MakeColumnHeader()

    -- Pre-scan: build two sets so we can:
    --   1. Flag main rows whose item also appears in alts ("[also for alts]")
    --   2. SKIP alt rows whose item already lives in the main list (dedup)
    -- The dedup keeps each item visible exactly once. Alts then only show
    -- reagents EXCLUSIVE to alternative paths (Dreamfoil, Icecap, etc.).
    local mainIds, altIds = {}, {}
    for _, item in ipairs(list) do
        if item.id then
            local k = item.kind or "material"
            if k == "alt"      then altIds[item.id]  = true
            elseif k == "material" then mainIds[item.id] = true
            end
        end
    end

    -- Running subtotals — materials and recipes are summed independently so
    -- the footer can show each group on its own line.
    local matTotal, recTotal = 0, 0
    local lastKind

    for _, item in ipairs(list) do
      -- repeat ... until true is the Lua 5.1 idiom for "continue" (no goto).
      repeat
        local kind = item.kind or "material"

        -- Dedup: alt rows whose item is already covered by the main list are
        -- silently skipped (they'd just duplicate quantities). The "[also
        -- for alts]" marker on the corresponding main row tells the user
        -- it's also relevant to alternative paths.
        if kind == "alt" and item.id and mainIds[item.id] then
            break
        end

        if kind ~= lastKind then
            if kind == "recipe" then
                MakeSectionHeader("Vendor recipes")
            elseif kind == "alt" then
                MakeSectionHeader("Alternatives -- pick the cheapest path (totals excluded)")
            end
            lastKind = kind
        end

        if GetItemInfo and item.id then GetItemInfo(item.id) end

        local need = (kind == "recipe") and 1 or item.count
        -- Have includes bank (true = include bank).
        local have = (item.id and GetItemCount and GetItemCount(item.id, true)) or 0
        local buy  = math.max(0, need - have)
        local hasEnough = (have >= need)
        local rowH = (kind == "recipe") and rowH_rec
                  or (kind == "alt")    and rowH_alt
                  or rowH_mat
        -- Price lookup cascade for shopping list:
        --   1. Captured vendor price (live, includes rep discount)
        --   2. Hardcoded item.vendorPrice from the profession data
        --   3. Captured AH buyout (lowest seen on any scan)
        -- priceSource lets the renderer mark vendor prices with a "(v)" tag
        -- so the user knows where the number comes from.
        local price, priceSource
        if item.id and A.VendorPrices then
            local v = A.VendorPrices.Get(item.id)
            if v then price, priceSource = v, "vendor" end
        end
        if not price and item.vendorPrice then
            price, priceSource = item.vendorPrice, "vendor"
        end
        if not price and item.id and A.AHPrices then
            local ah = A.AHPrices.Get(item.id)
            if ah then price, priceSource = ah, "ah" end
        end
        local excluded = item.id and A.DB and A.DB.IsExcluded and A.DB.IsExcluded(item.id)

        -- Sum into the matching group only if not excluded.
        -- "alt" entries (alternative-path materials) NEVER contribute to totals
        -- -- they exist as info only, since the player only follows one path.
        if not excluded and price and buy > 0 and kind ~= "alt" then
            if kind == "material" then matTotal = matTotal + (buy * price)
            else                       recTotal = recTotal + (buy * price)
            end
        end

        local row = CreateFrame("Button", nil, child)
        row:SetSize(rowWidth, rowH)
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -totalH)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        -- Excluded rows render at low alpha so they're clearly de-emphasized
        -- but still readable. The user can shift+click again to re-include.
        if excluded then row:SetAlpha(0.4) end
        if kind == "alt" and not excluded then row:SetAlpha(0.7) end

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.07, 0.08, 0.09, 0.55)

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.04)

        -- Icon
        local iconTex = row:CreateTexture(nil, "ARTWORK")
        iconTex:SetSize(16, 16)
        local iconTop = (kind == "recipe" or kind == "alt") and 6 or 3
        iconTex:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -iconTop)
        iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        local iconPath = item.id and select(10, GetItemInfo(item.id))
        iconTex:SetTexture(iconPath or "Interface\\Icons\\INV_Misc_QuestionMark")
        if hasEnough then iconTex:SetVertexColor(0.55, 0.58, 0.62) end

        -- Name (with optional "(excluded)" suffix when applicable). For
        -- recipes we strip the redundant "Formula: " prefix — the section
        -- header already labels the group.
        local displayName = item.name
        if kind == "recipe" then
            displayName = displayName:gsub("^Formula:%s*", "")
        end
        local nameLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLbl:SetPoint("TOPLEFT", iconTex, "TOPRIGHT", 6, 1)
        nameLbl:SetPoint("RIGHT",   row, "RIGHT", COL_NAME_R, 0)
        nameLbl:SetJustifyH("LEFT")
        local nameText = hasEnough and (C.dim .. displayName .. C.reset) or (C.white .. displayName .. C.reset)
        if excluded then
            nameText = nameText .. "  " .. C.dim .. "(excluded)" .. C.reset
        end
        -- Cross-ref: if this is a main material AND its id also appears in
        -- an alt path entry, hint that the same item also covers alternatives
        -- (the alt row itself is dedup'd away). Skip for "alt" and "recipe".
        if kind == "material" and item.id and altIds[item.id] then
            nameText = nameText .. "  " .. C.cyan .. "[also for alts]" .. C.reset
        end
        nameLbl:SetText(nameText)

        -- Recipes also get a vendor / req sub-line below the name.
        if kind == "recipe" then
            local subLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            subLbl:SetPoint("TOPLEFT", nameLbl, "BOTTOMLEFT", 0, -1)
            subLbl:SetPoint("RIGHT",   row,     "RIGHT", COL_NAME_R, 0)
            subLbl:SetJustifyH("LEFT")
            subLbl:SetTextColor(0.55, 0.58, 0.65)
            local sub = item.vendor or ""
            if item.req then
                sub = sub .. "   " .. C.dim .. "| " .. item.req .. C.reset
            end
            subLbl:SetText(sub)
        end

        -- Need / Have / Buy / Price ea. columns. Same for both kinds when an
        -- itemId is available; recipes without an id show a status pill.
        local function ColText(text, rightOffset, width)
            local f = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            f:SetPoint("TOPRIGHT", row, "TOPRIGHT", rightOffset, -3)
            f:SetWidth(width)
            f:SetJustifyH("RIGHT")
            f:SetText(text)
            return f
        end

        if not item.id then
            -- Recipes (or anything) without verified id can't show counts/price.
            local statusLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            statusLbl:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -3)
            statusLbl:SetText(C.dim .. "?" .. C.reset)
        else
            -- Need (gray)
            ColText(C.dim .. tostring(need) .. C.reset, COL_NEED_R, 36)

            -- Have (green if >= need, red if 0, white otherwise)
            local haveCol
            if have >= need then haveCol = C.green
            elseif have == 0 then haveCol = C.red
            else                  haveCol = C.white end
            ColText(haveCol .. tostring(have) .. C.reset, COL_HAVE_R, 36)

            -- Buy (red if > 0, "--" if 0)
            local buyText = (buy > 0)
                and (C.red .. tostring(buy) .. C.reset)
                or  (C.dim .. "--" .. C.reset)
            ColText(buyText, COL_BUY_R, 36)

            -- Price ea. (formatted coin + "(v)" suffix when sourced from a
            -- vendor instead of the AH).
            local priceText
            if price then
                priceText = FormatCoin(price)
                if priceSource == "vendor" then
                    priceText = priceText .. " " .. C.dim .. "(v)" .. C.reset
                end
            else
                priceText = C.dim .. "--" .. C.reset
            end
            ColText(priceText, COL_PRICE_R, 80)

            -- Total = Buy x Price ea. White when there's something to buy
            -- and we have a price; dim "--" otherwise. Doesn't render the
            -- (v) marker -- that lives on Price ea.
            local totalText
            if price and buy > 0 then
                totalText = C.white .. (FormatCoin(buy * price) or "--") .. C.reset
            else
                totalText = C.dim .. "--" .. C.reset
            end
            ColText(totalText, COL_TOTAL_R, 80)
        end

        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if item.id then GameTooltip:SetHyperlink("item:" .. item.id) end
            GameTooltip:AddLine(" ")
            local ctrlHint = excluded
                and "ctrl+click = re-include in totals"
                or  "ctrl+click = exclude from totals"
            GameTooltip:AddLine(string.format(
                "%sclick%s = AH (captures price) | %sshift+click%s = chat | %s%s%s | %sright-click%s = Wowhead",
                C.dim, C.reset, C.dim, C.reset, C.dim, ctrlHint, C.reset, C.dim, C.reset), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnClick", function(self, button)
            -- Ctrl+click on a shopping row → toggle exclusion from the group
            -- total. Intercepted before falling through to the generic
            -- Items.HandleClick (which handles plain click, shift+click chat
            -- link, and right-click Wowhead).
            if button == "LeftButton" and IsControlKeyDown and IsControlKeyDown() then
                if item.id and A.DB and A.DB.ToggleExclude then
                    A.DB.ToggleExclude(item.id)
                    if A.UI.MainPanel.UpdateButton then A.UI.MainPanel.UpdateButton() end
                end
                return
            end
            A.Items.HandleClick(item.id, item.name, button)
        end)

        totalH = totalH + rowH
      until true
    end

    -- Update the sticky three-line footer with both subtotals + grand total.
    local function FooterText(total)
        if total > 0 then return C.white .. (FormatCoin(total) or "0") .. C.reset end
        return C.dim .. "-- (click items to capture prices)" .. C.reset
    end
    if shoppingPanel.matTotalVal then shoppingPanel.matTotalVal:SetText(FooterText(matTotal)) end
    if shoppingPanel.recTotalVal then shoppingPanel.recTotalVal:SetText(FooterText(recTotal)) end
    if shoppingPanel.sumTotalVal then
        local grand = matTotal + recTotal
        if grand > 0 then
            shoppingPanel.sumTotalVal:SetText(C.white .. (FormatCoin(grand) or "0") .. C.reset)
        else
            shoppingPanel.sumTotalVal:SetText(C.dim .. "--" .. C.reset)
        end
    end

    child:SetHeight(math.max(totalH, 1))
end

-- ============================================================================
-- Render: Config tab — list of editable slots. Workflow:
--   1. Click a row → marks the slot as "selectedSlotKey".
--   2. Shift+click an item in your bag → assigned to the selected slot
--      (intercepted by the hook in Config.lua, which calls
--       A.UI.MainPanel.AssignSelectedSlot).
--   3. The X button on each row clears that slot.
--   4. "Apply suggested items" at the bottom applies AlfredEnchantingDefaults
--      to all slots.
-- ============================================================================
local function RenderConfigTab()
    if not configPanel then return end

    local old = configPanel.scrollChild
    if old then old:Hide() end
    local child = CreateFrame("Frame", nil, configPanel.scrollFrame)
    child:SetWidth(FRAME_W - PAD * 2 - 36)
    child:SetHeight(1)
    configPanel.scrollFrame:SetScrollChild(child)
    configPanel.scrollChild = child

    local slots = (A.Profession and A.Profession.slots) or {}
    local rowWidth = child:GetWidth()
    local rowH = 30
    local totalH = 0

    -- Profession with no per-slot target items (Alchemy, Cooking, etc.):
    -- show a placeholder explaining there's nothing to configure.
    if #slots == 0 then
        local empty = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        empty:SetPoint("TOPLEFT", child, "TOPLEFT", 12, -16)
        empty:SetPoint("RIGHT",   child, "RIGHT",   -12, 0)
        empty:SetJustifyH("LEFT")
        empty:SetTextColor(0.65, 0.68, 0.75)
        empty:SetText(string.format(
            "%s does not require per-slot target items.\nThe macro casts the recipe directly — no configuration needed.",
            (A.Profession and A.Profession.name) or "This profession"))
        child:SetHeight(80)
        return
    end

    -- Header with instructions
    local headerRow = CreateFrame("Frame", nil, child)
    headerRow:SetSize(rowWidth, 36)
    headerRow:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    local headerBg = headerRow:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0.09, 0.10, 0.12, 0.9)
    local headerLbl = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerLbl:SetPoint("TOPLEFT", headerRow, "TOPLEFT", 8, -4)
    headerLbl:SetPoint("RIGHT",   headerRow, "RIGHT", -8, 0)
    headerLbl:SetJustifyH("LEFT")
    headerLbl:SetText(string.format(
        "%s1.%s click a row to select the slot.   %s2.%s shift+click the item in your bag.",
        C.white, C.reset, C.white, C.reset))
    local hintLbl = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintLbl:SetPoint("BOTTOMLEFT", headerRow, "BOTTOMLEFT", 8, 4)
    hintLbl:SetPoint("RIGHT",      headerRow, "RIGHT", -8, 0)
    hintLbl:SetJustifyH("LEFT")
    hintLbl:SetTextColor(0.55, 0.58, 0.65)
    hintLbl:SetText(string.format("Default items apply if you leave a slot empty. /alfred set <slot> <item> also works."))
    totalH = totalH + 38

    -- Slot rows
    local defaults = (A.Profession and A.Profession.slotDefaults) or {}
    for _, slotDef in ipairs(slots) do
        local slotKey = slotDef.key
        local item    = A.DB.GetSlotItem(slotKey)
        local isSel   = (selectedSlotKey == slotKey)

        local row = CreateFrame("Button", nil, child)
        row:SetSize(rowWidth, rowH)
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -totalH)
        row:EnableMouse(true)
        row:RegisterForClicks("LeftButtonUp")

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        if isSel then
            bg:SetColorTexture(0.20, 0.23, 0.28, 1.0)
        else
            bg:SetColorTexture(0.07, 0.08, 0.09, 0.55)
        end

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.04)

        -- Side marker if selected
        if isSel then
            local marker = row:CreateTexture(nil, "ARTWORK")
            marker:SetWidth(4)
            marker:SetPoint("TOPLEFT",    row, "TOPLEFT",    0, 0)
            marker:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
            marker:SetTexture("Interface\\BUTTONS\\WHITE8X8")
            marker:SetVertexColor(0.85, 0.88, 0.95, 1.0)
        end

        -- Bottom separator
        local sep = row:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  0, 0)
        sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        sep:SetColorTexture(0.18, 0.20, 0.26, 0.5)

        -- Slot label (left)
        local slotLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        slotLbl:SetPoint("LEFT", row, "LEFT", 12, 0)
        slotLbl:SetWidth(160)
        slotLbl:SetJustifyH("LEFT")
        slotLbl:SetText(isSel and (C.white .. slotDef.label .. C.reset) or (C.gray .. slotDef.label .. C.reset))

        -- Assigned item (center). "unassigned" is the primary default state.
        -- If the wow-professions guide suggests an item for this slot, it is
        -- shown as a dim hint afterwards — but the macro DOES NOT use it
        -- until the user assigns it explicitly.
        local itemLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        itemLbl:SetPoint("LEFT", slotLbl, "RIGHT", 12, 0)
        itemLbl:SetPoint("RIGHT", row, "RIGHT", -50, 0)
        itemLbl:SetJustifyH("LEFT")
        if item and item ~= "" then
            itemLbl:SetText(C.white .. item .. C.reset)
        else
            local def = defaults[slotKey]
            if def and def ~= "" then
                itemLbl:SetText(string.format("%sunassigned%s   %s| guide: %s%s",
                    C.dim, C.reset, C.dim, def, C.reset))
            else
                itemLbl:SetText(C.dim .. "unassigned" .. C.reset)
            end
        end

        -- X (clear) button on the right — only if an item is explicitly assigned
        if item and item ~= "" then
            local clearBtn = CreateFrame("Button", nil, row)
            clearBtn:SetSize(20, 20)
            clearBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            clearBtn:RegisterForClicks("LeftButtonUp")
            local clearLbl = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            clearLbl:SetPoint("CENTER")
            clearLbl:SetText("X")
            clearLbl:SetTextColor(0.55, 0.58, 0.65)
            clearBtn:SetScript("OnEnter", function() clearLbl:SetTextColor(0.95, 0.50, 0.50) end)
            clearBtn:SetScript("OnLeave", function() clearLbl:SetTextColor(0.55, 0.58, 0.65) end)
            clearBtn:SetScript("OnClick", function()
                A.DB.SetSlotItem(slotKey, "")
                -- UpdateButton triggers a re-render of the Config tab + footer
                if AlfredEnchanting_UpdateButton then AlfredEnchanting_UpdateButton() end
                print(string.format("|cff5a5e68[Alfred:Enchanting]|r %s cleared.", slotDef.label))
            end)
        end

        -- Hover tooltip (slot item, if any)
        local rowItem = item
        row:SetScript("OnEnter", function(self)
            if rowItem and rowItem ~= "" then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if GameTooltip.SetItemByName then
                    GameTooltip:SetItemByName(rowItem)
                else
                    local _, link = GetItemInfo(rowItem)
                    if link then GameTooltip:SetHyperlink(link)
                    else GameTooltip:AddLine(rowItem) end
                end
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Click → mark slot as selected
        local rowKey, rowLabel = slotKey, slotDef.label
        row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnClick", function()
            selectedSlotKey = rowKey
            -- UpdateButton fires RefreshAll → re-renders the Config tab with the marker on the new slot
            if AlfredEnchanting_UpdateButton then AlfredEnchanting_UpdateButton() end
            print(string.format("|cff7fb87f[Alfred:Enchanting]|r Active slot: |cffeaeaee%s|r — shift+click the item in your bag.", rowLabel))
        end)

        totalH = totalH + rowH
    end

    -- Bottom button: apply guide suggestions to all slots
    -- (overwrites existing assignments — asks for confirmation).
    totalH = totalH + 8
    local applyBtn = MakeFlatButton(child, "Apply suggested items", 200, 22)
    applyBtn:SetPoint("TOPLEFT", child, "TOPLEFT", 8, -totalH)
    applyBtn:RegisterForClicks("LeftButtonUp")
    applyBtn:SetScript("OnClick", function()
        StaticPopup_Show("ALFRED_RESET_SLOT_DEFAULTS")
    end)
    totalH = totalH + 30

    child:SetHeight(math.max(totalH, 1))
end

-- Shared StaticPopup to confirm importing the guide's suggestions.
StaticPopupDialogs["ALFRED_RESET_SLOT_DEFAULTS"] = {
    text    = "Apply the items suggested by the wow-professions guide to all slots?\nCurrent assignments will be overwritten.",
    button1 = "Yes, apply",
    button2 = "Cancel",
    OnAccept = function()
        local defaults = (A.Profession and A.Profession.slotDefaults) or {}
        for k, v in pairs(defaults) do
            A.DB.SetSlotItem(k, v)
        end
        if AlfredEnchanting_UpdateButton then AlfredEnchanting_UpdateButton() end
        if currentTab == "config" then RenderConfigTab() end
        print("|cff7fb87f[Alfred:Enchanting]|r Defaults applied.")
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- Public API: assignment from shift+click in bag (called by Config.lua via hook).
-- Returns true if something was assigned, false if no slot was selected or the tab is inactive.
function A.UI.MainPanel.AssignSelectedSlot(itemLink)
    if currentTab ~= "config" then return false end
    if not selectedSlotKey then
        -- Visible hint to the user: if they're on the config tab and didn't
        -- click a slot, explain the flow.
        print("|cffc8a070[Alfred:Enchanting]|r Click a slot in the list first, then shift+click the item.")
        return false
    end
    if not itemLink then return false end
    local itemName = GetItemInfo(itemLink) or itemLink:match("%[(.-)%]")
    if not itemName then return false end

    A.DB.SetSlotItem(selectedSlotKey, itemName)

    -- Look up the slot label for the print
    local slotLabel = selectedSlotKey
    local slots = (A.Profession and A.Profession.slots) or {}
    for _, s in ipairs(slots) do
        if s.key == selectedSlotKey then slotLabel = s.label; break end
    end

    -- UpdateButton → RefreshAll → re-renders the active tab (Config) + footer.
    if AlfredEnchanting_UpdateButton then AlfredEnchanting_UpdateButton() end
    print(string.format("|cff7fb87f[Alfred:Enchanting]|r |cffeaeaee%s|r -> |cffeaeaee%s|r",
        itemName, slotLabel))
    return true
end

function A.UI.MainPanel.GetSelectedSlot() return selectedSlotKey end
function A.UI.MainPanel.SetSelectedSlot(key) selectedSlotKey = key end

-- ============================================================================
-- Render: Trainer tab. Lists guide recipes available at the open trainer
-- with [Learn] buttons and a "Learn All Available" call-to-action. Driven
-- by Core/Trainer.lua via OpenTrainerTab/CloseTrainerTab.
-- ============================================================================
local function FormatCoinShort(copper)
    if not copper or copper <= 0 then return "free" end
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then return string.format("%dg %ds %dc", g, s, c) end
    if s > 0 then return string.format("%ds %dc", s, c) end
    return string.format("%dc", c)
end

local function RenderTrainerTab()
    if not trainerPanel then return end
    local old = trainerPanel.scrollChild
    if old then old:Hide() end
    local child = CreateFrame("Frame", nil, trainerPanel.scrollFrame)
    child:SetWidth(FRAME_W - PAD * 2 - 36)
    child:SetHeight(1)
    trainerPanel.scrollFrame:SetScrollChild(child)
    trainerPanel.scrollChild = child

    local rowWidth = child:GetWidth()
    local totalH = 0

    -- Header strip
    local count, totalCost, matches = 0, 0, {}
    if A.Trainer and A.Trainer.ScanOpen then
        count, totalCost, matches = A.Trainer.ScanOpen()
    end

    local headerRow = CreateFrame("Frame", nil, child)
    headerRow:SetSize(rowWidth, 36)
    headerRow:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    local hdrBg = headerRow:CreateTexture(nil, "BACKGROUND")
    hdrBg:SetAllPoints()
    hdrBg:SetColorTexture(0.09, 0.10, 0.12, 0.9)
    local hdrLbl = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrLbl:SetPoint("TOPLEFT", headerRow, "TOPLEFT", 8, -4)
    hdrLbl:SetPoint("RIGHT",   headerRow, "RIGHT", -8, 0)
    hdrLbl:SetJustifyH("LEFT")
    if count == 0 then
        hdrLbl:SetText(C.dim .. "No guide recipes match this trainer's offering." .. C.reset)
    else
        local availN = 0
        for _, m in ipairs(matches) do
            if m.kind == "available" then availN = availN + 1 end
        end
        hdrLbl:SetText(string.format("%sFrom your guide:|r %s%d here|r %s(%d available now)|r",
            C.dim, C.white, count, C.dim, availN))
    end
    local hdrSub = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrSub:SetPoint("BOTTOMLEFT", headerRow, "BOTTOMLEFT", 8, 4)
    hdrSub:SetPoint("RIGHT",      headerRow, "RIGHT", -8, 0)
    hdrSub:SetJustifyH("LEFT")
    hdrSub:SetTextColor(0.55, 0.58, 0.65)
    hdrSub:SetText("Click [Learn] on a row, or use the Learn All button at the bottom.")
    totalH = totalH + 38

    if count == 0 then
        child:SetHeight(totalH + 20)
        return
    end

    -- Sort: available first, then unavailable, ordered by skillStart.
    table.sort(matches, function(a, b)
        if a.kind ~= b.kind then return a.kind == "available" end
        return (a.step.skillStart or 0) < (b.step.skillStart or 0)
    end)

    local rowH = 30
    for _, m in ipairs(matches) do
        local row = CreateFrame("Frame", nil, child)
        row:SetSize(rowWidth, rowH)
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -totalH)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.07, 0.08, 0.09, 0.55)

        if m.kind ~= "available" then row:SetAlpha(0.55) end

        -- Left: name + range
        local nameLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLbl:SetPoint("LEFT", row, "LEFT", 10, 0)
        local rangeStr = (m.step.skillStart and m.step.skillEnd)
            and string.format("  %s%d-%d|r", C.dim, m.step.skillStart, m.step.skillEnd) or ""
        nameLbl:SetText((m.kind == "available" and C.white or C.dim) .. m.name .. C.reset .. rangeStr)

        -- Right: cost + button (or status pill if not available)
        if m.kind == "available" then
            local btn = MakeFlatButton(row, "Learn", 60, 22)
            btn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            btn:RegisterForClicks("LeftButtonUp")
            local capturedName = m.name
            btn:SetScript("OnClick", function()
                if A.Trainer and A.Trainer.LearnByName then
                    A.Trainer.LearnByName(capturedName)
                    -- TRAINER_UPDATE will fire and re-render the tab.
                end
            end)
            local costLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            costLbl:SetPoint("RIGHT", btn, "LEFT", -8, 0)
            costLbl:SetTextColor(0.85, 0.85, 0.55)
            costLbl:SetText(FormatCoinShort(m.cost))
        else
            local statusLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            statusLbl:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            statusLbl:SetTextColor(0.55, 0.58, 0.65)
            statusLbl:SetText(m.kind == "used" and "already learned" or "skill too low")
        end

        local sep = row:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  0, 0)
        sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        sep:SetColorTexture(0.18, 0.20, 0.26, 0.5)

        totalH = totalH + rowH
    end

    -- Bottom: Learn All button + total cost
    totalH = totalH + 12
    local availCount, availCost = 0, 0
    for _, m in ipairs(matches) do
        if m.kind == "available" then
            availCount = availCount + 1
            availCost  = availCost + (m.cost or 0)
        end
    end
    if availCount > 0 then
        local learnAllBtn = MakeFlatButton(child, string.format("Learn All Available (%d)", availCount), 240, 26)
        learnAllBtn:SetPoint("TOPLEFT", child, "TOPLEFT", 8, -totalH)
        learnAllBtn:RegisterForClicks("LeftButtonUp")
        learnAllBtn:SetScript("OnClick", function()
            if A.Trainer and A.Trainer.LearnAll then
                local n, spent = A.Trainer.LearnAll()
                print(string.format("|cff00ff00[Alfred]|r Learned %d recipe%s for %s.",
                    n, n == 1 and "" or "s", FormatCoinShort(spent)))
            end
        end)
        local totLbl = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        totLbl:SetPoint("LEFT", learnAllBtn, "RIGHT", 12, 0)
        totLbl:SetText(string.format("%sTotal:|r %s%s|r", C.dim, C.white, FormatCoinShort(availCost)))
        totalH = totalH + 32
    end

    child:SetHeight(math.max(totalH, 1))
end

-- ============================================================================
-- Render: footer (icon + Cast + req + chips + status, fed by currentStep)
-- ============================================================================

-- Build a single clickable material chip — same look-and-feel as a shopping
-- list row, but compact so several fit in a single line. Click handler is
-- routed through A.Items.HandleClick (left=AH, shift+left=chat, right=Wowhead).
local function MakeMatChip(parent, mat, hasEnough, have, need)
    local chip = CreateFrame("Button", nil, parent)
    chip:SetHeight(20)
    chip:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local bg = chip:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if hasEnough then
        bg:SetColorTexture(0.13, 0.16, 0.20, 0.85)
    else
        bg:SetColorTexture(0.30, 0.10, 0.10, 0.85)  -- muted red for missing
    end
    chip._bg = bg
    MakeBox(chip)

    local hl = chip:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)

    local ico = chip:CreateTexture(nil, "ARTWORK")
    ico:SetSize(14, 14)
    ico:SetPoint("LEFT", chip, "LEFT", 4, 0)
    ico:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local iconPath = mat.itemId and select(10, GetItemInfo(mat.itemId))
    ico:SetTexture(iconPath or "Interface\\Icons\\INV_Misc_QuestionMark")
    if not hasEnough then ico:SetVertexColor(1.0, 0.85, 0.85) end

    local lbl = chip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", ico, "RIGHT", 4, 0)
    if hasEnough then
        lbl:SetText(string.format("%s%dx%s %s%s%s",
            C.dim, need, C.reset,
            C.white, mat.name, C.reset))
    else
        lbl:SetText(string.format("%s%dx%s %s%s%s %s(%d/%d)%s",
            C.red, need, C.reset,
            C.white, mat.name, C.reset,
            C.dim, have, need, C.reset))
    end
    chip:SetWidth(lbl:GetStringWidth() + 14 + 4 + 4 + 8)

    local matId, matName = mat.itemId, mat.name
    chip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if matId then GameTooltip:SetHyperlink("item:" .. matId) end
        GameTooltip:AddLine(string.format("%sHave %d / Need %d%s",
            C.dim, have, need, C.reset), 1, 1, 1)
        GameTooltip:AddLine(string.format(
            "%sclick%s = AH | %sshift+click%s = chat | %sright-click%s = Wowhead",
            C.dim, C.reset, C.dim, C.reset, C.dim, C.reset), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    chip:SetScript("OnClick", function(self, btn)
        A.Items.HandleClick(matId, matName, btn)
    end)
    return chip
end

local function RenderFooter()
    if not footerSpellLabel then return end
    local step = A.UI.MainPanel.GetCurrentStep()
    local entry = A.UI.MainPanel.GetGuideEntry(step)
    if not entry then return end

    local kind     = entry.kind or "enchant"
    local kindCol  = KIND_COLORS[kind] or "ffffd100"
    local slot     = (kind == "enchant") and A.UI.MainPanel.GetSlotForSpell(entry.spell) or nil
    local item     = slot and A.UI.MainPanel.GetItemForSlotKey(slot)
    local qtyStr   = entry.quantity and ("  " .. C.dim .. tostring(entry.quantity) .. "x" .. C.reset) or ""
    local optBadge = entry.optional and ("  " .. C.cyan .. "[OPT]" .. C.reset) or ""

    footerSpellLabel:SetText(string.format(
        "%s>%s  |c%s[%s]|r  %s%s%s%s%s",
        C.gold, C.reset,
        kindCol, kind:upper(),
        C.white, entry.spell, C.reset,
        qtyStr, optBadge))

    -- Recipe icon (same logic as guide rows): output item if available, then
    -- spell icon, then profession default. Wires the icon's click + tooltip
    -- to the crafted item when an outputItemId exists.
    if footerIcon and footerIconTex then
        local iconPath
        if entry.outputItemId then
            if GetItemInfo then GetItemInfo(entry.outputItemId) end  -- prime cache
            iconPath = select(10, GetItemInfo(entry.outputItemId))
        end
        if not iconPath then iconPath = A.Spells.GetIcon(entry.spell) end
        if not iconPath then iconPath = A.Profession.icon or "Interface\\Icons\\Trade_Engraving" end
        footerIconTex:SetTexture(iconPath)
        footerIconTex:SetVertexColor(1.0, 1.0, 1.0)
        footerIcon._itemId    = entry.outputItemId
        footerIcon._spellName = entry.spell
        footerIcon._kind      = kind
    end

    if footerItemLabel then
        if kind == "enchant" then
            if item and item ~= "" then
                footerItemLabel:SetText(string.format(
                    "%s->%s %s%s%s  %s(%s)%s",
                    C.gray, C.reset,
                    C.gold, item, C.reset,
                    C.dim, A.UI.MainPanel.GetSlotLabel(slot), C.reset))
                footerItemLabel:Show()
            else
                footerItemLabel:SetText(string.format(
                    "%s-> no item for %s -- /alfred config%s",
                    C.red, A.UI.MainPanel.GetSlotLabel(slot or "?"), C.reset))
                footerItemLabel:Show()
            end
        else
            footerItemLabel:SetText(string.format("%sCrafted item — no target or popup%s", C.dim, C.reset))
            footerItemLabel:Show()
        end
    end

    -- Requirements check
    local req = { learned = true, hasAllMats = true, missingMats = {} }
    local ok, r = pcall(A.Reagents.CheckStep, entry)
    if ok and r then req = r end

    -- Req label: keep the recipe-learned signal here; missing-mats info is now
    -- conveyed by red chips below.
    if footerReqLabel then
        if not req.learned then
            footerReqLabel:SetText(C.red .. "[x] Recipe not learned -- train it" .. C.reset)
        elseif req.hasAllMats then
            footerReqLabel:SetText(C.green .. "[ok] Recipe learned  |  [ok] Mats OK" .. C.reset)
        else
            footerReqLabel:SetText(C.green .. "[ok] Recipe learned" .. C.reset
                .. "   " .. C.orange .. "[x] Missing materials" .. C.reset)
        end
    end

    -- Material chips (clickable like shopping rows). Rebuild every refresh so
    -- counts stay accurate when bag contents change.
    if footerMatsContainer then
        for _, c in ipairs(footerMatsContainer._chips or {}) do
            c:Hide()
            c:SetParent(nil)
        end
        footerMatsContainer._chips = {}

        if entry.materials and #entry.materials > 0 then
            local total = entry.quantity or entry.count or 1
            local x = 0
            for _, m in ipairs(entry.materials) do
                local needPerCast = (total > 0) and math.ceil(m.quantity / total) or m.quantity
                local have = (m.itemId and GetItemCount and GetItemCount(m.itemId, true)) or 0
                local hasEnough = have >= needPerCast
                if m.itemId and GetItemInfo then GetItemInfo(m.itemId) end  -- prime cache
                local chip = MakeMatChip(footerMatsContainer, m, hasEnough, have, needPerCast)
                chip:SetPoint("LEFT", footerMatsContainer, "LEFT", x, 0)
                x = x + chip:GetWidth() + 6
                table.insert(footerMatsContainer._chips, chip)
            end
        end
    end

    -- SecureActionButton + sync of the real macro.
    -- Strategy: instead of inline `macrotext` (which sometimes fails in TBC
    -- Classic with SecureActionButtonTemplate alone, without
    -- UIPanelButtonTemplate), point the button at the NAMED macro that
    -- A.Macro.Update keeps in the game's macro list. The secure handler only
    -- needs "macro=AlfredEnchant" — more robust.
    local body = A.Macro.Build(entry.spell, item, kind)
    local inCombat = InCombatLockdown and InCombatLockdown()
    local needsItem = (kind == "enchant")
    local canBuild  = entry.spell and (not needsItem or (item and item ~= ""))

    -- For tradeskill crafts, compute how many we can do RIGHT NOW from bag
    -- and embed it in the macro so a single click queues the whole batch
    -- (server runs them ~1s apart, abort on movement). For enchants we keep
    -- a count of 1 since each cast targets a single item slot.
    --
    -- Three caps applied in order:
    --   1) matsAvailable    -- how many crafts the bag actually supports
    --   2) step.quantity    -- the guide's recommended count for this step
    --   3) craftsToSkillEnd -- color-based estimate of crafts left before
    --      the player levels past skillEnd; prevents wasting mats on green/
    --      gray crafts past the point of usefulness.
    -- skillCapped flag tells the button it should say "Step complete" when
    -- the third cap drove maxCrafts to 0 (i.e. the goal is already met).
    local maxCrafts, skillCapped = 1, false
    if kind ~= "enchant" then
        local fromMats   = (A.Reagents.MaxCraftsFor and A.Reagents.MaxCraftsFor(entry)) or 1
        local fromGuide  = entry.quantity or fromMats
        local fromSkill  = (A.Reagents.CraftsToReachSkillEnd and A.Reagents.CraftsToReachSkillEnd(entry)) or math.huge
        maxCrafts = math.min(fromMats, fromGuide, fromSkill)
        skillCapped = (fromSkill == 0)
        if maxCrafts < 1 then maxCrafts = skillCapped and 0 or 1 end
    end

    -- 1) Keep the real macro in sync first (the button reads it by name)
    local macroOk, macroInfo
    if canBuild and not inCombat then
        macroOk, macroInfo = A.Macro.Update(entry.spell, item, kind, maxCrafts)
    end

    -- 2) Set macro on castBtn. Pass the numeric INDEX returned by
    --    A.Macro.Update — some versions of the secure dispatch only accept a
    --    number (not a name). If idx isn't a number, fall back to the name.
    if castBtn then
        local canCast = canBuild and not inCombat and req.learned and req.hasAllMats and macroOk
        if not inCombat then
            castBtn:SetAttribute("macrotext", nil)
            if canCast then
                local target = (type(macroInfo) == "number") and macroInfo or A.Profession.MacroName
                castBtn:SetAttribute("macro", target)
            else
                castBtn:SetAttribute("macro", nil)
            end
        end
        -- For tradeskill kinds (potion/elixir/rod/wand/oil), DoTradeSkill
        -- needs the recipe list to be cached, which only happens after the
        -- profession window has been opened ONCE this session. If the list
        -- is empty we keep the button enabled (so the user can still try)
        -- but flag it visually with "Open profession" so they know what to do.
        local needsTradeskillList = (kind ~= "enchant")
        local tradeskillListLoaded = (GetNumTradeSkills and GetNumTradeSkills() or 0) > 0
        -- The single-craft companion button is only meaningful for
        -- tradeskill kinds (an enchant always casts on a single item, so
        -- there's no "1 vs N" choice). Reanchor macrosBtn so the layout
        -- doesn't leave a hole when craft1Btn is hidden.
        if craft1Btn then
            if kind == "enchant" then
                craft1Btn:Hide()
                if macrosBtn then
                    macrosBtn:ClearAllPoints()
                    macrosBtn:SetPoint("LEFT", castBtn, "RIGHT", 6, 0)
                end
            else
                craft1Btn:Show()
                if macrosBtn then
                    macrosBtn:ClearAllPoints()
                    macrosBtn:SetPoint("LEFT", craft1Btn, "RIGHT", 6, 0)
                end
                if not inCombat then
                    -- Macrotext directly (avoids needing a 2nd named macro).
                    -- /run with DoTradeSkill works fine via macrotext.
                    local body1 = A.Macro.Build(entry.spell, item, kind, 1)
                    craft1Btn:SetAttribute("macro", nil)
                    craft1Btn:SetAttribute("macrotext", body1 or "")
                end
                if canCast and tradeskillListLoaded then
                    craft1Btn:Enable()
                else
                    craft1Btn:Disable()
                end
            end
        end

        if canCast then
            if needsTradeskillList and not tradeskillListLoaded then
                castBtn:Enable()
                castBtn:SetText("Open profession once")
            elseif kind == "enchant" then
                castBtn:Enable()
                castBtn:SetText("Enchant")
            elseif skillCapped then
                -- Skill goal met (current rank >= step.skillEnd or prof cap).
                -- Disable the bulk button: nothing more to gain here.
                castBtn:Disable()
                castBtn:SetText("Step complete")
            else
                -- Show batch size so the user knows how many they're queueing.
                castBtn:Enable()
                castBtn:SetText(string.format("Craft (%d)", maxCrafts))
            end
        else
            castBtn:Disable()
            if inCombat then              castBtn:SetText("(combat)")
            elseif not canBuild then      castBtn:SetText("Configure item")
            elseif not req.learned then   castBtn:SetText("No recipe")
            elseif not req.hasAllMats then castBtn:SetText("Missing mats")
            elseif not macroOk then        castBtn:SetText("Macro fail")
            else                           castBtn:SetText(kind == "enchant" and "Enchant" or "Craft")
            end
        end
    end

    -- 3) Footer status text
    if footerStatusLabel then
        if canBuild then
            if macroOk then
                footerStatusLabel:SetText(string.format("%sMacro %s updated (id=%s)%s",
                    C.green, A.Profession.MacroName, tostring(macroInfo), C.reset))
            elseif inCombat then
                footerStatusLabel:SetText(C.dim .. "Macro: in combat (not updated)" .. C.reset)
            else
                footerStatusLabel:SetText(string.format("%sMacro: %s%s", C.orange, tostring(macroInfo), C.reset))
            end
        else
            footerStatusLabel:SetText(C.dim .. "Macro: configure an item first" .. C.reset)
        end
    end
end

-- ============================================================================
-- Secure macrotext helper: makes any SecureActionButton additionally open
-- the active profession's tradeskill window when clicked. We only set the
-- macrotext when:
--   * the active profession is NOT enchanting (kind != "enchant" everywhere)
--   * the tradeskill list isn't already cached (GetNumTradeSkills == 0)
-- That way, once the list IS loaded, clicking prev/next no longer toggles
-- the window open/closed (the /cast on a tradeskill spell toggles its UI).
-- Combat-safe: SetAttribute calls are no-ops in lockdown.
-- ============================================================================
local function UpdateProfOpenerSecure(button)
    if not button or not button.SetAttribute then return end
    if InCombatLockdown and InCombatLockdown() then return end

    local def = A.Profession
    local skill = def and def.skillName
    local listLoaded = (GetNumTradeSkills and GetNumTradeSkills() or 0) > 0
    -- Detect "enchant-style" profession by inspecting its first non-header
    -- step's kind (if all are "enchant", we don't auto-open).
    local isEnchant = false
    if def and def.data and def.data.steps then
        for _, s in ipairs(def.data.steps) do
            if s.kind and s.kind ~= "header" then
                isEnchant = (s.kind == "enchant")
                break
            end
        end
    end

    if not skill or isEnchant or listLoaded then
        button:SetAttribute("macrotext", nil)
    else
        button:SetAttribute("macrotext", "/cast " .. skill)
    end
end

-- ============================================================================
-- Profession switcher menu (UIDropDownMenu)
-- ============================================================================
local profMenuFrame
local function BuildProfessionMenu()
    if profMenuFrame then return profMenuFrame end
    profMenuFrame = CreateFrame("Frame", "AlfredProfessionMenu", UIParent, "UIDropDownMenuTemplate")
    UIDropDownMenu_Initialize(profMenuFrame, function(self, level)
        local activeId = Alfred.GetActiveProfessionId()
        for _, id in ipairs(Alfred.GetRegisteredProfessions()) do
            local def = Alfred.GetProfession(id)
            local learned, rank, max = Alfred.IsProfessionLearned(id)
            local info = UIDropDownMenu_CreateInfo()
            local marker = learned and "[*] " or "[ ] "
            info.text = marker .. (def.name or id)
                       .. (learned and string.format("  (%d/%d)", rank or 0, max or 0)
                                    or "  (not learned)")
            info.checked = (id == activeId)
            info.func = function()
                A.Engine.SwitchProfession(id)
                CloseDropDownMenus()
            end
            info.notCheckable = false
            UIDropDownMenu_AddButton(info, level)
        end
    end, "MENU")
    return profMenuFrame
end

function A.UI.MainPanel.ToggleProfessionMenu(anchor)
    local menu = BuildProfessionMenu()
    ToggleDropDownMenu(1, nil, menu, anchor or "cursor", 0, 0)
end

-- Called by Engine.SwitchProfession after activeId/A.Profession have flipped.
-- Refreshes the bits that were captured at Create() time (icon + title) and
-- then re-runs RefreshAll so the rest of the panel reflects the new data.
function A.UI.MainPanel.OnProfessionChanged()
    if not mainFrame then return end
    if headerIcon then
        headerIcon:SetTexture(A.Profession.icon or "Interface\\Icons\\Trade_Engraving")
    end
    if titleStr then
        titleStr:SetText(string.format("%sAlfred%s  -  %s  %s[v]%s",
            C.cyan, C.reset, A.Profession.name or "Profession", C.dim, C.reset))
    end
    -- Reset selected slot — the new profession may not have any.
    selectedSlotKey = nil
    if A.UI.MainPanel.Refresh then A.UI.MainPanel.Refresh() end
end

-- ============================================================================
-- Render: skill bar + nav step label
-- ============================================================================
local function RenderHeaderInfo()
    local data = A.Profession.data
    local maxSkill = (data and data.maxSkill) or 375
    local activeId = Alfred and Alfred.GetActiveProfessionId and Alfred.GetActiveProfessionId() or nil
    local learned, lRank, lMax
    if activeId and Alfred.IsProfessionLearned then
        learned, lRank, lMax = Alfred.IsProfessionLearned(activeId)
    end
    -- A.Tradeskill.GetPlayerSkillRank reads from the active tradeskill window,
    -- which only works when the trainer/tradeskill UI is open. The skill-line
    -- API (cached in Registry) is always available for learned professions.
    local rank    = (learned and lRank) or A.Tradeskill.GetPlayerSkillRank() or 0
    local maxRank = (learned and lMax)  or (select(2, A.Tradeskill.GetPlayerSkillRank())) or 0

    if skillBarFill and skillBarText then
        local barW = (FRAME_W - PAD * 2 - 18 - 2)  -- track interior width
        local pct = math.max(0, math.min((rank or 0) / maxSkill, 1))
        skillBarFill:SetWidth(math.max(1, barW * pct))
        if learned then
            skillBarText:SetText(string.format(
                "%s%s%s   %s%d|r %s/ %d  (cap %d)|r",
                C.cyan, A.Profession.skillName or A.Profession.name or "Skill", C.reset,
                C.white, rank,
                C.dim, maxSkill,
                maxRank))
        else
            -- Single-line "not learned" notice rendered inside the skill bar so
            -- it doesn't push content panels around. Yellow tint draws the eye
            -- without needing an extra strip below the bar.
            skillBarText:SetText(string.format(
                "|cffe6b870[!] %s -- not learned (reference view)|r",
                A.Profession.name or "This profession"))
        end
    end

    -- Keep the prev/next nav buttons' "open profession" macrotext fresh.
    -- Re-evaluated on every refresh so it self-clears as soon as the
    -- tradeskill list is loaded (avoids the /cast toggling the window).
    UpdateProfOpenerSecure(prevBtn)
    UpdateProfOpenerSecure(nextBtn)

    if navStepLabel then
        local cur   = A.UI.MainPanel.GetCurrentStep()
        local total = A.UI.MainPanel.GetTotalSteps()
        local entry = A.UI.MainPanel.GetGuideEntry(cur)
        local rangeText = entry and string.format("  %s| %d-%d|r",
            C.dim, entry.skillStart or 0, entry.skillEnd or 0) or ""
        navStepLabel:SetText(string.format("%sStep|r %s%d / %d%s%s",
            C.dim, C.white, cur, total, C.reset, rangeText))
    end

    if statusText then
        local ver = (GetAddOnMetadata and GetAddOnMetadata("Alfred", "Version")) or ""
        statusText:SetText((ver ~= "" and (C.dim .. "v" .. ver .. C.reset) or ""))
    end
end

-- ============================================================================
-- Main refresh: re-renders everything. Called by A.UI.MainPanel.Refresh.
-- ============================================================================
local function RefreshAll()
    if not mainFrame then return end
    RenderHeaderInfo()
    if currentTab == "guide" then
        RenderGuideTab()
    elseif currentTab == "shopping" then
        RenderShoppingTab()
    elseif currentTab == "config" then
        RenderConfigTab()
    elseif currentTab == "trainer" then
        if RenderTrainerTab then RenderTrainerTab() end
    end
    RenderFooter()
end

A.UI.MainPanel.Refresh = RefreshAll
AlfredEnchanting_RefreshGuide = RefreshAll

-- Throttled refresh used by GET_ITEM_INFO_RECEIVED. Flood of events at boot
-- (one per item) collapses into a single RefreshAll after a short delay.
local iconRefreshScheduled = false
function A.UI.MainPanel.QueueIconRefresh()
    if iconRefreshScheduled or not mainFrame then return end
    iconRefreshScheduled = true
    A.Timer.After(0.5, function()
        iconRefreshScheduled = false
        if mainFrame and mainFrame:IsShown() then RefreshAll() end
    end)
end

-- ============================================================================
-- ShowTab: switch between Guide / Shopping List / Config
-- ============================================================================
local function ShowTab(which)
    -- Remember the previous non-trainer tab so we can restore it when the
    -- trainer window closes (we don't want users stranded on an empty tab).
    if which ~= "trainer" then prevTab = which end
    currentTab = which
    -- Show the matching panel, hide the others
    if guidePanel    then if which == "guide"    then guidePanel:Show()    else guidePanel:Hide()    end end
    if shoppingPanel then if which == "shopping" then shoppingPanel:Show() else shoppingPanel:Hide() end end
    if configPanel   then if which == "config"   then configPanel:Show()   else configPanel:Hide()   end end
    if trainerPanel  then if which == "trainer"  then trainerPanel:Show()  else trainerPanel:Hide()  end end
    -- Activate the matching tab, deactivate the others
    if tabGuide    then if which == "guide"    then tabGuide:Activate()    else tabGuide:Deactivate()    end end
    if tabShopping then if which == "shopping" then tabShopping:Activate() else tabShopping:Deactivate() end end
    if tabConfig   then if which == "config"   then tabConfig:Activate()   else tabConfig:Deactivate()   end end
    if tabTrainer  then if which == "trainer"  then tabTrainer:Activate()  else tabTrainer:Deactivate()  end end
    RefreshAll()
end

-- Called by Core/Trainer.lua when a trainer window opens/closes.
-- Reveals the Trainer tab, auto-shows the panel, and switches to it.
function A.UI.MainPanel.OpenTrainerTab()
    if not mainFrame then A.UI.MainPanel.Create() end
    if tabTrainer then tabTrainer:Show() end
    A.UI.MainPanel.Show()
    ShowTab("trainer")
end

function A.UI.MainPanel.CloseTrainerTab()
    if tabTrainer then tabTrainer:Hide() end
    -- If the user was on the Trainer tab when the trainer closed, fall
    -- back to whatever they were viewing before (kept in prevTab).
    if currentTab == "trainer" then
        ShowTab(prevTab or "guide")
    end
end

A.UI.MainPanel.ShowTab = ShowTab
A.UI.MainPanel.GetCurrentTab = function() return currentTab end

-- ============================================================================
-- Step navigation
-- ============================================================================
local function IsHeaderStep(n)
    local data = A.Profession and A.Profession.data
    local s = data and data.steps and data.steps[n]
    return s and s.kind == "header"
end

-- When SetStep lands on a header (via direct /alfred step N or via
-- next/prev), advance in the requested direction until we hit a real step
-- or run out. `dir` defaults to +1 (forward).
local function SkipHeaders(n, dir)
    local total = A.UI.MainPanel.GetTotalSteps()
    dir = dir or 1
    while n >= 1 and n <= total and IsHeaderStep(n) do
        n = n + dir
    end
    if n < 1 then n = 1 end
    if n > total then n = total end
    return n
end

local function SetStep(n)
    local p = A.DB.Active()
    if not p then return end
    local total = A.UI.MainPanel.GetTotalSteps()
    if n < 1 then n = 1 end
    if n > total then n = total end
    if IsHeaderStep(n) then n = SkipHeaders(n, 1) end
    p.currentStep = n
    RefreshAll()
end

A.UI.MainPanel.SetStep  = SetStep
A.UI.MainPanel.NextStep = function() SetStep(SkipHeaders(A.UI.MainPanel.GetCurrentStep() + 1,  1)) end
A.UI.MainPanel.PrevStep = function() SetStep(SkipHeaders(A.UI.MainPanel.GetCurrentStep() - 1, -1)) end

-- ============================================================================
-- CreateMainFrame: draws the entire custom shell
-- ============================================================================
function A.UI.MainPanel.Create()
    if mainFrame then return end

    local f = CreateFrame("Frame", "AlfredEnchantingContainer", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    -- HIGH so we sit above UnitFrames and most WeakAuras.
    -- StaticPopups (used for "Apply suggested items") live in
    -- FULLSCREEN_DIALOG and always draw on top — no conflict.
    f:SetFrameStrata("HIGH")
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint(1)
        local shared = A.DB.Shared()
        if shared then shared.framePos = { point = p, relPoint = rp, x = x, y = y } end
    end)
    f:Hide()
    mainFrame = f

    -- Initial position
    f:ClearAllPoints()
    local shared = A.DB.Shared()
    local pos = shared and shared.framePos
    if pos and pos.point then
        f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    end

    -- Main background — neutral, almost black with a hint of cool gray
    local mainBg = f:CreateTexture(nil, "BACKGROUND")
    mainBg:SetAllPoints()
    mainBg:SetColorTexture(0.06, 0.07, 0.08, 0.97)

    -- Outer border
    MakeBorderLine(f, "TOP")
    MakeBorderLine(f, "BOTTOM")
    MakeBorderLine(f, "LEFT")
    MakeBorderLine(f, "RIGHT")

    -- =========================================================================
    -- HEADER
    -- =========================================================================
    local headerBg = f:CreateTexture(nil, "BACKGROUND")
    headerBg:SetHeight(HEADER_H)
    headerBg:SetPoint("TOPLEFT",  f, "TOPLEFT",  1, -1)
    headerBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    headerBg:SetColorTexture(0.09, 0.10, 0.12, 1.0)

    local headerSep = f:CreateTexture(nil, "BORDER")
    headerSep:SetHeight(1)
    headerSep:SetPoint("TOPLEFT",  f, "TOPLEFT",  1, -HEADER_H)
    headerSep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -HEADER_H)
    headerSep:SetColorTexture(0.06, 0.07, 0.09, 1.0)

    -- Accent gradient line
    local accent = f:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(ACCENT_H)
    accent:SetPoint("TOPLEFT",  f, "TOPLEFT",  1, -(HEADER_H + 1))
    accent:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -(HEADER_H + 1))
    ApplyGradient(accent)

    -- Header icon (profession icon) — file-level upvalue so we can refresh it
    -- when the user switches to another profession.
    headerIcon = f:CreateTexture(nil, "OVERLAY")
    headerIcon:SetSize(34, 34)
    headerIcon:SetPoint("LEFT", f, "TOPLEFT", 9, -(HEADER_H / 2))
    headerIcon:SetTexture(A.Profession.icon or "Interface\\Icons\\Trade_Engraving")
    headerIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Title — clickable area: opens the profession switcher.
    local titleBtn = CreateFrame("Button", nil, f)
    titleBtn:SetPoint("LEFT", f, "TOPLEFT", 50, -(HEADER_H / 2))
    titleBtn:SetSize(260, 26)
    titleStr = titleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleStr:SetPoint("LEFT", titleBtn, "LEFT", 0, 0)
    titleStr:SetText(string.format("%sAlfred%s  -  %s  %s[v]%s",
        C.cyan, C.reset, A.Profession.name or "Profession", C.dim, C.reset))
    titleBtn:SetScript("OnEnter", function()
        titleStr:SetText(string.format("%sAlfred%s  -  %s  %s[v]%s",
            C.cyan, C.reset, A.Profession.name or "Profession", C.white, C.reset))
        GameTooltip:SetOwner(titleBtn, "ANCHOR_BOTTOMLEFT")
        GameTooltip:AddLine("Switch profession")
        GameTooltip:AddLine("Click to pick another registered profession.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    titleBtn:SetScript("OnLeave", function()
        titleStr:SetText(string.format("%sAlfred%s  -  %s  %s[v]%s",
            C.cyan, C.reset, A.Profession.name or "Profession", C.dim, C.reset))
        GameTooltip:Hide()
    end)
    titleBtn:SetScript("OnClick", function() A.UI.MainPanel.ToggleProfessionMenu(titleBtn) end)
    profSwitcherBtn = titleBtn

    -- Close (X) button: flat, red on hover
    local closeBtn = CreateFrame("Button", "AlfredEnchantingClose", f)
    closeBtn:SetSize(30, HEADER_H)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    local closeBg = closeBtn:CreateTexture(nil, "BACKGROUND")
    closeBg:SetAllPoints()
    closeBg:SetColorTexture(0, 0, 0, 0)
    local closeX = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    closeX:SetPoint("CENTER")
    closeX:SetText("X")
    closeX:SetTextColor(0.50, 0.53, 0.60)
    closeBtn:SetScript("OnEnter", function()
        closeBg:SetColorTexture(0.72, 0.12, 0.10, 0.85)
        closeX:SetTextColor(1, 1, 1)
    end)
    closeBtn:SetScript("OnLeave", function()
        closeBg:SetColorTexture(0, 0, 0, 0)
        closeX:SetTextColor(0.50, 0.53, 0.60)
    end)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- =========================================================================
    -- ROW 1: Nav (prev / step / next) + status (version)
    -- =========================================================================
    -- Nav buttons are SECURE so a click can also dispatch a /cast on the
    -- profession's spell (opens the tradeskill window for non-enchant
    -- professions). The SetStep handlers are attached via HookScript so
    -- they run alongside the secure dispatch without breaking it.
    prevBtn = MakeFlatSecureButton(f, "AlfredPrevStep", "<", 28, 24)
    prevBtn:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, NAV_Y)
    prevBtn:SetAttribute("type", "macro")
    prevBtn:HookScript("OnClick", function() A.UI.MainPanel.PrevStep() end)
    prevBtn._lbl:SetFontObject("GameFontNormal")

    navStepLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    navStepLabel:SetPoint("LEFT", prevBtn, "RIGHT", 10, 0)
    navStepLabel:SetWidth(220)
    navStepLabel:SetJustifyH("LEFT")
    navStepLabel:SetText("Step ? / ?")

    nextBtn = MakeFlatSecureButton(f, "AlfredNextStep", ">", 28, 24)
    nextBtn:SetPoint("LEFT", navStepLabel, "RIGHT", 4, 0)
    nextBtn:SetAttribute("type", "macro")
    nextBtn:HookScript("OnClick", function() A.UI.MainPanel.NextStep() end)
    nextBtn._lbl:SetFontObject("GameFontNormal")

    -- Keep global names for back-compat with external frame lookups
    _G["AlfredEnchantingPrev"] = prevBtn
    _G["AlfredEnchantingNext"] = nextBtn

    statusText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, NAV_Y - 4)
    statusText:SetText("")

    -- =========================================================================
    -- ROW 2: Tabs Guide / Shopping List
    -- =========================================================================
    -- Tab widths chosen so all four fit horizontally when the Trainer tab
    -- is shown (4 * 116 + 3 * 2 = 470, fits inside FRAME_W - PAD*2 = 496).
    local TAB_W = 116
    tabGuide = MakeTSMTab(f, "Guide", TAB_W)
    tabGuide:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, TABS_Y)
    tabGuide:SetScript("OnClick", function() ShowTab("guide") end)

    tabShopping = MakeTSMTab(f, "Shopping List", TAB_W)
    tabShopping:SetPoint("LEFT", tabGuide, "RIGHT", 2, 0)
    tabShopping:SetScript("OnClick", function() ShowTab("shopping") end)

    tabConfig = MakeTSMTab(f, "Config", TAB_W)
    tabConfig:SetPoint("LEFT", tabShopping, "RIGHT", 2, 0)
    tabConfig:SetScript("OnClick", function() ShowTab("config") end)

    -- Trainer tab: hidden by default, shown only while a profession trainer
    -- is open (Core/Trainer.lua + OpenTrainerTab/CloseTrainerTab below).
    tabTrainer = MakeTSMTab(f, "Trainer", TAB_W)
    tabTrainer:SetPoint("LEFT", tabConfig, "RIGHT", 2, 0)
    tabTrainer:SetScript("OnClick", function() ShowTab("trainer") end)
    tabTrainer:Hide()

    tabGuide:Activate()

    -- Separator below tabs
    local tabSep = f:CreateTexture(nil, "BORDER")
    tabSep:SetHeight(1)
    tabSep:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, TABS_Y - 28)
    tabSep:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, TABS_Y - 28)
    tabSep:SetColorTexture(0.20, 0.22, 0.30, 0.5)

    -- =========================================================================
    -- SKILL BAR
    -- =========================================================================
    local barW = FRAME_W - PAD * 2 - 18
    local barTrack = CreateFrame("Frame", nil, f)
    barTrack:SetSize(barW, BAR_H)
    barTrack:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, BAR_Y)
    skillBarTrack = barTrack
    local trackBg = barTrack:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0.05, 0.06, 0.08, 1.0)
    MakeBox(barTrack)
    skillBarFill = barTrack:CreateTexture(nil, "ARTWORK")
    skillBarFill:SetHeight(BAR_H - 2)
    skillBarFill:SetPoint("LEFT", barTrack, "LEFT", 1, 0)
    skillBarFill:SetWidth(1)
    ApplyGradient(skillBarFill)
    local barShine = barTrack:CreateTexture(nil, "OVERLAY")
    barShine:SetHeight(3)
    barShine:SetPoint("TOPLEFT",  barTrack, "TOPLEFT",  1, -1)
    barShine:SetPoint("TOPRIGHT", barTrack, "TOPRIGHT", -1, -1)
    barShine:SetColorTexture(1, 1, 1, 0.10)
    skillBarText = barTrack:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    skillBarText:SetPoint("CENTER")
    skillBarText:SetText("")

    -- =========================================================================
    -- CONTENT PANELS
    -- =========================================================================
    -- Guide panel
    guidePanel = CreateFrame("Frame", nil, f)
    guidePanel:SetPoint("TOPLEFT",     f, "TOPLEFT",     PAD,         CONTENT_Y)
    guidePanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD + 18), CONTENT_BOTTOM)
    local gScroll = CreateFrame("ScrollFrame", "AlfredGuideScroll", guidePanel, "UIPanelScrollFrameTemplate")
    gScroll:SetPoint("TOPLEFT",     guidePanel, "TOPLEFT",     0, 0)
    gScroll:SetPoint("BOTTOMRIGHT", guidePanel, "BOTTOMRIGHT", 0, 0)
    local gChild = CreateFrame("Frame", nil, gScroll)
    gChild:SetWidth(FRAME_W - PAD * 2 - 36)
    gChild:SetHeight(1)
    gScroll:SetScrollChild(gChild)
    guidePanel.scrollFrame = gScroll
    guidePanel.scrollChild = gChild

    -- Shopping panel
    shoppingPanel = CreateFrame("Frame", nil, f)
    shoppingPanel:SetPoint("TOPLEFT",     f, "TOPLEFT",     PAD,         CONTENT_Y)
    shoppingPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD + 18), CONTENT_BOTTOM)
    shoppingPanel:Hide()

    -- Sticky three-line total footer at the bottom of the shopping panel
    -- (outside the scroll region so it stays visible while scrolling). Lines:
    --   1. Materials subtotal
    --   2. Recipes subtotal
    --   3. Grand total — Materials + Recipes, in brighter text
    local SHOP_FOOTER_H = 60
    local sFooter = CreateFrame("Frame", nil, shoppingPanel)
    sFooter:SetHeight(SHOP_FOOTER_H)
    sFooter:SetPoint("BOTTOMLEFT",  shoppingPanel, "BOTTOMLEFT",  0, 0)
    sFooter:SetPoint("BOTTOMRIGHT", shoppingPanel, "BOTTOMRIGHT", 0, 0)
    local sFooterBg = sFooter:CreateTexture(nil, "BACKGROUND")
    sFooterBg:SetAllPoints()
    sFooterBg:SetColorTexture(0.09, 0.10, 0.12, 0.95)
    local sFooterSep = sFooter:CreateTexture(nil, "ARTWORK")
    sFooterSep:SetHeight(1)
    sFooterSep:SetPoint("TOPLEFT",  sFooter, "TOPLEFT",  0, 0)
    sFooterSep:SetPoint("TOPRIGHT", sFooter, "TOPRIGHT", 0, 0)
    sFooterSep:SetColorTexture(0.20, 0.22, 0.30, 0.6)

    -- Materials line
    local matLbl = sFooter:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    matLbl:SetPoint("TOPLEFT", sFooter, "TOPLEFT", 8, -3)
    matLbl:SetTextColor(0.55, 0.58, 0.65)
    matLbl:SetText("Materials (missing):")
    local matVal = sFooter:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    matVal:SetPoint("TOPRIGHT", sFooter, "TOPRIGHT", -8, -3)
    matVal:SetText("")

    -- Recipes line
    local recLbl = sFooter:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    recLbl:SetPoint("TOPLEFT", sFooter, "TOPLEFT", 8, -19)
    recLbl:SetTextColor(0.55, 0.58, 0.65)
    recLbl:SetText("Recipes (missing):")
    local recVal = sFooter:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    recVal:SetPoint("TOPRIGHT", sFooter, "TOPRIGHT", -8, -19)
    recVal:SetText("")

    -- Divider above the grand total
    local sumSep = sFooter:CreateTexture(nil, "ARTWORK")
    sumSep:SetHeight(1)
    sumSep:SetPoint("TOPLEFT",  sFooter, "TOPLEFT",  8,  -36)
    sumSep:SetPoint("TOPRIGHT", sFooter, "TOPRIGHT", -8, -36)
    sumSep:SetColorTexture(0.20, 0.22, 0.30, 0.4)

    -- Grand total line (brighter — primary text + GameFontNormal)
    local sumLbl = sFooter:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sumLbl:SetPoint("TOPLEFT", sFooter, "TOPLEFT", 8, -40)
    sumLbl:SetTextColor(0.92, 0.93, 0.95)
    sumLbl:SetText("Total (missing):")
    local sumVal = sFooter:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sumVal:SetPoint("TOPRIGHT", sFooter, "TOPRIGHT", -8, -40)
    sumVal:SetText("")

    shoppingPanel.matTotalVal = matVal
    shoppingPanel.recTotalVal = recVal
    shoppingPanel.sumTotalVal = sumVal

    local sScroll = CreateFrame("ScrollFrame", "AlfredShopScroll", shoppingPanel, "UIPanelScrollFrameTemplate")
    sScroll:SetPoint("TOPLEFT",     shoppingPanel, "TOPLEFT",     0, 0)
    -- Bottom offset is +SHOP_FOOTER_H (positive = upward in WoW coords) so the
    -- scroll viewport stops above the sticky total bar.
    sScroll:SetPoint("BOTTOMRIGHT", shoppingPanel, "BOTTOMRIGHT", 0, SHOP_FOOTER_H)
    local sChild = CreateFrame("Frame", nil, sScroll)
    sChild:SetWidth(FRAME_W - PAD * 2 - 36)
    sChild:SetHeight(1)
    sScroll:SetScrollChild(sChild)
    shoppingPanel.scrollFrame = sScroll
    shoppingPanel.scrollChild = sChild

    -- Config panel
    configPanel = CreateFrame("Frame", nil, f)
    configPanel:SetPoint("TOPLEFT",     f, "TOPLEFT",     PAD,         CONTENT_Y)
    configPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD + 18), CONTENT_BOTTOM)
    configPanel:Hide()
    local cScroll = CreateFrame("ScrollFrame", "AlfredConfigScroll", configPanel, "UIPanelScrollFrameTemplate")
    cScroll:SetPoint("TOPLEFT",     configPanel, "TOPLEFT",     0, 0)
    cScroll:SetPoint("BOTTOMRIGHT", configPanel, "BOTTOMRIGHT", 0, 0)
    local cChild = CreateFrame("Frame", nil, cScroll)
    cChild:SetWidth(FRAME_W - PAD * 2 - 36)
    cChild:SetHeight(1)
    cScroll:SetScrollChild(cChild)
    configPanel.scrollFrame = cScroll
    configPanel.scrollChild = cChild

    -- Trainer panel (shown only while a profession trainer is open).
    trainerPanel = CreateFrame("Frame", nil, f)
    trainerPanel:SetPoint("TOPLEFT",     f, "TOPLEFT",     PAD,         CONTENT_Y)
    trainerPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD + 18), CONTENT_BOTTOM)
    trainerPanel:Hide()
    local tScroll = CreateFrame("ScrollFrame", "AlfredTrainerScroll", trainerPanel, "UIPanelScrollFrameTemplate")
    tScroll:SetPoint("TOPLEFT",     trainerPanel, "TOPLEFT",     0, 0)
    tScroll:SetPoint("BOTTOMRIGHT", trainerPanel, "BOTTOMRIGHT", 0, 0)
    local tChild = CreateFrame("Frame", nil, tScroll)
    tChild:SetWidth(FRAME_W - PAD * 2 - 36)
    tChild:SetHeight(1)
    tScroll:SetScrollChild(tChild)
    trainerPanel.scrollFrame = tScroll
    trainerPanel.scrollChild = tChild

    -- =========================================================================
    -- FOOTER (Icon + spell + item + req + mat-chips + Cast + status)
    -- =========================================================================
    local footerSep = f:CreateTexture(nil, "BORDER")
    footerSep:SetHeight(1)
    footerSep:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  PAD,    FOOTER_H + 4)
    footerSep:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD,   FOOTER_H + 4)
    footerSep:SetColorTexture(0.20, 0.22, 0.30, 0.5)

    -- Recipe icon — same look-and-feel as guide-row icons (34x34, trimmed
    -- TexCoord). Clickable (AH/chat/Wowhead) when the step has an outputItemId.
    local FICON_SZ = 34
    footerIcon = CreateFrame("Button", nil, f)
    footerIcon:SetSize(FICON_SZ, FICON_SZ)
    footerIcon:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, FOOTER_H - 38)
    footerIcon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local fIconBg = footerIcon:CreateTexture(nil, "BACKGROUND")
    fIconBg:SetAllPoints()
    fIconBg:SetColorTexture(0.05, 0.06, 0.07, 0.55)
    footerIconTex = footerIcon:CreateTexture(nil, "ARTWORK")
    footerIconTex:SetAllPoints()
    footerIconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local fIconHl = footerIcon:CreateTexture(nil, "HIGHLIGHT")
    fIconHl:SetAllPoints()
    fIconHl:SetColorTexture(1, 1, 1, 0.08)
    footerIcon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self._itemId then
            GameTooltip:SetHyperlink("item:" .. self._itemId)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(string.format(
                "%sclick%s = AH | %sshift+click%s = chat | %sright-click%s = Wowhead",
                C.dim, C.reset, C.dim, C.reset, C.dim, C.reset), 1, 1, 1, true)
        elseif self._spellName then
            GameTooltip:AddLine(self._spellName, 1, 1, 1)
            if self._kind then
                GameTooltip:AddLine("[" .. self._kind:upper() .. "]", 0.6, 0.6, 0.65)
            end
        end
        GameTooltip:Show()
    end)
    footerIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    footerIcon:SetScript("OnClick", function(self, btn)
        if self._itemId then
            A.Items.HandleClick(self._itemId, self._spellName, btn)
        end
    end)

    -- Text labels — anchored to the right of the icon for the top two rows
    -- (spell + item). Req label spans the full width below the icon.
    local TEXT_X = PAD + FICON_SZ + 8

    footerSpellLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    footerSpellLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", TEXT_X, FOOTER_H - 18)
    footerSpellLabel:SetPoint("RIGHT",      f, "BOTTOMRIGHT", -PAD, 0)
    footerSpellLabel:SetJustifyH("LEFT")
    footerSpellLabel:SetText("?")

    footerItemLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footerItemLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", TEXT_X, FOOTER_H - 36)
    footerItemLabel:SetPoint("RIGHT",      f, "BOTTOMRIGHT", -PAD, 0)
    footerItemLabel:SetJustifyH("LEFT")
    footerItemLabel:SetText("")

    footerReqLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footerReqLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, FOOTER_H - 56)
    footerReqLabel:SetPoint("RIGHT",      f, "BOTTOMRIGHT", -PAD, 0)
    footerReqLabel:SetJustifyH("LEFT")
    footerReqLabel:SetText("")

    -- Material chips row — RenderFooter rebuilds these each refresh.
    footerMatsContainer = CreateFrame("Frame", nil, f)
    footerMatsContainer:SetHeight(20)
    footerMatsContainer:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  PAD,  FOOTER_H - 80)
    footerMatsContainer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, FOOTER_H - 80)
    footerMatsContainer._chips = {}

    -- Action buttons (Cast + Macros + Guide)
    castBtn = MakeFlatSecureButton(f, "AlfredEnchantingCast", "Enchant", 130, 28)
    castBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 22)
    castBtn:SetAttribute("type", "macro")

    -- Special styling for the cast button: muted green when "ready", dark gray
    -- when disabled. Green is the only exception to the minimalist gray theme
    -- — it's the addon's primary call-to-action.
    local CAST_BG_READY      = { 0.10, 0.28, 0.12, 1.0 }
    local CAST_BG_HOVER      = { 0.16, 0.40, 0.18, 1.0 }
    local CAST_BG_DISABLED   = { 0.08, 0.09, 0.11, 1.0 }
    local CAST_TEXT_READY    = { 0.92, 0.96, 0.93, 1.0 }
    local CAST_TEXT_DISABLED = { 0.38, 0.40, 0.44, 1.0 }
    castBtn._bg:SetColorTexture(unpack(CAST_BG_READY))
    castBtn._lbl:SetTextColor(unpack(CAST_TEXT_READY))

    castBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Enchant (selected step)")
        GameTooltip:AddLine("Click runs the |cffffd100" .. (A.Profession.MacroName or "?") .. "|r macro:", 1, 1, 1, true)
        GameTooltip:AddLine("/cast + /use + /click StaticPopup1Button1", 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine("Tip: drag the macro to the action bar for a native keybind.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
        if self:IsEnabled() then self._bg:SetColorTexture(unpack(CAST_BG_HOVER)) end
    end)
    castBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        if self:IsEnabled() then
            self._bg:SetColorTexture(unpack(CAST_BG_READY))
        else
            self._bg:SetColorTexture(unpack(CAST_BG_DISABLED))
        end
    end)
    castBtn:SetScript("OnEnable", function(self)
        self._bg:SetColorTexture(unpack(CAST_BG_READY))
        self._lbl:SetTextColor(unpack(CAST_TEXT_READY))
    end)
    castBtn:SetScript("OnDisable", function(self)
        self._bg:SetColorTexture(unpack(CAST_BG_DISABLED))
        self._lbl:SetTextColor(unpack(CAST_TEXT_DISABLED))
    end)
    -- Important: do NOT do SetScript("OnClick", ...) on castBtn.
    -- The SecureActionButtonTemplate XML already has the correct OnClick, and
    -- it's the only one that preserves the secure context to dispatch the
    -- macro. Replacing it with a Lua handler breaks the dispatch (verified
    -- on TBC Classic Anniversary).

    -- Single-craft button (visible only for tradeskill kinds; reanchors
    -- macrosBtn at refresh time depending on kind).
    craft1Btn = MakeFlatSecureButton(f, "AlfredCraft1", "Craft 1", 64, 28)
    craft1Btn:SetPoint("LEFT", castBtn, "RIGHT", 6, 0)
    craft1Btn:SetAttribute("type", "macro")
    craft1Btn:Hide()
    craft1Btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Craft a single one")
        GameTooltip:AddLine("Useful for testing, or when you only need 1 more.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    craft1Btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    macrosBtn = MakeFlatButton(f, "Macros", 90, 28)
    macrosBtn:SetPoint("LEFT", castBtn, "RIGHT", 6, 0)
    macrosBtn:RegisterForClicks("LeftButtonUp")
    macrosBtn:SetScript("OnClick", function()
        if InCombatLockdown and InCombatLockdown() then
            print("|cffff9900[Alfred:Enchanting]|r Cannot open Macros while in combat.")
            return
        end
        if not MacroFrame then
            if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_MacroUI")
            elseif LoadAddOn then LoadAddOn("Blizzard_MacroUI") end
        end
        if ShowMacroFrame then ShowMacroFrame() end
    end)

    footerStatusLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footerStatusLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 6)
    footerStatusLabel:SetPoint("RIGHT",      f, "BOTTOMRIGHT", -PAD, 0)
    footerStatusLabel:SetJustifyH("LEFT")
    footerStatusLabel:SetText("")

    -- Initial render whenever it's created/the step changes
    RefreshAll()
end

-- ============================================================================
-- Pin to external frame (TSM, etc.)
-- ============================================================================
function A.UI.MainPanel.ApplyPin()
    if not mainFrame then return end
    local shared = A.DB.Shared()
    local pinName = shared and shared.pinTo
    if pinName then
        local target = _G[pinName]
        if target and target:IsShown() then
            mainFrame:ClearAllPoints()
            mainFrame:SetPoint("TOPLEFT", target, "TOPRIGHT", 4, 0)
            return true
        end
    end
    mainFrame:ClearAllPoints()
    local pos = shared and shared.framePos
    if pos and pos.point then
        mainFrame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    end
    return false
end

function A.UI.MainPanel.Show()
    if not mainFrame then A.UI.MainPanel.Create() end
    if mainFrame then
        A.UI.MainPanel.ApplyPin()
        mainFrame:Show()
        RefreshAll()
    end
end

function A.UI.MainPanel.Hide()
    if mainFrame then mainFrame:Hide() end
end

function A.UI.MainPanel.IsShown()
    return mainFrame and mainFrame:IsShown()
end

function A.UI.MainPanel.GetContainer() return mainFrame end

function A.UI.MainPanel.UpdateButton()
    if not mainFrame then return end
    RefreshAll()
end

AlfredEnchanting_UpdateButton = A.UI.MainPanel.UpdateButton
