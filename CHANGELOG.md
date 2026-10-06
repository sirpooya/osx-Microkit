# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Entries accumulate under [Unreleased] as work lands, and move into a versioned
section when a release is cut.

## [Unreleased]

> First version: a native Mac configurator for Work Louder and other VIA keyboards.

### Added
- Remap every key and both knobs (press, turn left, turn right) on any layer of a VIA keyboard, with Mac-style key labels and undo
- Lighting controls built from the keyboard's own definition: brightness, effect, speed and color
- Macro editor: type text, tap, hold or release keys, and pause, with a live byte budget
- Key tester, layout options, keyboard info, and backup and restore to a file
- A full backup is saved automatically before the first change to a keyboard each launch
- Music mode: the keyboard's lights follow whatever is playing on your Mac (Spectrum, Pulse or Beat Rainbow), with a live visualizer. Nothing is saved to the keyboard, and your lighting comes back when you stop
- Demo keyboard: try every screen, including Music, with a pretend Micro Pad when no keyboard is plugged in (File > Add Demo Keyboard)

### Changed
- The Creator Micro now uses MicroMap's workspace: a lifelike Creator Micro, a Figma shortcut library, drag and drop, layers with Apply, and lighting that changes when Figma is in front. Microkit's music mode, macros, key tester, backups and every keyboard keycode sit alongside it (MicroMap by Martin Málek, MIT)
- New app icon and menu bar icon: four diamonds on a dark keycap.
- Keycaps on the Creator Micro canvas now use the newer Work Louder x Figma key designs (Red, Coral, Violet, Blue, Green, Black), and the Move, Frame, Rectangle, Pen and Edit shape actions use its new tool icons.
- Settings open in their own compact window instead of taking over the main window.
- Clicking the menu bar icon opens the Microkit window; right-click (or Control-click) shows the menu with Settings and Quit.

### Fixed
- ⌘, opens Settings for every keyboard, not only the Creator Micro.

