# Contributing to Sidl

Thank you for your help. This guide explains how to set up the project, how the code is organized, and how to send a change.

## Before you start

- For a bug fix or a small change, you can open a pull request directly.
- For a new gesture, a new action, or a larger change, open an issue first. Then we can agree on the design before you write code.
- Do not add a new dependency without discussion in an issue. Sidl has no dependencies, and we want to keep it that way.

## Set up

You need macOS 13 or later, a trackpad, and Xcode or the Xcode Command Line Tools (Swift 5.9 or later).

```bash
git clone https://github.com/shresthaoshan/sidl.git
cd sidl
swift build
swift test
scripts/bundle.sh
open Sidl.app
```

Scroll blocking needs Accessibility permission, and macOS links that permission to the code signature.
To keep it across rebuilds, create a self-signed code signing certificate. The [README](README.md#signing) has the steps.

`swift run` also works for quick checks, but without the `.app` bundle macOS gives the permission to your terminal, not to Sidl.

## How the code works

```
MultitouchSupport ──frames + device ID──▶ TouchMonitor ──▶ TouchHub ──▶ Output
   (touch thread)                                          one GestureRouter     │
                                                           + CornerClickDetector ▼
                                                           for each trackpad   main thread: Actions, HUD
```

1. `CMultitouch` (C) loads the private `MultitouchSupport` framework and sends each frame of finger positions, with the ID of the trackpad that sent it, to `TouchMonitor`.
2. `TouchMonitor` passes the frame to `TouchHub` **on the touch thread**, under one lock. This sets the scroll block before the scroll events for the same movement arrive. The lock also makes sure that frames from two trackpads are never handled at the same time.
3. `TouchHub` keeps a `GestureRouter` and a `CornerClickDetector` for each trackpad, so frames from two trackpads never mix.
4. `GestureRouter` runs every recognizer on each frame, and uses the current `Mapping` to decide which actions to send.
   - `EdgeSwipeRecognizer`: a two-finger swipe in from the left or top edge. It fires once.
   - `EdgeSlideRecognizer`: a two-finger vertical slide on the left or right edge. It reports travel on each frame.
5. `CornerClickDetector` tracks a single finger in a top corner. It keeps the corner for 0.3 seconds after the finger lifts, because tap-to-click sends the click after the lift.
6. `TouchMonitor` sends the actions to the main thread, where `Actions`, `Volume`, `Brightness`, and `HUD` do the work.
7. `InputFilter` is one `CGEventTap` on the main thread. It reads its state from `TouchMonitor`:
   - **Scroll events:** it drops them while a gesture on any trackpad owns the fingers.
   - **Left clicks:** on a mouse-down, it asks for the corner of a single finger on any trackpad. If the corner has an action, `ClickFilter` drops the mouse-down, the drags, and the mouse-up, and the action runs.
8. `DeviceWatcher` tells `TouchMonitor` when a trackpad connects or disconnects (an IOKit notification for `AppleMultitouchDevice`), and when the Mac wakes. `TouchMonitor` then reads the device list again, after 1 second, and clears `TouchHub`.
9. `SettingsStore` saves the `Mapping` in `UserDefaults`. It also keeps a lock-protected copy for the touch thread.

### Rules

- Recognizers, `GestureRouter`, `CornerClickDetector`, `ClickFilter`, and `TouchHub` are plain structs with no system calls. Keep them that way, so tests can check them with fake frames.
- Gesture state belongs to one trackpad. Keep it in `TouchHub`, never in a single shared value.
- The event tap callback must return fast, or macOS turns the tap off. Run actions with `DispatchQueue.main.async`, not inside the callback.
- Code that runs on the touch thread must not touch UI or `@Published` values. Use `DispatchQueue.main.async` for that.
- Private APIs are loaded with `dlopen` and `dlsym`, and the code must work when a symbol is missing. Never crash because a private API changed.

## Add a new action or gesture

For a new **action** (for example, Mute):

1. Add a case to `DiscreteAction` or `ContinuousAction` in `Sources/Sidl/Settings.swift`, with a `title`.
2. Handle the case in `Actions.perform` or `Actions.adjust`.
3. Add the case to the picker in `SettingsView.swift`. A discrete action is then available for swipes and corner clicks.
4. Add tests, including a test that values saved by older versions still decode.

For a new **gesture**:

1. Add a recognizer, or reuse one with new parameters.
2. Add a field to `Mapping` with a default value, and add its `load` and `store` lines in `SettingsStore` (key `gesture.<name>`).
3. Run the recognizer in `GestureRouter`. Decide how it interacts with the other gestures in the same zone, and include it in `claimsScroll`.
4. Add a row in `SettingsView.swift`.
5. Add tests for the recognizer, the router, and the store.

A new setting must not break existing users. When a stored value is missing or cannot be read, `SettingsStore` must use the default.

## Tests

- `swift test` must pass before you send a pull request.
- Add tests for each change in a recognizer, the router, the settings, or the HUD.
- For a bug fix, add a test that fails before the fix.
- Tests must not change real system state. For example, use a fake `LoginItemService`, and do not change the real volume.

### Test on a real trackpad

Unit tests cannot check how a gesture feels. Before you send a gesture change:

1. Run `scripts/bundle.sh && open Sidl.app`.
2. Open Sidl Settings. The **Gestures** tab shows each finger on the trackpad drawing, and the trigger zone of the selected gesture.
   When a gesture runs, its mark pulses and its zone flashes, so you can see which gesture Sidl recognized.
3. Try the gesture, and also try normal scrolling and the macOS gestures near the same edge (for example, Notification Center on the right edge).

In the pull request, write which Mac, which trackpad, and which macOS version you used.

### Record a test fixture

`Tests/SidlTests/Fixtures/` has real trackpad frames, recorded on a real trackpad. `FixtureTests` replays each file through the recognizers and checks which gestures fire. Synthetic frames in the other tests cannot show how real fingers move, so these files catch false triggers.

To record a new file:

1. Run `scripts/bundle.sh`.
2. Run `scripts/record-touches.sh <name>`, for example `scripts/record-touches.sh right-edge-swipe-left`. The script quits Sidl and starts it again with recording on.
3. Do only the gesture that the file is for. Sidl still runs the actions while it records.
4. Press Control-C, then run `open Sidl.app`.
5. Add the file and what it must fire to the table in `FixtureTests.swift`.

## Code style

- For the Settings window, the HUD, and the haptics, follow [DESIGN.md](DESIGN.md).
- Match the code around your change: names, comment density, and idioms.
- Keep changes small. Prefer the standard library and system frameworks to new code.
- Write comments that explain **why**, not what.
- Swift 5 language mode, and no compiler warnings.

## AI-assisted contributions

You can use AI tools, such as coding assistants, to write code, tests, or documentation. Sidl itself was built with AI assistance.

- **Disclose it.** In the pull request, say which parts an AI tool wrote or changed.
- **You are responsible for the change.** Read, understand, and test every line before you send it. You must be able to explain the change in review.
- **Test on real hardware.** An AI tool cannot feel a gesture. Gesture changes must be tested on a real trackpad, as described in [Test on a real trackpad](#test-on-a-real-trackpad).
- **No unreviewed output.** Pull requests and bug reports that look like unreviewed AI output are closed without review.

## Commits and pull requests

- One change for each pull request.
- Commit subject: a short sentence in the imperative mood, for example "Add mute action". Use the body for details.
- In the pull request, describe what changed, why, and how you tested it.

## Report a bug

Open an issue with:

- Your macOS version and Mac model.
- The trackpad: built-in or Magic Trackpad, and whether more than one is connected.
- The steps to reproduce, what you expected, and what happened.
- Whether the **Settings** tab in Sidl Settings shows Accessibility as **Granted**.

## License

Sidl uses the [MIT License](LICENSE). When you send a pull request, you agree that your contribution is released under the same license.
