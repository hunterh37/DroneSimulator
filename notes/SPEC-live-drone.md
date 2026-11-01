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

## Stage 3. Altitude ceiling + e2e tests
Ceiling 10 ft = 305 cm above takeoff (Tello state `h`, cm). Fields: `tof` cm also available.
- `SafetyGovernor` (pure struct, DroneLink): input DroneSticks + height cm + telemetry age -> output DroneSticks + `SafetyStatus`.
  - h >= 240 cm (8 ft): status `.warning`, throttle up scaled linearly to 0 at 290 cm.
  - h >= 290 cm: throttle up clamped to 0 (`.ceiling`).
  - h > 305 cm: throttle forced to -0.3 (descend) until below 290 (`.over`).
  - telemetry older than 1 s while flying: throttle up clamped to 0, status `.noTelemetry`.
  - Configurable `ceilingCM` (default 305).
- TelloLink applies the governor every rc tick before sending; exposes `safety: SafetyStatus`. Takeoff blocked if battery < 15 percent.
- UI: LiveDroneFeedView shows a colored banner for warning/ceiling/over/noTelemetry with height in ft.
- E2E tests (swift test, macOS): `MockTello` UDP server on 127.0.0.1 (configurable cmd and state ports in TelloLink init) replies `ok`, records received commands, pushes state packets. Cases: connect sends `command`; takeoff then full-up sticks at h:100 -> rc c > 0; at h:295 -> rc c == 0; at h:320 -> rc c < 0; stale state -> c <= 0; stale sticks -> rc 0 0 0 0; land sends `land`; low battery blocks takeoff.

## Stage 4. Connection flow + debug view
Tello has no Bluetooth. Link is the drone's own Wi-Fi AP (SSID TELLO-XXXXXX, open), UDP only.
- DroneLink `TelloConnector` (@MainActor @Observable) state machine: idle -> joiningWiFi -> handshaking (`command` until `ok`, retry 3x 500 ms) -> ready | failed(reason, hint).
  - Join: `NEHotspotConfiguration(ssidPrefix: "TELLO-")`, joinOnce false, via NEHotspotConfigurationManager when `#if canImport(NetworkExtension)` and available on visionOS; app target gets entitlement `com.apple.developer.networking.HotspotConfiguration`. If unavailable or denied: fall back to "Open Settings > Wi-Fi, join TELLO-..." and auto-poll handshake every 1 s for 60 s so it connects the moment the user returns.
  - Auto reconnect on link loss while not flying; while flying, failsafe is the drone's own 15 s auto-land.
  - Failure hints (one line each): drone off, wrong Wi-Fi, no reply, battery low.
- UI: one big primary button whose label tracks state (CONNECT / JOINING TELLO WI-FI / HANDSHAKE / READY). 3-dot step indicator (Wi-Fi, Link, Video). No other text unless failed.
- Debug view (gear > Debug, toggle `showDebug`): scrolling packet log (last 200, tx/rx, timestamp ms, text), state fields table (all keys from 8890), cmd RTT ms, state packet rate Hz, video fps, NAL counts by type, bytes/s, current SSID if readable, ports. Copy-log button. Monochrome per notes/design.
- Tests: connector state machine against MockTello (handshake retry, no reply -> failed, auto reconnect). Packet log ring buffer unit test.
