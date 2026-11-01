# Live drone (Tello) on Vision Pro

## Fly
1. Power the Tello. On Vision Pro, Settings > Wi-Fi > join TELLO-XXXXXX (no internet while joined).
2. Open DroneArena. Home > Live drone. The simulator space closes; the live-drone space and feed window open.
3. Feed window: press CONNECT. Wi-Fi auto-join is not available (no entitlements file), so the button shows SETTINGS > WI-FI > TELLO-. Join the drone Wi-Fi in Settings and return; the app polls `command` every 1 s for 60 s, then starts `streamon`. Dots show Wi-Fi, Link, Video. Gear > Debug opens the packet log and stats.
4. Toggle Arm, then Take off. Fly with the hand thumb sticks, Mode 2: left = throttle (up/down) + yaw, right = pitch + roll.
5. Land, or Exit (lands, `streamoff`, disconnects, returns to the main window). Kill = `emergency` (motors stop, drone falls).

## Safety
Stale stick input over 0.4 s sends hover. Speed slider caps each rc axis (default 60/100). Closing the feed window lands.
Altitude ceiling 10 ft (305 cm, Tello `h`): upward throttle tapers from 240 cm to 0 at 290 cm, is clamped to 0 above 290 cm, and is replaced by a -0.3 descent above 305 cm until height is below 290 cm. Telemetry older than 1 s while flying clamps upward throttle to 0. Takeoff is refused below 15 percent battery. The feed window shows a banner for each state. Logic: `SafetyGovernor`, applied in `TelloLink` each rc tick.
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
