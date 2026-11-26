# ClassicAPI Settings (for ClassicAPI v1.23.9+)

A lightweight, Vanilla-styled companion settings panel, profile & preset manager, custom boss ID registry, and cross-mod overlap detector built for **ClassicAPI v1.23.9+** on World of Warcraft 1.12.1 / Turtle WoW.

> **Version Compatibility:** Targets **ClassicAPI v1.23.9+** (`CLASSIC_API_VERSION >= 12309`). If ClassicAPI is missing or older than `v1.23.9`, the addon prints a login warning recommending an update, keeps all UI entries visible, and tags unsupported settings with `[Req v1.23.9+]` (plus tooltip and chat warnings if clicked) instead of hiding or crashing.

## Client DLL Mods

- **ClassicAPI v1.23.9+** *(Required for settings)* — Reads and writes ClassicAPI CVars (`GetCVar`, `GetCVarDefault`, `C_CVar.SetCVar`, `C_CVar.DoesCVarExist`, `C_CVar.GetCVarInfo`), listens to `CVAR_UPDATE` for live UI sync, manages `C_PlayerCache`, `GetMaxAnimFramerate` / `SetMaxAnimFramerate`, `C_VoiceChat` TTS voices/test playback, `C_InstanceEncounter.AddBossCreatureID` / `RemoveBossCreatureID`, `UnitCreatureID`, and launches built-in tools (`C_SettingsUtil.OpenSettingsPanel`, `/profiler`, `/etrace`, `/framestack`, `/tinspect`, `/luaerrors`, `/classicapi`, `/addons`, `/replay`).
- **UnitXP SP3** *(Optional — detected for overlap checks)* — Reads `UnitXP("FPScap")` and `UnitXP("backgroundFPScap")` to warn when both ClassicAPI and UnitXP SP3 are capping FPS simultaneously, and flags ActionCam + UnitXP SP3 camera overlap.
- **Nampower** *(Optional — detected for status display)* — Checks `GetNampowerVersion()` in the Overlaps & Status overview.
- **SuperWoW** *(Optional — detected for status display)* — Checks `SUPERWOW_VERSION` / `SUPERWOW_STRING` in the Overlaps & Status overview.
- **WeirdUtils** *(Optional — detected for overlap checks)* — Inspects `GetWeirdUtilsVersion()` to detect overlapping modules (`dpslog`, `interact`, `bigcursor`).

Written in strict **Lua 5.0** with zero external library dependencies.

## Features

- **Vanilla 1.12 Interface:** Standard `UI-DialogBox` window titled `ClassicAPI Settings (v1.23.9+)`, bottom bar showing `Target: v1.23.9+ | Installed: <version>`, `UIPanelScrollFrame` with mouse-wheel scrolling, `Escape` key close (`UISpecialFrames`), draggable frame with saved position, and a draggable Vanilla minimap button.
- **Cross-Tab Search & "Modified Only (N)" Filter:** Instantly filter all settings across all 5 tabs by name, CVar, or description with a live match counter, or toggle **Modified Only (N)** to review only CVars changed from their defaults.
- **Visual Dependency Dimming:** Dependent child settings (e.g. `maxFPS` when `useMaxFPS=0`, ActionCam sliders when `CameraKeepCharacterCentered=1`, Soft Target sub-options when disabled, `cameraZSmooth` when `CameraReduceUnexpectedMovement=0`) automatically dim to ~48% opacity and explain why in their hover tooltip (`[INACTIVE] ...`).
- **Safe Editing (`Undo`, `Reset Tab`, Confirmation Popups & `Reload UI!`):**
  - Vanilla `StaticPopup` confirmation dialogs protect **Reset All CVars** and **Profile Delete** against accidental clicks.
  - Bottom bar includes **Reset Tab** (resets only the active tab), **Undo** (10-step session stack for presets, profiles, imports, quick fixes, and resets — also `/capi undo`), and a dynamic orange **`Reload UI!`** button whenever `scriptProfile` is toggled.
- **Exact Numeric Slider Inputs:** Every slider includes an inline EditBox so you can type exact values (e.g. `144` FPS or `600` seconds) and press Enter, in addition to dragging the slider.
- **ClassicAPI Keybind Status Bar:** Displays live bound keys (`GetBindingKey`) for **Focus Target** (`FOCUSTARGET`), **Target Focus** (`TARGETFOCUS`), and **Interact With Target** (`INTERACTTARGET`) with a one-click **Key Bindings** button — plus an overlap warning if Soft Interact is enabled without an Interact keybind.
- **Version Guard & Graceful Degradation:**
  - Automatically warns in chat on `PLAYER_LOGIN` if `ClassicAPI.dll` is missing or older than `v1.23.9`, and adds a warning card to the **Overlaps** tab.
  - Every setting unavailable on an older build stays visible with an orange `[Req v1.23.9+]` tag, an `[UNSUPPORTED ON CURRENT VERSION]` explanation in its hover tooltip, and a safe chat warning if clicked.
