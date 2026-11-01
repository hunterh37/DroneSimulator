
## Stage 1 done
DroneLink video, package only. Tests: 9 pass. App build succeeds.
- `TelloLink.video: TelloVideoStream`, `startVideo()` (listener on 11111 + `streamon`), `stopVideo()` (`streamoff` + stop)
- `@MainActor @Observable TelloVideoStream`: `init(port: UInt16 = 11111)`, `start()`, `stop()`, `ingest(_ data: Data)`, `displayLayer: AVSampleBufferDisplayLayer`, `fps: Double`, `framesDecoded: Int`, `lastFrameAt: Date?`, `isListening: Bool`
- `TelloVideoView(stream: TelloVideoStream)`: UIViewRepresentable, UIKit only
- `NALUnit(bytes:)` with `type`; `H264NALParser`: `feed(_ [UInt8]) -> [NALUnit]`, `flush() -> [NALUnit]`

## Stage 2 done
Live Drone mode in app. App build succeeds. Not run on device or simulator.
Files (DroneArena-vision/HelicopterGame/HelicopterGame/):
- RealDrone/LiveDroneMode.swift (enter/exit flow, LiveDroneImmersiveView with thumb visualizers + DualThumbController.start)
- RealDrone/LiveDroneFeedView.swift (window live-drone-feed: video, HUD, Connect/Arm/Take off/Land/Kill/Exit, speed, invert pitch)
- RealDrone/RealDroneBridge.swift (isActive flag; sample sends only when active; stop disarms, lands, streamoff)
- RealDrone/RealDronePanel.swift (deleted)
- HelicopterGameApp.swift (real-drone window replaced by live-drone-feed; ImmersiveSpace "live-drone")
- UI/DroneMainMenuView.swift ("Real drone" button replaced by "Live drone")
User flow: Home > Live drone (closes sim space if open, opens live-drone space + feed window, closes MainWindow) > Connect (bridge.start + streamon) > Arm > Take off > fly with hand sticks > Exit (land, stop, close space and feed, reopen MainWindow).

## Stage 3 done
SafetyGovernor + TelloLink (statePort init arg, stateAt, safety, takeoffBlockedReason, governor) + banner in LiveDroneFeedView. Tests: 30 pass (SafetyGovernorTests, TelloE2ETests with MockTello on 127.0.0.1). App build succeeds. Not flown on hardware.

## Design pass done
LiveTheme, LiveHUD, LiveAltitudeTape, LiveControls, LiveDroneFeedView split; home button restyled. Sim + device builds succeed. Not run on device.

## Stage 4 done
TelloConnector (idle, joiningWiFi, handshaking, ready, failed), PacketLog (200 ring), TelloLink.insist (4 tries, 0.4 s, ok only; used for command, streamon, takeoff, land; commandFailure shown in safety strip), stats (stateRate, cmdRTT, stateFields, nalCounts, bytesPerSecond). App: LiveConnectButton, LiveDebugView, gear Debug toggle. Tests: 41 pass. Sim + device builds succeed. No entitlements file for the target, so no NEHotspotConfiguration join; manual join with 1 s poll. Not run on hardware.

## Return home done
DeadReckoner + VelocityCalibration + ReturnStatus (DroneLink/DeadReckoner.swift). TelloLink: returnHome, canReturnHome, returnStatus, reckoner, returnTimeout, returnSpeedLimit. App: Return chip behind Debug, safety strip text, Home row in debug view. Tests: 61 pass. Calibration is assumed, not measured. Not flown. Task 4 of notes/PLAN-return-to-home.md is the remaining hardware gate.

## Pinch stick package done
`DroneArena-vision/HelicopterGame/DicyaninPinchStick/` (product `DicyaninPinchStick`, targets PinchStickCore, PinchStick). 10 core tests pass; visionOS build succeeds. Not yet linked to the app.
Public API (import PinchStick):
- `@MainActor final class PinchStickController`: `init()`, `var onOutput: ((PinchStickOutput) -> Void)?`, `var config: PinchStickConfig`, `var visualsEnabled: Bool`, `func start(rootEntity: Entity) async`, `func stop()`.
- `struct PinchStickOutput { left, right: SIMD2<Float>; leftHeld, rightHeld: Bool }`. Left: x yaw, y throttle. Right: x roll, y pitch (forward positive). Fires on change only; zero on release, tracking loss, stop.
- Integration: root entity at immersive space origin, ImmersiveSpace open, NSHandsTrackingUsageDescription set. Route onOutput to `DualThumbController.shared.setVirtualJoystickInput`; set old thumb input and visualizer off.
