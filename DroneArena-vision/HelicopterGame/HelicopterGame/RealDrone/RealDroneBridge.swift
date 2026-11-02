#if os(visionOS)
import DicyaninThumbController
import DroneLink
import Foundation
import Observation

/// App glue: samples the shared thumb joystick channels (hand thumb sticks or
/// world joystick rig, both write DualThumbController) and feeds DroneLink.
/// All drone protocol and hardware code lives in the DroneLink package.
@MainActor @Observable
final class RealDroneBridge {
    static let shared = RealDroneBridge()

    let link: TelloLink
    let connector: TelloConnector
    var invertPitch = false
    /// Shows the debug panel over the feed.
    var showDebug = false
    /// True only while Live Drone mode is open. Nothing is sent otherwise.
    private(set) var isActive = false
    private(set) var sticks = DroneSticks.zero
    private var timer: Timer?

    private init() {
        let l = TelloLink()
        link = l
        connector = TelloConnector(link: l)
        connector.startsVideo = true
        StickDebugFlags.shared.applyStored(link: l)
    }

    /// One-button connect: starts the stick sampler, then the connector flow.
    func connect() {
        start()
        connector.connect()
    }

    private func start() {
        guard timer == nil else { return }
        isActive = true
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { _ in
            MainActor.assumeIsolated { RealDroneBridge.shared.sample() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        isActive = false
        connector.cancel()
        link.sticksEnabled = false
        link.land()
        link.stopVideo()
        timer?.invalidate(); timer = nil
        link.disconnect()
    }

    private func sample() {
        guard isActive else { return }
        let j = readJoystick()
        // Tick always so detections and red boxes update in every mode, even with flag B.
        let a = AutonomyController.shared.tick(joystick: j, link: link)
        let s = StickDebugFlags.shared.bypassAutonomy ? j : a
        if s != sticks { sticks = s }
        link.update(s)
    }

    /// Mode 2, matches MobileVirtualJoystickComponent: left = throttle (y) + yaw (x),
    /// right = pitch (y) + roll (x).
    func readJoystick() -> DroneSticks {
        let c = DualThumbController.shared
        let t = LiveTouchInput.shared
        let hl = c.leftIsActive ? c.leftDirection * c.leftMagnitude : .zero
        let hr = c.rightIsActive ? c.rightDirection * c.rightMagnitude : .zero
        let l = t.left.map { SIMD3($0.x, $0.y, 0) } ?? hl
        let r = t.right.map { SIMD3($0.x, $0.y, 0) } ?? hr
        return DroneSticks(yaw: l.x, throttle: l.y, roll: r.x, pitch: invertPitch ? -r.y : r.y)
    }
}
#endif
