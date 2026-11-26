-- ClassicAPISettings: Vanilla-Styled Options Frame (v1.2.0)
-- Features: Search & Modified-Only filter, exact Slider EditBox inputs,
-- ClassicAPI keybind status bar, Custom Profiles + Export/Import,
-- Custom Boss Creature IDs (v1.23.9+), and Cross-Mod Overlap detection.
-- Strict Lua 5.0 compatible.

ClassicAPISettings = ClassicAPISettings or {}
local CAS = ClassicAPISettings

local FRAME_W = 630
local FRAME_H = 530
local CONTENT_W = 565

local mainFrame = nil
local scrollFrame = nil
local scrollChild = nil
local exportDialog = nil
local tabButtons = {}
local tabPanels = {}
local searchPanel = nil
local searchBox = nil
local modifiedOnlyCB = nil
local searchClearBtn = nil
local searchCountFS = nil
local undoBtn = nil
local resetTabBtn = nil
local reloadWarnBtn = nil
local pendingDeleteProfile = nil
local activeTabId = "general"

-- Vanilla Confirmation Popups
StaticPopupDialogs["CLASSICAPISETTINGS_RESET_ALL"] = {
    text = "Reset ALL ClassicAPI CVars managed by ClassicAPI Settings back to their default values?",
    button1 = "Reset All",
    button2 = "Cancel",
    OnAccept = function()
        CAS.PushUndoSnapshot("Reset All CVars")
        local changed = CAS.ResetAllCVarsToDefault()
        CAS.Print("Reset " .. tostring(changed) .. " ClassicAPI CVar(s) to default. Use Undo to revert.")
        CAS.RefreshUI()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

StaticPopupDialogs["CLASSICAPISETTINGS_DELETE_PROFILE"] = {
    text = "Delete saved profile '%s'?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function()
        if pendingDeleteProfile then
            CAS.DeleteProfile(pendingDeleteProfile)
            CAS.Print("Deleted profile: " .. tostring(pendingDeleteProfile))
            pendingDeleteProfile = nil
            CAS.RefreshUI()
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}
local searchQuery = ""
local modifiedOnly = false
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
    elseif CAS.GetDependencyStatus then
        local depActive, depReason = CAS.GetDependencyStatus(item)
        if not depActive and depReason then
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine("[INACTIVE] " .. depReason, 0.85, 0.72, 0.35, 1)
        end
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

local function StyleMiniEditBox(eb)
    eb:SetAutoFocus(false)
    eb:SetFontObject(GameFontHighlightSmall)
    eb:SetTextInsets(4, 4, 2, 2)
    eb:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    eb:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
    eb:SetBackdropBorderColor(0.55, 0.55, 0.55, 0.9)
end

local function IsItemModified(item)
    local supported = CAS.GetItemSupportStatus(item)
    if not supported then return false end
    if item.kind == "api_bool" then
        return item.get() ~= item.default
    elseif item.kind == "api_slider" then
        local v = item.get() or item.default
        return math.abs(v - item.default) > 0.001
    elseif item.kind == "bool" or item.kind == "cycle" or item.kind == "tts_voice" then
        local cur = CAS.SafeGetCVar(item.key)
        local def = CAS.SafeGetCVarDefault(item.key)
        return (def ~= nil and cur ~= nil and cur ~= def)
    elseif item.kind == "slider" then
        local cur = tonumber(CAS.SafeGetCVar(item.key))
        local def = tonumber(CAS.SafeGetCVarDefault(item.key))
        return (cur ~= nil and def ~= nil and math.abs(cur - def) > 0.001)
    end
    return false
end

-- Shared setting row factory (used by both Standard Tabs and the Search/Filter panel)
local function CreateSettingWidget(parent, item, prefixTag)
    local tagStr = prefixTag and ("|cff88ccff[" .. prefixTag .. "]|r ") or ""
    local curItem = item

    if item.kind == "bool" or item.kind == "api_bool" then
        local row = CreateFrame("Frame", nil, parent)
        row:SetWidth(CONTENT_W - 16)
        row:SetHeight(24)

        local cb = CreateFrame("CheckButton", NextWidgetName("Check"), row, "UICheckButtonTemplate")
        cb:SetPoint("LEFT", row, "LEFT", 0, 0)
        cb:SetWidth(24)
        cb:SetHeight(24)

        local text = getglobal(cb:GetName() .. "Text")
        text:SetFontObject(GameFontHighlightSmall)
        text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        text:SetText(item.label)

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

        return {
            row = row,
            height = 24,
            item = curItem,
            refresh = function()
                local supported = CAS.GetItemSupportStatus(curItem)
                local badge = tagStr .. GetUnsupportedTag(curItem) .. (GetBadgeTextForKey(curItem.key) or "")
                local isMod = false
                if curItem.kind == "api_bool" then
                    local val = curItem.get()
                    cb:SetChecked(val and 1 or nil)
                    isMod = supported and (val ~= curItem.default)
                else
                    local val = CAS.SafeGetCVar(curItem.key)
                    local def = CAS.SafeGetCVarDefault(curItem.key)
                    cb:SetChecked((val == "1") and 1 or nil)
                    isMod = supported and (def ~= nil and val ~= nil and val ~= def)
                end
                cb:Enable()
                text:SetText(badge .. curItem.label)
                if not supported then
                    text:SetTextColor(0.75, 0.52, 0.35)
                    resetBtn:Hide()
                elseif isMod then
                    text:SetTextColor(1, 0.85, 0.2)
                    resetBtn:Show()
                else
                    text:SetTextColor(0.92, 0.92, 0.92)
                    resetBtn:Hide()
                end
                local depActive = (not CAS.GetDependencyStatus) or CAS.GetDependencyStatus(curItem)
                row:SetAlpha((supported and depActive) and 1.0 or 0.48)
            end,
        }

    elseif item.kind == "slider" or item.kind == "api_slider" then
        local row = CreateFrame("Frame", nil, parent)
        row:SetWidth(CONTENT_W - 16)
        row:SetHeight(44)

        local titleFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        titleFS:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -3)
        titleFS:SetText(item.label)

        -- Exact numeric input EditBox
        local valEB = CreateFrame("EditBox", NextWidgetName("ValEdit"), row)
        valEB:SetWidth(54)
        valEB:SetHeight(18)
        valEB:SetPoint("TOPRIGHT", row, "TOPRIGHT", -32, -1)
        valEB:SetJustifyH("RIGHT")
        StyleMiniEditBox(valEB)

        local sName = NextWidgetName("Slider")
        local slider = CreateFrame("Slider", sName, row, "OptionsSliderTemplate")
        slider:SetWidth(CONTENT_W - 60)
        slider:SetHeight(16)
        slider:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -21)
        slider:SetMinMaxValues(item.min, item.max)
        slider:SetValueStep(item.step)

        local lowFS = getglobal(sName .. "Low")
        local highFS = getglobal(sName .. "High")
        local txtFS = getglobal(sName .. "Text")
        if lowFS then lowFS:SetText(tostring(item.min)) end
        if highFS then highFS:SetText(tostring(item.max)) end
        if txtFS then txtFS:SetText("") end

        local function FormatEditVal(v)
            if curItem.step < 1 then
                return string.format("%.2f", v)
            end
            return tostring(math.floor(v + 0.5))
        end

        local function ApplyNumericValue(v)
            if v < curItem.min then v = curItem.min end
            if v > curItem.max then v = curItem.max end
            if curItem.kind == "api_slider" then
                curItem.set(v)
            else
                local strVal = (curItem.step < 1) and string.format("%.2f", v) or tostring(math.floor(v + 0.5))
                CAS.SafeSetCVar(curItem.key, strVal)
            end
        end

        valEB:SetScript("OnEnterPressed", function()
            local okSup, reason = CAS.GetItemSupportStatus(curItem)
            this:ClearFocus()
            if not okSup then
                CAS.Print("|cffff5533[Unsupported]|r Cannot change '" .. curItem.label .. "': " .. tostring(reason))
                CAS.RefreshUI()
                return
            end
            local num = tonumber(this:GetText())
            if num then
                ApplyNumericValue(num)
            end
            CAS.RefreshUI()
        end)
        valEB:SetScript("OnEscapePressed", function()
            this:ClearFocus()
            CAS.RefreshUI()
        end)
        SetTooltip(valEB, "Exact Value Input", {
            "Click to type an exact number (" .. tostring(curItem.min) .. " to " .. tostring(curItem.max) .. "), then press Enter.",
        })

        slider:SetScript("OnValueChanged", function()
            if isRefreshing then return end
            local okSup = CAS.GetItemSupportStatus(curItem)
            if not okSup then return end
            local v = this:GetValue()
            if curItem.step < 1 then
                v = math.floor(v / curItem.step + 0.5) * curItem.step
            else
                v = math.floor(v + 0.5)
            end
            valEB:SetText(FormatEditVal(v))
            ApplyNumericValue(v)
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
        resetBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -1)

        return {
            row = row,
            height = 46,
            item = curItem,
            refresh = function()
                local supported = CAS.GetItemSupportStatus(curItem)
                local badge = tagStr .. GetUnsupportedTag(curItem) .. (GetBadgeTextForKey(curItem.key) or "")
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
                if not (valEB.HasFocus and valEB:HasFocus()) then
                    valEB:SetText(supported and FormatEditVal(numVal) or "N/A")
                end
                titleFS:SetText(badge .. curItem.label)
                local isMod = supported and (defNum ~= nil and math.abs(numVal - defNum) > 0.001)
                if not supported then
                    titleFS:SetTextColor(0.75, 0.52, 0.35)
                    resetBtn:Hide()
                elseif isMod then
                    titleFS:SetTextColor(1, 0.85, 0.2)
                    resetBtn:Show()
                else
                    titleFS:SetTextColor(0.92, 0.92, 0.92)
                    resetBtn:Hide()
                end
                local depActive = (not CAS.GetDependencyStatus) or CAS.GetDependencyStatus(curItem)
                row:SetAlpha((supported and depActive) and 1.0 or 0.48)
            end,
        }

    elseif item.kind == "cycle" or item.kind == "tts_voice" then
        local row = CreateFrame("Frame", nil, parent)
        row:SetWidth(CONTENT_W - 16)
        row:SetHeight(26)

        local titleFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        titleFS:SetPoint("LEFT", row, "LEFT", 6, 0)
        titleFS:SetText(item.label)

        local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btn:SetWidth(185)
        btn:SetHeight(21)
        btn:SetPoint("RIGHT", row, "RIGHT", -32, 0)

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

        return {
            row = row,
            height = 28,
            item = curItem,
            refresh = function()
                local supported = CAS.GetItemSupportStatus(curItem)
                local badge = tagStr .. GetUnsupportedTag(curItem) .. (GetBadgeTextForKey(curItem.key) or "")
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
                local isMod = supported and (def ~= nil and cur ~= nil and cur ~= def)
                if not supported then
                    titleFS:SetTextColor(0.75, 0.52, 0.35)
                    resetBtn:Hide()
                elseif isMod then
                    titleFS:SetTextColor(1, 0.85, 0.2)
                    resetBtn:Show()
                else
                    titleFS:SetTextColor(0.92, 0.92, 0.92)
                    resetBtn:Hide()
                end
                local depActive = (not CAS.GetDependencyStatus) or CAS.GetDependencyStatus(curItem)
                row:SetAlpha((supported and depActive) and 1.0 or 0.48)
            end,
        }
    end

    return nil
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

        elseif item.kind == "bindings_bar" then
            local bar = CreateFrame("Frame", nil, panel)
            bar:SetWidth(CONTENT_W - 20)
            bar:SetHeight(26)
            bar:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
            bar:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            bar:SetBackdropColor(0.08, 0.1, 0.14, 0.85)
            bar:SetBackdropBorderColor(0.4, 0.55, 0.75, 0.8)

            local infoFS = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            infoFS:SetPoint("LEFT", bar, "LEFT", 8, 0)
            infoFS:SetWidth(CONTENT_W - 140)
            infoFS:SetJustifyH("LEFT")

            local kbBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
            kbBtn:SetWidth(96)
            kbBtn:SetHeight(19)
            kbBtn:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
            kbBtn:SetText("Key Bindings")
            kbBtn:SetScript("OnClick", function()
                CAS.OpenKeyBindings()
            end)
            SetTooltip(kbBtn, "Open Key Bindings", { "Opens WoW's Key Bindings window (Targeting Functions group)." })

            local curBindings = item.bindings
            table.insert(panel.controls, {
                item = item,
                refresh = function()
                    local parts = {}
                    local bi
                    for bi = 1, table.getn(curBindings) do
                        local b = curBindings[bi]
                        local keyText = CAS.GetBindingDisplay(b.action)
                        if keyText then
                            table.insert(parts, b.label .. ": |cff44ff44[" .. keyText .. "]|r")
                        else
                            table.insert(parts, b.label .. ": |cffff5555Not Bound|r")
                        end
                    end
                    infoFS:SetText(table.concat(parts, "    |    "))
                end,
            })
            y = y - 32

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
                    CAS.PushUndoSnapshot("Preset: " .. curBDef.label)
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

        else
            local widget = CreateSettingWidget(panel, item, nil)
            if widget then
                widget.row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
                table.insert(panel.controls, widget)
                y = y - widget.height
            end
        end
    end

    panel.contentHeight = math.max(360, -y + 20)
