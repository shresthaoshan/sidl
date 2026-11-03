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
MultitouchSupport ──frames──▶ TouchMonitor ──▶ GestureRouter ──▶ Output
   (touch thread)                                   │              │
                                       recognizers + Mapping       ▼
                                                           main thread: Actions, HUD
```

1. `CMultitouch` (C) loads the private `MultitouchSupport` framework and sends each frame of finger positions to `TouchMonitor`.
2. `TouchMonitor` runs `GestureRouter` **on the touch thread**. This sets the scroll block before the scroll events for the same movement arrive.
3. `GestureRouter` runs every recognizer on each frame, and uses the current `Mapping` to decide which actions to send.
   - `EdgeSwipeRecognizer`: a two-finger swipe in from the left or top edge. It fires once.
   - `EdgeSlideRecognizer`: a two-finger vertical slide on the left or right edge. It reports travel on each frame.
4. `TouchMonitor` sends the actions to the main thread, where `Actions`, `Volume`, `Brightness`, and `HUD` do the work.
5. `ScrollBlocker` is a `CGEventTap`. It drops scroll events while a gesture owns the fingers.
6. `SettingsStore` saves the `Mapping` in `UserDefaults`. It also keeps a lock-protected copy for the touch thread.

### Rules

- Recognizers and `GestureRouter` are plain structs with no system calls. Keep them that way, so tests can check them with fake frames.
- Code that runs on the touch thread must not touch UI or `@Published` values. Use `DispatchQueue.main.async` for that.
- Private APIs are loaded with `dlopen` and `dlsym`, and the code must work when a symbol is missing. Never crash because a private API changed.

## Add a new action or gesture

For a new **action** (for example, Mute):

1. Add a case to `DiscreteAction` or `ContinuousAction` in `Sources/Sidl/Settings.swift`, with a `title`.
2. Handle the case in `Actions.perform` or `Actions.adjust`.
3. Add the case to the picker in `SettingsView.swift`.
4. Add tests.

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
2. Open the menu bar panel. It shows each finger's position and state, and the last gesture.
3. Try the gesture, and also try normal scrolling and the macOS gestures near the same edge (for example, Notification Center on the right edge).

In the pull request, write which Mac, which trackpad, and which macOS version you used.

## Code style

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
- What the menu bar panel shows: `Scroll blocking: on` or `off`, the device count, and the last gesture.

## License

Sidl uses the [MIT License](LICENSE). When you send a pull request, you agree that your contribution is released under the same license.
