---
name: godot-ios-sim
description: Build and run the game in the iOS Simulator to check a scene visually. Load for manual/visual checks (UI track, any block with a "Manual" line), or when asked to run or screenshot the app.
---

# Running the game in the iOS Simulator

## Build
- `scripts/ios_sim` exports the iOS Xcode project, merges the local arm64 simulator library into it, builds it, and prints the `.app` path. `scripts/ios_sim --run` also installs and launches it on the booted simulator (for a developer without the simulator tool).
- It needs `~/.local/share/godot-ios-sim/<godot version>/libgodot.ios.template_debug.arm64.simulator.a`. If it's missing (e.g. after a Godot upgrade), the script prints the rebuild steps; the source lives in `~/dev/godot-<version>`. The rebuild takes about 20 minutes: run it in the background.

## Drive
1. Boot a simulator if none is booted (`xcrun simctl list devices booted`; default `iPhone 17 Pro`), then call the simulator tool's `attach` **before** building so the developer can watch.
2. Run `scripts/ios_sim`, then the simulator tool's `launch` with the printed app path.
3. Godot draws everything itself, so `inspect` sees no buttons or labels. Take a `screenshot`, read positions from it, and `tap` in device points (the launch result gives the point size; screenshot pixels ÷ ~2.29 on an iPhone 17 Pro).
   - Godot ignores instant taps: pass `duration: 0.15`.
   - The first frames after launch are Godot's splash; wait a few seconds.
   - A screenshot right after a tap can catch the button mid-press; take another before judging the result.
4. Walk through the block's manual-check list, screenshot each step, and report what you saw.

## Limits
- The simulator renders with Godot's OpenGL fallback (Compatibility), not Metal. Layout, text and input match the phone; shaders and colour can differ. The block's on-device check still needs the developer's phone.
- A visual bug found here still gets a failing view-model or core test first (see `godot-testing`).