end

-- Cross-tab Search & Modified-Only panel (reuses pre-built rows, zero per-keystroke allocations)
local function BuildSearchPanel(panel)
    panel.entries = {}
    local emptyFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyFS:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -14)
    emptyFS:SetText("|cffaaaaaaNo settings match your current filter.|r")
    emptyFS:Hide()

    local t, i
    for t = 1, table.getn(CAS.Tabs) do
        local tab = CAS.Tabs[t]
        if tab.items then
            for i = 1, table.getn(tab.items) do
                local item = tab.items[i]
                if item.kind == "bool" or item.kind == "slider" or item.kind == "cycle" or item.kind == "tts_voice" or item.kind == "api_bool" or item.kind == "api_slider" then
                    local widget = CreateSettingWidget(panel, item, tab.title)
                    if widget then
                        widget.row:Hide()
                        local haystack = string.lower(
                            tostring(item.label or "") .. " " ..
                            tostring(item.key or "") .. " " ..
                            tostring(item.desc or "") .. " " ..
                            tostring(tab.title or "")
                        )
                        table.insert(panel.entries, {
                            widget = widget,
                            haystack = haystack,
                        })
                    end
                end
            end
        end
    end

    panel.refreshSearch = function()
        local q = string.lower(searchQuery or "")
        local y = -8
        local shown = 0
        local ei
        for ei = 1, table.getn(panel.entries) do
            local entry = panel.entries[ei]
            local matchText = (q == "") or (string.find(entry.haystack, q, 1, true) ~= nil)
            local matchMod = (not modifiedOnly) or IsItemModified(entry.widget.item)
            if matchText and matchMod then
                entry.widget.row:ClearAllPoints()
                entry.widget.row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
                entry.widget.row:Show()
                entry.widget.refresh()
                y = y - entry.widget.height
                shown = shown + 1
            else
                entry.widget.row:Hide()
            end
        end
        if shown == 0 then
            emptyFS:Show()
            panel.contentHeight = 360
        else
            emptyFS:Hide()
            panel.contentHeight = math.max(360, -y + 20)
        end
        if searchCountFS then
            searchCountFS:SetText("|cff88ccff" .. tostring(shown) .. (shown == 1 and " match|r" or " matches|r"))
            searchCountFS:Show()
        end
    end
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
                local capFixLabel = ov.fixLabel
                card.fixBtn:SetScript("OnClick", function()
                    CAS.PushUndoSnapshot("Quick Fix: " .. capFixLabel)
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

-- Export / Import Popup Dialog
function CAS.ShowExportImportDialog(mode)
    if not exportDialog then
        exportDialog = CreateFrame("Frame", "ClassicAPISettingsExportFrame", UIParent)
        exportDialog:SetWidth(460)
        exportDialog:SetHeight(240)
        exportDialog:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        exportDialog:SetFrameStrata("FULLSCREEN_DIALOG")
        exportDialog:SetMovable(true)
        exportDialog:EnableMouse(true)
        exportDialog:RegisterForDrag("LeftButton")
        exportDialog:SetScript("OnDragStart", function() this:StartMoving() end)
        exportDialog:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
        exportDialog:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })

        exportDialog.title = exportDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        exportDialog.title:SetPoint("TOP", exportDialog, "TOP", 0, -16)

        exportDialog.hint = exportDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        exportDialog.hint:SetPoint("TOPLEFT", exportDialog, "TOPLEFT", 20, -38)
        exportDialog.hint:SetWidth(420)
        exportDialog.hint:SetJustifyH("LEFT")

        local box = CreateFrame("Frame", nil, exportDialog)
        box:SetPoint("TOPLEFT", exportDialog, "TOPLEFT", 18, -62)
        box:SetPoint("BOTTOMRIGHT", exportDialog, "BOTTOMRIGHT", -18, 46)
        box:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        box:SetBackdropColor(0.04, 0.04, 0.06, 0.95)

        local eb = CreateFrame("EditBox", "ClassicAPISettingsExportEditBox", box)
        eb:SetMultiLine(true)
        eb:SetMaxLetters(4096)
        eb:SetFontObject(GameFontHighlightSmall)
        eb:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8)
        eb:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 8)
        eb:SetScript("OnEscapePressed", function() exportDialog:Hide() end)
        exportDialog.editBox = eb

        exportDialog.actionBtn = CreateFrame("Button", nil, exportDialog, "UIPanelButtonTemplate")
        exportDialog.actionBtn:SetWidth(110)
        exportDialog.actionBtn:SetHeight(22)
        exportDialog.actionBtn:SetPoint("BOTTOMLEFT", exportDialog, "BOTTOMLEFT", 20, 16)

        local closeBtn = CreateFrame("Button", nil, exportDialog, "UIPanelButtonTemplate")
        closeBtn:SetWidth(80)
        closeBtn:SetHeight(22)
        closeBtn:SetPoint("BOTTOMRIGHT", exportDialog, "BOTTOMRIGHT", -20, 16)
        closeBtn:SetText("Close")
        closeBtn:SetScript("OnClick", function() exportDialog:Hide() end)

        table.insert(UISpecialFrames, "ClassicAPISettingsExportFrame")
    end

    if mode == "export" then
        exportDialog.title:SetText("Export ClassicAPI Settings")
        exportDialog.hint:SetText("Press Ctrl+C to copy your modified ClassicAPI settings string:")
        exportDialog.editBox:SetText(CAS.ExportCurrentSettings())
        exportDialog.editBox:SetFocus()
        exportDialog.editBox:HighlightText()
        exportDialog.actionBtn:SetText("Select All")
        exportDialog.actionBtn:SetScript("OnClick", function()
            exportDialog.editBox:SetFocus()
            exportDialog.editBox:HighlightText()
        end)
    else
        exportDialog.title:SetText("Import ClassicAPI Settings")
        exportDialog.hint:SetText("Paste a CAS1|... string below and click Apply Import:")
        exportDialog.editBox:SetText("")
        exportDialog.editBox:SetFocus()
        exportDialog.actionBtn:SetText("Apply Import")
        exportDialog.actionBtn:SetScript("OnClick", function()
            CAS.PushUndoSnapshot("Import Settings")
            local ok, applied, skipped, err = CAS.ImportSettingsString(exportDialog.editBox:GetText())
            if not ok then
                CAS.Print("|cffff5533[Import Error]|r " .. tostring(err))
                return
            end
            CAS.Print(string.format("Imported settings: %d applied, %d skipped.", applied, skipped))
            exportDialog:Hide()
            CAS.RefreshUI()
        end)
    end
    exportDialog:Show()
