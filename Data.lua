-- ClassicAPISettings: CVar Definitions, API Settings, and Built-in Presets
-- All CVars and APIs verified against ClassicAPI v1.23.1 documentation.
-- Strict Lua 5.0 compatible.

ClassicAPISettings = ClassicAPISettings or {}
local CAS = ClassicAPISettings

local SOFT_MODE_OPTIONS = {
    { value = "0", label = "Off (0)" },
    { value = "2", label = "Key + Mouse (2)" },
    { value = "3", label = "Always (3)" },
}

local SOFT_ARC_OPTIONS = {
    { value = "0", label = "Ahead (0)" },
    { value = "1", label = "30 deg (1)" },
    { value = "2", label = "Any Dir (2)" },
}

local SOFT_FORCE_OPTIONS = {
    { value = "0", label = "Keep (0)" },
    { value = "1", label = "Enemy (1)" },
    { value = "2", label = "Friend (2)" },
}

-- Tab definitions: each setting item has:
--   kind: "header" | "bool" | "slider" | "cycle" | "api_bool" | "api_slider" | "tts_voice" | "actions"
--   key:  CVar name or unique API key
--   label, desc
CAS.Tabs = {
    {
        id = "general",
        title = "General",
        items = {
            { kind = "header", label = "Gameplay & Input" },
            {
                kind = "bool",
                key = "ActionButtonUseKeyDown",
                label = "Action Button Use Key Down",
                desc = "Trigger action-bar key bindings on key press (1) instead of key release (0).",
            },
            {
                kind = "bool",
                key = "stopAutoAttackOnTargetChange",
                label = "Stop Auto-Attack on Target Change",
                desc = "Stop melee auto-attack, Auto Shot, and wand shots when switching targets.",
            },
            {
                kind = "bool",
                key = "autoStand",
                label = "Auto Stand",
                desc = "Automatically stand up when casting, looting, or opening the flight map while seated.",
            },
            {
                kind = "bool",
                key = "autoDismount",
                label = "Auto Dismount",
                desc = "Automatically dismount when casting, attacking, looting, or interacting while mounted.",
            },
            {
                kind = "bool",
                key = "autoUnshift",
                label = "Auto Unshift (Druid / Ghost Wolf)",
                desc = "Automatically leave shapeshift form when casting an incompatible spell, using items, or talking to NPCs.",
            },

            { kind = "header", label = "Interface & Visual QoL" },
            {
                kind = "bool",
                key = "expandedCursors",
                label = "Expanded Contextual Cursors",
                desc = "Show contextual cursor icons (anvil, hearthstone, stable, quest !/?, fishing bobber hook).",
            },
            {
                kind = "bool",
                key = "countdownForCooldowns",
                label = "Native Cooldown Countdown Numbers",
                desc = "Draw remaining time numbers natively on Cooldown frames. Disable if pfUI/OmniCC draws numbers.",
            },
            {
                kind = "bool",
                key = "dontShowEquipmentSetsOnItems",
                label = "Hide Equipment Sets on Item Tooltips",
                desc = "Remove the 'Equipment Sets:' line from item tooltips.",
            },
            {
                kind = "bool",
                key = "breakUpLargeNumbers",
                label = "Break Up Large Numbers",
                desc = "Insert thousands separators in BreakUpLargeNumbers formatting.",
            },
            {
                kind = "slider",
                key = "ShakeStrengthUI",
                label = "UI Shake Strength",
                desc = "Scale factor for ScriptAnimationUtil.ShakeFrame (0 disables screen/frame shake).",
                min = 0, max = 2, step = 0.1, fmt = "%.1f",
            },

            { kind = "header", label = "Persistent Player Cache" },
            {
                kind = "api_bool",
                key = "C_PlayerCache",
                label = "Enable Persistent Player Name Cache",
                desc = "Saves seen player GUID/name/class/race records to WTF\\ClassicAPI\\NameCache-*.txt across sessions.",
                get = function()
                    if C_PlayerCache and type(C_PlayerCache.IsEnabled) == "function" then
                        local ok, v = pcall(C_PlayerCache.IsEnabled)
                        return ok and (v and true or false) or false
                    end
                    return false
                end,
                set = function(val)
                    if C_PlayerCache and type(C_PlayerCache.SetEnabled) == "function" then
                        pcall(C_PlayerCache.SetEnabled, val and true or false)
                    end
                end,
                default = false,
            },
        },
    },
    {
        id = "softtarget",
        title = "Soft Target",
        items = {
            {
                kind = "actions",
                label = "Quick Presets",
                buttons = {
                    {
                        label = "All Off",
                        tip = "Disable Soft Interact, Soft Enemy, and Soft Friend.",
                        func = function()
                            CAS.SafeSetCVar("SoftTargetInteract", "0")
                            CAS.SafeSetCVar("SoftTargetEnemy", "0")
                            CAS.SafeSetCVar("SoftTargetFriend", "0")
                        end,
                    },
                    {
                        label = "Interact Only",
                        tip = "Enable Soft Interact (Always, 10 yds, with icon). Disable Soft Enemy & Friend.",
                        func = function()
                            CAS.SafeSetCVar("SoftTargetInteract", "3")
                            CAS.SafeSetCVar("SoftTargetInteractArc", "0")
                            CAS.SafeSetCVar("SoftTargetInteractRange", "10")
                            CAS.SafeSetCVar("SoftTargetIconInteract", "1")
                            CAS.SafeSetCVar("SoftTargetEnemy", "0")
                            CAS.SafeSetCVar("SoftTargetFriend", "0")
                        end,
                    },
                    {
                        label = "Interact + Enemy",
                        tip = "Enable Soft Interact (Always) and Soft Enemy (Key+Mouse, 45 yds).",
                        func = function()
                            CAS.SafeSetCVar("SoftTargetInteract", "3")
                            CAS.SafeSetCVar("SoftTargetIconInteract", "1")
                            CAS.SafeSetCVar("SoftTargetEnemy", "2")
                            CAS.SafeSetCVar("SoftTargetEnemyRange", "45")
                            CAS.SafeSetCVar("SoftTargetFriend", "0")
                        end,
                    },
                },
            },

            { kind = "header", label = "Soft Interact (NPCs, Corpses, Nodes)" },
            {
                kind = "cycle",
                key = "SoftTargetInteract",
                label = "Soft Interact Mode",
                desc = "Controls softinteract targeting for the Interact Key (0/1=Off, 2=Keyboard+Mouse, 3=Always).",
                options = SOFT_MODE_OPTIONS,
            },
            {
                kind = "cycle",
                key = "SoftTargetInteractArc",
                label = "Soft Interact Arc",
                desc = "Cone direction for soft-interact detection (0=Ahead, 1=Within 30 deg, 2=Any direction).",
                options = SOFT_ARC_OPTIONS,
            },
            {
                kind = "slider",
                key = "SoftTargetInteractRange",
                label = "Soft Interact Range (yds)",
                desc = "Maximum distance in yards for soft-interact objects (default 10).",
                min = 5, max = 40, step = 1, fmt = "%d",
            },
            {
                kind = "bool",
                key = "SoftTargetInteractRangeIsHard",
                label = "Hard Interact Range Limit",
                desc = "Strictly enforce SoftTargetInteractRange instead of picking usable objects beyond it.",
            },
            {
                kind = "bool",
                key = "SoftTargetIconInteract",
                label = "Show Soft Interact Icon",
                desc = "Display an icon above the active soft-interact object.",
            },

            { kind = "header", label = "Soft Enemy & Soft Friend" },
            {
                kind = "cycle",
                key = "SoftTargetEnemy",
                label = "Soft Enemy Mode",
                desc = "Controls softenemy unit token (0/1=Off, 2=Keyboard+Mouse, 3=Always).",
                options = SOFT_MODE_OPTIONS,
            },
            {
                kind = "cycle",
                key = "SoftTargetEnemyArc",
                label = "Soft Enemy Arc",
                desc = "Cone direction for softenemy detection.",
                options = SOFT_ARC_OPTIONS,
            },
            {
                kind = "slider",
                key = "SoftTargetEnemyRange",
                label = "Soft Enemy Range (yds)",
                desc = "Maximum distance in yards for softenemy (default 45).",
                min = 5, max = 60, step = 1, fmt = "%d",
            },
            {
                kind = "bool",
                key = "SoftTargetIconEnemy",
                label = "Show Soft Enemy Icon",
                desc = "Display an icon over the active softenemy unit.",
            },
            {
                kind = "cycle",
                key = "SoftTargetFriend",
                label = "Soft Friend Mode",
                desc = "Controls softfriend unit token (0/1=Off, 2=Keyboard+Mouse, 3=Always).",
                options = SOFT_MODE_OPTIONS,
            },
            {
                kind = "cycle",
                key = "SoftTargetFriendArc",
                label = "Soft Friend Arc",
                desc = "Cone direction for softfriend detection.",
                options = SOFT_ARC_OPTIONS,
            },
            {
                kind = "slider",
                key = "SoftTargetFriendRange",
                label = "Soft Friend Range (yds)",
                desc = "Maximum distance in yards for softfriend (default 45).",
                min = 5, max = 60, step = 1, fmt = "%d",
            },
            {
                kind = "bool",
                key = "SoftTargetIconFriend",
                label = "Show Soft Friend Icon",
                desc = "Display an icon over the active softfriend unit.",
            },

            { kind = "header", label = "Behavior & Icon Scaling" },
            {
                kind = "bool",
                key = "SoftTargetMatchLocked",
                label = "Match Locked Target",
                desc = "Use your current locked target as the soft unit when it qualifies.",
            },
            {
                kind = "bool",
                key = "SoftTargetWithLocked",
                label = "Keep Soft Target While Locked",
                desc = "Keep softenemy/softfriend active even when you already have a locked target.",
            },
            {
                kind = "cycle",
                key = "SoftTargetForce",
                label = "Loose Target Force Mode",
                desc = "Loose target follows softenemy (1), softfriend (2), or stays unchanged (0).",
                options = SOFT_FORCE_OPTIONS,
            },
            {
                kind = "bool",
                key = "SoftTargetLowPriorityIcons",
                label = "Show Low-Priority Pointer Icons",
                desc = "Also show the standard pointer icon as a soft-target icon.",
            },
            {
                kind = "slider",
                key = "SoftTargetNameplateSize",
                label = "Nameplate Icon Size (px)",
                desc = "Size of soft-target icons anchored to nameplates (default 19).",
                min = 8, max = 48, step = 1, fmt = "%d",
            },
            {
                kind = "slider",
                key = "SoftTargetWorldtextSize",
                label = "World Icon Size (px)",
                desc = "Screen pixel size of non-nameplate soft-target icons (default 32).",
                min = 12, max = 64, step = 1, fmt = "%d",
            },
            {
                kind = "slider",
                key = "SoftTargetWorldtextNearScale",
                label = "World Icon Near Scale",
                desc = "Scale multiplier at NearDist yards (1.0 keeps constant size).",
                min = 0.5, max = 3.0, step = 0.1, fmt = "%.1f",
            },
            {
                kind = "slider",
                key = "SoftTargetWorldtextNearDist",
                label = "World Icon Near Dist (yds)",
                desc = "Distance where NearScale applies (default 4).",
                min = 1, max = 20, step = 1, fmt = "%d",
            },
            {
                kind = "slider",
                key = "SoftTargetWorldtextFarDist",
                label = "World Icon Far Dist (yds)",
                desc = "Distance where icon returns to normal size (default 40).",
                min = 10, max = 80, step = 2, fmt = "%d",
            },
        },
    },
    {
        id = "camera",
        title = "Camera",
        items = {
            {
                kind = "actions",
                label = "ActionCam Presets",
                minVersion = 12309,
                minVersionStr = "v1.23.9",
                buttons = {
                    {
                        label = "Off",
                        width = 76,
                        minVersion = 12309,
                        minVersionStr = "v1.23.9",
                        tip = "Disable all ActionCam features and restore centered camera.",
                        func = function()
                            CAS.SafeSetCVar("CameraKeepCharacterCentered", "1")
                            CAS.SafeSetCVar("test_cameraDynamicPitch", "0")
                            CAS.SafeSetCVar("test_cameraOverShoulder", "0")
                            CAS.SafeSetCVar("test_cameraTargetFocusEnemyEnable", "0")
                            CAS.SafeSetCVar("test_cameraTargetFocusInteractEnable", "0")
                            CAS.SafeSetCVar("test_cameraHeadMovementStrength", "0")
                        end,
                    },
                    {
                        label = "Basic",
                        width = 76,
                        minVersion = 12309,
                        minVersionStr = "v1.23.9",
                        tip = "Unlock center + Dynamic Pitch only (equivalent to ActionCam basic).",
                        func = function()
                            CAS.SafeSetCVar("CameraKeepCharacterCentered", "0")
                            CAS.SafeSetCVar("test_cameraDynamicPitch", "1")
                            CAS.SafeSetCVar("test_cameraOverShoulder", "0")
                            CAS.SafeSetCVar("test_cameraTargetFocusEnemyEnable", "0")
                            CAS.SafeSetCVar("test_cameraTargetFocusInteractEnable", "0")
                            CAS.SafeSetCVar("test_cameraHeadMovementStrength", "0")
                        end,
                    },
                    {
                        label = "On",
                        width = 76,
                        minVersion = 12309,
                        minVersionStr = "v1.23.9",
                        tip = "Dynamic Pitch + Over-the-Shoulder + Interact Focus + Head Movement (ActionCam on).",
                        func = function()
                            CAS.SafeSetCVar("CameraKeepCharacterCentered", "0")
                            CAS.SafeSetCVar("test_cameraDynamicPitch", "1")
                            CAS.SafeSetCVar("test_cameraOverShoulder", "1")
                            CAS.SafeSetCVar("test_cameraTargetFocusEnemyEnable", "0")
                            CAS.SafeSetCVar("test_cameraTargetFocusInteractEnable", "1")
                            CAS.SafeSetCVar("test_cameraHeadMovementStrength", "1")
                        end,
                    },
                    {
                        label = "Full",
                        width = 76,
                        minVersion = 12309,
                        minVersionStr = "v1.23.9",
                        tip = "Enable all ActionCam features including Enemy Target Focus (ActionCam full).",
                        func = function()
                            CAS.SafeSetCVar("CameraKeepCharacterCentered", "0")
                            CAS.SafeSetCVar("test_cameraDynamicPitch", "1")
                            CAS.SafeSetCVar("test_cameraOverShoulder", "1")
                            CAS.SafeSetCVar("test_cameraTargetFocusEnemyEnable", "1")
                            CAS.SafeSetCVar("test_cameraTargetFocusInteractEnable", "1")
                            CAS.SafeSetCVar("test_cameraHeadMovementStrength", "1")
                        end,
                    },
                },
            },

            { kind = "header", label = "ActionCam Master Switches (Requires v1.23.9+)" },
            {
                kind = "bool",
                key = "CameraKeepCharacterCentered",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Keep Character Centered (Blocks Most ActionCam)",
                desc = "Default 1. Must be set to 0 for Over-the-Shoulder, Dynamic Pitch, Head Movement, and Enemy Focus to operate.",
            },
            {
                kind = "bool",
                key = "CameraReduceUnexpectedMovement",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Reduce Unexpected Movement (Enables Vertical Smoothing)",
                desc = "Disables Over-the-Shoulder and allows cameraZSmooth vertical smoothing to operate.",
            },

            { kind = "header", label = "Over the Shoulder & Dynamic Pitch" },
            {
                kind = "slider",
                key = "test_cameraOverShoulder",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Over-the-Shoulder Offset (yds)",
                desc = "Horizontal camera offset in yards (positive = right, negative = left, 0 = off).",
                min = -5, max = 5, step = 0.25, fmt = "%.2f",
            },
            {
                kind = "bool",
                key = "test_cameraDynamicPitch",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Enable Dynamic Pitch",
                desc = "Tilts camera down up to 5 deg so your character's feet stay in the lower part of the screen.",
            },
            {
                kind = "slider",
                key = "test_cameraDynamicPitchBaseFovPad",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Dynamic Pitch Base FOV Pad",
                desc = "Fraction of screen height that the character's feet stay below (0.0 to 1.0, default 0.4).",
                min = 0, max = 1, step = 0.05, fmt = "%.2f",
            },
            {
                kind = "slider",
                key = "test_cameraDynamicPitchBaseFovPadDownScale",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Dynamic Pitch Look-Down Scale",
                desc = "How much Dynamic Pitch tilts while looking down (0.0 to 1.0, default 0.25).",
                min = 0, max = 1, step = 0.05, fmt = "%.2f",
            },
            {
                kind = "slider",
                key = "test_cameraDynamicPitchSmartPivotCutoffDist",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Smart Pivot Cutoff Distance (yds)",
                desc = "Within this camera distance (0 to 50 yds, default 10), stops cameraPivot while looking up.",
                min = 0, max = 50, step = 1, fmt = "%d",
            },

            { kind = "header", label = "Head Movement" },
            {
                kind = "slider",
                key = "test_cameraHeadMovementStrength",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Head Movement Strength",
                desc = "How strongly the camera follows character head bob (0 = off, 0.5 = low, 1 = normal, 2 = heavy).",
                min = 0, max = 2, step = 0.1, fmt = "%.1f",
            },
            {
                kind = "slider",
                key = "test_cameraHeadMovementStandingStrength",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Head Movement Standing Strength",
                desc = "Strength while standing still (0 = only follow while moving/falling, default 0.3).",
                min = 0, max = 1, step = 0.1, fmt = "%.1f",
            },
            {
                kind = "slider",
                key = "test_cameraHeadMovementMovingStrength",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Head Movement Moving Strength",
                desc = "Strength while moving (default 0.5).",
                min = 0, max = 1, step = 0.1, fmt = "%.1f",
            },
            {
                kind = "slider",
                key = "test_cameraHeadMovementRangeScale",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Head Movement Range Scale (yds)",
                desc = "Camera distance for full head movement strength (0 to 50, default 5). Fades to 0 at 3x distance.",
                min = 0, max = 50, step = 1, fmt = "%d",
            },
            {
                kind = "slider",
                key = "test_cameraHeadMovementDeadZone",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Head Movement Dead Zone (yds)",
                desc = "How far the head can move before the camera follows (default 0.015).",
                min = 0, max = 1, step = 0.01, fmt = "%.2f",
            },
            {
                kind = "slider",
                key = "test_cameraHeadMovementStandingDampRate",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Head Movement Standing Damp Rate",
                desc = "How fast the camera catches up with the head while standing (0.1 to 50, default 10).",
                min = 1, max = 50, step = 1, fmt = "%d",
            },
            {
                kind = "slider",
                key = "test_cameraHeadMovementMovingDampRate",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Head Movement Moving Damp Rate",
                desc = "How fast the camera catches up with the head while moving (0.1 to 50, default 10).",
                min = 1, max = 50, step = 1, fmt = "%d",
            },
            {
                kind = "slider",
                key = "test_cameraHeadMovementFirstPersonDampRate",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Head Movement First-Person Damp Rate",
                desc = "How fast the camera catches up with the head in first person (0.1 to 50, default 20).",
                min = 1, max = 50, step = 1, fmt = "%d",
            },

            { kind = "header", label = "Target Focus" },
            {
                kind = "bool",
                key = "test_cameraTargetFocusEnemyEnable",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Target Focus: Attackable Enemies",
                desc = "Subtly turns the camera toward your current attackable target (up to 80 yds).",
            },
            {
                kind = "slider",
                key = "test_cameraTargetFocusEnemyStrengthPitch",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Enemy Focus Pitch Strength",
                desc = "Vertical camera turn fraction toward enemy target (0.0 to 1.0, default 0.4).",
                min = 0, max = 1, step = 0.05, fmt = "%.2f",
            },
            {
                kind = "slider",
                key = "test_cameraTargetFocusEnemyStrengthYaw",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Enemy Focus Yaw Strength",
                desc = "Horizontal camera turn fraction toward enemy target (0.0 to 1.0, default 0.5).",
                min = 0, max = 1, step = 0.05, fmt = "%.2f",
            },
            {
                kind = "bool",
                key = "test_cameraTargetFocusInteractEnable",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Target Focus: NPCs & Objects",
                desc = "Turns the camera toward NPCs/objects when their quest, vendor, or trainer window opens.",
            },
            {
                kind = "slider",
                key = "test_cameraTargetFocusInteractStrengthPitch",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Interact Focus Pitch Strength",
                desc = "Vertical camera turn fraction toward interacted NPC/object (0.0 to 1.0, default 0.75).",
                min = 0, max = 1, step = 0.05, fmt = "%.2f",
            },
            {
                kind = "slider",
                key = "test_cameraTargetFocusInteractStrengthYaw",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Interact Focus Yaw Strength",
                desc = "Horizontal camera turn fraction toward interacted NPC/object (0.0 to 1.0, default 1.0).",
                min = 0, max = 1, step = 0.05, fmt = "%.2f",
            },

            { kind = "header", label = "Vertical Smoothing & Indirect Visibility" },
            {
                kind = "cycle",
                key = "cameraZSmooth",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Vertical Smoothing (cameraZSmooth)",
                desc = "Requires Reduce Unexpected Movement=1. Smooths vertical camera motion (0=Off, 1=Moving, 2=Always).",
                options = {
                    { value = "0", label = "Off (0)" },
                    { value = "1", label = "Moving (1)" },
                    { value = "2", label = "Always (2)" },
                },
            },
            {
                kind = "bool",
                key = "cameraIndirectVisibility",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Indirect Visibility (Avoid Obstacles)",
                desc = "Looks around intervening walls/pillars for a clear view before zooming the camera in.",
            },
            {
                kind = "slider",
                key = "cameraIndirectOffset",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Indirect Visibility Offset (yds)",
                desc = "How far to the sides and above the character the camera checks for a clear view (default 6).",
                min = 1, max = 15, step = 0.5, fmt = "%.1f",
            },
        },
    },
    {
        id = "combat",
        title = "Combat",
        items = {
            { kind = "header", label = "Built-in Damage Meter" },
            {
                kind = "bool",
                key = "damageMeterEnabled",
                label = "Enable Built-in Damage Meter [Char]",
                desc = "Enable ClassicAPI's backported retail Damage Meter. When 0, counts nothing and does not load.",
            },
            {
                kind = "bool",
                key = "damageMeterResetOnNewInstance",
                label = "Auto-Reset Damage Meter on New Instance [Char]",
                desc = "Automatically clear Damage Meter sessions each time you enter a different instance.",
            },

            { kind = "header", label = "Combat Log & 3D Encounter Replay" },
            {
                kind = "slider",
                key = "combatLogRetentionTime",
                label = "Combat Log Retention (sec)",
                desc = "Number of seconds the combat log retains entries (default 300).",
                min = 60, max = 1800, step = 30, fmt = "%ds",
            },
            {
                kind = "bool",
                key = "advancedCombatLogging",
                label = "Advanced Combat Logging",
                desc = "Write unit health, power, position, and level into WoWCombatLog.txt (Classic Era format).",
            },
            {
                kind = "bool",
                key = "advancedCombatLoggingMovement",
                label = "Advanced Combat Log Movement File",
                desc = "Write unit movement tracks to a companion file while Advanced Combat Logging is on. Required for /replay.",
            },
            {
                kind = "actions",
                label = "Combat Log & Replay Actions",
                buttons = {
                    {
                        label = "Toggle /combatlog",
                        tip = "Start or stop writing combat log to disk.",
                        func = function()
                            if type(LoggingCombat) == "function" then
                                local cur = LoggingCombat()
                                LoggingCombat(not cur)
                                CAS.Print("Combat logging: " .. (LoggingCombat() and "|cff00ff00ON|r" or "|cffff5555OFF|r"))
                            else
                                CAS.RunSlash("/combatlog")
                            end
                        end,
                    },
                    {
                        label = "Open /replay",
                        tip = "Open ClassicAPI's 3D Encounter Replay window.",
                        func = function()
                            CAS.RunSlash("/replay")
                        end,
                    },
                },
            },
        },
    },
    {
        id = "perf",
        title = "Perf & UI",
        items = {
            { kind = "header", label = "Frame Rate & Profiling" },
            {
                kind = "bool",
                key = "useMaxFPS",
                label = "Limit Foreground FPS",
                desc = "Cap FPS to maxFPS while WoW is the active window. Watch for overlap with UnitXP SP3 FPScap.",
            },
            {
                kind = "slider",
                key = "maxFPS",
                label = "Foreground Max FPS",
                desc = "Maximum foreground frame rate when Limit Foreground FPS is enabled (default 120).",
                min = 30, max = 300, step = 5, fmt = "%d",
            },
            {
                kind = "bool",
                key = "useMaxFPSBk",
                label = "Limit Background FPS",
                desc = "Cap FPS to maxFPSBk while WoW is in the background.",
            },
            {
                kind = "slider",
                key = "maxFPSBk",
                label = "Background Max FPS",
                desc = "Maximum background frame rate when Limit Background FPS is enabled (default 30).",
                min = 10, max = 120, step = 5, fmt = "%d",
            },
            {
                kind = "slider",
                key = "maxFPSLoading",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Loading Screen Max FPS",
                desc = "Caps loading screen redraws per second (10-100, default 10). Lower values load faster with many addons.",
                min = 10, max = 100, step = 5, fmt = "%d",
            },
            {
                kind = "api_slider",
                key = "MaxAnimFramerate",
                label = "Max Animation Framerate (Session)",
                desc = "Calls SetMaxAnimFramerate(fps). Limits animation updates per second (default 30; 0 pauses until end).",
                min = 0, max = 120, step = 5, fmt = "%d",
                default = 30,
                get = function()
                    if type(GetMaxAnimFramerate) == "function" then
                        local ok, v = pcall(GetMaxAnimFramerate)
                        if ok and type(v) == "number" then return v end
                    end
                    return 30
                end,
                set = function(val)
                    if type(SetMaxAnimFramerate) == "function" then
                        pcall(SetMaxAnimFramerate, val)
                    end
                end,
            },
            {
                kind = "bool",
                key = "scriptProfile",
                label = "Enable Lua CPU Profiling (Requires /reload)",
                desc = "Enables *CPUUsage functions for /profiler. Adds CPU overhead; disable after profiling.",
            },

            { kind = "header", label = "Default Nameplate Appearance" },
            {
                kind = "bool",
                key = "nameplateUseClassColorForFriendlyPlayerUnitNames",
                minVersion = 12309, minVersionStr = "v1.23.9",
                label = "Class-Color Friendly Player Nameplate Names",
                desc = "Colors friendly player names on default nameplates by class color.",
            },
            {
                kind = "slider",
                key = "nameplateSelectedAlpha",
                label = "Target Nameplate Alpha",
                desc = "Alpha of the target's default Blizzard nameplate (default 1.0).",
                min = 0.1, max = 1.0, step = 0.05, fmt = "%.2f",
            },
            {
                kind = "slider",
                key = "nameplateNotSelectedAlpha",
                label = "Non-Target Nameplate Alpha",
                desc = "Alpha of non-target default Blizzard nameplates (default 0.5).",
                min = 0.1, max = 1.0, step = 0.05, fmt = "%.2f",
            },

            { kind = "header", label = "Bag Sorting & Name AutoComplete" },
            {
                kind = "bool",
                key = "sortBagsRightToLeft",
                label = "Sort Bags Right-to-Left",
                desc = "Fill bags starting from the last slot of the last bag during C_Container.SortBags().",
            },
            {
                kind = "bool",
                key = "backpackAutosortDisabled",
                label = "Ignore Backpack on Sort",
                desc = "Keep items in your main backpack untouched when sorting bags.",
            },
            {
                kind = "bool",
                key = "bankAutosortDisabled",
                label = "Ignore Main Bank on Sort",
                desc = "Keep items in the main bank slots untouched when sorting bank bags.",
            },
            {
                kind = "bool",
                key = "autoCompleteResortNamesOnRecency",
                label = "AutoComplete: Sort by Recent Whispers",
                desc = "Place recently whispered players first in C_AutoComplete results (1) instead of alphabetical (0).",
            },
            {
                kind = "bool",
                key = "autoCompleteWhenEditingFromCenter",
                label = "AutoComplete: Match When Editing Mid-Name",
                desc = "Also match text after the cursor when editing inside a player name.",
            },
            {
                kind = "bool",
                key = "autoCompleteUseContext",
                label = "AutoComplete: Respect Context Flags",
                desc = "Apply includeFlags and excludeFlags filters in C_AutoComplete.",
            },

            { kind = "header", label = "Text-to-Speech (TTS)" },
            {
                kind = "tts_voice",
                key = "ttsVoice",
                label = "TTS Voice",
                desc = "Windows SAPI voice index used by C_VoiceChat.SpeakText.",
            },
            {
                kind = "slider",
                key = "ttsSpeed",
                label = "TTS Speech Rate",
                desc = "Speech rate from -10 (slowest) to 10 (fastest), default 0.",
                min = -10, max = 10, step = 1, fmt = "%d",
            },
            {
                kind = "slider",
                key = "ttsVolume",
                label = "TTS Volume",
                desc = "Speech volume from 0 to 100 (default 100).",
                min = 0, max = 100, step = 5, fmt = "%d%%",
            },
            {
                kind = "actions",
                label = "TTS Test",
                buttons = {
                    {
                        label = "Test Speak",
                        tip = "Speak a sample phrase using the selected TTS voice, speed, and volume.",
                        func = function()
                            if C_VoiceChat and type(C_VoiceChat.SpeakText) == "function" then
                                local voiceID = tonumber(CAS.SafeGetCVar("ttsVoice")) or 0
                                local rate = tonumber(CAS.SafeGetCVar("ttsSpeed")) or 0
                                local vol = tonumber(CAS.SafeGetCVar("ttsVolume")) or 100
                                pcall(C_VoiceChat.SpeakText, voiceID, "ClassicAPI Text to Speech test.", 0, rate, vol)
                            else
                                CAS.Print("C_VoiceChat.SpeakText is not available.")
                            end
                        end,
                    },
                    {
                        label = "Stop Speak",
                        tip = "Immediately stop any active or queued TTS playback.",
                        func = function()
                            if C_VoiceChat and type(C_VoiceChat.StopSpeakingText) == "function" then
                                pcall(C_VoiceChat.StopSpeakingText)
                            end
                        end,
                    },
                },
            },
        },
    },
    {
        id = "overlaps",
        title = "Overlaps",
        custom = true,
    },
    {
        id = "tools",
        title = "Tools",
        custom = true,
    },
}

