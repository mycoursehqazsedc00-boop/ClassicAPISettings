-- ClassicAPISettings: Vanilla-Styled Options Frame
-- Strict Lua 5.0 compatible.

ClassicAPISettings = ClassicAPISettings or {}
local CAS = ClassicAPISettings

local FRAME_W = 620
local FRAME_H = 500
local CONTENT_W = 555

local mainFrame = nil
local scrollFrame = nil
local scrollChild = nil
local tabButtons = {}
local tabPanels = {}
local activeTabId = "general"
local isRefreshing = false
local widgetIdCounter = 0

local function NextWidgetName(prefix)
    widgetIdCounter = widgetIdCounter + 1
    return "ClassicAPISettings_" .. prefix .. "_" .. widgetIdCounter
end

local function SetTooltip(owner, title, lines)
    if not owner or not GameTooltip then return end
    owner:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 0.82, 0)
        if lines then
            local i
            for i = 1, table.getn(lines) do
                local ln = lines[i]
                if type(ln) == "table" then
                    GameTooltip:AddLine(ln.text, ln.r or 1, ln.g or 1, ln.b or 1, 1)
                else
                    GameTooltip:AddLine(tostring(ln), 0.9, 0.9, 0.9, 1)
                end
            end
        end
        GameTooltip:Show()
    end)
    owner:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function ShowSettingTooltip(owner, item)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(item.label, 1, 0.82, 0)
    if item.desc then
        GameTooltip:AddLine(item.desc, 0.95, 0.95, 0.95, 1)
    end
    local supported, unsupReason = CAS.GetItemSupportStatus(item)
    if not supported then
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("[UNSUPPORTED ON CURRENT VERSION]", 1, 0.25, 0.25)
        GameTooltip:AddLine(unsupReason, 1, 0.72, 0.25, 1)
    end
    if item.kind == "bool" or item.kind == "slider" or item.kind == "cycle" or item.kind == "tts_voice" then
        local cur = CAS.SafeGetCVar(item.key)
        local def = CAS.SafeGetCVarDefault(item.key)
        local scope = "Account (Config.wtf)"
        if C_CVar and type(C_CVar.GetCVarInfo) == "function" then
            local ok, _, _, _, isChar = pcall(C_CVar.GetCVarInfo, item.key)
            if ok and isChar then
                scope = "Per-Character (config-cache.wtf)"
            end
        end
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("CVar: |cff88ccff" .. item.key .. "|r   (" .. scope .. ")", 0.75, 0.75, 0.75)
        GameTooltip:AddLine("Current: |cffffffff" .. tostring(cur or "nil") .. "|r   Default: |cffaaaaaa" .. tostring(def or "nil") .. "|r", 0.75, 0.75, 0.75)
    elseif item.kind == "api_bool" or item.kind == "api_slider" then
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("API Setting: |cff88ccff" .. item.key .. "|r   Default: |cffaaaaaa" .. tostring(item.default) .. "|r", 0.75, 0.75, 0.75)
    end
    local ovs = CAS.OverlapsByKey[item.key]
    if ovs and table.getn(ovs) > 0 then
        GameTooltip:AddLine(" ", 1, 1, 1)
        local i
        for i = 1, table.getn(ovs) do
            local ov = ovs[i]
            local r, g, b = 0.4, 0.8, 1.0
            if ov.severity == "HIGH" then
                r, g, b = 1.0, 0.25, 0.25
            elseif ov.severity == "WARN" then
                r, g, b = 1.0, 0.65, 0.1
            end
            GameTooltip:AddLine("[" .. ov.severity .. "] " .. ov.title, r, g, b, 1)
            GameTooltip:AddLine(ov.detail, 0.9, 0.85, 0.7, 1)
        end
    end
    GameTooltip:Show()
end

local function AttachSettingTooltip(owner, item)
    owner:SetScript("OnEnter", function()
        ShowSettingTooltip(this, item)
    end)
    owner:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function EnableRowHover(row, item)
    row:EnableMouse(true)
    local hl = row:CreateTexture(nil, "BACKGROUND")
    hl:SetTexture(1, 0.82, 0, 0.08)
    hl:SetAllPoints(row)
    hl:Hide()
    row:SetScript("OnEnter", function()
        hl:Show()
        ShowSettingTooltip(this, item)
    end)
    row:SetScript("OnLeave", function()
        hl:Hide()
        GameTooltip:Hide()
    end)
end

local function GetUnsupportedTag(item)
    local supported = CAS.GetItemSupportStatus(item)
    if supported then return "" end
    local reqStr = item.minVersionStr or CAS.TARGET_CLASSICAPI_STRING
    return "|cffff6633[Req " .. reqStr .. "+]|r "
end

