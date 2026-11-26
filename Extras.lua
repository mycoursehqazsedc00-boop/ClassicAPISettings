-- ClassicAPISettings: User Profiles, Export/Import, Custom Boss IDs & Key Bindings
-- Strict Lua 5.0 compatible.

ClassicAPISettings = ClassicAPISettings or {}
local CAS = ClassicAPISettings

-- Lookup table for fast CVar validation during Import
CAS.ManagedCVarLookup = {}
do
    local i
    for i = 1, table.getn(CAS.ManagedCVars) do
        CAS.ManagedCVarLookup[CAS.ManagedCVars[i]] = true
    end
end

-- =========================================================================
-- 1. Key Bindings Helpers
-- =========================================================================

function CAS.GetBindingDisplay(action)
    if not action or type(GetBindingKey) ~= "function" then
        return nil
    end
    local k1, k2 = GetBindingKey(action)
    if k1 and k2 then
        return k1 .. " / " .. k2
    elseif k1 then
        return k1
    end
    return nil
end

function CAS.OpenKeyBindings()
    if type(KeyBindingFrame_LoadUI) == "function" then
        pcall(KeyBindingFrame_LoadUI)
    end
    if KeyBindingFrame and type(ShowUIPanel) == "function" then
        ShowUIPanel(KeyBindingFrame)
    else
        CAS.Print("Open Esc -> Key Bindings -> Targeting Functions to set ClassicAPI keybinds.")
    end
end

-- =========================================================================
-- 2. Custom User Profiles & Export / Import
-- =========================================================================

local function EnsureProfilesDB()
    if type(ClassicAPISettingsDB) ~= "table" then
        ClassicAPISettingsDB = {}
    end
    if type(ClassicAPISettingsDB.profiles) ~= "table" then
        ClassicAPISettingsDB.profiles = {}
    end
    return ClassicAPISettingsDB.profiles
end

local function TrimString(s)
    if type(s) ~= "string" then return "" end
    local _, _, trimmed = string.find(s, "^%s*(.-)%s*$")
    return trimmed or ""
end

function CAS.GetProfileNames()
    local profiles = EnsureProfilesDB()
    local names = {}
    for k in pairs(profiles) do
        table.insert(names, k)
    end
    table.sort(names)
    return names
end

function CAS.SaveProfile(name)
    name = TrimString(name)
    if name == "" then
        return false, "Profile name cannot be empty."
    end
    local profiles = EnsureProfilesDB()
    local snap = { cvars = {} }
    local i
    for i = 1, table.getn(CAS.ManagedCVars) do
        local key = CAS.ManagedCVars[i]
        local val = CAS.SafeGetCVar(key)
        if val ~= nil then
            snap.cvars[key] = tostring(val)
        end
    end
    if C_PlayerCache and type(C_PlayerCache.IsEnabled) == "function" then
        local ok, enabled = pcall(C_PlayerCache.IsEnabled)
        if ok then snap.playerCache = enabled and true or false end
    end
    if type(GetMaxAnimFramerate) == "function" then
        local ok, fps = pcall(GetMaxAnimFramerate)
        if ok and type(fps) == "number" then snap.maxAnimFPS = fps end
    end
    profiles[name] = snap
    return true, nil
end

function CAS.LoadProfile(name)
    local profiles = EnsureProfilesDB()
    local snap = profiles[name]
    if type(snap) ~= "table" then
        return false, 0, 0, "Profile '" .. tostring(name) .. "' not found."
    end
    local applied, skipped = 0, 0
    if type(snap.cvars) == "table" then
        for key, val in pairs(snap.cvars) do
            if CAS.ManagedCVarLookup[key] and CAS.IsCVarSupported(key) then
                if CAS.SafeSetCVar(key, val) then
                    applied = applied + 1
                else
                    skipped = skipped + 1
                end
            else
                skipped = skipped + 1
            end
        end
    end
    if snap.playerCache ~= nil and C_PlayerCache and type(C_PlayerCache.SetEnabled) == "function" then
        pcall(C_PlayerCache.SetEnabled, snap.playerCache)
    end
    if type(snap.maxAnimFPS) == "number" and type(SetMaxAnimFramerate) == "function" then
        pcall(SetMaxAnimFramerate, snap.maxAnimFPS)
    end
    return true, applied, skipped, nil
