# Sidl

Sidl is a macOS menu bar app that adds gestures to the edges of your trackpad.
Slide along an edge to change the volume or the screen brightness. Swipe in from an edge to open an app or control music.

## Gestures

All gestures use two fingers. Each edge zone is the outer 10% of the trackpad.

| Gesture | Default action | Other actions |
|---|---|---|
| Swipe right from the left edge | Open Terminal | Open any app, Play/Pause, Next track, Previous track, None |
| Swipe down from the top edge | Play/Pause | Open any app, Next track, Previous track, None |
| Slide up or down on the left edge | Brightness | Volume, None |
| Slide up or down on the right edge | Volume | Brightness, None |

The macOS gesture for Notification Center (two-finger swipe left from the right edge) still works.
A horizontal move on the right edge cancels the volume slide.

## Features

- **Settings window:** choose the action for each gesture, or turn a gesture off.
- **Sensitivity:** one setting for slides (how far you slide for a full change) and one for swipes (how far you swipe before it triggers). Each has levels 1 to 5.
- **On-screen display:** shows the volume or brightness level while you slide.
- **Scroll blocking:** while an edge gesture is active, the window under the pointer does not scroll.
- **Launch at login.**

## Requirements

- macOS 13 Ventura or later.
- A Mac trackpad: built-in, or a Magic Trackpad.
- **Accessibility permission**, for scroll blocking. The other gestures work without it.

Brightness control works only on the built-in display.

## Install

There are no releases yet. To use Sidl now, build it from source.

## Build from source

You need Xcode or the Xcode Command Line Tools (Swift 5.9 or later).

```bash
git clone https://github.com/shresthaoshan/sidl.git
cd sidl
swift test
scripts/bundle.sh
open Sidl.app
```

`scripts/bundle.sh` builds `Sidl.app` (debug by default; run `scripts/bundle.sh release` for a release build).

### Signing

macOS links the Accessibility permission to the app's code signature.

- If you have no signing certificate, the script uses ad-hoc signing. Each rebuild then gets a new identity, and you must grant Accessibility again after each build.
- To keep the permission across rebuilds, create a self-signed certificate one time:
  1. Open **Keychain Access → Certificate Assistant → Create a Certificate**.
  2. Name: `Touchyy Dev`. Identity Type: **Self Signed Root**. Certificate Type: **Code Signing**.
  3. Open the certificate, and set **Trust → Code Signing** to **Always Trust**.

To use a certificate with a different name, set `SIGN_IDENTITY`:

```bash
SIGN_IDENTITY="My Certificate" scripts/bundle.sh
```

### Permissions

When Sidl starts, macOS asks for Accessibility permission. Turn on **Sidl** in **System Settings → Privacy & Security → Accessibility**.
The menu bar panel shows `Scroll blocking: on` when the permission is active.

## How it works

Sidl uses private macOS frameworks. That is why it is not on the Mac App Store.

| Part | API |
|---|---|
| Raw finger positions | `MultitouchSupport.framework` (private), loaded at runtime with `dlopen` |
| Volume | CoreAudio |
| Brightness | `DisplayServices.framework` (private) |
| Play/Pause, next, previous | `MediaRemote.framework` (private) |
| Scroll blocking | A `CGEventTap` on scroll events |
| Open app, launch at login | `NSWorkspace`, `SMAppService` |

Private APIs can change in any macOS update.

## Known limitations

- Only one trackpad is supported at a time. A MacBook with a Magic Trackpad connected can confuse the gestures.
- A trackpad that you connect after Sidl starts is not detected until you restart Sidl.
- Gestures may stop after the Mac wakes from sleep. Restart Sidl if this happens.
- Brightness does not work on external displays.

## Project layout

```
Sources/CMultitouch/   C shim that loads MultitouchSupport
Sources/Sidl/          The app: recognizers, router, actions, settings, HUD
Tests/SidlTests/       Unit tests
scripts/bundle.sh      Builds and signs Sidl.app
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, architecture, tests, and how to send a change.

## License

Sidl is released under the [MIT License](LICENSE).
