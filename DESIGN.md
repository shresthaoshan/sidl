# Sidl design

The rules for what Sidl shows and how it feels: the Settings window, the HUD, and the haptics.
When the code and this file disagree, the code is correct. Update this file.

## Principles

- **Show the truth.** The trackpad drawing uses the real sizes from the recognizers. When a size changes in the code, the drawing changes with it.
- **Native first.** Use the system font, system controls, and the accent color. Add a custom look only where a native control cannot show the idea.
- **Quiet.** Feedback is short and fades. Nothing stays on screen that the user did not ask for.

## Settings window

- Opens only from the menu bar menu (**Settings…**, ⌘,). It never opens at launch.
- Two tabs, in a segmented control: **Gestures** and **Settings**.
- Width: the trackpad drawing width + 40 pt. Both tabs use the same width.
- The **Gestures** tab is not a `Form`, because a grouped `Form` limits rows to about 600 pt, which is less than a real-size drawing.
- The **Settings** tab is a grouped `Form`: General, Sensitivity, Permissions.
- Sensitivity uses sliders with five stops, 220 pt wide, labeled Low and High.

## Trackpad drawing

| Item | Value |
|---|---|
| Size | The real size of the default trackpad (`mt_surface_size` and the screen's points per millimeter), at most 80% of the screen width. Fallback: 420 × 262 pt. |
| Color | Aluminum gradient, `#B3BABD` at the top to `#A2AAAD` at the bottom. It stays silver in dark mode, so the drawing always uses the light color scheme. |
| Border | 1 pt, `rgb(0.53, 0.56, 0.58)`. Corner radius 12 pt. |
| Gray text | `white 0.27`, darker than `.secondary`, so it stays readable on silver. |

### Zones

The zone sizes are the same as in `GestureRouter` and `CornerClickDetector`. Change both together.

| Gesture | Zone | How it looks when selected |
|---|---|---|
| Edge swipe | 10% of the trackpad at its edge | A gradient in the swipe direction, from accent 45% to 0, over the zone plus the swipe travel at the current sensitivity |
| Edge slide | 10% of the trackpad at its edge | A meter: accent 12% for the strip, accent 45% up to the level of the last slide. Solid accent 25% before the first slide |
| Corner click | 12% × 12% in the corner | Solid accent 25% |

Every selected zone also has a 3 pt accent border along the trackpad edge, only where the zone touches the edge.

### Marks

- One mark for each gesture: an icon tile (26 pt) and two lines, the action and the gesture name.
- A mark on the left starts at its point, and a mark on the right ends at its point, so the icon faces its edge. The top-edge mark is centered.
- Selected: accent icon tile with a white icon, and a white 35% background.
- Disabled (None): gray text and a faint tile.
- At first, no gesture is selected. A click on the empty trackpad clears the selection.

## Live feedback

| Event | Feedback |
|---|---|
| Finger on the trackpad | A 24 pt dot, accent 70%. Gray while the finger lifts. |
| Swipe or corner click | The mark grows to 112% with a spring (response 0.2 s, damping 0.5), then goes back after 0.18 s. The zone flashes and fades over 0.6 s (ease-out). |
| Swipe only | A 40 pt accent ring grows from the center of the fingers, from 0.3× to 4×, and fades over 0.6 s. |
| Slide | The mark grows to 105% and the zone shows while the slide runs. Both fade 0.3 s after the last slide frame. |

Animations never change the selection.

## HUD

- A capsule at the bottom center of the screen that has the pointer, on every Space, also over full-screen apps.
- The level bar is drawn shapes, not `ProgressView`: the native bar animates to each value, so it trails a fast slide.
- It stays 1.2 s after the last change, then fades over 0.3 s.

## Haptics

- One tick when a swipe fires: `MTActuator` waveform 6. `NSHapticFeedbackManager` has one strength, and it is too weak.
- Slides and corner clicks do not tick. A tick for each 10% of a slide was tried: it was too strong, and it lagged.
- **Haptic feedback on swipes** in Settings turns it off.

## Writing

- Short sentences, sentence case. The menu items are "Settings…" and "Quit Sidl".
- Gesture names say the edge, the direction, and the fingers: "Left-edge swipe right (two fingers)".
