# Live drone (Tello) on Vision Pro

## Fly
1. Power the Tello. On Vision Pro, Settings > Wi-Fi > join TELLO-XXXXXX (no internet while joined).
2. Open DroneArena. Home > Live drone. The simulator space closes; the live-drone space and feed window open.
3. Feed window: Connect (sends `command`, then `streamon`; video appears from UDP 11111).
4. Toggle Arm, then Take off. Fly with the hand thumb sticks, Mode 2: left = throttle (up/down) + yaw, right = pitch + roll.
5. Land, or Exit (lands, `streamoff`, disconnects, returns to the main window). Kill = `emergency` (motors stop, drone falls).

## Safety
Stale stick input over 0.4 s sends hover. Speed slider caps each rc axis (default 60/100). Closing the feed window lands.
Invert pitch toggle exists because the forward sign is not yet verified on hardware.

## Code
- `DroneArena-vision/HelicopterGame/DroneLink/` SPM package, no app imports.
  `TelloLink` (commands, rc loop, telemetry), `TelloVideoStream` (UDP 11111, H.264 NAL parse, AVSampleBufferDisplayLayer),
  `TelloVideoView`, `DroneSticks`, `H264NALParser`. Tests: `swift test --package-path .../DroneLink` (9 pass).
- `HelicopterGame/RealDrone/` app glue: `RealDroneBridge` (DualThumbController -> DroneSticks, only while active),
  `LiveDroneMode` (space + enter/exit), `LiveDroneFeedView` (feed, HUD, controls).
- Spec: `notes/SPEC-live-drone.md`. Agent log: `notes/HANDOFF.md`.

## Not verified
No run on headset or real Tello. Video decode path, pitch sign, visualizer in live space, window sequencing.
Frames display one NAL late (parser waits for next start code).
