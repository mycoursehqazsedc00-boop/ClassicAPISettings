# ClassicAPI Settings (for ClassicAPI v1.23.9+)

A lightweight, Vanilla-styled companion settings panel, preset manager, and cross-mod overlap detector built for **ClassicAPI v1.23.9+** on World of Warcraft 1.12.1 / Turtle WoW.

> **Version Compatibility:** Targets **ClassicAPI v1.23.9+** (`CLASSIC_API_VERSION >= 12309`). If ClassicAPI is missing or older than `v1.23.9`, the addon prints a login warning recommending an update, keeps all UI entries visible, and tags unsupported settings with `[Req v1.23.9+]` (plus tooltip and chat warnings if clicked) instead of hiding or crashing.

## Client DLL Mods

- **ClassicAPI v1.23.9+** *(Required for settings)* — Reads and writes ClassicAPI CVars (`GetCVar`, `GetCVarDefault`, `C_CVar.SetCVar`, `C_CVar.DoesCVarExist`, `C_CVar.GetCVarInfo`), listens to `CVAR_UPDATE` for live UI sync, manages `C_PlayerCache`, `GetMaxAnimFramerate` / `SetMaxAnimFramerate`, `C_VoiceChat` TTS voices/test playback, and launches built-in tools (`C_SettingsUtil.OpenSettingsPanel`, `/profiler`, `/etrace`, `/framestack`, `/tinspect`, `/luaerrors`, `/classicapi`, `/addons`, `/replay`).
- **UnitXP SP3** *(Optional — detected for overlap checks)* — Reads `UnitXP("FPScap")` and `UnitXP("backgroundFPScap")` to warn when both ClassicAPI and UnitXP SP3 are capping FPS simultaneously, and flags ActionCam + UnitXP SP3 camera overlap.
- **Nampower** *(Optional — detected for status display)* — Checks `GetNampowerVersion()` in the Overlaps & Status overview.
- **SuperWoW** *(Optional — detected for status display)* — Checks `SUPERWOW_VERSION` / `SUPERWOW_STRING` in the Overlaps & Status overview.
- **WeirdUtils** *(Optional — detected for overlap checks)* — Inspects `GetWeirdUtilsVersion()` to detect overlapping modules (`dpslog`, `interact`, `bigcursor`).

Written in strict **Lua 5.0** with zero external library dependencies.

## Features

- **Vanilla 1.12 Interface:** Standard `UI-DialogBox` window titled `ClassicAPI Settings (v1.23.9+)`, bottom bar showing `Target: v1.23.9+ | Installed: <version>`, `UIPanelScrollFrame` with mouse-wheel scrolling, `Escape` key close (`UISpecialFrames`), draggable frame with saved position, and a draggable Vanilla minimap button.
- **Version Guard & Graceful Degradation:**
  - Automatically warns in chat on `PLAYER_LOGIN` if `ClassicAPI.dll` is missing or older than `v1.23.9`, and adds a warning card to the **Overlaps** tab.
  - Every setting unavailable on an older build stays visible with an orange `[Req v1.23.9+]` tag, an `[UNSUPPORTED ON CURRENT VERSION]` explanation in its hover tooltip, and a safe chat warning if clicked.
