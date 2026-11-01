# Return-to-Home Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One button in Live Drone mode that flies the Tello back toward its takeoff point at low speed and lands it.

**Architecture:** A pure `DeadReckoner` struct integrates `vgx`, `vgy` and `yaw` from the 8890 state packets into a position relative to takeoff, and turns that position into sticks that point home. `TelloLink.tick` sends those sticks through the existing `SafetyGovernor` while a return is active. The button stays behind the Debug toggle until a hardware flight passes.

**Tech Stack:** Swift 6, Network, Swift Testing, `MockTello`, SwiftUI (visionOS).

**Spec:** No separate spec. The Decisions section below is the spec.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Flight method | Closed-loop `rc` sticks | `go x y z` blocks, skips the governor, cannot be taken over by the sticks, and a retried `go` would move twice |
| Path | Straight line at current height, no yaw | Least code, and no climbing near the 10 ft ceiling |
| Speed | rc capped at `min(speedLimit, 30)` | Odometry is rough and there is no obstacle sensing |
| Arrival | Within 50 cm of estimated home, then `land` | Estimate is not precise enough for less |
| Timeout | 45 s, then `land` in place | Bounds a return that never converges |
| Telemetry lost | Over 1 s: `land` in place | Position cannot be trusted without packets |
| Pilot takeover | Any axis above 0.2 ends the return and hovers under stick control | Pilot always wins |
| Disarm, Land, Kill | End the return | Existing controls keep their meaning |
| Trigger | Button only | See Not building |

## Known unknowns

