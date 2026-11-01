# Context (DroneSimulator)

Repo: github.com/hunterh37/DroneSimulator (public). App root: `DroneArena-vision/HelicopterGame`.
Project `DroneArena.xcodeproj`, scheme `DroneArena`, visionOS target uses file-system synchronized group `HelicopterGame/` (new .swift files auto-included).
Rules: see `/Users/hunter/Dev/DroneSimulator/CLAUDE.md` (no em dashes, no emojis, files < 500 LOC, no git stash/branches).

Build (wrap in buildq, max 3 min):
`cd DroneArena-vision/HelicopterGame && ~/.claude/scripts/buildq -- xcodebuild -project DroneArena.xcodeproj -scheme DroneArena -destination 'generic/platform=visionOS Simulator' -derivedDataPath /tmp/dd-dronelink build 2>&1 | grep -E "error:|BUILD" | head -20`
Package tests: `~/.claude/scripts/buildq -- swift test --package-path DroneArena-vision/HelicopterGame/DroneLink 2>&1 | grep -E "error:|passed|failed" | head`

## File map
- `DroneLink/` local SPM package (visionOS 2, iOS 18, macOS 15). Linked to visionOS app target. NO app imports allowed.
  - `Sources/DroneLink/DroneSticks.swift` Mode 2 sticks -> `rc a b c d`.
  - `Sources/DroneLink/TelloLink.swift` @MainActor @Observable. UDP 192.168.10.1:8889 cmd, 8890 state. connect/takeoff/land/emergency/update(sticks). 20 Hz rc loop, stale failsafe.
  - `Tests/DroneLinkTests/` Swift Testing.
- `HelicopterGame/RealDrone/RealDroneBridge.swift` samples `DualThumbController.shared` (left=throttle y + yaw x, right=pitch y + roll x) at 30 Hz -> `link.update`.
- `HelicopterGame/RealDrone/RealDronePanel.swift` window id `real-drone`.
- `HelicopterGame/HelicopterGameApp.swift` scenes: MainWindow, real-drone, joystick-help, ImmersiveSpace(appModel.immersiveSpaceID).
- `HelicopterGame/UI/DroneMainMenuView.swift` home overlay button "Real drone".
- `HelicopterGame/AppModel.swift` wires VirtualJoystickBridge -> DualThumbController.

## Tello facts
- Video: send `streamon`; raw H.264 Annex B over UDP to headset port 11111, 960x720 ~30fps, NALs split across ~1460 byte datagrams. SPS(7)/PPS(8) repeat before IDR(5).
- Tello auto-lands after 15 s with no command.