end

function CAS.DeleteProfile(name)
    local profiles = EnsureProfilesDB()
    if profiles[name] ~= nil then
        profiles[name] = nil
        return true
    end
    return false
end

-- Exports only non-default managed CVars (+ API flags) in compact CAS1 format
function CAS.ExportCurrentSettings()
    local parts = {}
    local i
    for i = 1, table.getn(CAS.ManagedCVars) do
        local key = CAS.ManagedCVars[i]
        local cur = CAS.SafeGetCVar(key)
        local def = CAS.SafeGetCVarDefault(key)
        if cur ~= nil and cur ~= def then
            table.insert(parts, key .. "=" .. tostring(cur))
        end
    end
    if C_PlayerCache and type(C_PlayerCache.IsEnabled) == "function" then
        local ok, enabled = pcall(C_PlayerCache.IsEnabled)
        if ok and enabled then
            table.insert(parts, "__playerCache=1")
        end
    end
    if type(GetMaxAnimFramerate) == "function" then
        local ok, fps = pcall(GetMaxAnimFramerate)
        if ok and type(fps) == "number" and fps ~= 30 then
            table.insert(parts, "__maxAnimFPS=" .. tostring(fps))
        end
    end
    if table.getn(parts) == 0 then
        return "CAS1|DEFAULTS"
    end
    return "CAS1|" .. table.concat(parts, ";")
end

function CAS.ImportSettingsString(str)
    str = TrimString(str)
    if string.sub(str, 1, 5) ~= "CAS1|" then
        return false, 0, 0, "Invalid format. String must start with 'CAS1|'."
    end
    local body = string.sub(str, 6)
    if body == "DEFAULTS" or body == "" then
        local count = CAS.ResetAllCVarsToDefault()
        return true, count, 0, nil
    end

    local applied, skipped = 0, 0
    for token in string.gfind(body, "[^;]+") do
        local _, _, k, v = string.find(token, "^([^=]+)=(.*)$")
        if k and v then
            k = TrimString(k)
            v = TrimString(v)
            if k == "__playerCache" then
                if C_PlayerCache and type(C_PlayerCache.SetEnabled) == "function" then
                    pcall(C_PlayerCache.SetEnabled, v == "1")
                    applied = applied + 1
                else
                    skipped = skipped + 1
                end
            elseif k == "__maxAnimFPS" then
                local num = tonumber(v)
                if num and type(SetMaxAnimFramerate) == "function" then
                    pcall(SetMaxAnimFramerate, num)
                    applied = applied + 1
                else
                    skipped = skipped + 1
                end
            elseif CAS.ManagedCVarLookup[k] and CAS.IsCVarSupported(k) then
                if CAS.SafeSetCVar(k, v) then
                    applied = applied + 1
                else
                    skipped = skipped + 1
                end
            else
                skipped = skipped + 1
            end
        end
    end
    return true, applied, skipped, nil
end

-- =========================================================================
-- 3. Persistent Custom Boss Creature IDs (C_InstanceEncounter, v1.23.9+)
-- =========================================================================

local function EnsureBossDB()
    if type(ClassicAPISettingsDB) ~= "table" then
        ClassicAPISettingsDB = {}
    end
    if type(ClassicAPISettingsDB.bossIDs) ~= "table" then
        ClassicAPISettingsDB.bossIDs = {}
    end
    return ClassicAPISettingsDB.bossIDs
end

function CAS.IsBossAPISupported()
    if not CAS.Mods.classicapi then
        return false, "ClassicAPI.dll is not loaded."
    end
    if CAS.Mods.classicapiOutdated then
        return false, "Requires ClassicAPI v1.23.9+ (installed: " .. tostring(CAS.Mods.classicapiVersion) .. ")."
    end
    if not C_InstanceEncounter or type(C_InstanceEncounter.AddBossCreatureID) ~= "function" then
        return false, "C_InstanceEncounter.AddBossCreatureID is unavailable in your ClassicAPI build."
    end
    return true, nil