- `vgx` and `vgy` are dm/s per the [RoboMaster TT manual](https://manuals.online/ryze/drone/robomaster-tt/user-manual/19vef). The older SDK docs give no unit.
- No source states whether they are body or world frame, their sign, or the sign of `yaw`. Task 4 measures all of this and `VelocityCalibration` holds the result.
- Odometry from these fields [accumulates error quickly](https://tellopilots.com/threads/tello-localization-odometry.6012/). The drone lands near home, not on it.
- Whether the Tello holds the last `rc` values after Wi-Fi drops is not confirmed. If it does, a link loss mid-return could keep it moving until the 15 s auto-land. Run E only tests the hover case, because testing the moving case risks a crash.

## Not building

- Return on Wi-Fi loss: no link means no commands. The Tello's own 15 s auto-land already covers it.
- Low-battery auto-return, facing home in flight, obstacle avoidance, drift correction. Add after Task 4 if the flights justify them.

## Global Constraints

- Never create branches, worktrees or `git stash`. Commit on `main`.
- No em dashes or emojis anywhere. Files under 500 LOC.
- `DroneLink` has no app imports.
- Xcode is at `~/Downloads/Xcode.app` (27.2, visionOS 27.2 SDK) and is not the active developer directory. The active Command Line Tools `swift test` crashes in dyld, so run `export DEVELOPER_DIR=/Users/zackhanna/Downloads/Xcode.app/Contents/Developer` first in every shell. `~/.claude/scripts/buildq` from `notes/CONTEXT.md` does not exist on this machine, so the commands here omit it.
- Paths are relative to the repo root. Run commands from `DroneArena-vision/HelicopterGame`.

Test command: `swift test --package-path DroneLink 2>&1 | grep -E "error:|Test run|failed"` (baseline: 41 tests pass)

App build precondition: the Xcode project references a local package at `../../../ImmersiveTesting`, which resolves to `/Users/zackhanna/Desktop/Provision/ImmersiveTesting` and is missing, so the app build currently fails at package resolution. It is public at `github.com/hunterh37/ImmersiveTesting`. Cloning it there is outside this repo, so the owner must do it or approve it. Tasks 1 and 2 do not need it. Tasks 3 and 4 do.

App build command: `xcodebuild -project DroneArena.xcodeproj -scheme DroneArena -destination 'generic/platform=visionOS Simulator' -derivedDataPath /tmp/dd-dronelink build 2>&1 | grep -E "error:|BUILD"`

## Review Focus

1. Pilot grabs the sticks mid-return: return ends at once, drone stays flying, no `land`. Pinned in Task 2 `pilotTakesOver`.
2. Telemetry stops mid-return: lands in place rather than flying blind. Pinned in Task 2 `telemetryLossLands`.
3. Kill, Land or disarm mid-return: no return sticks go out afterward. Pinned in Task 2 `killEndsReturn`, `disarmEndsReturn`.
4. A telemetry gap earlier in the flight: home is unknown, so the button refuses. Pinned in Task 2 `gapRefusesReturn`.
5. Return while over the ceiling or with speed set to 100: governor still descends and rc stays within 30. Pinned in Task 2 `returnObeysCeilingAndCap`.

---

### Task 1: DeadReckoner

**Files:**
- Create: `DroneArena-vision/HelicopterGame/DroneLink/Sources/DroneLink/DeadReckoner.swift`
- Test: `DroneArena-vision/HelicopterGame/DroneLink/Tests/DroneLinkTests/DeadReckonerTests.swift`

**Interfaces:**
- Produces:
  - `public struct VelocityCalibration: Equatable, Sendable` with `var bodyFrame = true`, `var swapAxes = false`, `var xSign = 1.0`, `var ySign = 1.0`, `var yawSign = 1.0`, `var cmPerUnit = 10.0`, and a public memberwise-style `init` with those defaults.
  - `public struct DeadReckoner: Equatable, Sendable` with `var calibration`, `private(set) var xCM: Double`, `private(set) var yCM: Double`, `private(set) var isValid: Bool`, `static let maxGap: TimeInterval = 1`, `static let arriveCM = 50.0`.
  - `mutating func add(vgx: Int, vgy: Int, yaw: Int, at: Date)`
  - `mutating func reset()` clears position and validity, keeps `calibration`.
  - `func homeSticks(yaw: Int) -> DroneSticks?` returns nil once within `arriveCM`.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import DroneLink

struct DeadReckonerTests {
    let t0 = Date(timeIntervalSince1970: 1000)
    func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }

    func moved(_ c: VelocityCalibration = .init(), vgx: Int = 10, vgy: Int = 0, yaw: Int = 0) -> DeadReckoner {
        var d = DeadReckoner(); d.calibration = c
        d.add(vgx: vgx, vgy: vgy, yaw: yaw, at: t0)
        d.add(vgx: vgx, vgy: vgy, yaw: yaw, at: t0.addingTimeInterval(1))
        return d
    }

    @Test func firstSampleDoesNotMove() {
        var d = DeadReckoner(); d.add(vgx: 10, vgy: 10, yaw: 0, at: t0)
        #expect(d.xCM == 0 && d.yCM == 0)
    }
    @Test func integratesForward() { let d = moved(); #expect(near(d.xCM, 100) && near(d.yCM, 0)) }
    @Test func bodyFrameRotatesByYaw() { let d = moved(yaw: 90); #expect(near(d.xCM, 0) && near(d.yCM, 100)) }
    @Test func worldFrameIgnoresYaw() {
        let d = moved(.init(bodyFrame: false), yaw: 90); #expect(near(d.xCM, 100) && near(d.yCM, 0))
    }
    @Test func signAndSwapApply() {
        #expect(near(moved(.init(xSign: -1)).xCM, -100))
        #expect(near(moved(.init(swapAxes: true)).yCM, 100))
    }
    @Test func gapInvalidatesUntilReset() {
        var d = moved()
        d.add(vgx: 10, vgy: 0, yaw: 0, at: t0.addingTimeInterval(2.5))
        #expect(!d.isValid && near(d.xCM, 100))
        d.add(vgx: 10, vgy: 0, yaw: 0, at: t0.addingTimeInterval(2.6))
        #expect(!d.isValid)
        d.reset()
        #expect(d.isValid && d.xCM == 0)
    }
    @Test func sticksPointHome() throws {
        let s = try #require(moved().homeSticks(yaw: 0))
        #expect(s.pitch < 0 && abs(s.roll) < 0.01 && s.throttle == 0 && s.yaw == 0)
    }
    @Test func sticksAccountForYaw() throws {
        let s = try #require(moved().homeSticks(yaw: 90))
        #expect(s.roll > 0 && abs(s.pitch) < 0.01)
    }
    @Test func nilWhenArrived() {
        #expect(moved(vgx: 4).homeSticks(yaw: 0) == nil)
    }
    @Test func stickMagnitudeClamped() throws {
        let slow = try #require(moved(vgx: 6).homeSticks(yaw: 0))
        let far = try #require(moved(vgx: 100).homeSticks(yaw: 0))
        #expect(abs(slow.pitch + 0.4) < 0.01 && abs(far.pitch + 1) < 0.01)
    }
}
```

- [ ] **Step 2: Run the tests, expect a compile failure**

Run the test command. Expected: `error:` naming `DeadReckoner`.

- [ ] **Step 3: Implement `DeadReckoner.swift`**

Axes: `x` is forward at yaw 0, `y` is right at yaw 0, yaw is clockwise-positive after `yawSign`.

Reading from raw fields: apply `swapAxes`, then signs, then `cmPerUnit`, giving forward `f` and right `r` in cm/s.

In `add`: the first sample after reset only stores the time. A gap above `maxGap` sets `isValid = false` and skips integration. Once invalid, nothing integrates until `reset`.

```text
theta = radians(yaw * yawSign), or 0 for velocity when !bodyFrame
x += (f cos(theta) - r sin(theta)) * dt
y += (f sin(theta) + r cos(theta)) * dt

homeSticks, with the real theta even when !bodyFrame:
hx = -x, hy = -y, dist = hypot(hx, hy)
magnitude = clamp(dist / 150, 0.4, 1)
pitch = magnitude * (hx cos(theta) + hy sin(theta)) / dist
roll  = magnitude * (-hx sin(theta) + hy cos(theta)) / dist
```

Add `// shortcut: dead reckoning drifts and vg fields are whole dm/s, upgrade with mission pads or object tracking` above the struct.

- [ ] **Step 4: Run the tests, expect all pass**

- [ ] **Step 5: Commit** `DeadReckoner.swift` and `DeadReckonerTests.swift` with message `DroneLink: dead reckoner for return to home`.

### Task 2: TelloLink return flow

**Files:**
- Modify: `DroneArena-vision/HelicopterGame/DroneLink/Sources/DroneLink/TelloLink.swift` (`takeoff`, `land`, `emergency`, `disconnect`, `tick`, `noteState`)
- Modify: `DroneArena-vision/HelicopterGame/DroneLink/Tests/DroneLinkTests/TelloE2ETests.swift` (`MockTello.pushState`, new tests in `TelloE2ETests`, reusing `wait`, `fly`, `makeFlying`)

**Interfaces:**
- Consumes: `DeadReckoner` from Task 1.
- Produces, on `TelloLink`:
  - `public enum ReturnStatus: Equatable, Sendable { case idle, returning, arrived, pilotTookOver, positionLost, timedOut }` (top level in `DeadReckoner.swift` or `TelloLink.swift`)
  - `public private(set) var returnStatus: ReturnStatus = .idle`
  - `public var reckoner = DeadReckoner()`
  - `public var returnTimeout: TimeInterval = 45`
  - `public static let returnSpeedLimit = 30`
  - `public var canReturnHome: Bool` is true when flying, armed, `reckoner.isValid`, and not already returning.
  - `public func returnHome()` does nothing unless `canReturnHome`.

- [ ] **Step 1: Extend `MockTello.pushState`**

Signature `pushState(h: Int, bat: Int = 80, vgx: Int = 0, vgy: Int = 0, yaw: Int = 0)`, with those values in the packet. Existing calls keep compiling.

- [ ] **Step 2: Write the failing tests**

Add a `lastB(_:)` helper next to `lastC` (`p[2]`). Each test calls `link.disconnect(); m.stop()` at the end. Shared setup:

```swift
private func makeReturning(h: Int = 100) async throws -> (MockTello, TelloLink) {
    let (m, link) = try await makeFlying(h: h)
    m.pushState(h: h, vgx: 10)
    #expect(await wait { link.reckoner.xCM >= 100 })
    m.pushState(h: h)
    link.returnHome()
    #expect(link.returnStatus == .returning)
    return (m, link)
}
```

| Test | Setup | Assertions |
|---|---|---|
| `returnFliesHomeAndLands` | `makeReturning`, wait for `lastB < 0`, then `pushState(h: 100, vgx: -10)` | waits for `returnStatus == .arrived` and `commands.contains("land")` |
| `pilotTakesOver` | `makeReturning`, then `fly` (feeds `fullUp`) | `returnStatus == .pilotTookOver`, `state == .flying`, no `land` |
| `telemetryLossLands` | `makeReturning`, then `stopState()` | `returnStatus == .positionLost`, `land` sent |
| `killEndsReturn` | `makeReturning`, wait for `lastB < 0`, then `emergency()` | `returnStatus == .idle`, `emergency` sent, rc count unchanged after 200 ms |
| `disarmEndsReturn` | `makeReturning`, then `sticksEnabled = false` | `returnStatus == .idle`, last rc becomes `rc 0 0 0 0`, no `land` |
| `gapRefusesReturn` | `makeFlying`, `stopState()`, sleep 1.2 s, `pushState(h: 100)`, wait for `!reckoner.isValid` | `canReturnHome == false`, after `returnHome()` status is `.idle` |
| `returnObeysCeilingAndCap` | `makeFlying(h: 320)`, `speedLimit = 100`, then the same push and `returnHome()` as `makeReturning` with h 320 | waits for `lastC < 0` and `lastB < 0`, every rc sent has `abs(b) <= 30` |
| `returnTimesOut` | `makeFlying`, `returnTimeout = 0.3`, then push and `returnHome()` with no return velocity | `returnStatus == .timedOut`, `land` sent |
| `newTakeoffResetsHome` | after `returnFliesHomeAndLands` flow, `takeoff()` | `reckoner.xCM == 0`, `returnStatus == .idle` |

- [ ] **Step 3: Run the tests, expect a compile failure** naming `returnHome`.

- [ ] **Step 4: Implement in `TelloLink`**

- `noteState`: when `state == .flying` and `vgx`, `vgy`, `yaw` are all present, call `reckoner.add(..., at: now)`.
- `takeoff`: `reckoner.reset()` and `returnStatus = .idle` beside `governor.reset()`.
- `land`, `emergency`, `disconnect`: if `.returning`, set `.idle`.
- `tick`: at the top of the `state == .flying` branch, if `.returning`, run these in order:
  1. Not `sticksEnabled`: set `.idle` and fall through to the existing keepalive path.
  2. Fresh pilot sticks with any axis magnitude above 0.2: set `.pilotTookOver` and fall through to normal stick handling.
  3. Telemetry age over `governor.telemetryMaxAge`, `stateAt` nil, or `!reckoner.isValid`: `land()`, then set `.positionLost`, return.
  4. Elapsed over `returnTimeout`: `land()`, then set `.timedOut`, return.
  5. `reckoner.homeSticks(yaw: stateFields["yaw"] ?? 0)` is nil: `land()`, then set `.arrived`, return.
  6. Otherwise apply `governor.apply` to those sticks, update `safety`, send `rcCommand(limit: max(0, min(speedLimit, Self.returnSpeedLimit)), deadzone: deadzone)`, update `lastRC` and `keepAliveAt`, return.

Terminal statuses are set after `land()` because `land()` only clears `.returning`.

- [ ] **Step 5: Run the tests, expect all pass**, including the 41 existing tests.

- [ ] **Step 6: Commit** the two files with message `DroneLink: return home flow in TelloLink`.

### Task 3: Button, status strip, debug readout, docs

**Files:**
- Modify: `DroneArena-vision/HelicopterGame/HelicopterGame/RealDrone/LiveControls.swift` (chip row)
- Modify: `DroneArena-vision/HelicopterGame/HelicopterGame/RealDrone/LiveHUD.swift` (`LiveSafetyStrip.content`, `.normal` case)
- Modify: `DroneArena-vision/HelicopterGame/HelicopterGame/RealDrone/LiveDebugView.swift` (one row)
- Modify: `notes/LIVE_DRONE.md`, `notes/HANDOFF.md`

**Interfaces:**
- Consumes: `returnHome()`, `canReturnHome`, `returnStatus`, `reckoner` from Task 2.

- [ ] **Step 1: Add the button**

In the chip row between Take off and Land, only `if bridge.showDebug`: `Button("Return") { link.returnHome() }` with `LiveChipStyle()`, `.disabled(!link.canReturnHome)`. Add `// shortcut: hidden behind Debug until Task 4 of notes/PLAN-return-to-home.md passes`.

- [ ] **Step 2: Add the strip text**

In `.normal`, after the `commandFailure` check and before `takeoffBlockedReason`:

| Status | Text | Colors |
|---|---|---|
| `.returning` | `Returning home` | `warn` |
| `.arrived` | `Home reached. Landing` | `warn` |
| `.pilotTookOver` | `Return cancelled. Pilot control` | `none` |
| `.positionLost` | `Position lost. Landing here` | `red` |
| `.timedOut` | `Return timed out. Landing here` | `red` |

- [ ] **Step 3: Add the debug row**

In `LiveDebugView`, using its existing row style: `HOME` showing `xCM` and `yCM` rounded to whole cm, plus `LOST` when `!reckoner.isValid`. Task 4 reads this.

- [ ] **Step 4: Update docs**

`notes/LIVE_DRONE.md`: under Safety, list the Decisions table's behavior in a short paragraph and state that the drone lands near home, not on it, with no obstacle sensing. `notes/HANDOFF.md`: add `## Return home done` with test count and `Not flown`.

- [ ] **Step 5: Run the app build command.** Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit** the five files with message `Live drone: return home button behind Debug`.

### Task 4: Hardware calibration and flight gate

Needs a person, a Tello and a headset. Cannot be done by an agent or skipped. The button stays behind Debug until this passes.

**Files:**
- Modify: `DroneArena-vision/HelicopterGame/HelicopterGame/RealDrone/RealDroneBridge.swift` (`init`, measured calibration)
- Modify: `DroneArena-vision/HelicopterGame/HelicopterGame/RealDrone/LiveControls.swift` (remove gate)
- Modify: `notes/LIVE_DRONE.md`, `notes/HANDOFF.md`

Preflight: indoors with a textured floor, 3 m clear in every direction, propeller guards on, battery above 50%, speed 20, Debug on. Takeover is any stick. Kill stays available.

- [ ] **Step 1: Measure the fields, reading the Debug state table in hover**

| Input | Read | Sets |
|---|---|---|
| Pitch forward | which of `vgx`, `vgy` moves, and its sign | `swapAxes`, `xSign` |
| Roll right | the other field and its sign | `ySign` |
| Yaw clockwise about 90 degrees | whether `yaw` rises | `yawSign` |
| Pitch forward, still turned 90 degrees | same field as first row means body frame, otherwise world | `bodyFrame` |
| Fly a taped 2 m line | `HOME` distance against 200 cm | `cmPerUnit` |

- [ ] **Step 2: Set the measured values in `RealDroneBridge.init` with `l.reckoner.calibration = VelocityCalibration(...)`, then run the app build.** The struct defaults stay nominal, so the package tests do not depend on the measurement.

- [ ] **Step 3: Flight test, each run from a taped takeoff mark, measuring landing distance from the mark**

| Run | Flight | Pass |
|---|---|---|
| A | 1 m forward, Return | Moves toward the mark first try. If it moves away, take over and recheck Step 1 |
| B | 2 m forward, 2 m right, Return | Lands within 1 m |
| C | 2 m out, yaw 90 degrees, Return | Lands within 1 m |
| D | Mid-return, push a stick | Hovers under stick control |
| E | Hovering with sticks centered and no return active, turn off headset Wi-Fi | Drone auto-lands within about 15 s |

- [ ] **Step 4: If all pass, delete the `bridge.showDebug` gate and its shortcut comment.** If B or C fail, keep the gate and record the error in `notes/HANDOFF.md`.

- [ ] **Step 5: Record results in `notes/LIVE_DRONE.md` and `notes/HANDOFF.md`, remove the matching lines from "Not verified", run the app build, commit** with message `Live drone: calibrate return home from flight test`.
