# CLAUDE.md: Microkit (native macOS keyboard configurator, a SwiftUI take on usevia.app)

## Goal
A native Swift/SwiftUI Mac app that does what usevia.app does: detect a VIA-enabled QMK keyboard
over raw HID, show its layout, and remap keys, encoders, layers, macros and lighting live, with
no reflashing. First target is Work Louder hardware (worklouder.cc), starting with the Creator
Micro ("Micro Pad") on the desk. It replaces opening usevia.app in Chrome (WebHID) and the
Electron "Input" app. Keep it minimal and dependency-light. No cloud sync, no accounts, no analytics.

## Status
- 2026-10-06: Settings moved out of the main window into their own fixed 760 x 600 window
  (`App/SettingsWindowController.swift`, AppKit-owned per house rule). The menu bar item is now an
  `NSStatusItem` (`App/StatusItemController.swift`): left click opens the main window, right click
  or Control-click shows the menu. Verified by screenshot: the settings window (General page) with
  the demo board. Not verified: the left and right clicks themselves, and reopening the main
  window from the icon after closing it (it relies on the stored SwiftUI `openWindow`).
  Reinstalled to /Applications (user said yes) for the user to try.
- 2026-10-05: **Microkit now uses MicroMap's interface for the Creator Micro** (user: "exactly
  this but with extra features of ours"). MicroMap's source (MIT) lives in `Microkit/MicroMap/`,
  its artwork and Figma catalog in `Microkit/Resources/MicroMap/` (CC BY 4.0), attribution in
  `ThirdParty/`. Its `HIDDeviceService` was rewritten as an adapter over Microkit's `DeviceStore`
  and `KeyboardSession`, so there is still one HID stack. Added to MicroMap's sidebar: Music,
  Macros, Key Tester, Device modes (Microkit's screens) and Keys / Media / Layers / Macros /
  Lighting categories in Actions (every VIA keycode as an action). Verified by screenshot with the
  demo board: Actions canvas, Music, Device. Not verified: Lights, drag and drop, Apply, Macros and
  Key Tester inside the new frame, and anything on real hardware.
- 2026-10-04 (later): Phases 1 to 5 built in one pass. `MicrokitCore` (protocol, keycode tables,
  definitions, menus, macros, backups) has 31 Swift Testing tests, all passing. The app builds
  clean and was run against the real Micro Pad: keymap, knobs, lighting values, macro M0 (⇧⌘S)
  and device facts all read correctly. Verified by screenshot: Keymap, Lighting, Macros, Key
  Tester, Device. NOT yet verified: any write to the device (assigning a key, lighting change,
  macro save, restore), clicking keys in the UI (the screen was locked during QC so synthetic
  clicks could not land), and the key tester lighting up on real presses. The write log
  (see Decisions) showed 0 writes while every screen was opened.
- 2026-10-05: Demo keyboard added (user asked to see features without the device). File > Add
  Demo Keyboard, the empty-state button, or launch flag `--demo`. It is `VirtualKeyboard` (moved
  from the tests into `MicrokitCore/Protocol`) seeded by `Model/DemoKeyboard.swift` with the real
  Micro Pad's keymap, knobs, lighting and M0. Writes stay in memory. In the Key Tester, clicking a
  key presses it. Music mode works in demo too (the lights it drives are virtual; the visualizer
  shows the color). Reinstalled to /Applications with demo and music mode.
- 2026-10-04 (night): Phase 7, Music mode, built: `MicrokitCore/Music` (SpectrumAnalyzer,
  MusicColorMapper, MusicTarget; 7 new tests, 38 total passing), `Microkit/Audio/SystemAudioCapture`
  (Core Audio tap), `Model/MusicController`, `Views/Music/`. The app builds. NOT yet run: the
  Micro Pad was unplugged, so neither the audio permission prompt nor streaming to the lights has
  been seen working. First run on hardware: start, play music, stop, confirm the old lighting is
  back and `log show` lists no `write ... 09` (custom_save).
- 2026-10-04 (evening): Installed to /Applications with `scripts/install.sh` (user said yes),
  signed by team 37MA269X54. Debug builds had been ad-hoc. The user also approved one real key
  change plus undo, but the Micro Pad was unplugged (`hidutil list` showed no 0x574C device), so
  that test is still pending; it also exercises hot-plug once the board is connected.
- 2026-10-04: Repo created. Research done and a read-only probe run against the real device
  (results under "Hardware facts"). The Xcode license has since been accepted; `xcodebuild` works.

## Hardware facts (measured 2026-10-04, do not re-derive)
Device on the desk: Work Louder **Micro Pad** (Creator Micro v1), VID `0x574C` ("WL"),
PID `0xE6E3`, upstream QMK board `keyboards/work_louder/micro` (atmega32u4). `hidutil list` shows
three interfaces: usage page 1 / usage 6 (keyboard), 1 / 2 (mouse), and **0xFF60 / 0x61 (VIA raw
HID)**. Only the last one is ours.

Read-only probe results (IOHIDManager matched on 0xFF60/0x61, non-exclusive open):
- Opening the device returned success with **no Input Monitoring prompt** (run from the VSCode
  terminal, which may already hold the grant: re-confirm from the bundled app).
- Max input and output report size: 32 bytes.
- VIA protocol version `0x000C` (12). Current QMK master is `0x000D` (13).
- `id_keycodes_version` (keyboard value 0x06) answers `0xFF` (unhandled): this firmware predates it.
- 4 dynamic layers, matrix 4 x 4, 2 encoders (definition puts encoder 0 at r0c0, encoder 1 at r0c3).
- 16 macros, macro buffer 823 bytes (`0x0337`). M0 is hold ⇧, hold ⌘, type "s", release both.
- Has both rgblight (channel 2) and RGB matrix (channel 3). rgblight brightness 0xFF effect 8
  (Rainbow Mood 3); RGB matrix brightness 0xFD effect 10. Work Louder's own "Indicators"
  brightness is channel 0, value 1, currently 3 (range 0 to 5).
- Decoder anchors (layer 0 as found): `0x0827` LGUI(KC_0), `0x0029` KC_ESC, `0x0A20`
  LSFT+LGUI(KC_3), `0x7700` QK_MACRO_0, `0x7E01` QK_KB_1 (custom keycode 1), `0x5201` TO(1).
  Encoder 1 ccw/cw = `0x00AA`/`0x00A9` (volume down/up), encoder 0 ccw/cw = `0x002D`/`0x002E`.
  A correct v12 decoder must render all of these.

Physical controls (from MicroMap's hardware notes, see "Prior art"; matches our probe):
- r0c0 = press of encoder 0, the vertical **Scroller** (physical up = VIA clockwise);
  r0c3 = press of encoder 1, the **Dial**. The other 14 matrix positions are keys K1 to K14.
- r3c0 is the "Figma" key on the Figma edition; r3c3 is the "Smiley" key, a firmware layer switch
  (TO(1) on this board). The standard and Figma editions are USB-identical: same VID:PID.
- The three indicator lights show the layer: layer 0 all off, layers 1 to 3 light one each.
Lighting quirks of this firmware (MicroMap, verified on hardware by them, not yet by us):
- RGB Light brightness is capped at 150 internally (`RGBLIGHT_LIMIT_VAL`); VIA's 0 to 255 is scaled.
- RGB Light ignores color and brightness writes while its effect is 0 (off): set the effect
  first, then color and brightness. RGB Matrix quantizes brightness (read-back can differ by 1 to 2).
- Rainbow effects take only the hue per LED: saturation must be 255 or they render white.
- Re-sending the same effect value restarts the animation (a visible blink): never resend it.

VIA definition: `https://usevia.app/definitions/v3/1464657635.json` (vpid = VID << 16 | PID),
name "Creator Micro". It is the **compiled** form: `layouts.keys[]` already carries
`x y w h r rx ry row col ei color d`, so no KLE parser is needed. Also `menus` (VIA v3 custom UI:
range, dropdown, color, toggle bound to `[id_name, channel, valueId]`), `keycodes`
(`qmk_rgblight_keycodes`, `qmk_rgb_matrix_keycodes`) and `customKeycodes` (map to QK_KB_0 + n).
Index of all supported boards: `https://usevia.app/definitions/supported_kbs.json`.

## VIA protocol reference (source: qmk_firmware `quantum/via.h`, `quantum/via.c`)
Every exchange is one 32-byte output report (report ID 0, `IOHIDDeviceSetReport`) answered by one
32-byte input report that echoes byte 0 (the command id). Byte 0 of `0xFF` means unhandled.
Multi-byte values are big-endian. Chunked reads and writes carry at most 28 data bytes.

| Id | Command | Request after id | Reply data |
|---|---|---|---|
| 0x01 | get_protocol_version | | [1..2] version |
| 0x02 | get_keyboard_value | value id | [2...] value |
| 0x03 | set_keyboard_value | value id, data | |
| 0x04 | dynamic_keymap_get_keycode | layer, row, col | [4..5] keycode |
| 0x05 | dynamic_keymap_set_keycode | layer, row, col, hi, lo | |
| 0x06 | dynamic_keymap_reset | | |
| 0x07 | custom_set_value | channel, value id, data | |
| 0x08 | custom_get_value | channel, value id | [3...] value |
| 0x09 | custom_save | channel | |
| 0x0A | eeprom_reset | | |
| 0x0B | bootloader_jump | | (device disappears) |
| 0x0C | macro_get_count | | [1] count |
| 0x0D | macro_get_buffer_size | | [1..2] size |
| 0x0E | macro_get_buffer | off hi, off lo, size<=28 | [4...] bytes |
| 0x0F | macro_set_buffer | off hi, off lo, size, bytes | |
| 0x10 | macro_reset | | |
| 0x11 | get_layer_count | | [1] layers |
| 0x12 | dynamic_keymap_get_buffer | off hi, off lo, size<=28 | [4...] bytes |
| 0x13 | dynamic_keymap_set_buffer | off hi, off lo, size, bytes | |
| 0x14 | get_encoder | layer, encoder, clockwise | [4..5] keycode |
| 0x15 | set_encoder | layer, encoder, clockwise, hi, lo | |

Keyboard value ids: 0x01 uptime, 0x02 layout options, 0x03 switch matrix state (key tester),
0x04 firmware version, 0x05 device indication (blink the board), 0x06 keycodes version (proto 13+).
Switch matrix state: protocol 12+ sends a row offset after the value id and data starts at reply
byte 3; older firmware has no offset and data starts at byte 2. Each row is `ceil(cols / 8)` bytes,
most significant byte first. Current QMK answers all zeros unless built with `VIA_INSECURE`.
Layout options: VIA packs choices first-group-highest (the-via/app `src/utils/bit-pack.ts`); a
plain-string label is a 1-bit toggle, `[title, a, b, c]` takes `ceil(log2(3))` bits.
Custom channels: 0 keyboard-specific, 1 backlight, 2 rgblight, 3 RGB matrix, 4 audio, 5 LED matrix.
Lighting value ids: 1 brightness, 2 effect, 3 effect speed, 4 color (hue, sat).

Keymap buffer (0x12/0x13) is `layers x rows x cols x 2` bytes, row-major, big-endian keycodes.
Read the whole keymap with it, not 0x04 per key. Encoders are not in that buffer.

Macro buffer: macros are consecutive NUL-terminated byte strings. Plain bytes are ASCII typed as
text. `0x01` prefixes an action: `0x01 0x01 kc` tap, `0x01 0x02 kc` down, `0x01 0x03 kc` up
(one-byte basic keycodes only), `0x01 0x04 <ascii digits> |` delay in ms.

Keycode table by protocol: 12 uses the VIA "v12" numbering (QK_TO 0x5200, QK_MACRO 0x7700,
QK_KB 0x7E00, mods as 0x0100 LCTL / 0x0200 LSFT / 0x0400 LALT / 0x0800 LGUI, 0x1000 right-hand
flag). 13+ must read keycodes version 0x06 first (VIA accepts BCD 8 to 9) and use the v13 table.
Protocol 11 and older number keycodes differently, so Microkit shows them read-only. Protocol 11
already uses the v12 layer ranges (TO 0x5200) but puts macros at 0x7702 and keyboard keycodes at
0x7F00; protocol 10 and older also move layers (TO 0x5000, MO 0x5100) and macros (0x5F12).
On protocol 12 VIA's Lighting picker offers only the 19 legacy `RGB_*` keys plus backlight,
because older firmware may lack the newer lighting codes (see `_research/usevia/COMPARISON.md`).
Tables are GENERATED by `Tools/gen-keycodes.py` from QMK `data/constants/keycodes/*.hjson`
(0.0.7 for protocol 12, 0.0.8 and 0.0.9 for protocol 13, merged with QMK's own `!delete!` and
`!reset!` rules); never hand-edit `Keycodes/Generated/`. Rerun instructions are in the script.

## Tech stack (Apple frameworks only, exceptions listed)
- Swift 6 language mode. SwiftUI, AppKit where needed. IOKit `IOHIDManager` for HID (no hidapi).
- Min target: macOS 14.0.
- Storage: no UserDefaults yet. `~/Library/Application Support/Microkit/` holds `Definitions/`
  (usevia.app cache, `Imported/` overrides) and `Backups/` (automatic and manual JSON backups).
  When preferences arrive, every key goes in one `Keys` enum.
- Format: XcodeGen `project.yml` is the source of truth; the `.xcodeproj` is generated and ignored.
  Protocol logic lives in a local Swift package (`Packages/MicrokitCore`) so `swift test` covers it.

> Do NOT add a Swift package unless a task truly needs it. Ask first. Approved exceptions: none yet.

## Project layout
(Since 2026-10-05 the Creator Micro UI is MicroMap's: `Microkit/MicroMap/` holds its App, Models,
Services, Stores, Support and Views folders; `Views/Microkit/` there hosts Microkit's modes.
`Views/Root/MainWindowView` picks MicroMap's `ContentView` for the Creator Micro or no keyboard,
and Microkit's own `RootView` for any other VIA keyboard.)
```
project.yml                        XcodeGen spec (Swift 6, strict concurrency, macOS 14)
scripts/install.sh                 Release build to /Applications, then deletes build/
Tools/gen-keycodes.py              QMK hjson -> Keycodes/Generated/*.swift
Tools/via-probe.swift              read-only CLI probe (the one used on 2026-10-04)
Microkit/
  App/                             MicrokitApp (one Window scene), AppDelegate, SettingsWindowController,
                                   StatusItemController (menu bar icon)
  HID/HIDThread.swift              dedicated run-loop thread for every IOKit HID callback
  HID/HIDDeviceMonitor.swift       IOHIDManager on 0xFF60/0x61, hot-plug events as AsyncStream
  HID/HIDDeviceTransport.swift     ReportTransport: serial queue, SetReport out, inbox of input reports
  Model/DeviceStore.swift          @Observable list of sessions, driven by monitor events
  Model/KeyboardSession.swift      one keyboard: load, assign + undo, lighting, macros, backup
  Model/DefinitionStore.swift      imported file > cache > usevia.app
  Theme/Theme.swift                every measured constant (key unit fractions, keycap colors)
  Views/Shared/                    KeyboardCanvas, KeyGeometry, KeycapView, KnobView, KeyLegendView
  Views/Keymap/                    KeymapScreen, SelectionBar, KnobActionPicker, KeycodePickerView,
                                   AdvancedKeycodeBuilder
  Views/Lighting/ Macros/ KeyTester/ Device/ Root/
  Resources/AppIcon.icon           Icon Composer icon from the user (Work Louder mark)
  Resources/Assets.xcassets        WorkLouderMark (template SVG, sidebar and empty state)
Packages/MicrokitCore/             pure Swift, no IOKit, no AppKit
  Sources/MicrokitCore/Protocol/   VIACommand, VIAClient, ReportTransport, Keymap, EncoderMap
  Sources/MicrokitCore/Keycodes/   tables, KeycodeFormatter (Mac legends), Composer, Catalog
  Sources/MicrokitCore/Definition/ KeyboardDefinition, LayoutKey, menus, ShowIfExpression
  Sources/MicrokitCore/Macros/     MacroCodec, MacroStep
  Sources/MicrokitCore/Snapshot/   KeyboardBackup, BackupService
  Tests/MicrokitCoreTests/         SimulatedKeyboard (via.c in memory), RecordedMicroPad replies,
                                   Fixtures/creator-micro.json
```
Build: `xcodegen generate && xcodebuild -project Microkit.xcodeproj -scheme Microkit build`
(or the `mac-qc` skill's `build.sh --scheme Microkit`).
Core tests: `cd Packages/MicrokitCore && swift test`.
Install: `scripts/install.sh` (writes to /Applications: ask the user before running it).
Launch flags for QC: `--demo` adds the demo keyboard; `--mode=actions|lights|music|macros|tester|device`
opens a MicroMap-shell mode, `--settings` or `--settings=keyboard|general|about` opens the settings
window (ONE token: `--mode music` makes macOS read "music" as a file to open
and the window never appears); `--section ...` still drives the generic screens. Add
`-ApplePersistenceIgnoreState YES` if a window fails to restore. Never use synthetic clicks while
the user is working: they land in whatever app is in front.

## Phases
1. **Core and transport.** Done 2026-10-04.
2. **Keymap editor.** Done 2026-10-04, writes not yet tried on hardware.
3. **Macros.** Done 2026-10-04, saving not yet tried on hardware.
4. **Lighting.** Done 2026-10-04, changes not yet tried on hardware.
5. **Tools.** Key tester, backup and restore, identify, layout options, keymap reset: done
   2026-10-04, untested on hardware. Not done: VIA `.layout` import, recording a key from the
   Mac keyboard into the picker, source (KLE) definition import.
6. **Later, only if asked.** Per-app layers (see Open questions), Bluetooth.
7. **Music mode.** In progress since 2026-10-04. See "Music mode".

## Decisions (DECIDED, do not re-litigate unless you spot a real problem)
- 2026-10-05 Creator Micro editing follows MicroMap: changes go to a local draft and reach the
  board only on **Apply** (with a confirmation), all four layers at once. MicroMap's draft keys
  (`figmaMicro.*` in UserDefaults) are storage addresses: do not rename them. The "Figma" key
  (r3c0) opens Figma through the global shortcut ⌃⌥⌘F on every layer and the Smiley key (r3c3) stays
  a layer switch, as in MicroMap. Lights mode switches presets when Figma gains or loses focus;
  music mode overrides it while running.
- 2026-10-05 One HID stack: MicroMap code never opens the device. Everything goes through
  `HIDDeviceService` (the adapter), which uses `KeyboardSession.writeKeycode` (backup and read-back)
  and `setLiveLighting` (never custom_save).
- 2026-10-05 MicroMap code is vendored, not a dependency: edit it in place, mark changes with
  "Microkit:" comments, keep `ThirdParty/` attribution. Its unit tests were not ported yet.
- 2026-10-05 The app keeps running in the menu bar after its window closes (MicroMap behavior),
  replacing the earlier "closing the window quits".
- 2026-10-06 Settings are their own small window (user asked), not a screen inside the main
  window, so MicroMap's "Back to app" row is gone. Menu bar icon: left click opens the main
  window, right click shows the menu (user asked). SwiftUI's MenuBarExtra cannot tell the two
  apart, hence AppKit.
- 2026-10-04 Signing: Manual, "Apple Development", team `37MA269X54` (the certificate's OU).
  `FTQDQPMU3H` in the certificate's name is the personal ID; using it as the team fails with
  "No signing certificate Mac Development found".
- 2026-10-04 Bundle id `in.pooya.microkit` (Debug `in.pooya.microkit.debug`). It and the defaults
  prefix `microkit.` are storage addresses: renaming strands data.
- 2026-10-04 Regular windowed app with one main window, like VIA. Not a menu-bar utility.
- 2026-10-04 IOKit directly, no hidapi. Open with `kIOHIDOptionsTypeNone`, never seize: other
  tools (VIA in Chrome, Work Louder Input, BetterTouchTool) may share the device.
- 2026-10-04 Only the 0xFF60/0x61 interface is opened. The key tester uses switch matrix state over
  raw HID instead of the keyboard interface, which keeps Input Monitoring out of the picture.
- 2026-10-04 Sandbox off (house rule). No HID entitlement is needed unsandboxed.
- 2026-10-04 Definitions are fetched from usevia.app at runtime and cached; the user can also
  import a local definition JSON (unlisted or self-built boards). Nothing from the-via repos is
  vendored: the-via/app and the-via/keyboards are GPL-3.0. Reimplement from the QMK protocol.
- 2026-10-04 Never two reports in flight: replies carry no request id, only the echoed request
  header. `HIDDeviceTransport` runs exchanges one at a time on its own serial queue and skips any
  input report whose header does not match (`VIACommand.echoLength`). `VIAClient` is a plain
  Sendable struct, not an actor, so there is no reentrancy to reason about.
- 2026-10-04 Writes apply immediately like VIA, are read back to confirm, and keymap edits go on
  an undo stack. Before the first write of each launch, `KeyboardSession.ensureBackup()` saves a
  full backup to `Backups/`.
- 2026-10-04 Opening a screen must never write. Lighting rows compare against the loaded value
  before sending (a hue round-trip can drift by one), and sliders only send while being dragged.
  Every write is logged: `/usr/bin/log show --predicate 'subsystem == "in.pooya.microkit"' --last 10m`
  (use the full path: in zsh `log` is a builtin). 0 writes were logged across a full QC pass.
- 2026-10-04 Keycap legends are Mac style (⌘0, ⇧⌘3, ↩, ⌫, SF Symbols for media), from
  `MacKeyLabels`; the QMK name stays in the tooltip.
- 2026-10-04 License: the user wants everything in Swift; no VIA code is copied. The one piece of
  VIA data in the repo is the test fixture `creator-micro.json`.
- 2026-10-04 Scope: VIA keyboards only. Work Louder's private Input protocol is out of scope.

## Device safety (the Micro Pad is the user's daily driver)
- Read commands are always fine. Any write (0x03, 0x05, 0x06, 0x07, 0x09, 0x0A, 0x0F, 0x10, 0x13,
  0x15) to the physical device during development needs the user's yes first, and a full
  backup taken before it (the app does this itself through `ensureBackup`).
- Never send 0x0A (eeprom reset), 0x06 (keymap reset), 0x10 (macro reset) or 0x0B (bootloader
  jump) without an explicit request naming that command. 0x0B drops the board into its bootloader.
- Tests use a fake `ReportTransport` replaying recorded replies, never the device.

## Prior art: other native Mac apps (found 2026-10-05; the first research round missed them)
- **MicroMap** (github.com/hello-malek/micromap, Swift, MIT, July 2026, 9 stars): a native macOS
  configurator for the **Work Louder Figma Creator Micro**, the same VID:PID as ours. IOKit raw HID,
  a curated catalog of Figma shortcuts verified against Figma, drag to assign, a local draft
  written only after a confirmed **Apply**, launch at login, layout-aware shortcut encoding
  (non-US keyboards), perimeter (channel 2) and key matrix (channel 3) presets that switch when
  Figma is or is not frontmost, keycap artwork from the Work Louder x Figma Community file
  (CC BY 4.0). No music mode, no general keycode picker, no macros editor. Its docs are copied to
  `_research/micromap/` (hardware notes are the most useful part).
- **LayerLens** (github.com/FireBall1725/LayerLens, Swift, GPL-3.0): an overlay showing the active
  QMK/Vial layer; VIA keymap viewer and lighting controls, not an editor. Live layer events need
  its own firmware module.
- **KeyAura** (jonathanlaf/keyaura): learning overlay for ZSA Voyager. **Strata** (FarzadHayat/strata):
  HID-level remapping daemon, not VIA.
What this means for Microkit: the plain "native Mac configurator for the Creator Micro" idea
exists (MicroMap, Figma-focused). Microkit differs by being a general VIA editor (every keycode,
layers, macros, knobs, read-back, undo, backups) plus music mode, which none of these have.
MicroMap is MIT, so its code and findings can be reused with attribution if the user wants.

## Work Louder landscape (for later phases)
- QMK upstream has `work_louder/micro`, `nano`, `loop`, `work_board`, `numpad`: plain VIA boards.
- Newer models (Creator Micro V2, XYZ, Nomad E / E V2, Knob / Knob F1) run Work Louder firmware
  (release repos under github.com/worklouder) configured by the closed-source **Input** app
  (Electron plus a node-hid fork). Input's extra protocol (per-app layer switching, device told
  the focused app) is undocumented.
- CORRECTION 2026-10-05: the Creator Micro 2 does NOT speak VIA. It is an ESP32-S3 board with
  VID `0x303A`, PID `0x8297` (USB) / `0x8298` (BLE), on vendor usage page `0xFF00` with Work Louder's
  Input protocol. The Framer edition shares those IDs; the Codex edition is `0x303A:0x8360`
  (MicroMap's research, citing the Espressif usb-pids registry). The earlier "also works with VIA"
  came from a review site and was wrong. Only the original Creator Micro (`0x574C:0xE6E3`) is VIA.
- **Codex Micro** (OpenAI edition, July 2026) runs OpenAI firmware that reports every key and
  encoder event to the host; the ChatGPT/Codex app opens it exclusively.
- BetterTouchTool supports all of the above natively (docs.folivora.ai, "Work Louder Keyboard
  Support"): on QMK models it rewrites the on-device layout to F13 to F20 combos, which is the
  only way to get per-app behavior on stock VIA firmware.

## Open questions (the user decides)
- Per-app layers: the user asked for a simpler explanation before deciding (2026-10-04). Options:
  skip; rewrite the keymap on every app switch (works on stock firmware, wears EEPROM); or flash
  custom QMK with a "switch to layer N" raw HID command (no wear, needs one reflash).
- Per-app layers: asked again in plain words on 2026-10-04, answer "dunno yet". Do not push it.
- Approved, pending hardware: one real key change on the Micro Pad, then undo it.

## Music mode (Phase 7)
Goal: the keyboard's lights follow whatever is playing on the Mac (Spotify, YouTube, anything),
plus an on-screen visualizer showing the same thing.

### What already exists (researched 2026-10-04, why we build our own)
- **Work Louder Input** (official, closed source, Electron; downloads at
  github.com/worklouder/input-releases): per-app presets and underglow color per focused app.
  No music or audio-reactive lighting found. Built for the newer boards (Creator Micro 2,
  Nomad E, Knob, XYZ); support for the Micro Pad v1 unverified.
- **usevia.app**: no music mode. Requested in the-via/app issue #389 (2026-04-14), still open.
- **rgb-music-visualizer** (github.com/vantfindthe/rgb-music-visualizer, Python): exactly this idea,
  including "Keychron and other QMK keyboards with VIA" over VIA raw HID, whole-board color, no
  EEPROM use. **Windows only.** Confirms the approach works on stock VIA firmware.
- **OpenRGB + Keyboard Visualizer / OpenRGB Effects plugin** (openrgb.org, CalcProgrammer1/
  KeyboardVisualizer): audio visualizer, runs on Mac (rough there), but a QMK board needs firmware
  with the OpenRGB protocol first. That is the route to per-key music effects.
- **SignalRGB**: audio-reactive, Windows only.
- **BetterTouchTool**: can set Work Louder LED colors from scripts (documented mainly for the
  Codex Micro); no music sync built in.
- QMK community modules (kolbenhans/qmk-modules) do per-key audio-reactive lighting, again via
  custom firmware.
- **MicroMap** (native Mac, same board; see "Prior art"): per-app lighting presets for Figma, no
  music or audio reaction.
Conclusion: on a Mac, with the Micro Pad's stock firmware, nothing does this. We build it.

### Why it is safe for the keyboard
QMK `via.c` applies `custom_set_value` for rgblight and RGB matrix with the `_noeeprom` setters
(`rgblight_sethsv_noeeprom`, `rgb_matrix_mode_noeeprom`, ...). Only `custom_save` (0x09) writes
EEPROM. Music mode streams set commands and NEVER sends save, so it causes no wear, and the
saved lighting returns on replug. On stop, Microkit sets the values it found before starting.

### Limits on stock VIA firmware
One color for the whole underglow and one for the whole backlight (RGB matrix): VIA has no
per-key color command. Per-key effects need OpenRGB-protocol or VialRGB firmware (out of scope
unless the user asks).

### Design
- Capture: Core Audio process tap (`CATapDescription` global stereo tap, macOS 14.2+) wrapped in
  a private aggregate device; IO proc on its own queue. Permission: "System Audio Recording Only"
  (Privacy & Security > Screen & System Audio Recording), prompted on first start, text from
  `NSAudioCaptureUsageDescription`. No driver, no microphone. Audio never leaves the Mac.
- Analysis (`MicrokitCore`, testable): 1024-point FFT with Accelerate, log-spaced bands, bass /
  mid / treble with adaptive normalization, beat detection on bass energy against its recent
  average.
- Mapping (`MicrokitCore`): styles Spectrum (hue from where the sound sits, bass red to treble
  blue), Pulse (your color, breathing with the bass), Beat Rainbow (hue jumps on each beat).
  Fast attack, slow release, brightness floor.
- Output: targets come from the definition's menus (each section with a color control: on the
  Micro Pad "Underglow" channel 2 and "Backlight" channel 3). Start sets the effect to Solid
  Color, then streams color and brightness, latest frame only (no queue build-up), about 30 fps.

## Privacy (local-first)
No telemetry, no analytics, no account. Network calls, exhaustively: `usevia.app/definitions/...`
for keyboard definitions, cached after the first fetch. Nothing the user stores leaves this Mac.
Music mode analyzes system audio in memory only; nothing is recorded or stored.

## Reference material and QC
- `_qc/reference/`: screenshots of usevia.app configuring the Micro Pad, when captured. They are
  the visual spec for layout and flow (not for styling: this app should look native).
- Screenshot-QC every significant view with the `mac-qc` skill before calling it done, and run its
  `clean.sh` at the end of every pass.
- `_research/usevia/` (gitignored, local only): a full study of usevia.app's UI done 2026-10-05.
  `screens/` holds screenshots of every VIA screen, `notes/` the per-area write-ups, and
  `COMPARISON.md` what Microkit has, lacks or does differently. Read it before changing a
  screen's layout or flow.
- To see usevia.app's full UI without a keyboard: `_research/usevia/fake-webhid.js` fakes a WebHID
  Micro Pad (protocol 12, the real board's data). Open a chrome-devtools page, then
  `navigate_page` to https://usevia.app/ with the file's text as `initScript`. Each page has
  its own fake board, so several agents can work in separate tabs (pass `pageId` on every call).
- QC findings (2026-10-04): `mac-qc`'s `run.sh` fails with "LAUNCH_ARGS[@]: unbound variable"
  when given no launch args; pass `-- --section keymap`. When the Mac is locked
  (`macqc frontmost` says loginwindow) synthetic clicks do nothing and `ax tree` loops on
  AXApplication; screenshots still work, so use `--section` launches.

## Changelog
After any user-visible or behavioral change, log it:

```bash
python3 ~/Documents/GitHub/claude-skills/skills/release/changelog.py add <type> "<entry>"
```

Types: added, changed, deprecated, removed, fixed, security. Write the entry for someone reading
release notes. Skip pure refactors and doc-only edits. Releases are cut with the `release` skill.

## Working style
- Read this file first. Follow the phase order.
- Put testable logic in `MicrokitCore`, not the app target.
- Use the `mac-pro`, `swift-pro` and `mac-qc` skills for scaffold, Swift code and QC.
- Commit in small, working increments. Explain any deviation from this spec.
- Ask before adding any external dependency.
- No em dashes: prose, code comments, commit messages.

## Definition of done
- [x] `swift test` passes, decoding every anchor in "Hardware facts" from recorded replies (31 tests).
- [x] The app shows the Micro Pad with protocol 12, 4 layers, the full keymap, both knobs and
      lighting values read from the device (screenshots, 2026-10-04).
- [ ] Unplug and replug updates the app without relaunching (code path exists, not exercised).
- [ ] Assigning a key, undo, a lighting change and a macro save work on the real Micro Pad.
- [ ] Key tester lights up on real presses (depends on the firmware's VIA_INSECURE setting).