end

local function BuildToolsTab(panel)
    panel.controls = {}
    panel.profileRows = {}
    panel.bossRows = {}
    local y = -8

    local function AddHeader(text, anchorY)
        if anchorY < -12 then anchorY = anchorY - 6 end
        local hdr = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hdr:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, anchorY)
        hdr:SetText(text)
        local line = panel:CreateTexture(nil, "ARTWORK")
        line:SetTexture(1, 0.82, 0, 0.35)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -2)
        line:SetWidth(CONTENT_W - 20)
        return anchorY - 24
    end

    -- Section 1: Built-in ClassicAPI Tools
    y = AddHeader("ClassicAPI Built-in Debug & Utility Windows", y)
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
        btn:SetWidth(168)
        btn:SetHeight(23)
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", 10 + col * 176, y)
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
            y = y - 27
        end
    end
    if col > 0 then y = y - 27 end

    -- Section 2: Built-in Presets
    y = AddHeader("One-Click Configuration Presets", y)
    for i = 1, table.getn(CAS.BuiltInPresets) do
        local p = CAS.BuiltInPresets[i]
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetWidth(155)
        btn:SetHeight(22)
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, y)
        btn:SetText(p.label)
        local curP = p
        btn:SetScript("OnClick", function()
            CAS.PushUndoSnapshot("Preset: " .. curP.label)
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
        y = y - 26
    end

    local resetAllBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetAllBtn:SetWidth(235)
    resetAllBtn:SetHeight(23)
    resetAllBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, y - 2)
    resetAllBtn:SetText("Reset All ClassicAPI CVars to Default")
    resetAllBtn:SetScript("OnClick", function()
        StaticPopup_Show("CLASSICAPISETTINGS_RESET_ALL")
    end)
    SetTooltip(resetAllBtn, "Reset All CVars", { "Restores every ClassicAPI CVar managed by this addon back to GetCVarDefault()." })
    y = y - 32

    -- Section 3: Addon Preferences
    y = AddHeader("ClassicAPISettings Addon Preferences", y)

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
    y = y - 24

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
    y = y - 28

    -- Section 4: Custom User Profiles & Export/Import
    y = AddHeader("Custom User Profiles & Export / Import", y)

    local profEB = CreateFrame("EditBox", NextWidgetName("ProfName"), panel)
    profEB:SetWidth(180)
    profEB:SetHeight(21)
    profEB:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, y)
    StyleMiniEditBox(profEB)
    profEB:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    SetTooltip(profEB, "Profile Name", { "Enter a name (e.g. Raid, PvP, OpenWorld) and click Save Profile." })

    local saveProfBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    saveProfBtn:SetWidth(95)
    saveProfBtn:SetHeight(22)
    saveProfBtn:SetPoint("LEFT", profEB, "RIGHT", 6, 0)
    saveProfBtn:SetText("Save Profile")
    saveProfBtn:SetScript("OnClick", function()
        local nm = profEB:GetText()
        local ok, err = CAS.SaveProfile(nm)
        if not ok then
            CAS.Print("|cffff5533[Profile]|r " .. tostring(err))
            return
        end
        profEB:SetText("")
        profEB:ClearFocus()
        CAS.Print("Saved profile: |cffffd200" .. tostring(nm) .. "|r")
        CAS.RefreshUI()
    end)
    SetTooltip(saveProfBtn, "Save Profile", { "Saves all current ClassicAPI CVars, C_PlayerCache, and MaxAnimFramerate under this profile name." })

    local exportBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    exportBtn:SetWidth(76)
    exportBtn:SetHeight(22)
    exportBtn:SetPoint("LEFT", saveProfBtn, "RIGHT", 8, 0)
    exportBtn:SetText("Export")
    exportBtn:SetScript("OnClick", function() CAS.ShowExportImportDialog("export") end)
    SetTooltip(exportBtn, "Export Settings", { "Generate a compact CAS1|... string of your modified ClassicAPI CVars for backup or sharing." })

    local importBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    importBtn:SetWidth(76)
    importBtn:SetHeight(22)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 6, 0)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function() CAS.ShowExportImportDialog("import") end)
    SetTooltip(importBtn, "Import Settings", { "Paste a CAS1|... string to apply exported ClassicAPI settings." })

    local profListTopY = y - 28
    local noProfFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noProfFS:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, profListTopY)
    noProfFS:SetText("|cffaaaaaaNo saved profiles yet.|r")

    -- Dynamic Section 4b: Auto-Switch Profile by Zone
    local autoSwAnchor = CreateFrame("Frame", nil, panel)
    autoSwAnchor:SetWidth(CONTENT_W - 16)
    autoSwAnchor:SetHeight(76)

    local cbAutoSw = CreateFrame("CheckButton", NextWidgetName("Check"), autoSwAnchor, "UICheckButtonTemplate")
    cbAutoSw:SetPoint("TOPLEFT", autoSwAnchor, "TOPLEFT", 0, 0)
    cbAutoSw:SetWidth(24)
    cbAutoSw:SetHeight(24)
    getglobal(cbAutoSw:GetName() .. "Text"):SetFontObject(GameFontHighlightSmall)
    getglobal(cbAutoSw:GetName() .. "Text"):SetText("Auto-Switch Profile by Zone (Open World / Dungeon / Raid / BG)")
    cbAutoSw:SetScript("OnClick", function()
        if isRefreshing then return end
        local cfg = CAS.EnsureAutoSwitchDB()
        cfg.enabled = this:GetChecked() and true or false
        if cfg.enabled then
            CAS.CheckAutoSwitchProfile(true)
        end
        CAS.RefreshUI()
    end)
    SetTooltip(cbAutoSw, "Auto-Switch Profile by Zone", { "Automatically loads the assigned profile whenever you enter Open World, a 5-man Dungeon, a Raid, or a Battleground." })

    local AUTO_CTX = {
        { key = "world", label = "World" },
        { key = "party", label = "Dungeon" },
        { key = "raid", label = "Raid" },
        { key = "pvp", label = "BG" },
    }
    local autoSwBtns = {}
    local ci
    for ci = 1, table.getn(AUTO_CTX) do
        local cDef = AUTO_CTX[ci]
        local colIdx = math.mod(ci - 1, 2)
        local rowIdx = math.floor((ci - 1) / 2)
        local lbl = autoSwAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT", autoSwAnchor, "TOPLEFT", 12 + colIdx * 265, -28 - rowIdx * 24)
        lbl:SetText(cDef.label .. ":")

        local btn = CreateFrame("Button", nil, autoSwAnchor, "UIPanelButtonTemplate")
        btn:SetWidth(175)
        btn:SetHeight(20)
        btn:SetPoint("TOPLEFT", autoSwAnchor, "TOPLEFT", 72 + colIdx * 265, -24 - rowIdx * 24)
        local capKey = cDef.key
        btn:SetScript("OnClick", function()
            local cfg = CAS.EnsureAutoSwitchDB()
            local names = CAS.GetProfileNames()
            local opts = { "" }
            local ni
            for ni = 1, table.getn(names) do table.insert(opts, names[ni]) end
            local cur = cfg[capKey] or ""
            local curIdx = 1
            for ni = 1, table.getn(opts) do
                if opts[ni] == cur then curIdx = ni break end
            end
            local nextIdx = curIdx + 1
            if nextIdx > table.getn(opts) then nextIdx = 1 end
            local chosen = opts[nextIdx]
            cfg[capKey] = (chosen ~= "") and chosen or nil
            CAS.RefreshUI()
        end)
        SetTooltip(btn, "Assign Profile for " .. cDef.label, { "Click to cycle through saved profiles (or None) for " .. cDef.label .. "." })
        autoSwBtns[cDef.key] = btn
    end

    -- Dynamic Section 5: Custom Boss Creature IDs (positioned below auto-switch)
    local bossSectionAnchor = CreateFrame("Frame", nil, panel)
    bossSectionAnchor:SetWidth(CONTENT_W - 16)
    bossSectionAnchor:SetHeight(64)

    local bossHdr = bossSectionAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bossHdr:SetPoint("TOPLEFT", bossSectionAnchor, "TOPLEFT", 0, 0)
    bossHdr:SetText("Custom Boss Creature IDs (C_InstanceEncounter, v1.23.9+)")

    local bossLine = bossSectionAnchor:CreateTexture(nil, "ARTWORK")
    bossLine:SetTexture(1, 0.82, 0, 0.35)
    bossLine:SetHeight(1)
    bossLine:SetPoint("TOPLEFT", bossHdr, "BOTTOMLEFT", 0, -2)
    bossLine:SetWidth(CONTENT_W - 20)

    local bossHint = bossSectionAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bossHint:SetPoint("TOPLEFT", bossHdr, "BOTTOMLEFT", 2, -6)
    bossHint:SetWidth(CONTENT_W - 24)
    bossHint:SetJustifyH("LEFT")
    bossHint:SetText("Auto-registered on every login /reload so custom Turtle WoW bosses get boss1..5 & Damage Meter sessions.")

    local bossIdEB = CreateFrame("EditBox", NextWidgetName("BossID"), bossSectionAnchor)
    bossIdEB:SetWidth(100)
    bossIdEB:SetHeight(21)
    bossIdEB:SetPoint("TOPLEFT", bossHint, "BOTTOMLEFT", 0, -6)
    StyleMiniEditBox(bossIdEB)
    bossIdEB:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    SetTooltip(bossIdEB, "Boss Creature ID", { "Enter a numeric Creature ID (e.g. 639 for Edwin VanCleef) and click Add ID." })

    local addBossBtn = CreateFrame("Button", nil, bossSectionAnchor, "UIPanelButtonTemplate")
    addBossBtn:SetWidth(75)
    addBossBtn:SetHeight(22)
    addBossBtn:SetPoint("LEFT", bossIdEB, "RIGHT", 6, 0)
    addBossBtn:SetText("Add ID")
    addBossBtn:SetScript("OnClick", function()
        local ok, res = CAS.AddBossID(bossIdEB:GetText(), "")
        if not ok then
            CAS.Print("|cffff5533[Boss ID]|r " .. tostring(res))
            return
        end
        bossIdEB:SetText("")
        bossIdEB:ClearFocus()
        CAS.Print("Added custom boss ID: |cffffd200" .. tostring(res) .. "|r")
        CAS.RefreshUI()
    end)

    local addTargetBossBtn = CreateFrame("Button", nil, bossSectionAnchor, "UIPanelButtonTemplate")
    addTargetBossBtn:SetWidth(135)
    addTargetBossBtn:SetHeight(22)
    addTargetBossBtn:SetPoint("LEFT", addBossBtn, "RIGHT", 6, 0)
    addTargetBossBtn:SetText("Add Current Target")
    addTargetBossBtn:SetScript("OnClick", function()
        local ok, res = CAS.AddTargetBossID()
        if not ok then
            CAS.Print("|cffff5533[Boss ID]|r " .. tostring(res))
            return
        end
        CAS.Print("Registered target as custom boss: |cffffd200" .. tostring(res) .. "|r")
        CAS.RefreshUI()
    end)
    SetTooltip(addTargetBossBtn, "Add Current Target", { "Reads UnitCreatureID('target') and persists it to auto-register with C_InstanceEncounter on every login." })

    local noBossFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noBossFS:SetText("|cffaaaaaaNo custom boss IDs saved.|r")

    local function EnsureProfileRow(idx)
        if panel.profileRows[idx] then return panel.profileRows[idx] end
        local r = CreateFrame("Frame", nil, panel)
        r:SetWidth(CONTENT_W - 24)
        r:SetHeight(22)
        r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.label:SetPoint("LEFT", r, "LEFT", 6, 0)
        r.delBtn = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.delBtn:SetWidth(24)
        r.delBtn:SetHeight(19)
        r.delBtn:SetPoint("RIGHT", r, "RIGHT", -2, 0)
        r.delBtn:SetText("X")
        r.loadBtn = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.loadBtn:SetWidth(58)
        r.loadBtn:SetHeight(19)
        r.loadBtn:SetPoint("RIGHT", r.delBtn, "LEFT", -4, 0)
        r.loadBtn:SetText("Load")
        panel.profileRows[idx] = r
        return r
    end

    local function EnsureBossRow(idx)
        if panel.bossRows[idx] then return panel.bossRows[idx] end
        local r = CreateFrame("Frame", nil, panel)
        r:SetWidth(CONTENT_W - 24)
        r:SetHeight(22)
        r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.label:SetPoint("LEFT", r, "LEFT", 6, 0)
        r.delBtn = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.delBtn:SetWidth(24)
        r.delBtn:SetHeight(19)
        r.delBtn:SetPoint("RIGHT", r, "RIGHT", -2, 0)
        r.delBtn:SetText("X")
        panel.bossRows[idx] = r
        return r
    end

    panel.refreshCustom = function()
        if ClassicAPISettingsDB then
            cbMinimap:SetChecked(ClassicAPISettingsDB.showMinimap and 1 or nil)
            cbLoginWarn:SetChecked(ClassicAPISettingsDB.warnOnLogin and 1 or nil)
        end

        -- Refresh saved profiles list
        local pNames = CAS.GetProfileNames()
        local pCount = table.getn(pNames)
        local idx
        for idx = 1, table.getn(panel.profileRows) do
            panel.profileRows[idx]:Hide()
        end
        local curY = profListTopY
        if pCount == 0 then
            noProfFS:Show()
            curY = curY - 22
        else
            noProfFS:Hide()
            for idx = 1, pCount do
                local pname = pNames[idx]
                local r = EnsureProfileRow(idx)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, curY)
                r.label:SetText("|cffffd200" .. pname .. "|r")
                local capName = pname
                r.loadBtn:SetScript("OnClick", function()
                    CAS.PushUndoSnapshot("Load Profile: " .. capName)
                    local ok, applied, skipped, err = CAS.LoadProfile(capName)
                    if ok then
                        CAS.Print(string.format("Loaded profile '|cffffd200%s|r' (%d applied, %d skipped).", capName, applied, skipped))
                        CAS.RefreshUI()
                    else
                        CAS.Print("|cffff5533[Profile]|r " .. tostring(err))
                    end
                end)
                r.delBtn:SetScript("OnClick", function()
                    pendingDeleteProfile = capName
                    StaticPopup_Show("CLASSICAPISETTINGS_DELETE_PROFILE", capName)
                end)
                r:Show()
                curY = curY - 23
            end
        end

        -- Position Auto-Switch Profile section below profiles
        curY = curY - 8
        autoSwAnchor:ClearAllPoints()
        autoSwAnchor:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, curY)
        local autoCfg = CAS.EnsureAutoSwitchDB()
        cbAutoSw:SetChecked(autoCfg.enabled and 1 or nil)
        local ci
        for ci = 1, table.getn(AUTO_CTX) do
            local cKey = AUTO_CTX[ci].key
            local assigned = autoCfg[cKey]
            local btn = autoSwBtns[cKey]
            if btn then
                btn:SetText(assigned and ("|cffffd200" .. assigned .. "|r") or "|cff888888(None)|r")
                btn:SetAlpha(autoCfg.enabled and 1.0 or 0.55)
            end
        end
        curY = curY - 76

        -- Position Custom Boss section below auto-switch
        curY = curY - 12
        bossSectionAnchor:ClearAllPoints()
        bossSectionAnchor:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, curY)
        local bossSupported = CAS.IsBossAPISupported()
        if bossSupported then
            bossHdr:SetText("Custom Boss Creature IDs (C_InstanceEncounter, v1.23.9+)")
        else
            bossHdr:SetText("|cffff6633[Req v1.23.9+]|r Custom Boss Creature IDs (C_InstanceEncounter)")
        end

        curY = curY - 72
        local bList = CAS.GetSavedBossList()
        local bCount = table.getn(bList)
        for idx = 1, table.getn(panel.bossRows) do
            panel.bossRows[idx]:Hide()
        end
        if bCount == 0 then
            noBossFS:ClearAllPoints()
            noBossFS:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, curY)
            noBossFS:Show()
            curY = curY - 22
        else
            noBossFS:Hide()
            for idx = 1, bCount do
                local b = bList[idx]
                local r = EnsureBossRow(idx)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, curY)
                r.label:SetText("|cff88ccff" .. tostring(b.id) .. "|r  -  " .. b.name)
                local capId = b.id
                r.delBtn:SetScript("OnClick", function()
                    CAS.RemoveBossID(capId)
                    CAS.Print("Removed custom boss ID: " .. tostring(capId))
                    CAS.RefreshUI()
                end)
                r:Show()
                curY = curY - 23
            end
        end

        panel.contentHeight = math.max(360, -curY + 20)
    end
