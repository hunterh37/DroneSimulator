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

## Return to home
Return button, shown only with Debug on until flight-tested (`notes/PLAN-return-to-home.md`, Task 4). Requires Arm. Position is integrated from `vgx`, `vgy`, `yaw` since takeoff (`DeadReckoner`), so it drifts: the drone lands near home, not on it. It flies a straight line at current height with rc capped at 30, and it has no obstacle sensing, so keep the path clear.
Ends with a landing on arrival (within 50 cm of the estimate), after 45 s, or when telemetry is over 1 s old. Any stick above 0.2 cancels and hands back control. Land, Kill and disarm also end it. A telemetry gap earlier in the flight loses home and disables the button until the next takeoff. Not available after Wi-Fi loss, since no commands can reach the drone.

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
Return to home: `vgx`, `vgy`, `yaw` frame and signs (`VelocityCalibration` holds assumed defaults), and whether the Tello holds its last `rc` after Wi-Fi loss.
