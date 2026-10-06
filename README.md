# Microkit

A native macOS configurator for VIA keyboards, written in Swift and SwiftUI. It does what
[usevia.app](https://usevia.app) does, without a browser: it finds a VIA-enabled QMK keyboard over
USB, shows its layout, and changes keys, knobs, layers, macros and lighting live, with no
reflashing.

It started with the Work Louder Creator Micro, which gets a dedicated workspace built on
[MicroMap](https://github.com/hello-malek/micromap). Every other VIA keyboard gets Microkit's
general editor.

> **Status: early.** Reading a keyboard (keymap, knobs, lighting, macros) is tested on a real
> Creator Micro. Writing to a keyboard is implemented but not yet tested on hardware. Before its
> first change in each launch, Microkit saves a full backup of the keyboard, which you can restore
> from the Device screen.

## Features

- **Keymap.** Every key and every knob (press, turn left, turn right) on every layer, with any VIA
  keycode, Mac-style labels (⌘, ⇧, media symbols) and undo. Each change is read back from the
  keyboard to confirm it.
- **Lighting.** Brightness, effect, speed and color, built from the keyboard's own VIA definition.
- **Macros.** Type text, tap, hold or release keys, and pause, with a live count of the keyboard's
  macro memory.
- **Music mode.** The lights follow whatever your Mac is playing (Spectrum, Pulse or Beat Rainbow),
  with an on-screen visualizer. Colors are streamed live and never saved to the keyboard, so your
  own lighting comes back when you stop.
- **Tools.** Key tester (needs firmware support), layout options, keyboard info, backup and
  restore to a file.
- **Creator Micro workspace** (from MicroMap). A lifelike board, a library of Figma shortcuts,
  drag and drop, changes collected in a draft and written to all four layers on Apply, lighting
  presets that switch when Figma is in front, and a global shortcut that opens Figma.
- **Demo keyboard.** Try every screen without hardware: File > Add Demo Keyboard.
- **Menu bar.** Microkit keeps running after its window closes. Click the menu bar icon to open the
  window, right-click it for the menu.

## Supported keyboards

- Any QMK keyboard with VIA enabled whose definition is published on usevia.app. For an unlisted
  or self-built board, import its VIA definition JSON.
- VIA protocol 12 and newer can be edited. Protocol 11 and older number keycodes differently, so
  Microkit shows them read-only.
- The Work Louder Creator Micro (USB `574C:E6E3`) opens in the dedicated workspace. The Creator
  Micro 2 and Work Louder's other newer boards use Work Louder's own protocol instead of VIA and
  are not supported.

## Requirements

- macOS 14 Sonoma or later. Music mode needs macOS 14.2 or later.
- Microkit opens only the keyboard's VIA interface, never the one you type through, and shares it
  with other apps (VIA in a browser, for example). If macOS still blocks access, allow Microkit in
  System Settings > Privacy & Security > Input Monitoring.
- Music mode asks once for permission to record system audio, listed under System Settings >
  Privacy & Security > Screen & System Audio Recording. No driver or microphone is involved.

## Build from source

You need Xcode 16 or later (Swift 6) and [XcodeGen](https://github.com/yonaskolb/XcodeGen).
`project.yml` is the source of truth; the Xcode project is generated from it.

```sh
brew install xcodegen
git clone https://github.com/sirpooya/osx-Microkit.git
cd osx-Microkit
xcodegen generate
```

The project signs with the author's Apple Development team. To build without it, sign ad hoc:

```sh
xcodebuild -project Microkit.xcodeproj -scheme Microkit -configuration Release \
  -derivedDataPath build CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build
open build/Build/Products/Release/Microkit.app
```

Or set `DEVELOPMENT_TEAM` in `project.yml` to your own team, run `xcodegen generate` again, and
build from Xcode.

The VIA protocol, keycode tables, definitions, macros and music analysis live in the
`Packages/MicrokitCore` Swift package. Its tests run against a simulated keyboard and recorded
replies, never a real device:

```sh
cd Packages/MicrokitCore && swift test
```

Launch with `--demo` to add the demo keyboard at startup.

## How it works

- Talks to the keyboard with IOKit raw HID (usage page `0xFF60`), one 32-byte report at a time,
  following the VIA protocol in QMK's `quantum/via.c`. The device is never opened exclusively.
- Keyboard definitions come from usevia.app and are cached in
  `~/Library/Application Support/Microkit/Definitions`. Backups go to `Backups/` in the same folder.
- Keycode tables are generated from QMK's keycode data by `Tools/gen-keycodes.py`.
- Music mode captures system audio with a Core Audio process tap and sends live lighting
  commands. It never sends VIA's save command, so it causes no EEPROM wear.

## Privacy

No accounts, analytics or telemetry. The only network request downloads keyboard definitions from
usevia.app, cached after the first fetch. Music mode analyzes sound in memory on your Mac; nothing
is recorded, stored or sent.

## Credits

- [MicroMap](https://github.com/hello-malek/micromap) by Martin Málek (MIT License): the Creator
  Micro workspace, Figma shortcut catalog, lighting presets and Figma integration. Vendored in
  `Microkit/MicroMap/`, with Microkit's changes marked `Microkit:` in comments.
- Keycap textures, controller renders and shortcut icons come from the
  [Work Louder x Figma](https://www.figma.com/community/file/1384624700163384062/work-louder-x-figma)
  Figma Community file by Robert Culver (CC BY 4.0).
- The VIA protocol comes from [QMK](https://qmk.fm) and [VIA](https://usevia.app). Microkit
  reimplements it from QMK's source; no code from the VIA app is included.

Full attribution is in [`ThirdParty/`](ThirdParty/). Figma, Work Louder and Creator Micro are
trademarks of their owners. Microkit is an independent project, not affiliated with or endorsed by
them.