local function GetBadgeTextForKey(key)
    local ovs = CAS.OverlapsByKey[key]
    if not ovs or table.getn(ovs) == 0 then return nil end
    local best = "INFO"
    local i
    for i = 1, table.getn(ovs) do
        local s = ovs[i].severity
        if s == "HIGH" then
            best = "HIGH"
            break
        elseif s == "WARN" then
            best = "WARN"
        end
    end
    if best == "HIGH" then
        return "|cffff3333[!]|r "
    elseif best == "WARN" then
        return "|cffffaa22[!]|r "
    else
        return "|cff66bbff[i]|r "
    end
end

local function CreateResetButton(parent, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetWidth(22)
    btn:SetHeight(18)
    btn:SetText("R")
    btn:SetScript("OnClick", function()
        onClick()
        CAS.RefreshUI()
    end)
    SetTooltip(btn, "Reset to Default", { "Restore this setting to its ClassicAPI default value." })
    return btn
end

local function BuildStandardTab(panel, tabDef)
    panel.controls = {}
    local y = -8
    local i

    for i = 1, table.getn(tabDef.items) do
        local item = tabDef.items[i]

        if item.kind == "header" then
            if y < -12 then y = y - 6 end
            local hdr = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            hdr:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
            hdr:SetText(item.label)
            local line = panel:CreateTexture(nil, "ARTWORK")
            line:SetTexture(1, 0.82, 0, 0.35)
            line:SetHeight(1)
            line:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -2)
            line:SetWidth(CONTENT_W - 20)
            y = y - 24

        elseif item.kind == "actions" then
            local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            lbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y - 4)
            lbl:SetText(item.label .. ":")
            local bx = 135
            local bIdx
            for bIdx = 1, table.getn(item.buttons) do
                local bDef = item.buttons[bIdx]
                local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
                btn:SetHeight(22)
                btn:SetWidth(bDef.width or 116)
                btn:SetPoint("TOPLEFT", panel, "TOPLEFT", bx, y)
                btn:SetText(bDef.label)
                local fn = bDef.func
                local curBDef = bDef
                btn:SetScript("OnClick", function()
                    if curBDef.minVersion then
                        local okSup, reason = CAS.GetItemSupportStatus(curBDef)
                        if not okSup then
                            CAS.Print("|cffff5533[Unsupported]|r " .. tostring(reason))
                            return
                        end
                    end
                    fn()
                    CAS.RefreshUI()
                end)
                if bDef.tip then
                    local tipLines = { bDef.tip }
                    if bDef.minVersion then
                        table.insert(tipLines, { text = "Requires ClassicAPI " .. (bDef.minVersionStr or CAS.TARGET_CLASSICAPI_STRING) .. "+", r = 1, g = 0.7, b = 0.2 })
                    end
                    SetTooltip(btn, bDef.label, tipLines)
                end
                bx = bx + (bDef.width or 116) + 6
            end
            y = y - 30

        elseif item.kind == "bool" or item.kind == "api_bool" then
            local row = CreateFrame("Frame", nil, panel)
            row:SetWidth(CONTENT_W - 16)
            row:SetHeight(24)
            row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)

            local cb = CreateFrame("CheckButton", NextWidgetName("Check"), row, "UICheckButtonTemplate")
            cb:SetPoint("LEFT", row, "LEFT", 0, 0)
            cb:SetWidth(24)
            cb:SetHeight(24)

            local text = getglobal(cb:GetName() .. "Text")
            text:SetFontObject(GameFontHighlightSmall)
            text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
            text:SetText(item.label)

            local curItem = item
            cb:SetScript("OnClick", function()
                if isRefreshing then return end
                local okSup, reason = CAS.GetItemSupportStatus(curItem)
                if not okSup then
                    CAS.Print("|cffff5533[Unsupported]|r Cannot change '" .. curItem.label .. "': " .. tostring(reason))
                    CAS.RefreshUI()
                    return
                end
                local checked = this:GetChecked() and true or false
                if curItem.kind == "api_bool" then
                    curItem.set(checked)
                else
                    CAS.SafeSetCVar(curItem.key, checked and "1" or "0")
                end
                CAS.RefreshUI()
            end)
            AttachSettingTooltip(cb, curItem)
            EnableRowHover(row, curItem)

            local resetBtn = CreateResetButton(row, function()
                if curItem.kind == "api_bool" then
                    curItem.set(curItem.default)
                else
                    local def = CAS.SafeGetCVarDefault(curItem.key)
                    if def ~= nil then CAS.SafeSetCVar(curItem.key, def) end
                end
            end)
            resetBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)

            table.insert(panel.controls, {
                item = curItem,
                refresh = function()
                    local supported = CAS.GetItemSupportStatus(curItem)
                    local badge = GetUnsupportedTag(curItem) .. (GetBadgeTextForKey(curItem.key) or "")
                    local isModified = false
                    if curItem.kind == "api_bool" then
                        local val = curItem.get()
                        cb:SetChecked(val and 1 or nil)
                        isModified = supported and (val ~= curItem.default)
                    else
                        local val = CAS.SafeGetCVar(curItem.key)
                        local def = CAS.SafeGetCVarDefault(curItem.key)
                        cb:SetChecked((val == "1") and 1 or nil)
                        isModified = supported and (def ~= nil and val ~= nil and val ~= def)
                    end
                    cb:Enable()
                    text:SetText(badge .. curItem.label)
                    if not supported then
                        text:SetTextColor(0.75, 0.52, 0.35)
                        resetBtn:Hide()
                    elseif isModified then
                        text:SetTextColor(1, 0.85, 0.2)
                        resetBtn:Show()
                    else
                        text:SetTextColor(0.92, 0.92, 0.92)
                        resetBtn:Hide()
                    end
                end,
            })

            y = y - 24

        elseif item.kind == "slider" or item.kind == "api_slider" then
            local row = CreateFrame("Frame", nil, panel)
            row:SetWidth(CONTENT_W - 16)
            row:SetHeight(42)
            row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)

            local titleFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            titleFS:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -2)
            titleFS:SetText(item.label)

            local valFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            valFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", -34, -2)

            local sName = NextWidgetName("Slider")
            local slider = CreateFrame("Slider", sName, row, "OptionsSliderTemplate")
            slider:SetWidth(CONTENT_W - 60)
            slider:SetHeight(16)
            slider:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -18)
            slider:SetMinMaxValues(item.min, item.max)
            slider:SetValueStep(item.step)

            local lowFS = getglobal(sName .. "Low")
            local highFS = getglobal(sName .. "High")
            local txtFS = getglobal(sName .. "Text")
            if lowFS then lowFS:SetText(tostring(item.min)) end
            if highFS then highFS:SetText(tostring(item.max)) end
            if txtFS then txtFS:SetText("") end

            local curItem = item
            local function FormatVal(v)
                if curItem.fmt then
                    return string.format(curItem.fmt, v)
                end
                return tostring(v)
            end

            slider:SetScript("OnValueChanged", function()
                if isRefreshing then return end
                local okSup = CAS.GetItemSupportStatus(curItem)
                if not okSup then return end
                local v = this:GetValue()
                -- Round to step precision to avoid float noise
                if curItem.step < 1 then
                    v = math.floor(v / curItem.step + 0.5) * curItem.step
                else
                    v = math.floor(v + 0.5)
                end
                valFS:SetText(FormatVal(v))
                if curItem.kind == "api_slider" then
                    curItem.set(v)
                else
                    local strVal = (curItem.step < 1) and string.format("%.2f", v) or tostring(v)
                    CAS.SafeSetCVar(curItem.key, strVal)
                end
            end)
            slider:SetScript("OnMouseUp", function()
                local okSup, reason = CAS.GetItemSupportStatus(curItem)
                if not okSup then
                    CAS.Print("|cffff5533[Unsupported]|r Cannot change '" .. curItem.label .. "': " .. tostring(reason))
                end
                CAS.RefreshUI()
            end)
            AttachSettingTooltip(slider, curItem)
            EnableRowHover(row, curItem)

            local resetBtn = CreateResetButton(row, function()
                if curItem.kind == "api_slider" then
                    curItem.set(curItem.default)
                else
                    local def = CAS.SafeGetCVarDefault(curItem.key)
                    if def ~= nil then CAS.SafeSetCVar(curItem.key, def) end
                end
            end)
            resetBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -12)

            table.insert(panel.controls, {
                item = curItem,
                refresh = function()
                    local supported = CAS.GetItemSupportStatus(curItem)
                    local badge = GetUnsupportedTag(curItem) .. (GetBadgeTextForKey(curItem.key) or "")
                    local numVal, defNum
                    if curItem.kind == "api_slider" then
                        numVal = curItem.get() or curItem.default
                        defNum = curItem.default
                    else
                        local raw = CAS.SafeGetCVar(curItem.key)
                        local defRaw = CAS.SafeGetCVarDefault(curItem.key)
                        numVal = tonumber(raw)
                        defNum = tonumber(defRaw)
                        if numVal == nil then numVal = defNum or curItem.min end
                    end
                    local clamped = numVal
                    if clamped < curItem.min then clamped = curItem.min end
                    if clamped > curItem.max then clamped = curItem.max end
                    slider:SetValue(clamped)
                    valFS:SetText(supported and FormatVal(numVal) or "|cffff6633N/A|r")
                    titleFS:SetText(badge .. curItem.label)
                    local isModified = supported and (defNum ~= nil and math.abs(numVal - defNum) > 0.001)
                    if not supported then
                        titleFS:SetTextColor(0.75, 0.52, 0.35)
                        resetBtn:Hide()
                    elseif isModified then
                        titleFS:SetTextColor(1, 0.85, 0.2)
                        resetBtn:Show()
                    else
                        titleFS:SetTextColor(0.92, 0.92, 0.92)
                        resetBtn:Hide()
                    end
                end,
            })

            y = y - 46

        elseif item.kind == "cycle" or item.kind == "tts_voice" then
            local row = CreateFrame("Frame", nil, panel)
            row:SetWidth(CONTENT_W - 16)
            row:SetHeight(26)
            row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)

            local titleFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            titleFS:SetPoint("LEFT", row, "LEFT", 6, 0)
            titleFS:SetText(item.label)

            local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            btn:SetWidth(185)
            btn:SetHeight(21)
            btn:SetPoint("RIGHT", row, "RIGHT", -32, 0)

            local curItem = item
            local function GetOptions()
                if curItem.kind == "tts_voice" then
                    local opts = {}
                    if C_VoiceChat and type(C_VoiceChat.GetTtsVoices) == "function" then
                        local ok, voices = pcall(C_VoiceChat.GetTtsVoices)
                        if ok and type(voices) == "table" then
                            local vi
                            for vi = 1, table.getn(voices) do
                                local v = voices[vi]
                                local nm = tostring(v.name or ("Voice " .. tostring(v.voiceID)))
                                if string.len(nm) > 24 then
                                    nm = string.sub(nm, 1, 22) .. ".."
                                end
                                table.insert(opts, { value = tostring(v.voiceID), label = tostring(v.voiceID) .. ": " .. nm })
                            end
                        end
                    end
                    if table.getn(opts) == 0 then
                        table.insert(opts, { value = "0", label = "0: Default" })
                    end
                    return opts
                end
                return curItem.options
            end

            btn:SetScript("OnClick", function()
                local okSup, reason = CAS.GetItemSupportStatus(curItem)
                if not okSup then
                    CAS.Print("|cffff5533[Unsupported]|r Cannot change '" .. curItem.label .. "': " .. tostring(reason))
                    return
                end
                local opts = GetOptions()
                local n = table.getn(opts)
                if n == 0 then return end
                local cur = CAS.SafeGetCVar(curItem.key) or opts[1].value
                local curIdx = 1
                local oi
                for oi = 1, n do
                    if opts[oi].value == cur then
                        curIdx = oi
                        break
                    end
                end
                local nextIdx = curIdx + 1
                if nextIdx > n then nextIdx = 1 end
                CAS.SafeSetCVar(curItem.key, opts[nextIdx].value)
                CAS.RefreshUI()
            end)
            AttachSettingTooltip(btn, curItem)
            EnableRowHover(row, curItem)

            local resetBtn = CreateResetButton(row, function()
                local def = CAS.SafeGetCVarDefault(curItem.key)
                if def ~= nil then CAS.SafeSetCVar(curItem.key, def) end
            end)
            resetBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)

            table.insert(panel.controls, {
                item = curItem,
                refresh = function()
                    local supported = CAS.GetItemSupportStatus(curItem)
                    local badge = GetUnsupportedTag(curItem) .. (GetBadgeTextForKey(curItem.key) or "")
                    local cur = CAS.SafeGetCVar(curItem.key)
                    local def = CAS.SafeGetCVarDefault(curItem.key)
                    local opts = GetOptions()
                    local label = tostring(cur or "N/A")
                    local oi
                    for oi = 1, table.getn(opts) do
                        if opts[oi].value == cur then
                            label = opts[oi].label
                            break
                        end
                    end
                    btn:SetText(supported and label or "|cffff6633Unsupported|r")
                    titleFS:SetText(badge .. curItem.label)
                    local isModified = supported and (def ~= nil and cur ~= nil and cur ~= def)
                    if not supported then
                        titleFS:SetTextColor(0.75, 0.52, 0.35)
                        resetBtn:Hide()
                    elseif isModified then
                        titleFS:SetTextColor(1, 0.85, 0.2)
                        resetBtn:Show()
                    else
                        titleFS:SetTextColor(0.92, 0.92, 0.92)
                        resetBtn:Hide()
                    end
                end,
            })

            y = y - 28
        end
    end

    panel.contentHeight = math.max(360, -y + 20)