-- Flat list of all ClassicAPI CVars managed by this addon (for Reset All & Profiles)
CAS.ManagedCVars = {}
do
    local t, i
    for t = 1, table.getn(CAS.Tabs) do
        local tab = CAS.Tabs[t]
        if tab.items then
            for i = 1, table.getn(tab.items) do
                local item = tab.items[i]
                if item.kind == "bool" or item.kind == "slider" or item.kind == "cycle" or item.kind == "tts_voice" then
                    table.insert(CAS.ManagedCVars, item.key)
                end
            end
        end
    end
end

-- Built-in presets
CAS.BuiltInPresets = {
    {
        id = "recommended_qol",
        label = "Recommended QoL",
        desc = "Enables Auto Stand/Dismount/Unshift, Expanded Cursors, Soft Interact (Always), and disables CPU profiling.",
        apply = function()
            CAS.SafeSetCVar("autoStand", "1")
            CAS.SafeSetCVar("autoDismount", "1")
            CAS.SafeSetCVar("autoUnshift", "1")
            CAS.SafeSetCVar("expandedCursors", "1")
            CAS.SafeSetCVar("SoftTargetInteract", "3")
            CAS.SafeSetCVar("SoftTargetIconInteract", "1")
            CAS.SafeSetCVar("scriptProfile", "0")
            if C_PlayerCache and type(C_PlayerCache.SetEnabled) == "function" then
                pcall(C_PlayerCache.SetEnabled, true)
            end
        end,
    },
    {
        id = "raid_perf",
        label = "Raid Performance",
        desc = "Disables scriptProfile, built-in Damage Meter, and movement logging for minimal raid CPU overhead.",
        apply = function()
            CAS.SafeSetCVar("scriptProfile", "0")
            CAS.SafeSetCVar("damageMeterEnabled", "0")
            CAS.SafeSetCVar("advancedCombatLoggingMovement", "0")
            CAS.SafeSetCVar("SoftTargetEnemy", "0")
            CAS.SafeSetCVar("SoftTargetFriend", "0")
        end,
    },
    {
        id = "combat_replay",
        label = "Combat Log & Replay",
        desc = "Enables Advanced Combat Logging + Movement file and raises retention time to 600s for /replay.",
        apply = function()
            CAS.SafeSetCVar("advancedCombatLogging", "1")
            CAS.SafeSetCVar("advancedCombatLoggingMovement", "1")
            CAS.SafeSetCVar("combatLogRetentionTime", "600")
        end,
    },
}

function CAS.ResetAllCVarsToDefault()
    local count = 0
    local i
    for i = 1, table.getn(CAS.ManagedCVars) do
        local key = CAS.ManagedCVars[i]
        local def = CAS.SafeGetCVarDefault(key)
        if def ~= nil then
            local cur = CAS.SafeGetCVar(key)
            if cur ~= def then
                if CAS.SafeSetCVar(key, def) then
                    count = count + 1
                end
            end
        end
    end
    return count
end
