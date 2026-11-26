-- ClassicAPISettings: Core Lifecycle, CVAR_UPDATE Sync & Slash Commands
-- Strict Lua 5.0 compatible.

ClassicAPISettings = ClassicAPISettings or {}
local CAS = ClassicAPISettings

local ADDON_PREFIX = "|cff44bbff[ClassicAPISettings]|r "
local traceEnabled = false

function CAS.Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. tostring(msg))
    end
end

function CAS.Trace(msg)
    if traceEnabled then
        CAS.Print("|cffaaaaaa[trace]|r " .. tostring(msg))
    end
end

function CAS.RunSlash(cmd)
    if not cmd or cmd == "" then return end
    if ChatFrameEditBox and type(ChatEdit_SendText) == "function" then
        ChatFrameEditBox:SetText(cmd)
        ChatEdit_SendText(ChatFrameEditBox)
    else
        CAS.Print("Run command manually: " .. cmd)
    end
end

local function InitDB()
    if type(ClassicAPISettingsDB) ~= "table" then
        ClassicAPISettingsDB = {}
    end
    if ClassicAPISettingsDB.showMinimap == nil then
        ClassicAPISettingsDB.showMinimap = true
    end
    if ClassicAPISettingsDB.warnOnLogin == nil then
        ClassicAPISettingsDB.warnOnLogin = true
    end
    if ClassicAPISettingsDB.minimapAngle == nil then
        ClassicAPISettingsDB.minimapAngle = 215
    end
end

local function PrintStatus()
    CAS.DetectMods()
    CAS.ScanOverlaps()
    local m = CAS.Mods
    local capiStr
    if not m.classicapi then
        capiStr = "|cffff3333NOT LOADED (requires " .. CAS.TARGET_CLASSICAPI_STRING .. "+)|r"
    elseif m.classicapiOutdated then
        capiStr = "|cffffaa22" .. m.classicapiVersion .. " (OUTDATED - update to " .. CAS.TARGET_CLASSICAPI_STRING .. "+)|r"
    else
        capiStr = "|cff44ff44" .. m.classicapiVersion .. "|r"
    end
    CAS.Print("Status (Target: ClassicAPI " .. CAS.TARGET_CLASSICAPI_STRING .. "+):")
    CAS.Print("  ClassicAPI: " .. capiStr)
    CAS.Print("  Nampower: " .. (m.nampower and m.nampowerVersion or "no")
        .. " | UnitXP SP3: " .. (m.unitxp and "yes" or "no")
        .. " | SuperWoW: " .. (m.superwow and m.superwowVersion or "no")
        .. " | WeirdUtils: " .. (m.weirdutils and "yes" or "no"))
    local high, warn, info = CAS.GetOverlapCounts()
    CAS.Print(string.format("  Overlaps: %d HIGH, %d WARN, %d INFO", high, warn, info))
end

local function PrintOverlaps()
    CAS.DetectMods()
    CAS.ScanOverlaps()
    local n = table.getn(CAS.Overlaps)
    if n == 0 then
        CAS.Print("|cff44ff44No cross-mod overlaps or configuration warnings found.|r")
        return
    end
    CAS.Print("Detected overlaps / warnings (" .. n .. "):")
    local i
    for i = 1, n do
        local ov = CAS.Overlaps[i]
        local col = "|cff66bbff"
        if ov.severity == "HIGH" then col = "|cffff3333"
        elseif ov.severity == "WARN" then col = "|cffffaa22" end
        CAS.Print("  " .. col .. "[" .. ov.severity .. "]|r " .. ov.title)
    end
end

local function HandleSlash(msg)
    local cmd = string.lower(msg or "")
    local _, _, trimmed = string.find(cmd, "^%s*(.-)%s*$")
    cmd = trimmed or ""

    if cmd == "" or cmd == "ui" or cmd == "config" then
        CAS.ToggleUI()
    elseif cmd == "overlaps" or cmd == "conflicts" then
        CAS.ToggleUI("overlaps")
    elseif cmd == "tools" then
        CAS.ToggleUI("tools")
    elseif cmd == "soft" or cmd == "softtarget" then
        CAS.ToggleUI("softtarget")
    elseif cmd == "status" then
        PrintStatus()
    elseif cmd == "scan" then
        PrintOverlaps()
    elseif cmd == "minimap" then
        ClassicAPISettingsDB.showMinimap = not ClassicAPISettingsDB.showMinimap
        CAS.UpdateMinimapButton()
        CAS.Print("Minimap button: " .. (ClassicAPISettingsDB.showMinimap and "|cff44ff44Shown|r" or "|cffff5555Hidden|r"))
    elseif cmd == "resetpos" then
        ClassicAPISettingsDB.pos = nil
        if ClassicAPISettingsFrame then
            ClassicAPISettingsFrame:ClearAllPoints()
            ClassicAPISettingsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
        end
        CAS.Print("Window position reset.")
    elseif cmd == "trace" then
        traceEnabled = not traceEnabled
        CAS.Print("Debug trace: " .. (traceEnabled and "|cff44ff44ON|r" or "|cffff5555OFF|r"))
    else
        CAS.Print("Commands: /capi | /capi overlaps | /capi soft | /capi tools | /capi status | /capi scan | /capi minimap | /capi resetpos | /capi trace")
    end
end

SLASH_CLASSICAPISETTINGS1 = "/capi"
SLASH_CLASSICAPISETTINGS2 = "/capisettings"
SLASH_CLASSICAPISETTINGS3 = "/classicapisettings"
SlashCmdList["CLASSICAPISETTINGS"] = HandleSlash

-- Event Driver
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CVAR_UPDATE")

eventFrame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        InitDB()
        CAS.DetectMods()
        CAS.ScanOverlaps()
        CAS.UpdateMinimapButton()
        CAS.Trace("PLAYER_LOGIN complete.")

        -- Always warn on login if ClassicAPI is missing or older than v1.23.9
        if not CAS.Mods.classicapi then
            CAS.Print("|cffff3333WARNING:|r ClassicAPI.dll was NOT detected! Install ClassicAPI |cffffd200" .. CAS.TARGET_CLASSICAPI_STRING .. "+|r to use ClassicAPI Settings.")
        elseif CAS.Mods.classicapiOutdated then
            CAS.Print("|cffffaa22WARNING:|r ClassicAPI |cffffffff" .. tostring(CAS.Mods.classicapiVersion) .. "|r detected. Please update ClassicAPI.dll to |cffffd200" .. CAS.TARGET_CLASSICAPI_STRING .. "+|r! Settings marked |cffff6633[Req v1.23.9+]|r will not work on older builds.")
        elseif ClassicAPISettingsDB.warnOnLogin then
            local high, warn = CAS.GetOverlapCounts()
            if high > 0 or warn > 0 then
                CAS.Print(string.format("Found %d HIGH and %d WARN cross-mod overlap(s). Type |cffffd200/capi overlaps|r to review.", high, warn))
            end
        end
    elseif event == "CVAR_UPDATE" then
        CAS.Trace("CVAR_UPDATE: " .. tostring(arg1) .. " = " .. tostring(arg2))
        if ClassicAPISettingsFrame and ClassicAPISettingsFrame:IsShown() then
            CAS.RefreshUI()
        end
    end
end)