end

local function BuildOverlapsTab(panel)
    panel.cards = {}
    panel.controls = {}

    local hdr = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdr:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
    hdr:SetText("Detected Client DLL Mods")

    local modSummary = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    modSummary:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 4, -6)
    modSummary:SetWidth(CONTENT_W - 24)
    modSummary:SetJustifyH("LEFT")

    local rescanBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    rescanBtn:SetWidth(110)
    rescanBtn:SetHeight(21)
    rescanBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -6)
    rescanBtn:SetText("Re-scan Mods")
    rescanBtn:SetScript("OnClick", function()
        CAS.DetectMods()
        CAS.ScanOverlaps()
        CAS.RefreshUI()
    end)
    SetTooltip(rescanBtn, "Re-scan Client Mods & Overlaps", { "Re-checks installed DLL mods (ClassicAPI, Nampower, UnitXP SP3, SuperWoW, WeirdUtils) and refreshes all overlap warnings." })

    local ovHdr = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ovHdr:SetPoint("TOPLEFT", modSummary, "BOTTOMLEFT", -4, -14)
    ovHdr:SetText("Cross-Mod Overlaps & Configuration Warnings")

    local emptyFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyFS:SetPoint("TOPLEFT", ovHdr, "BOTTOMLEFT", 4, -8)
    emptyFS:SetText("|cff44ff44No overlaps or configuration warnings detected.|r")

    local function EnsureCard(idx)
        if panel.cards[idx] then return panel.cards[idx] end
        local card = CreateFrame("Frame", nil, panel)
        card:SetWidth(CONTENT_W - 20)
        card:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        card:SetBackdropColor(0.08, 0.08, 0.1, 0.85)

        card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -7)
        card.title:SetWidth(CONTENT_W - 180)
        card.title:SetJustifyH("LEFT")

        card.detail = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        card.detail:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
        card.detail:SetWidth(CONTENT_W - 40)
        card.detail:SetJustifyH("LEFT")

        card.fixBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
        card.fixBtn:SetHeight(20)
        card.fixBtn:SetWidth(145)
        card.fixBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -6)

        panel.cards[idx] = card
        return card
    end

    panel.refreshCustom = function()
        local m = CAS.Mods
        local parts = {}
        table.insert(parts, "ClassicAPI: " .. (m.classicapi and ("|cff44ff44" .. m.classicapiVersion .. "|r") or "|cffff4444Not Found|r"))
        table.insert(parts, "Nampower: " .. (m.nampower and ("|cff44ff44" .. m.nampowerVersion .. "|r") or "|cff888888No|r"))
        table.insert(parts, "UnitXP SP3: " .. (m.unitxp and "|cff44ff44Loaded|r" or "|cff888888No|r"))
        table.insert(parts, "SuperWoW: " .. (m.superwow and ("|cff44ff44" .. m.superwowVersion .. "|r") or "|cff888888No|r"))
        if m.weirdutils then
            local wList = {}
            for k in pairs(m.weirdutilsModules) do table.insert(wList, k) end
            table.sort(wList)
            local wTxt = table.getn(wList) > 0 and table.concat(wList, ", ") or "loaded"
            table.insert(parts, "WeirdUtils: |cff44ff44" .. wTxt .. "|r")
        else
            table.insert(parts, "WeirdUtils: |cff888888No|r")
        end
        modSummary:SetText(table.concat(parts, "   |   "))

        local count = table.getn(CAS.Overlaps)
        local i
        for i = 1, table.getn(panel.cards) do
            panel.cards[i]:Hide()
        end

        if count == 0 then
            emptyFS:Show()
            panel.contentHeight = 360
            return
        end

        emptyFS:Hide()
        local y = -98
        for i = 1, count do
            local ov = CAS.Overlaps[i]
            local card = EnsureCard(i)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)

            local col = "|cff66bbff"
            if ov.severity == "HIGH" then
                col = "|cffff3333"
                card:SetBackdropBorderColor(1, 0.25, 0.25, 0.9)
            elseif ov.severity == "WARN" then
                col = "|cffffaa22"
                card:SetBackdropBorderColor(1, 0.65, 0.15, 0.9)
            else
                card:SetBackdropBorderColor(0.4, 0.7, 1, 0.75)
            end

            card.title:SetText(col .. "[" .. ov.severity .. "]|r " .. ov.title)
            card.detail:SetText(ov.detail)

            if ov.fixFunc and ov.fixLabel then
                card.fixBtn:SetText(ov.fixLabel)
                local fn = ov.fixFunc
                card.fixBtn:SetScript("OnClick", function()
                    fn()
                    CAS.RefreshUI()
                end)
                card.fixBtn:Show()
            else
                card.fixBtn:Hide()
            end

            local detailH = card.detail:GetHeight() or 28
            if detailH < 24 then detailH = 24 end
            local cardH = 34 + detailH
            card:SetHeight(cardH)
            card:Show()
            y = y - cardH - 8
        end

        panel.contentHeight = math.max(360, -y + 20)
    end
