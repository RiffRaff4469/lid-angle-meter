# Lid Angle Meter

**A macOS menu-bar app that shows your MacBook's live lid angle.**

This is a small utility. It reads the lid-angle sensor built into recent MacBooks and shows the current angle in the menu bar as a number and a tiny side-view laptop whose lid moves with yours. That's all it does. The sensor code is short and only needs IOKit, so it's a decent place to start if you want to use lid-angle data in another project.

## What it does

- Draws a side-view laptop in the menu bar with the lid at the current angle. Hover over it to see the smoothed and raw angle.
- Click the icon for a menu with:
  - a larger version of the drawing
  - the angle with a label, for example `106°  —  Lid open` (labels go from Lid closed through Barely open, Partially open, Lid open and Wide open to Folded flat)
  - a sensor status line
  - Quit
- Only shows the current reading. There's no maximum, no history, no logging and no settings.
- No Dock icon, no window, no network access, and it doesn't ask for permissions.
- On a Mac without the sensor, it shows `Lid sensor: not found` and stops polling.

## Install

Requirements: macOS 12 or later, a Swift 5.7+ toolchain (Xcode or the Command Line Tools), and a MacBook with the lid-angle sensor (see Limitations).

```sh
git clone https://github.com/RiffRaff4469/lid-angle-meter.git
cd lid-angle-meter
swift build -c release
.build/release/LidAngleMeter
```

A debug build works too: run `swift build`, then `.build/debug/LidAngleMeter`.

To build without SwiftPM, use one `swiftc` command:

```sh
swiftc -O -o LidAngleMeter Sources/LidAngleMeter/*.swift -framework AppKit -framework IOKit && ./LidAngleMeter
```

It's a bare executable, not an `.app` bundle. You don't need to sign it or grant it anything, because any process can read the lid-angle report.

## Using it

Start it from a terminal and the laptop icon appears in the menu bar. Click it to see the angle. To quit, pick **Quit LidAngleMeter** (or press ⌘Q while the menu is open), press Ctrl-C in the terminal, or run `pkill -f LidAngleMeter`.

## How it's built

- `LidAngleSensor.swift` (about 75 lines) does the sensor reading. It uses `IOHIDManager` to match devices on the standard HID sensor usage page `0x0020`, usage `0x008A` (Apple `0x05AC:0x8104`). It tries each matching interface and keeps the first one that answers feature report 1. The same device also exposes vendor-page (`0xFF00`) interfaces that fail that read, and those get skipped. The device stays open for as long as the app runs.
- The angle in degrees is `report[2] << 8 | report[1]`. `LidAngleSensor()` returns `nil` if there's no sensor, and `readAngle()` returns a `Double?`. Those two calls are all another project needs.
- It polls 25 times a second on a `Timer` added in `.common` run-loop mode, so the menu keeps updating while it's open. Readings are smoothed with an exponential moving average (alpha 0.15), and the raw value is kept for the tooltip.
- The icon is redrawn at most 10 times a second, and only when the angle moves more than 0.3°. The larger drawing only updates while the menu is open, so the app uses almost no CPU when it's idle.
- The icons are template `NSImage`s drawn with Core Graphics, so AppKit tints them to match light or dark menu bars.
- After 15 failed reads in a row (about 0.6 s), the app stops the timer and marks the sensor as not found.

## Limitations

- It only works on MacBooks that have the lid-angle sensor. Those are reportedly the 16-inch MacBook Pro (2019) and later models. I've only verified it on a 14-inch MacBook Pro (2021, M1 Pro). Package.swift targets macOS 12, but without the sensor the app just shows `Lid sensor: not found`.
- It doesn't start at login or install itself anywhere. You run it from where you built it.
- The drawing is limited to 0–180°. The number and tooltip show exactly what the sensor reports.

Tested with macOS 26.5 and Swift 6.3 on a MacBook Pro (14-inch, 2021, M1 Pro).

Made by RiffRaff4469. MIT licensed.
