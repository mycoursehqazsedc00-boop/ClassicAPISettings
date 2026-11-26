# ClassicAPI Settings

A lightweight, Vanilla-styled companion settings panel, preset manager, and cross-mod overlap detector for **ClassicAPI** on World of Warcraft 1.12.1 / Turtle WoW.

## Client DLL Mods

- **ClassicAPI** *(Required for settings)* — Reads and writes ClassicAPI CVars (`GetCVar`, `GetCVarDefault`, `C_CVar.SetCVar`), listens to `CVAR_UPDATE` for live UI sync, manages `C_PlayerCache`, `GetMaxAnimFramerate` / `SetMaxAnimFramerate`, `C_VoiceChat` TTS voices/test playback, and launches built-in tools (`C_SettingsUtil.OpenSettingsPanel`, `/profiler`, `/etrace`, `/framestack`, `/tinspect`, `/luaerrors`, `/classicapi`, `/replay`).
- **UnitXP SP3** *(Optional — detected for overlap checks)* — Reads `UnitXP("FPScap")` and `UnitXP("backgroundFPScap")` to warn when both ClassicAPI and UnitXP SP3 are capping FPS simultaneously.
- **Nampower** *(Optional — detected for status display)* — Checks `GetNampowerVersion()` in the Overlaps & Status overview.
- **SuperWoW** *(Optional — detected for status display)* — Checks `SUPERWOW_VERSION` / `SUPERWOW_STRING` in the Overlaps & Status overview.
- **WeirdUtils** *(Optional — detected for overlap checks)* — Inspects `GetWeirdUtilsVersion()` to detect overlapping modules (`dpslog`, `interact`, `bigcursor`).

Written in strict **Lua 5.0** with zero external library dependencies.

## Features

- **Vanilla 1.12 Interface:** Standard `UI-DialogBox` window, `UIPanelScrollFrame`, mouse-wheel scrolling, `Escape` key close (`UISpecialFrames`), draggable frame with saved position, and a draggable Vanilla minimap button.
- **Full ClassicAPI Configuration Coverage (4 Settings Tabs):**
  - **General:** `ActionButtonUseKeyDown`, `stopAutoAttackOnTargetChange`, `autoStand`, `autoDismount`, `autoUnshift`, `expandedCursors`, `countdownForCooldowns`, `dontShowEquipmentSetsOnItems`, `breakUpLargeNumbers`, `ShakeStrengthUI`, and `C_PlayerCache` persistent name cache.
  - **Soft Target:** All 20 `SoftTarget*` CVars (`SoftTargetInteract*`, `SoftTargetEnemy*`, `SoftTargetFriend*`, locked-target behavior, nameplate/world icon sizes & distance scaling) plus 1-click presets (*All Off*, *Interact Only*, *Interact + Enemy*).
  - **Combat:** Built-in Damage Meter (`damageMeterEnabled`, `damageMeterResetOnNewInstance`), `combatLogRetentionTime`, `advancedCombatLogging`, `advancedCombatLoggingMovement`, plus quick `/combatlog` and `/replay` buttons.
  - **Perf & UI:** Foreground/background FPS limits (`useMaxFPS`, `maxFPS`, `useMaxFPSBk`, `maxFPSBk`), `SetMaxAnimFramerate`, `scriptProfile`, default nameplate alpha (`nameplateSelectedAlpha`, `nameplateNotSelectedAlpha`), bag sorting (`sortBagsRightToLeft`, `backpackAutosortDisabled`, `bankAutosortDisabled`), `C_AutoComplete` settings, and Text-to-Speech (`ttsVoice`, `ttsSpeed`, `ttsVolume` + **Test Speak** / **Stop Speak**).
- **Live Modified Highlight & Per-Setting Reset:** Modified settings are highlighted in gold with an inline `R` reset button; live-syncs automatically via `CVAR_UPDATE`.
- **Cross-Mod Overlap & Conflict Detector (`Overlaps` Tab + Inline Badges):**
  - Displays inline `[!]` / `[i]` badges and detailed tooltip explanations next to affected settings.
  - Detects and provides one-click **Quick Fix** actions for:
    - WeirdUtils `dpslog` vs ClassicAPI `COMBAT_LOG_EVENT_UNFILTERED` / `GetSpellInfo`
    - ClassicAPI `useMaxFPS` / `useMaxFPSBk` vs UnitXP SP3 `FPScap` / `backgroundFPScap`
    - `advancedCombatLoggingMovement` enabled without `advancedCombatLogging`
    - `scriptProfile` left enabled during normal play
    - `countdownForCooldowns` vs `pfUI` / `OmniCC` / `tullaCC`
    - `damageMeterEnabled` alongside `GreedMeter` / `DPSMate` / `ShaguDPS` / `Details`
    - `SoftTargetInteract` vs WeirdUtils `interact`, `expandedCursors` vs WeirdUtils `bigcursor`, `autoStand`/`autoDismount` vs `_LazyPig`, default nameplate alpha vs `pfUI`, and `!BugGrabber` handoff info.
- **Tools & One-Click Presets (`Tools` Tab):** Quick buttons for `/profiler`, `/profiler widget`, `/etrace`, `/framestack`, `/tinspect`, `/luaerrors`, `/classicapi`, `/replay`, ClassicAPI's built-in Options panel, `ReloadUI()`, built-in presets (*Recommended QoL*, *Raid Performance*, *Combat Log & Replay*), and *Reset All ClassicAPI CVars to Default*.

## Slash Commands

- `/capi` (or `/capisettings`, `/classicapisettings`) — Toggle the settings window.
- `/capi overlaps` — Open directly on the Overlaps & Status tab.
- `/capi soft` — Open directly on the Soft Target tab.
- `/capi tools` — Open directly on the Tools & Presets tab.
- `/capi status` — Print detected client DLL mods and overlap counts to chat.
- `/capi scan` — Print all detected overlaps/warnings to chat.
- `/capi minimap` — Toggle the minimap button.
- `/capi resetpos` — Reset the window position to screen center.
- `/capi trace` — Toggle debug trace logging for `CVAR_UPDATE` and lifecycle events.