end

local function BuildToolsTab(panel)
    panel.controls = {}
    local y = -8

    local function AddHeader(text)
        if y < -12 then y = y - 6 end
        local hdr = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hdr:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
        hdr:SetText(text)
        local line = panel:CreateTexture(nil, "ARTWORK")
        line:SetTexture(1, 0.82, 0, 0.35)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -2)
        line:SetWidth(CONTENT_W - 20)
        y = y - 24
    end

    -- Section 1: Built-in ClassicAPI Tools
    AddHeader("ClassicAPI Built-in Debug & Utility Windows")
    local toolButtons = {
        { label = "/profiler", tip = "Open Lua memory & CPU profiler.", cmd = "/profiler" },
        { label = "/profiler widget", tip = "Toggle compact live memory/FPS profiler widget.", cmd = "/profiler widget" },
        { label = "/etrace", tip = "Toggle real-time Event Trace window.", cmd = "/etrace" },
        { label = "/framestack", tip = "Toggle interactive FrameStack inspector under cursor.", cmd = "/framestack" },
        { label = "/tinspect", tip = "Open Table Inspector on frame under cursor.", cmd = "/tinspect" },
        { label = "/luaerrors", tip = "Open ClassicAPI's Lua Error window.", cmd = "/luaerrors" },
        { label = "/classicapi", tip = "Open in-game ClassicAPI documentation browser.", cmd = "/classicapi" },
        { label = "/addons", tip = "Open ClassicAPI's Retail-style in-game AddOn List (Requires v1.23.9+).", cmd = "/addons", minVersion = 12309, minVersionStr = "v1.23.9" },
        { label = "/replay", tip = "Open 3D Encounter Replay window.", cmd = "/replay" },
        {
            label = "Built-in Options",
            tip = "Open ClassicAPI's native AddOn Options panel.",
            func = function()
                if C_SettingsUtil and type(C_SettingsUtil.OpenSettingsPanel) == "function" then
                    pcall(C_SettingsUtil.OpenSettingsPanel)
                else
                    CAS.Print("C_SettingsUtil.OpenSettingsPanel is unavailable.")
                end
            end,
        },
        {
            label = "Reload UI",
            tip = "Run ReloadUI() (required after toggling scriptProfile).",
            func = function()
                ReloadUI()
            end,
        },
    }

    local col = 0
    local i
    for i = 1, table.getn(toolButtons) do
        local tb = toolButtons[i]
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetWidth(155)
        btn:SetHeight(23)
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", 10 + col * 164, y)
        btn:SetText(tb.label)
        local curTb = tb
        btn:SetScript("OnClick", function()
            if curTb.minVersion then
                local okSup, reason = CAS.GetItemSupportStatus(curTb)
                if not okSup then
                    CAS.Print("|cffff5533[Unsupported]|r Cannot run '" .. curTb.label .. "': " .. tostring(reason))
                    return
                end
            end
            if curTb.func then
                curTb.func()
            elseif curTb.cmd then
                CAS.RunSlash(curTb.cmd)
            end
        end)
        SetTooltip(btn, tb.label, { tb.tip })
        col = col + 1
        if col >= 3 then
            col = 0
            y = y - 28
        end
    end
    if col > 0 then y = y - 28 end

    -- Section 2: Built-in Presets
    AddHeader("One-Click Configuration Presets")
    for i = 1, table.getn(CAS.BuiltInPresets) do
        local p = CAS.BuiltInPresets[i]
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetWidth(155)
        btn:SetHeight(23)
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, y)
        btn:SetText(p.label)
        local curP = p
        btn:SetScript("OnClick", function()
            curP.apply()
            CAS.Print("Applied preset: |cffffd200" .. curP.label .. "|r")
            CAS.RefreshUI()
        end)
        SetTooltip(btn, "Preset: " .. p.label, { p.desc, "Click to apply these CVar values immediately." })

        local descFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        descFS:SetPoint("LEFT", btn, "RIGHT", 10, 0)
        descFS:SetWidth(CONTENT_W - 185)
        descFS:SetJustifyH("LEFT")
        descFS:SetText(p.desc)
        y = y - 28
    end

    local resetAllBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetAllBtn:SetWidth(230)
    resetAllBtn:SetHeight(24)
    resetAllBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, y - 2)
    resetAllBtn:SetText("Reset All ClassicAPI CVars to Default")
    resetAllBtn:SetScript("OnClick", function()
        local changed = CAS.ResetAllCVarsToDefault()
        CAS.Print("Reset " .. tostring(changed) .. " ClassicAPI CVar(s) to default.")
        CAS.RefreshUI()
    end)
    SetTooltip(resetAllBtn, "Reset All CVars", { "Restores every ClassicAPI CVar managed by this addon back to GetCVarDefault()." })
    y = y - 34

    -- Section 3: Addon Preferences
    AddHeader("ClassicAPISettings Addon Preferences")

    local cbMinimap = CreateFrame("CheckButton", NextWidgetName("Check"), panel, "UICheckButtonTemplate")
    cbMinimap:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
    cbMinimap:SetWidth(24)
    cbMinimap:SetHeight(24)
    getglobal(cbMinimap:GetName() .. "Text"):SetFontObject(GameFontHighlightSmall)
    getglobal(cbMinimap:GetName() .. "Text"):SetText("Show Minimap Button")
    cbMinimap:SetScript("OnClick", function()
        if isRefreshing then return end
        ClassicAPISettingsDB.showMinimap = this:GetChecked() and true or false
        CAS.UpdateMinimapButton()
    end)
    SetTooltip(cbMinimap, "Show Minimap Button", { "Toggle the draggable Vanilla gear icon around your minimap. You can always open settings with /capi." })
    y = y - 26

    local cbLoginWarn = CreateFrame("CheckButton", NextWidgetName("Check"), panel, "UICheckButtonTemplate")
    cbLoginWarn:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
    cbLoginWarn:SetWidth(24)
    cbLoginWarn:SetHeight(24)
    getglobal(cbLoginWarn:GetName() .. "Text"):SetFontObject(GameFontHighlightSmall)
    getglobal(cbLoginWarn:GetName() .. "Text"):SetText("Print Chat Warning on Login if HIGH/WARN Overlaps Found")
    cbLoginWarn:SetScript("OnClick", function()
        if isRefreshing then return end
        ClassicAPISettingsDB.warnOnLogin = this:GetChecked() and true or false
    end)
    SetTooltip(cbLoginWarn, "Login Overlap Warning", { "Print a one-line reminder in chat on login whenever HIGH or WARN cross-mod overlaps are detected." })
    y = y - 30

    panel.refreshCustom = function()
        if ClassicAPISettingsDB then
            cbMinimap:SetChecked(ClassicAPISettingsDB.showMinimap and 1 or nil)
            cbLoginWarn:SetChecked(ClassicAPISettingsDB.warnOnLogin and 1 or nil)
        end
    end

    panel.contentHeight = math.max(360, -y + 20)
