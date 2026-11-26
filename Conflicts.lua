-- ClassicAPISettings: Cross-Mod Detection & Overlap/Conflict Analyzer
-- Strict Lua 5.0 compatible.

ClassicAPISettings = ClassicAPISettings or {}
local CAS = ClassicAPISettings

CAS.Mods = {
    classicapi = false,
    classicapiVersion = nil,
    nampower = false,
    nampowerVersion = nil,
    unitxp = false,
    superwow = false,
    superwowVersion = nil,
    weirdutils = false,
    weirdutilsModules = {},
}

CAS.Overlaps = {}
CAS.OverlapsByKey = {}

function CAS.FormatClassicAPIVersion(ver)
    if type(ver) ~= "number" then
        return tostring(ver or "unknown")
    end
    if ver >= 99999999 then
        return "dev"
    end
    local major = math.floor(ver / 10000)
    local minor = math.floor(math.mod(ver, 10000) / 100)
    local patch = math.mod(ver, 100)
    return string.format("v%d.%d.%d", major, minor, patch)
end

function CAS.SafeGetCVar(name)
    if not name or not GetCVar then return nil end
    local ok, val = pcall(GetCVar, name)
    if ok then return val end
    return nil
end

function CAS.SafeGetCVarDefault(name)
    if not name or not GetCVarDefault then return nil end
    local ok, val = pcall(GetCVarDefault, name)
    if ok then return val end
    return nil
end

function CAS.SafeSetCVar(name, val)
    if not name then return false end
    local strVal = tostring(val)
    if C_CVar and type(C_CVar.SetCVar) == "function" then
        local ok, res = pcall(C_CVar.SetCVar, name, strVal)
        return ok and (res ~= false)
    elseif SetCVar then
        local ok = pcall(SetCVar, name, strVal)
        return ok
    end
    return false
end

function CAS.IsAddonActive(addonName)
    if not addonName then return false end
    if type(IsAddOnLoaded) == "function" then
        local ok, loaded = pcall(IsAddOnLoaded, addonName)
        if ok and loaded then return true end
    end
    return false
end

function CAS.DetectMods()
    local m = CAS.Mods

    -- ClassicAPI
    if CLASSIC_API_VERSION ~= nil then
        m.classicapi = true
        m.classicapiVersion = CAS.FormatClassicAPIVersion(CLASSIC_API_VERSION)
    else
        m.classicapi = false
        m.classicapiVersion = nil
    end

    -- Nampower
    if type(GetNampowerVersion) == "function" then
        local ok, maj, min, pat = pcall(GetNampowerVersion)
        m.nampower = true
        if ok and maj then
            m.nampowerVersion = string.format("v%d.%d.%d", maj, min or 0, pat or 0)
        else
            m.nampowerVersion = "detected"
        end
    else
        m.nampower = false
        m.nampowerVersion = nil
    end

    -- UnitXP SP3
    m.unitxp = (type(UnitXP) == "function") and pcall(UnitXP, "nop", "nop") or false

    -- SuperWoW
    if SUPERWOW_VERSION ~= nil then
        m.superwow = true
        m.superwowVersion = tostring(SUPERWOW_STRING or SUPERWOW_VERSION)
    else
        m.superwow = false
        m.superwowVersion = nil
    end

    -- WeirdUtils
    m.weirdutilsModules = {}
    if type(GetWeirdUtilsVersion) == "function" then
        m.weirdutils = true
        local ok, mods = pcall(GetWeirdUtilsVersion)
        if ok and type(mods) == "table" then
            for k, v in pairs(mods) do
                m.weirdutilsModules[string.lower(tostring(k))] = tostring(v)
            end
        end
    else
        m.weirdutils = false
    end

    return m
end

local function GetUnitXPFpsCap(cmd)
    if not CAS.Mods.unitxp then return 0 end
    local ok, val = pcall(UnitXP, cmd)
    if ok and type(val) == "number" then
        return val
    end
    if type(UnitXP_SP3_Addon) == "table" and type(UnitXP_SP3_Addon[cmd]) == "number" then
        return UnitXP_SP3_Addon[cmd]
    end
    return 0
end

local function AddOverlap(severity, id, title, detail, keys, fixLabel, fixFunc)
    local entry = {
        severity = severity, -- "HIGH", "WARN", "INFO"
        id = id,
        title = title,
        detail = detail,
        keys = keys or {},
        fixLabel = fixLabel,
        fixFunc = fixFunc,
    }
    table.insert(CAS.Overlaps, entry)
    local i
    for i = 1, table.getn(entry.keys) do
        local key = entry.keys[i]
        if not CAS.OverlapsByKey[key] then
            CAS.OverlapsByKey[key] = {}
        end
        table.insert(CAS.OverlapsByKey[key], entry)
    end
end

