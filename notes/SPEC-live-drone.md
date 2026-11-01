# Live drone mode spec

Goal: a separate Live Drone mode on Vision Pro. Tello camera feed streams into a window in front of the user; the user flies the real drone with the hand thumb joysticks. The simulator stays unchanged and independent.

## Stage 1. DroneLink video (package only)
- `TelloVideoStream` (new files in `DroneLink/Sources/DroneLink/`): NWListener UDP 11111, reassemble Annex B stream, split NAL units, build CMVideoFormatDescription from SPS/PPS, wrap AVCC samples as CMSampleBuffer, enqueue to an `AVSampleBufferDisplayLayer` (owned by the stream, exposed as `displayLayer`). Track `fps`, `framesDecoded`, `lastFrameAt`.
- `TelloLink.startVideo()` sends `streamon`, `stopVideo()` sends `streamoff`. `TelloLink.video` holds the stream.
- `H264NALParser` pure struct, unit tested: split start codes (3 and 4 byte), across chunk boundaries, type extraction.
- SwiftUI: `TelloVideoView` (UIViewRepresentable hosting the display layer), public in the package.
- Done check: package tests pass; app build succeeds.

## Stage 2. Live Drone mode (app)
- New files in `HelicopterGame/RealDrone/` only, plus minimal hooks in `HelicopterGameApp.swift` and `DroneMainMenuView.swift`.
- `ImmersiveSpace(id: "live-drone")` (mixed): thumb controller visualizers + hand input only; no sim drone, no course. Starts DualThumbController.
- Window `live-drone-feed`: `TelloVideoView` 16:9 large, HUD (battery, height, state, rc out, fps), controls (Connect, Arm, Take off, Land, Kill, speed slider, invert pitch).
- Home button "Live drone" replaces "Real drone": dismisses main immersive space if open, opens live-drone space + feed window.
- Exit: land, disarm, stopVideo, disconnect, dismiss space, reopen MainWindow.
- RealDroneBridge only sends while live mode is active.
- Done check: app build succeeds.

## Safety
Arm is explicit. Stale input (0.4 s) -> hover. Leaving mode -> land. Kill button = `emergency`.
