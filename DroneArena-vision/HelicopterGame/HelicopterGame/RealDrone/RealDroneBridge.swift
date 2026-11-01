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
    }

    /// One-button connect: starts the stick sampler, then the connector flow.
    func connect() {
        start()
        connector.connect()
    }

    private func start() {
        guard timer == nil else { return }
        isActive = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor in RealDroneBridge.shared.sample() }
        }
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
        let c = DualThumbController.shared
        let l = c.leftIsActive ? c.leftDirection * c.leftMagnitude : .zero
        let r = c.rightIsActive ? c.rightDirection * c.rightMagnitude : .zero
        // Mode 2, matches MobileVirtualJoystickComponent: left = throttle (y) + yaw (x),
        // right = pitch (y) + roll (x).
        sticks = DroneSticks(
            yaw: l.x,
            throttle: l.y,
            roll: r.x,
            pitch: invertPitch ? -r.y : r.y
        )
        link.update(sticks)
    }
}
#endif