end

function CAS.SelectTab(tabId)
    activeTabId = tabId
    local i
    for i = 1, table.getn(CAS.Tabs) do
        local t = CAS.Tabs[i]
        local panel = tabPanels[t.id]
        local btn = tabButtons[t.id]
        if t.id == tabId then
            if panel then panel:Show() end
            if btn then
                btn:Disable()
                btn:SetBackdropColor(0.25, 0.2, 0.08, 1)
                btn:SetBackdropBorderColor(1, 0.82, 0, 1)
            end
        else
            if panel then panel:Hide() end
            if btn then
                btn:Enable()
                btn:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
                btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.9)
            end
        end
    end

    if scrollFrame then
        scrollFrame:SetVerticalScroll(0)
    end
    CAS.RefreshUI()
end

function CAS.RefreshUI()
    if not mainFrame then return end
    isRefreshing = true

    CAS.ScanOverlaps()
    local high, warn, info = CAS.GetOverlapCounts()

    -- Update Overlaps tab label with badge count
    local ovBtn = tabButtons["overlaps"]
    if ovBtn then
        if high > 0 then
            ovBtn:SetText("|cffff3333Overlaps (" .. (high + warn) .. ")|r")
        elseif warn > 0 then
            ovBtn:SetText("|cffffaa22Overlaps (" .. warn .. ")|r")
        elseif info > 0 then
            ovBtn:SetText("Overlaps (" .. info .. ")")
        else
            ovBtn:SetText("Overlaps")
        end
    end

    -- Update status bar text
    if mainFrame.statusFS then
        local ver
        if not CAS.Mods.classicapi then
            ver = "Target: " .. CAS.TARGET_CLASSICAPI_STRING .. "+  |  |cffff3333ClassicAPI NOT DETECTED|r"
        elseif CAS.Mods.classicapiOutdated then
            ver = "Target: " .. CAS.TARGET_CLASSICAPI_STRING .. "+  |  Installed: |cffffaa22" .. CAS.Mods.classicapiVersion .. " (Update!)|r"
        else
            ver = "Target: " .. CAS.TARGET_CLASSICAPI_STRING .. "+  |  Installed: |cff44ff44" .. CAS.Mods.classicapiVersion .. "|r"
        end
        local ovTxt = ""
        if high > 0 then
            ovTxt = "   |   |cffff3333" .. high .. " HIGH|r"
        elseif warn > 0 then
            ovTxt = "   |   |cffffaa22" .. warn .. " WARN|r"
        else
            ovTxt = "   |   |cff44ff44OK|r"
        end
        mainFrame.statusFS:SetText(ver .. ovTxt)
    end

    local panel = tabPanels[activeTabId]
    if panel then
        if panel.controls then
            local i
            for i = 1, table.getn(panel.controls) do
                panel.controls[i].refresh()
            end
        end
        if panel.refreshCustom then
            panel.refreshCustom()
        end
        if scrollChild then
            scrollChild:SetHeight(panel.contentHeight or 360)
        end
    end

    isRefreshing = false