end

local function IsFilterActive()
    return (searchQuery ~= "" or modifiedOnly)
end

function CAS.SelectTab(tabId)
    activeTabId = tabId
    -- Clear search filter when explicitly clicking a tab
    if IsFilterActive() then
        searchQuery = ""
        modifiedOnly = false
        if searchBox then searchBox:SetText("") end
        if modifiedOnlyCB then modifiedOnlyCB:SetChecked(nil) end
    end

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
    if searchPanel then searchPanel:Hide() end

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

    if searchClearBtn then
        if IsFilterActive() then searchClearBtn:Show() else searchClearBtn:Hide() end
    end

    -- Update Modified Only (N) counter
    if modifiedOnlyCB and searchPanel and searchPanel.entries then
        local modCount = 0
        local ei
        for ei = 1, table.getn(searchPanel.entries) do
            if IsItemModified(searchPanel.entries[ei].widget.item) then
                modCount = modCount + 1
            end
        end
        local modTxt = getglobal("ClassicAPISettingsModOnlyCBText")
        if modTxt then
            if modCount > 0 then
                modTxt:SetText("Modified Only |cffffd200(" .. tostring(modCount) .. ")|r")
            else
                modTxt:SetText("Modified Only (0)")
            end
        end
    end

    -- Update Reload UI! warning button (shown if scriptProfile changed since login)
    if reloadWarnBtn then
        local curProf = CAS.SafeGetCVar("scriptProfile") or "0"
        if CAS.InitialScriptProfile ~= nil and curProf ~= CAS.InitialScriptProfile then
            reloadWarnBtn:Show()
        else
            reloadWarnBtn:Hide()
        end
    end

    -- Update Undo button state
    if undoBtn then
        local uLbl = CAS.GetUndoLabel and CAS.GetUndoLabel() or nil
        if uLbl then
            undoBtn:Enable()
            undoBtn:SetAlpha(1.0)
        else
            undoBtn:Disable()
            undoBtn:SetAlpha(0.5)
        end
    end

    -- Update Reset Tab button visibility (only on standard setting tabs)
    if resetTabBtn then
        if (not IsFilterActive()) and activeTabId ~= "overlaps" and activeTabId ~= "tools" then
            resetTabBtn:Show()
        else
            resetTabBtn:Hide()
        end
    end

    if IsFilterActive() and searchPanel then
        local i
        for i = 1, table.getn(CAS.Tabs) do
            local p = tabPanels[CAS.Tabs[i].id]
            if p then p:Hide() end
        end
        searchPanel:Show()
        searchPanel.refreshSearch()
        if scrollChild then
            scrollChild:SetHeight(searchPanel.contentHeight or 360)
        end
    else
        if searchCountFS then searchCountFS:Hide() end
        if searchPanel then searchPanel:Hide() end
        local panel = tabPanels[activeTabId]
        if panel then
            panel:Show()
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
    headerTex:SetWidth(360)
    headerTex:SetHeight(64)
    headerTex:SetPoint("TOP", mainFrame, "TOP", 0, 12)

    local titleFS = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFS:SetPoint("TOP", headerTex, "TOP", 0, -14)
    titleFS:SetText("ClassicAPI Settings (" .. CAS.TARGET_CLASSICAPI_STRING .. "+)")

    local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -6, -6)

    local TAB_TIPS = {
        general = "Gameplay QoL, Focus keybinds, key-down casting, auto stand/dismount/unshift, cursors, cooldown numbers, and persistent player cache.",
        softtarget = "Interact keybind status, Soft Interact, Soft Enemy, Soft Friend modes, arcs, ranges, and world/nameplate icon sizing.",
        camera = "ActionCam presets and all 24 ActionCam CVars (Over-the-Shoulder, Dynamic Pitch, Head Movement, Target Focus, Vertical Smoothing, Indirect Visibility; v1.23.9+).",
        combat = "Built-in Damage Meter, Combat Log retention, Advanced Combat Logging, and 3D Encounter Replay.",
        perf = "Foreground/background/loading FPS limits, animation framerate, CPU profiling, nameplate appearance, bag sorting, AutoComplete, and TTS.",
        overlaps = "Detected client DLL mods and active cross-mod overlap warnings with one-click Quick Fix actions.",
        tools = "Quick launchers (/profiler, /etrace, /fstack, /addons, /replay), built-in presets, custom user profiles, Export/Import, and Custom Boss Creature IDs.",
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

    -- Search & Modified-Only Filter Bar
    local searchLbl = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLbl:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 20, -67)
    searchLbl:SetText("Search:")

    searchBox = CreateFrame("EditBox", "ClassicAPISettingsSearchBox", mainFrame)
    searchBox:SetWidth(235)
    searchBox:SetHeight(20)
    searchBox:SetPoint("LEFT", searchLbl, "RIGHT", 6, 0)
    StyleMiniEditBox(searchBox)
    searchBox:SetScript("OnTextChanged", function()
        if isRefreshing then return end
        searchQuery = this:GetText() or ""
        if scrollFrame then scrollFrame:SetVerticalScroll(0) end
        CAS.RefreshUI()
    end)
    searchBox:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)
    SetTooltip(searchBox, "Search All Settings", { "Filter settings across all 5 tabs by name, CVar, or description." })

    searchClearBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    searchClearBtn:SetWidth(20)
    searchClearBtn:SetHeight(19)
    searchClearBtn:SetPoint("LEFT", searchBox, "RIGHT", 4, 0)
    searchClearBtn:SetText("x")
    searchClearBtn:Hide()
    searchClearBtn:SetScript("OnClick", function()
        searchQuery = ""
        modifiedOnly = false
        searchBox:SetText("")
        searchBox:ClearFocus()
        modifiedOnlyCB:SetChecked(nil)
        CAS.RefreshUI()
    end)
    SetTooltip(searchClearBtn, "Clear Filter", { "Clear search text and Modified Only filter." })

    searchCountFS = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    searchCountFS:SetPoint("LEFT", searchClearBtn, "RIGHT", 8, 0)
    searchCountFS:Hide()

    modifiedOnlyCB = CreateFrame("CheckButton", "ClassicAPISettingsModOnlyCB", mainFrame, "UICheckButtonTemplate")
    modifiedOnlyCB:SetWidth(22)
    modifiedOnlyCB:SetHeight(22)
    modifiedOnlyCB:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -140, -62)
    local modTxt = getglobal("ClassicAPISettingsModOnlyCBText")
    modTxt:SetFontObject(GameFontHighlightSmall)
    modTxt:SetText("Modified Only")
    modifiedOnlyCB:SetScript("OnClick", function()
        if isRefreshing then return end
        modifiedOnly = this:GetChecked() and true or false
        if scrollFrame then scrollFrame:SetVerticalScroll(0) end
        CAS.RefreshUI()
    end)
    SetTooltip(modifiedOnlyCB, "Modified Only", { "Show only ClassicAPI settings whose current value differs from default." })

    -- Content Box
    local contentBox = CreateFrame("Frame", nil, mainFrame)
    contentBox:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 16, -88)
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

    -- Build cross-tab search panel
    searchPanel = CreateFrame("Frame", nil, scrollChild)
    searchPanel:SetAllPoints(scrollChild)
    searchPanel:Hide()
    BuildSearchPanel(searchPanel)

    -- Bottom Status Bar & Action Buttons
    mainFrame.statusFS = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.statusFS:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 20, 17)

    local okBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    okBtn:SetWidth(68)
    okBtn:SetHeight(22)
    okBtn:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -18, 13)
    okBtn:SetText("Close")
    okBtn:SetScript("OnClick", function()
        mainFrame:Hide()
    end)

    resetTabBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    resetTabBtn:SetWidth(76)
    resetTabBtn:SetHeight(22)
    resetTabBtn:SetPoint("RIGHT", okBtn, "LEFT", -6, 0)
    resetTabBtn:SetText("Reset Tab")
    resetTabBtn:SetScript("OnClick", function()
        CAS.PushUndoSnapshot("Reset Tab: " .. tostring(activeTabId))
        local changed = CAS.ResetTabToDefault(activeTabId)
        CAS.Print(string.format("Reset %d setting(s) on '%s' tab to default.", changed, tostring(activeTabId)))
        CAS.RefreshUI()
    end)
    SetTooltip(resetTabBtn, "Reset Current Tab", { "Restores only the settings on the currently open tab back to their defaults (Undo supported)." })

    undoBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    undoBtn:SetWidth(58)
    undoBtn:SetHeight(22)
    undoBtn:SetPoint("RIGHT", resetTabBtn, "LEFT", -6, 0)
    undoBtn:SetText("Undo")
    undoBtn:SetScript("OnClick", function()
        local ok, lbl, restored = CAS.PopAndUndo()
        if ok then
            CAS.Print(string.format("Undid '|cffffd200%s|r' (%d CVar(s) restored).", tostring(lbl), restored))
            CAS.RefreshUI()
        end
    end)
    undoBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText("Undo Last Bulk Change", 1, 0.82, 0)
        local lbl = CAS.GetUndoLabel and CAS.GetUndoLabel() or nil
        if lbl then
            GameTooltip:AddLine("Click to revert: |cffffd200" .. lbl .. "|r", 0.9, 0.9, 0.9, 1)
        else
            GameTooltip:AddLine("No recent preset, profile, import, or reset action to undo.", 0.7, 0.7, 0.7, 1)
        end
        GameTooltip:Show()
    end)
    undoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    reloadWarnBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    reloadWarnBtn:SetWidth(84)
    reloadWarnBtn:SetHeight(22)
    reloadWarnBtn:SetPoint("RIGHT", undoBtn, "LEFT", -6, 0)
    reloadWarnBtn:SetText("|cffffaa22Reload UI!|r")
    reloadWarnBtn:Hide()
    reloadWarnBtn:SetScript("OnClick", function() ReloadUI() end)
    SetTooltip(reloadWarnBtn, "Reload UI Required", { "scriptProfile was changed since login. Click to run ReloadUI() so the change takes effect." })

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