end

function CAS.ApplySavedBossIDs()
    local okSup = CAS.IsBossAPISupported()
    if not okSup then return 0 end
    local db = EnsureBossDB()
    local list = {}
    for id in pairs(db) do
        local num = tonumber(id)
        if num and num > 0 then
            table.insert(list, num)
        end
    end
    local count = table.getn(list)
    if count > 0 then
        pcall(C_InstanceEncounter.AddBossCreatureID, list)
    end
    return count
end

function CAS.AddBossID(creatureID, label)
    local okSup, reason = CAS.IsBossAPISupported()
    if not okSup then
        return false, reason
    end
    local num = tonumber(creatureID)
    if not num or num <= 0 or math.floor(num) ~= num or num > 4294967295 then
        return false, "Creature ID must be a positive integer."
    end
    local db = EnsureBossDB()
    local name = TrimString(label)
    if name == "" then
        name = "Creature #" .. tostring(num)
    end
    db[num] = name
    local ok, err = pcall(C_InstanceEncounter.AddBossCreatureID, num)
    if not ok then
        return false, tostring(err)
    end
    return true, name
end

function CAS.AddTargetBossID()
    local okSup, reason = CAS.IsBossAPISupported()
    if not okSup then
        return false, reason
    end
    if not UnitExists("target") then
        return false, "You have no target selected."
    end
    if UnitIsPlayer("target") then
        return false, "Target is a player, not a creature."
    end
    local cid = nil
    if type(UnitCreatureID) == "function" then
        local ok, v = pcall(UnitCreatureID, "target")
        if ok and v then cid = tonumber(v) end
    end
    if (not cid or cid <= 0) and C_CreatureInfo and type(C_CreatureInfo.GetCreatureID) == "function" and type(UnitGUID) == "function" then
        local okG, guid = pcall(UnitGUID, "target")
        if okG and guid then
            local okC, v = pcall(C_CreatureInfo.GetCreatureID, guid)
            if okC and v then cid = tonumber(v) end
        end
    end
    if not cid or cid <= 0 then
        return false, "Could not resolve Creature ID for current target."
    end
    local tName = UnitName("target") or ("Creature #" .. tostring(cid))
    return CAS.AddBossID(cid, tName)
end

function CAS.RemoveBossID(creatureID)
    local num = tonumber(creatureID)
    if not num then return false end
    local db = EnsureBossDB()
    db[num] = nil
    if C_InstanceEncounter and type(C_InstanceEncounter.RemoveBossCreatureID) == "function" then
        pcall(C_InstanceEncounter.RemoveBossCreatureID, num)
    end
    return true
end

function CAS.GetSavedBossList()
    local db = EnsureBossDB()
    local out = {}
    for id, name in pairs(db) do
        local num = tonumber(id)
        if num then
            table.insert(out, { id = num, name = tostring(name) })
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- =========================================================================
-- 4. Undo Stack (Session Snapshots before Bulk Actions)
-- =========================================================================

local undoStack = {}
local MAX_UNDO = 10

local function CaptureSnapshot(label)
    local snap = { label = tostring(label or "Change"), cvars = {} }
    local i
    for i = 1, table.getn(CAS.ManagedCVars) do
        local key = CAS.ManagedCVars[i]
        local val = CAS.SafeGetCVar(key)
        if val ~= nil then
            snap.cvars[key] = tostring(val)
        end
    end
    if C_PlayerCache and type(C_PlayerCache.IsEnabled) == "function" then
        local ok, enabled = pcall(C_PlayerCache.IsEnabled)
        if ok then snap.playerCache = enabled and true or false end
    end
    if type(GetMaxAnimFramerate) == "function" then
        local ok, fps = pcall(GetMaxAnimFramerate)
        if ok and type(fps) == "number" then snap.maxAnimFPS = fps end
    end
    return snap
end

function CAS.PushUndoSnapshot(label)
    table.insert(undoStack, CaptureSnapshot(label))
    while table.getn(undoStack) > MAX_UNDO do
        table.remove(undoStack, 1)
    end
end

function CAS.GetUndoLabel()
    local n = table.getn(undoStack)
    if n == 0 then return nil end
    return undoStack[n].label