end

function CAS.CreateUI()
    if mainFrame then return mainFrame end

    mainFrame = CreateFrame("Frame", "ClassicAPISettingsFrame", UIParent)
    mainFrame:SetWidth(FRAME_W)
    mainFrame:SetHeight(FRAME_H)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    mainFrame:SetFrameStrata("DIALOG")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:SetClampedToScreen(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function() this:StartMoving() end)
    mainFrame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local point, _, relPoint, x, y = this:GetPoint()
        if ClassicAPISettingsDB then
            ClassicAPISettingsDB.pos = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)

    mainFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    -- Vanilla Header Ribbon
    local headerTex = mainFrame:CreateTexture(nil, "ARTWORK")
    headerTex:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    headerTex:SetWidth(320)
    headerTex:SetHeight(64)
    headerTex:SetPoint("TOP", mainFrame, "TOP", 0, 12)

    local titleFS = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFS:SetPoint("TOP", headerTex, "TOP", 0, -14)
    titleFS:SetText("ClassicAPI Settings (" .. CAS.TARGET_CLASSICAPI_STRING .. "+)")

    local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -6, -6)

    local TAB_TIPS = {
        general = "Gameplay QoL, key-down casting, auto stand/dismount/unshift, cursors, cooldown numbers, and persistent player cache.",
        softtarget = "Soft Interact, Soft Enemy, Soft Friend modes, arcs, ranges, and world/nameplate icon sizing.",
        camera = "ActionCam presets, Over-the-Shoulder, Dynamic Pitch, Head Movement, Target Focus, Vertical Smoothing, and Indirect Visibility (v1.23.9+).",
        combat = "Built-in Damage Meter, Combat Log retention, Advanced Combat Logging, and 3D Encounter Replay.",
        perf = "Foreground/background FPS caps, animation framerate, CPU profiling, nameplate alpha, bag sorting, AutoComplete, and TTS.",
        overlaps = "Detected client DLL mods and active cross-mod overlap warnings with one-click Quick Fix actions.",
        tools = "Quick launchers for ClassicAPI debug tools (/profiler, /etrace, /fstack, /replay), built-in presets, and addon options.",
    }
    -- Tab bar
    local numTabs = table.getn(CAS.Tabs)
    local tabW = math.floor((FRAME_W - 36) / numTabs)
    local i
    for i = 1, numTabs do
        local t = CAS.Tabs[i]
        local btn = CreateFrame("Button", nil, mainFrame)
        btn:SetWidth(tabW - 3)
        btn:SetHeight(24)
        btn:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18 + (i - 1) * tabW, -34)
        btn:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        btn:SetNormalFontObject(GameFontNormalSmall)
        btn:SetDisabledFontObject(GameFontHighlightSmall)
        btn:SetHighlightFontObject(GameFontHighlightSmall)
        btn:SetText(t.title)
        local curId = t.id
        btn:SetScript("OnClick", function()
            CAS.SelectTab(curId)
        end)
        if TAB_TIPS[t.id] then
            SetTooltip(btn, t.title, { TAB_TIPS[t.id] })
        end
        tabButtons[t.id] = btn
    end

    -- Content Box
    local contentBox = CreateFrame("Frame", nil, mainFrame)
    contentBox:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 16, -62)
    contentBox:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -16, 40)
    contentBox:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    contentBox:SetBackdropColor(0.03, 0.03, 0.04, 0.78)
    contentBox:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)

    scrollFrame = CreateFrame("ScrollFrame", "ClassicAPISettingsScrollFrame", contentBox, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", contentBox, "TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", contentBox, "BOTTOMRIGHT", -28, 6)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function()
        local sb = getglobal("ClassicAPISettingsScrollFrameScrollBar")
        if not sb then return end
        local cur = sb:GetValue() or 0
        local step = 32
        if arg1 > 0 then
            sb:SetValue(cur - step)
        else
            sb:SetValue(cur + step)
        end
    end)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(CONTENT_W)
    scrollChild:SetHeight(400)
    scrollFrame:SetScrollChild(scrollChild)

    -- Build all tab panels
    for i = 1, numTabs do
        local t = CAS.Tabs[i]
        local panel = CreateFrame("Frame", nil, scrollChild)
        panel:SetAllPoints(scrollChild)
        panel:Hide()
        if t.id == "overlaps" then
            BuildOverlapsTab(panel)
        elseif t.id == "tools" then
            BuildToolsTab(panel)
        else
            BuildStandardTab(panel, t)
        end
        tabPanels[t.id] = panel
    end

    -- Bottom Status Bar & Close Button
    mainFrame.statusFS = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.statusFS:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 20, 17)

    local okBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    okBtn:SetWidth(80)
    okBtn:SetHeight(22)
    okBtn:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -18, 13)
    okBtn:SetText("Close")
    okBtn:SetScript("OnClick", function()
        mainFrame:Hide()
    end)

    -- Restore saved position
    if ClassicAPISettingsDB and ClassicAPISettingsDB.pos then
        local p = ClassicAPISettingsDB.pos
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint(p.point or "CENTER", UIParent, p.relPoint or "CENTER", p.x or 0, p.y or 20)
    end

    mainFrame:SetScript("OnShow", function()
        CAS.RefreshUI()
    end)

    table.insert(UISpecialFrames, "ClassicAPISettingsFrame")
    mainFrame:Hide()
    CAS.SelectTab(activeTabId)
    return mainFrame
end

function CAS.ToggleUI(tabId)
    local f = CAS.CreateUI()
    if tabId then
        CAS.SelectTab(tabId)
        f:Show()
        return
    end
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end