- **Full Row-Hover Tooltips:** Hovering anywhere on a setting row highlights the row and shows a popup tooltip with purpose, CVar name, storage scope (`Account` vs `Per-Character`), current vs default value, version requirements, and any active cross-mod overlap warnings.
- **Full ClassicAPI v1.23.9 Configuration Coverage (5 Settings Tabs):**
  - **General:** Focus keybinds bar, `ActionButtonUseKeyDown`, `stopAutoAttackOnTargetChange`, `autoStand`, `autoDismount`, `autoUnshift`, `expandedCursors`, `countdownForCooldowns`, `dontShowEquipmentSetsOnItems`, `breakUpLargeNumbers`, `ShakeStrengthUI`, and `C_PlayerCache` persistent name cache.
  - **Soft Target:** Interact keybind bar, all 20 `SoftTarget*` CVars (`SoftTargetInteract*`, `SoftTargetEnemy*`, `SoftTargetFriend*`, locked-target behavior, nameplate/world icon sizes & distance scaling) plus 1-click presets (*All Off*, *Interact Only*, *Interact + Enemy*).
  - **Camera (ActionCam — v1.23.9+):** Quick presets (*Off*, *Basic*, *On*, *Full*) and all 24 ActionCam CVars (`CameraKeepCharacterCentered`, `CameraReduceUnexpectedMovement`, `test_cameraOverShoulder`, `test_cameraDynamicPitch*`, `test_cameraHeadMovement*` incl. range scale/dead zone/damp rates, `test_cameraTargetFocus*` incl. pitch/yaw strengths, `cameraZSmooth`, `cameraIndirectVisibility`, and `cameraIndirectOffset`).
  - **Combat:** Built-in Damage Meter (`damageMeterEnabled`, `damageMeterResetOnNewInstance`), `combatLogRetentionTime`, `advancedCombatLogging`, `advancedCombatLoggingMovement`, plus quick `/combatlog` and `/replay` buttons.
  - **Perf & UI:** Foreground/background/loading FPS limits (`useMaxFPS`, `maxFPS`, `useMaxFPSBk`, `maxFPSBk`, `maxFPSLoading`), `SetMaxAnimFramerate`, `scriptProfile`, default nameplate appearance (`nameplateUseClassColorForFriendlyPlayerUnitNames`, `nameplateSelectedAlpha`, `nameplateNotSelectedAlpha`), bag sorting (`sortBagsRightToLeft`, `backpackAutosortDisabled`, `bankAutosortDisabled`), `C_AutoComplete` settings, and Text-to-Speech (`ttsVoice`, `ttsSpeed`, `ttsVolume` + **Test Speak** / **Stop Speak**).
- **Custom User Profiles, Auto-Switch by Zone & Export / Import (`Tools` Tab):** Save, load, and delete named profiles in `ClassicAPISettingsDB`, optionally auto-switch profiles when entering **Open World**, **Dungeon (5m)**, **Raid**, or **Battleground** (`PLAYER_ENTERING_WORLD` + `GetInstanceInfo`), or share/backup modified settings via compact `CAS1|...` Export/Import strings.
- **Persistent Custom Boss Creature IDs (`C_InstanceEncounter`, v1.23.9+):** Register custom Turtle WoW boss creature IDs by number or directly from your current target (`Add Current Target` / `/capi addboss`). Saved IDs are automatically re-registered on every `PLAYER_LOGIN` / `/reload` so `boss1..5`, `ENCOUNTER_START/END`, and Damage Meter sessions track them.
- **Cross-Mod Overlap & Conflict Detector (`Overlaps` Tab + Inline Badges):**
  - Displays inline `[!]` / `[i]` badges and detailed tooltip explanations next to affected settings.
  - Detects and provides one-click **Quick Fix** actions for 15 checks including missing/outdated ClassicAPI, Soft Interact without `INTERACTTARGET` keybind, ActionCam blocked by `CameraKeepCharacterCentered=1`, ActionCam + UnitXP SP3 Camera, WeirdUtils `dpslog`/`interact`/`bigcursor`, UnitXP SP3 `FPScap`/`backgroundFPScap`, `advancedCombatLoggingMovement` without `advancedCombatLogging`, `scriptProfile`, `countdownForCooldowns` vs `pfUI`/`OmniCC`/`tullaCC`, damage meters, `_LazyPig`, default nameplate alpha vs `pfUI`, and `!BugGrabber`.
- **Tools & Built-in Presets (`Tools` Tab):** Quick buttons for `/profiler`, `/profiler widget`, `/etrace`, `/framestack`, `/tinspect`, `/luaerrors`, `/classicapi`, `/addons` (`v1.23.9+`), `/replay`, ClassicAPI's built-in Options panel, `ReloadUI()`, built-in presets (*Recommended QoL*, *Raid Performance*, *Combat Log & Replay*), and *Reset All ClassicAPI CVars to Default*.

## Slash Commands

- `/capi` (or `/capisettings`, `/classicapisettings`) — Toggle the settings window.
- `/capi camera` — Open directly on the Camera (ActionCam) tab.
- `/capi soft` — Open directly on the Soft Target tab.
- `/capi overlaps` — Open directly on the Overlaps & Status tab.
- `/capi tools` (or `/capi profiles`) — Open directly on the Tools, Profiles & Custom Boss IDs tab.
- `/capi export` / `/capi import` — Open the `CAS1|...` Export or Import popup directly.
- `/capi addboss` — Register your current NPC target's Creature ID as a persistent custom boss (`v1.23.9+`).
- `/capi undo` — Revert the last bulk change (preset, profile load, import, quick fix, or reset).
- `/capi status` — Print target vs installed ClassicAPI version, other DLL mods, and overlap counts to chat.
- `/capi scan` — Print all detected overlaps/warnings to chat.
- `/capi minimap` — Toggle the minimap button.
- `/capi resetpos` — Reset the window position to screen center.
- `/capi trace` — Toggle debug trace logging for `CVAR_UPDATE` and lifecycle events.
