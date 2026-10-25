# Pervitin

Keeps your Mac awake for as long as you say. Nothing else.

Made by protowaldganger.

## Use

- Click the tube in the menu bar, pick a length (15 minutes to 8 hours, until a time, or until you stop it) and press Wach bleiben.
- Right-click the tube to start or stop instantly with the last length you picked.
- By default the display stays on and the screen saver stays away. Turn on "Let the display sleep" to keep only the Mac itself awake.

Closing the lid still puts a MacBook to sleep, as macOS intends.

## Private by design

No network access, no analytics, no statistics, sandboxed. It holds the same power assertions as macOS's own `caffeinate`, and the only thing it stores is your choices.

## Install

1. Download `Pervitin.zip` from Releases, unzip it and drag Pervitin into Applications.
2. Open it. macOS warns that it cannot verify the developer, because the app is not notarized. Open System Settings › Privacy & Security, scroll down and click Open Anyway.

## Build

Requires Xcode and macOS 13 or later.

```
./build.sh
cp -R build/Pervitin.app /Applications/
```

## Uninstall

```
rm -rf /Applications/Pervitin.app
rm -rf ~/Library/Containers/com.protowaldganger.pervitin
```