end

function CAS.PopAndUndo()
    local n = table.getn(undoStack)
    if n == 0 then
        return false, nil, 0
    end
    local snap = table.remove(undoStack, n)
    local restored = 0
    for key, val in pairs(snap.cvars) do
        local cur = CAS.SafeGetCVar(key)
        if cur ~= val then
            if CAS.SafeSetCVar(key, val) then
                restored = restored + 1
            end
        end
    end
    if snap.playerCache ~= nil and C_PlayerCache and type(C_PlayerCache.SetEnabled) == "function" then
        pcall(C_PlayerCache.SetEnabled, snap.playerCache)
    end
    if type(snap.maxAnimFPS) == "number" and type(SetMaxAnimFramerate) == "function" then
        pcall(SetMaxAnimFramerate, snap.maxAnimFPS)
    end
    return true, snap.label, restored
end

-- =========================================================================
-- 5. Visual Dependency Checker
-- =========================================================================

function CAS.GetDependencyStatus(item)
    if not item or not item.dependsOn then return true, nil end
    local i
    for i = 1, table.getn(item.dependsOn) do
        local dep = item.dependsOn[i]
        local val = CAS.SafeGetCVar(dep.cvar)
        if val ~= nil then
            if dep.nonZero then
                local num = tonumber(val) or 0
                if num == 0 then
                    return false, dep.reason or (dep.cvar .. " is 0")
                end
            elseif dep.values then
                local matched = false
                local vi
                for vi = 1, table.getn(dep.values) do
                    if val == dep.values[vi] then
                        matched = true
                        break
                    end
                end
                if not matched then
                    return false, dep.reason or (dep.cvar .. " disables this setting")
                end
            end
        end
    end
    return true, nil
end

-- =========================================================================
-- 6. Auto-Switch Profile by Zone Context (World / Dungeon / Raid / BG)
-- =========================================================================

local lastAutoContext = nil

function CAS.EnsureAutoSwitchDB()
    if type(ClassicAPISettingsDB) ~= "table" then
        ClassicAPISettingsDB = {}
    end
    if type(ClassicAPISettingsDB.autoSwitch) ~= "table" then
        ClassicAPISettingsDB.autoSwitch = {
            enabled = false,
            world = nil,
            party = nil,
            raid = nil,
            pvp = nil,
        }
    end
    return ClassicAPISettingsDB.autoSwitch
end

function CAS.GetCurrentZoneContext()
    if type(GetInstanceInfo) == "function" then
        local ok, _, instType = pcall(GetInstanceInfo)
        if ok and instType then
            if instType == "raid" then return "raid", "Raid" end
            if instType == "party" then return "party", "Dungeon" end
            if instType == "pvp" or instType == "arena" then return "pvp", "Battleground" end
            return "world", "Open World"
        end
    end
    if type(IsInInstance) == "function" then
        local inInst, instType = IsInInstance()
        if inInst then
            if instType == "raid" then return "raid", "Raid" end
            if instType == "pvp" then return "pvp", "Battleground" end
            return "party", "Dungeon"
        end
    end
    return "world", "Open World"
end

function CAS.CheckAutoSwitchProfile(force)
    local cfg = CAS.EnsureAutoSwitchDB()
    if not cfg.enabled then return false end
    local ctx, ctxLabel = CAS.GetCurrentZoneContext()
    if not force and ctx == lastAutoContext then
        return false
    end
    lastAutoContext = ctx
    local targetProf = cfg[ctx]
    if not targetProf or targetProf == "" then
        return false
    end
    local profiles = EnsureProfilesDB()
    if type(profiles[targetProf]) ~= "table" then
        return false
    end
    CAS.PushUndoSnapshot("Auto-Switch (" .. ctxLabel .. ")")
    local ok, applied = CAS.LoadProfile(targetProf)
    if ok then
        CAS.Print(string.format("Auto-switched to profile '|cffffd200%s|r' (%s, %d CVars).", targetProf, ctxLabel, applied))
        if CAS.RefreshUI then CAS.RefreshUI() end
        return true
    end
    return false
end

