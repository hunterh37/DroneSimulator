# Pinch stick (replaces thumb joystick)

Problem: old DicyaninThumbController reads thumb position relative to index finger. It never rests at zero and drifts. Visual is legacy.

## Input model
- Per hand. Pinch thumb tip to index tip (< 1.5 cm engage, > 2.5 cm release, hysteresis) grabs the stick. Origin = pinch point at grab.
- Stick vector = pinch point minus origin, in a frame yawed to the user's head at grab time (so forward is forward).
- Release pinch: output snaps to exactly zero, same frame. Losing hand tracking = release.
- Deadzone 1.2 cm radial, full throw 6 cm, response curve expo 0.35, output clamped to unit circle.
- One Euro filter on the pinch point (minCutoff 1.0, beta 0.02) before mapping. No filter on release.
- Left hand: x = yaw, y (up) = throttle. Right hand: x = roll, -z (forward) = pitch.
- Recenter on regrab. No recenter while held.

## Visual (monochrome, notes/design/LIVE_DRONE_DESIGN.md)
- Shown only while held, at the grab origin, billboarded to head yaw.
- Base: thin white ring r 6 cm (throw), hairline ring r 1.2 cm (deadzone), both 35 percent white.
- Knob: 1.4 cm solid white sphere at the clamped pinch point; tether line origin to knob, 60 percent white.
- Right hand ring lies flat (horizontal plane, pitch/roll); left hand ring stands vertical (throttle/yaw).
- Knob turns full white and ring brightens when outside deadzone; 120 ms fade in/out. No other colors.
- RealityKit ECS: PinchStickComponent + PinchStickSystem; pre-built entities, no per-frame allocation.

## 2D fallback
- In the live drone feed window: two on-screen sticks (drag circles) bottom-left and bottom-right, same mapping, release = zero. Used in Simulator and as backup.

## Package
`DicyaninPinchStick` local SPM at `DroneArena-vision/HelicopterGame/DicyaninPinchStick/`:
- `PinchStickCore` (pure Swift, macOS testable): state machine, hysteresis, filter, deadzone/expo mapping.
- `PinchStick` (visionOS): ARKit HandTrackingProvider reader, RealityKit visual, `PinchStickOutput { left: SIMD2<Float>, right: SIMD2<Float>, leftHeld, rightHeld }` callback.
- App routes output to `DualThumbController.shared.setVirtualJoystickInput` (sim and live drone share it) and disables the old thumb hand input + visualizer.