function CAS.ScanOverlaps()
    CAS.Overlaps = {}
    CAS.OverlapsByKey = {}

    local m = CAS.Mods
    if not m.classicapi then
        AddOverlap(
            "HIGH",
            "no_classicapi",
            "ClassicAPI.dll not detected",
            "ClassicAPI is not loaded. Add ClassicAPI.dll to dlls.txt and launch via VanillaFixes.exe.",
            {}
        )
        return CAS.Overlaps
    end

    -- 1. WeirdUtils dpslog vs ClassicAPI CLEU / GetSpellInfo
    if m.weirdutils and m.weirdutilsModules["dpslog"] then
        AddOverlap(
            "HIGH",
            "weirdutils_dpslog",
            "WeirdUtils 'dpslog' overlaps ClassicAPI Combat Log",
            "Both ClassicAPI and WeirdUtils dpslog provide COMBAT_LOG_EVENT_UNFILTERED, CombatLogGetCurrentEventInfo, GetSpellInfo, and UnitCastingInfo. Disable dpslog.dll to avoid duplicate/conflicting hooks.",
            { "advancedCombatLogging", "combatLogRetentionTime", "damageMeterEnabled" }
        )
    end

    -- 2. Foreground FPS Cap: ClassicAPI useMaxFPS vs UnitXP SP3 FPScap
    local useMaxFPS = CAS.SafeGetCVar("useMaxFPS")
    if m.unitxp and useMaxFPS == "1" then
        local xpFps = GetUnitXPFpsCap("FPScap")
        if xpFps and xpFps > 0 then
            AddOverlap(
                "HIGH",
                "fps_cap_unitxp",
                "Double Foreground FPS Cap (ClassicAPI + UnitXP SP3)",
                string.format("ClassicAPI useMaxFPS=1 (%s FPS) and UnitXP SP3 FPScap=%d are both active. Keep only one FPS limiter enabled to prevent frame pacing jitter.", tostring(CAS.SafeGetCVar("maxFPS") or "120"), xpFps),
                { "useMaxFPS", "maxFPS" },
                "Disable ClassicAPI Cap",
                function()
                    CAS.SafeSetCVar("useMaxFPS", "0")
                end
            )
        end
    end

    -- 3. Background FPS Cap: ClassicAPI useMaxFPSBk vs UnitXP SP3 backgroundFPScap
    local useMaxFPSBk = CAS.SafeGetCVar("useMaxFPSBk")
    if m.unitxp and useMaxFPSBk == "1" then
        local xpBkFps = GetUnitXPFpsCap("backgroundFPScap")
        if xpBkFps and xpBkFps > 0 then
            AddOverlap(
                "WARN",
                "bg_fps_cap_unitxp",
                "Double Background FPS Cap (ClassicAPI + UnitXP SP3)",
                string.format("ClassicAPI useMaxFPSBk=1 (%s FPS) and UnitXP SP3 backgroundFPScap=%d are both active. Disable one of them.", tostring(CAS.SafeGetCVar("maxFPSBk") or "30"), xpBkFps),
                { "useMaxFPSBk", "maxFPSBk" },
                "Disable ClassicAPI BG Cap",
                function()
                    CAS.SafeSetCVar("useMaxFPSBk", "0")
                end
            )
        end
    end

    -- 4. Advanced Combat Logging Movement enabled without Advanced Combat Logging
    if CAS.SafeGetCVar("advancedCombatLoggingMovement") == "1" and CAS.SafeGetCVar("advancedCombatLogging") ~= "1" then
        AddOverlap(
            "WARN",
            "acl_movement_no_acl",
            "Movement Log enabled without Advanced Combat Logging",
            "advancedCombatLoggingMovement only writes movement data for /replay while advancedCombatLogging is also enabled.",
            { "advancedCombatLogging", "advancedCombatLoggingMovement" },
            "Enable Advanced Log",
            function()
                CAS.SafeSetCVar("advancedCombatLogging", "1")
            end
        )
    end

    -- 5. CPU Profiling active during normal play
    if CAS.SafeGetCVar("scriptProfile") == "1" then
        AddOverlap(
            "WARN",
            "script_profile_on",
            "CPU Profiling (scriptProfile) is enabled",
            "scriptProfile=1 adds measurable CPU overhead on every Lua call and event. Turn it off and /reload after finishing /profiler checks.",
            { "scriptProfile" },
            "Disable scriptProfile",
            function()
                CAS.SafeSetCVar("scriptProfile", "0")
            end
        )
    end

    -- 6. Cooldown countdown numbers vs pfUI / OmniCC / tullaCC
    if CAS.SafeGetCVar("countdownForCooldowns") == "1" then
        local cdAddons = {}
        if CAS.IsAddonActive("pfUI") then table.insert(cdAddons, "pfUI") end
        if CAS.IsAddonActive("OmniCC") then table.insert(cdAddons, "OmniCC") end
        if CAS.IsAddonActive("tullaCC") then table.insert(cdAddons, "tullaCC") end
        if table.getn(cdAddons) > 0 then
            AddOverlap(
                "WARN",
                "cooldown_numbers_overlap",
                "Cooldown Numbers overlap (" .. table.concat(cdAddons, ", ") .. ")",
                "countdownForCooldowns=1 draws native cooldown text on Cooldown frames, which may draw double numbers alongside " .. table.concat(cdAddons, ", ") .. ".",
                { "countdownForCooldowns" },
                "Disable Native Numbers",
                function()
                    CAS.SafeSetCVar("countdownForCooldowns", "0")
                end
            )
        end
    end

    -- 7. SoftTargetInteract vs WeirdUtils interact
    local softInteract = CAS.SafeGetCVar("SoftTargetInteract")
    if m.weirdutils and m.weirdutilsModules["interact"] and (softInteract == "2" or softInteract == "3") then
        AddOverlap(
            "INFO",
            "weirdutils_interact",
            "Soft Interact overlaps WeirdUtils 'interact'",
            "ClassicAPI SoftTargetInteract is active while WeirdUtils interact module is loaded. You can rely on ClassicAPI's native Interact Key binding instead.",
            { "SoftTargetInteract" }
        )
    end

    -- 8. Expanded Cursors vs WeirdUtils bigcursor
    if m.weirdutils and m.weirdutilsModules["bigcursor"] and CAS.SafeGetCVar("expandedCursors") == "1" then
        AddOverlap(
            "INFO",
            "weirdutils_bigcursor",
            "Expanded Cursors + WeirdUtils 'bigcursor'",
            "Both ClassicAPI expandedCursors and WeirdUtils bigcursor modify cursor appearance. Verify cursor scaling feels right in-game.",
            { "expandedCursors" }
        )
    end

    -- 9. Built-in Damage Meter vs Third-party Damage Meters
    if CAS.SafeGetCVar("damageMeterEnabled") == "1" then
        local meters = {}
        if CAS.IsAddonActive("GreedMeter") then table.insert(meters, "GreedMeter") end
        if CAS.IsAddonActive("DPSMate") then table.insert(meters, "DPSMate") end
        if CAS.IsAddonActive("ShaguDPS") then table.insert(meters, "ShaguDPS") end
        if CAS.IsAddonActive("Details") then table.insert(meters, "Details") end
        if table.getn(meters) > 0 then
            AddOverlap(
                "INFO",
                "damage_meter_overlap",
                "Built-in Damage Meter running alongside " .. table.concat(meters, ", "),
                "Running multiple damage meters simultaneously increases raid CPU/memory usage. Disable ClassicAPI damageMeterEnabled if you prefer " .. meters[1] .. ".",
                { "damageMeterEnabled" },
                "Disable Built-in Meter",
                function()
                    CAS.SafeSetCVar("damageMeterEnabled", "0")
                end
            )
        end
    end

    -- 10. autoStand / autoDismount / autoUnshift vs _LazyPig
    if CAS.IsAddonActive("_LazyPig") then
        if CAS.SafeGetCVar("autoDismount") == "1" or CAS.SafeGetCVar("autoStand") == "1" then
            AddOverlap(
                "INFO",
                "lazypig_autodismount",
                "Auto Stand/Dismount also handled by _LazyPig",
                "ClassicAPI native autoStand/autoDismount is enabled while _LazyPig is loaded. ClassicAPI handles this at the engine level, so you can disable the duplicate option in _LazyPig.",
                { "autoStand", "autoDismount", "autoUnshift" }
            )
        end
    end

    -- 11. Default Nameplate Alpha CVars when pfUI is active
    if CAS.IsAddonActive("pfUI") then
        local npSel = CAS.SafeGetCVar("nameplateSelectedAlpha")
        local npNot = CAS.SafeGetCVar("nameplateNotSelectedAlpha")
        local npSelDef = CAS.SafeGetCVarDefault("nameplateSelectedAlpha") or "1"
        local npNotDef = CAS.SafeGetCVarDefault("nameplateNotSelectedAlpha") or "0.5"
        if (npSel and npSel ~= npSelDef) or (npNot and npNot ~= npNotDef) then
            AddOverlap(
                "INFO",
                "pfui_nameplate_alpha",
                "Nameplate Alpha CVars vs pfUI Nameplates",
                "nameplateSelectedAlpha and nameplateNotSelectedAlpha apply to default Blizzard nameplates. If pfUI nameplates are enabled, configure alpha inside pfUI instead.",
                { "nameplateSelectedAlpha", "nameplateNotSelectedAlpha" }
            )
        end
    end

    -- 12. !BugGrabber active (ClassicAPI error window yields to BugGrabber)
    if CAS.IsAddonActive("!BugGrabber") then
        AddOverlap(
            "INFO",
            "buggrabber_active",
            "!BugGrabber captures Lua errors",
            "ClassicAPI's built-in Lua error popup automatically yields to !BugGrabber/BugSack so errors are not shown twice. Use /bugsack or /luaerrors manually if needed.",
            {}
        )
    end

    return CAS.Overlaps
end

function CAS.GetOverlapCounts()
    local high, warn, info = 0, 0, 0
    local i
    for i = 1, table.getn(CAS.Overlaps) do
        local sev = CAS.Overlaps[i].severity
        if sev == "HIGH" then
            high = high + 1
        elseif sev == "WARN" then
            warn = warn + 1
        else
            info = info + 1
        end
    end
    return high, warn, info
end
