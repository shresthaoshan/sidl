# Sidl

Sidl is a macOS menu bar app that adds gestures to the edges and corners of your trackpad.
Slide along an edge to change the volume or the screen brightness. Swipe in from an edge, or click a top corner, to open an app, control music, or send a shortcut.

**Website:** [sidl.shresthaoshan.com](https://sidl.shresthaoshan.com/)

## The story behind Sidl

I was scrolling Threads with nothing on my mind when I saw a post about a tool that adds gesture controls like these to the trackpad you already have.

I went to its website. It cost $9, and that was the sale price.

So I built my own overnight, with the help of a DeepSeek-powered coding harness. That became Sidl: free and open source.

I do not have an Apple Developer Program membership yet (it costs $99 a year 😞), so there is no signed release.

For now, Sidl is here as source code. If you can build it yourself, you save the $9. Pull requests are welcome.

## Gestures

### Edge gestures (two fingers)

Each edge zone is the outer 10% of the trackpad.

| Gesture | Default action |
|---|---|
| Swipe right from the left edge | Open Terminal |
| Swipe down from the top edge | Play/Pause |
| Slide up or down on the left edge | Brightness |
| Slide up or down on the right edge | Volume |

The macOS gesture for Notification Center (two-finger swipe left from the right edge) still works.
A horizontal move on the right edge cancels the volume slide.

### Corner clicks (one finger)

Click, or tap if tap-to-click is on, in a top corner of the trackpad. Each corner zone is 12% × 12% of the trackpad.
Sidl runs the corner's action, and the app under the pointer gets no click.

| Corner | Default action |
|---|---|
| Top-left | Previous track |
| Top-right | Next track |

Clicks with two fingers, and clicks outside the top corners, work as normal.

### Actions

- **Swipes and corner clicks:** Open any app, Play/Pause, Next track, Previous track, Screenshot, Keyboard shortcut, or None.
  - **Screenshot** opens the macOS screenshot toolbar (the same as ⇧⌘5).
  - **Keyboard shortcut** sends a key combination that you record in Settings, for example ⌥⌘T.
- **Slides:** Volume, Brightness, or None.

## Features

- **Settings window:** open it from the menu bar icon. It shows your trackpad at real size, with each gesture where it happens, its trigger zone, and your fingers live. When a gesture runs, it lights up on the drawing. Click a gesture to choose its action, or turn it off.
- **Sensitivity:** one setting for slides (how far you slide for a full change) and one for swipes (how far you swipe before it triggers). Each has levels 1 to 5.
- **On-screen display:** shows the volume or brightness level while you slide.
- **Haptic feedback:** a tick on the trackpad when a swipe fires. You can turn it off in Settings.
- **Scroll blocking:** while an edge gesture is active, the window under the pointer does not scroll.
- **Launch at login.**

## Requirements

- macOS 13 Ventura or later.
- A Mac trackpad: built-in, or a Magic Trackpad.
- For haptic feedback, a Force Touch trackpad: built-in on Macs from 2015 and later, or Magic Trackpad 2 and later. The other features work on any Mac trackpad.
- **Accessibility permission**, for scroll blocking, corner clicks, and the Screenshot and Keyboard shortcut actions. The other gestures and actions work without it.

Brightness changes the display that has the pointer:

- **Built-in display:** always works.
- **Apple displays** (Studio Display, Pro Display XDR, LG UltraFine): should work, but this is not tested yet.
- **Other external monitors:** work over **DDC/CI** on Apple silicon Macs, when only one external monitor is connected and DDC/CI is on in the monitor's own menu. Some HDMI ports, docks, and adapters do not pass DDC/CI through.
- If brightness cannot be changed, the on-screen display shows "Not supported on this display".

## Install

There are no releases yet (see [The story behind Sidl](#the-story-behind-sidl)). To use Sidl now, build it from source.

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
In Sidl Settings, the **Settings** tab shows **Granted** next to Accessibility when the permission is active.

## How it works

Sidl uses private macOS frameworks. That is why it is not on the Mac App Store.

| Part | API |
|---|---|
| Raw finger positions, haptics, trackpad size | `MultitouchSupport.framework` (private), loaded at runtime with `dlopen`; haptics use its `MTActuator` functions |
| Volume | CoreAudio |
| Brightness | `DisplayServices.framework` (private); DDC/CI with `IOAVService` I2C functions (private) for external monitors |
| Play/Pause, next, previous | `MediaRemote.framework` (private) |
| Scroll blocking, corner clicks | One `CGEventTap` on scroll events and left clicks |
| Screenshot, keyboard shortcuts | Key events posted with `CGEvent` |
| Open app, launch at login | `NSWorkspace`, `SMAppService` |

Private APIs can change in any macOS update.

## Known limitations

- Sidl supports two trackpads at the same time, and trackpads that connect after it starts. These are not yet tested with a real Magic Trackpad. Please report problems.
- External monitor brightness (DDC/CI) is not yet tested with a real monitor. It works with one external monitor at a time, only on Apple silicon. Please report problems with your monitor model and how it connects.

## Troubleshooting

- **No gesture works.** Check that the Sidl icon is in the menu bar. If it is, look in the log for an error:
  `log show --last 10m --predicate 'process == "Sidl"' --style compact`
  "failed to load MultitouchSupport" means that a macOS update changed the private framework.
- **Corner clicks, scroll blocking, Screenshot, or Keyboard shortcut do nothing.** These need Accessibility permission. Open Sidl Settings, and look at the **Settings** tab. If Accessibility is not **Granted**, click **Open Settings** and turn on Sidl.
- **The permission stops working after a rebuild.** With ad-hoc signing, each build is a new app for macOS. In **System Settings → Privacy & Security → Accessibility**, remove Sidl with **−**, then add it again. To stop this, use a signing certificate (see [Signing](#signing)).
- **A swipe fires too easily, or not at all.** Change **Swipe sensitivity** in the **Settings** tab. The Gestures tab shows where a swipe must start, and how far it must go.
- **No haptic tick.** Haptics need a Force Touch trackpad, and **Haptic feedback on swipes** must be on. If it still fails, the log shows "haptic failed".
- **Brightness shows "Not supported on this display".** See the brightness notes in [Requirements](#requirements).

## Uninstall

1. In Sidl Settings, turn off **Launch at login**.
2. Click the Sidl icon in the menu bar, then click **Quit Sidl**.
3. Delete `Sidl.app`.
4. Remove the settings and the Accessibility permission:

   ```bash
   defaults delete app.sidl.Sidl
   tccutil reset Accessibility app.sidl.Sidl
   ```

## Project layout

```
Sources/CMultitouch/       C shim that loads MultitouchSupport
Sources/Sidl/              The app: recognizers, router, actions, settings, HUD
Tests/SidlTests/           Unit tests, and Fixtures/ with recorded trackpad frames
scripts/bundle.sh          Builds and signs Sidl.app
scripts/record-touches.sh  Records trackpad frames for a test fixture
DESIGN.md                  Design rules for Settings, the HUD, and haptics
```

## Contributing

See [CONTRIBUTING.md](https://github.com/shresthaoshan/sidl/blob/main/CONTRIBUTING.md) for setup, architecture, tests, and how to send a change.

## License

Sidl is released under the [MIT License](https://github.com/shresthaoshan/sidl/blob/main/LICENSE).