- **Full Row-Hover Tooltips:** Hovering anywhere on a setting row highlights the row and shows a popup tooltip with purpose, CVar name, storage scope (`Account` vs `Per-Character`), current vs default value, version requirements, and any active cross-mod overlap warnings.
- **Full ClassicAPI v1.23.9 Configuration Coverage (5 Settings Tabs):**
  - **General:** `ActionButtonUseKeyDown`, `stopAutoAttackOnTargetChange`, `autoStand`, `autoDismount`, `autoUnshift`, `expandedCursors`, `countdownForCooldowns`, `dontShowEquipmentSetsOnItems`, `breakUpLargeNumbers`, `ShakeStrengthUI`, and `C_PlayerCache` persistent name cache.
  - **Soft Target:** All 20 `SoftTarget*` CVars (`SoftTargetInteract*`, `SoftTargetEnemy*`, `SoftTargetFriend*`, locked-target behavior, nameplate/world icon sizes & distance scaling) plus 1-click presets (*All Off*, *Interact Only*, *Interact + Enemy*).
  - **Camera (ActionCam — v1.23.9+):** Quick presets (*Off*, *Basic*, *On*, *Full*) and all 24 ActionCam CVars (`CameraKeepCharacterCentered`, `CameraReduceUnexpectedMovement`, `test_cameraOverShoulder`, `test_cameraDynamicPitch*`, `test_cameraHeadMovement*` incl. range scale/dead zone/damp rates, `test_cameraTargetFocus*` incl. pitch/yaw strengths, `cameraZSmooth`, `cameraIndirectVisibility`, and `cameraIndirectOffset`).
  - **Combat:** Built-in Damage Meter (`damageMeterEnabled`, `damageMeterResetOnNewInstance`), `combatLogRetentionTime`, `advancedCombatLogging`, `advancedCombatLoggingMovement`, plus quick `/combatlog` and `/replay` buttons.
  - **Perf & UI:** Foreground/background/loading FPS limits (`useMaxFPS`, `maxFPS`, `useMaxFPSBk`, `maxFPSBk`, `maxFPSLoading`), `SetMaxAnimFramerate`, `scriptProfile`, default nameplate appearance (`nameplateUseClassColorForFriendlyPlayerUnitNames`, `nameplateSelectedAlpha`, `nameplateNotSelectedAlpha`), bag sorting (`sortBagsRightToLeft`, `backpackAutosortDisabled`, `bankAutosortDisabled`), `C_AutoComplete` settings, and Text-to-Speech (`ttsVoice`, `ttsSpeed`, `ttsVolume` + **Test Speak** / **Stop Speak**).
- **Live Modified Highlight & Per-Setting Reset:** Modified settings are highlighted in gold with an inline `R` reset button; live-syncs automatically via `CVAR_UPDATE`.
- **Cross-Mod Overlap & Conflict Detector (`Overlaps` Tab + Inline Badges):**
  - Displays inline `[!]` / `[i]` badges and detailed tooltip explanations next to affected settings.
  - Detects and provides one-click **Quick Fix** actions for:
    - Missing or outdated ClassicAPI (`< v1.23.9`)
    - ActionCam blocked while `CameraKeepCharacterCentered=1` (*Unlock Camera Center* Quick Fix) and ActionCam + UnitXP SP3 Camera notice
    - WeirdUtils `dpslog` vs ClassicAPI `COMBAT_LOG_EVENT_UNFILTERED` / `GetSpellInfo`
    - ClassicAPI `useMaxFPS` / `useMaxFPSBk` vs UnitXP SP3 `FPScap` / `backgroundFPScap`
    - `advancedCombatLoggingMovement` enabled without `advancedCombatLogging`
    - `scriptProfile` left enabled during normal play
    - `countdownForCooldowns` vs `pfUI` / `OmniCC` / `tullaCC`
    - `damageMeterEnabled` alongside `GreedMeter` / `DPSMate` / `ShaguDPS` / `Details`
    - `SoftTargetInteract` vs WeirdUtils `interact`, `expandedCursors` vs WeirdUtils `bigcursor`, `autoStand`/`autoDismount` vs `_LazyPig`, default nameplate alpha vs `pfUI`, and `!BugGrabber` handoff info.
- **Tools & One-Click Presets (`Tools` Tab):** Quick buttons for `/profiler`, `/profiler widget`, `/etrace`, `/framestack`, `/tinspect`, `/luaerrors`, `/classicapi`, `/addons` (`v1.23.9+`), `/replay`, ClassicAPI's built-in Options panel, `ReloadUI()`, built-in presets (*Recommended QoL*, *Raid Performance*, *Combat Log & Replay*), and *Reset All ClassicAPI CVars to Default*.

## Slash Commands

- `/capi` (or `/capisettings`, `/classicapisettings`) — Toggle the settings window.
- `/capi overlaps` — Open directly on the Overlaps & Status tab.
- `/capi soft` — Open directly on the Soft Target tab.
- `/capi tools` — Open directly on the Tools & Presets tab.
- `/capi status` — Print target vs installed ClassicAPI version, other DLL mods, and overlap counts to chat.
- `/capi scan` — Print all detected overlaps/warnings to chat.
- `/capi minimap` — Toggle the minimap button.
- `/capi resetpos` — Reset the window position to screen center.
- `/capi trace` — Toggle debug trace logging for `CVAR_UPDATE` and lifecycle events.
