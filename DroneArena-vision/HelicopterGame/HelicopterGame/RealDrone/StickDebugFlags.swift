#if os(visionOS)
import DicyaninThumbController
import DroneLink
import SwiftUI

/// A/B/C fallbacks for isolating a broken stage in the stick pipeline.
@MainActor @Observable
final class StickDebugFlags {
    static let shared = StickDebugFlags()
    /// A: PinchStick off, DualThumbController raw hand tracking feeds the sticks.
    var legacyThumb = false {
        didSet {
            UserDefaults.standard.set(legacyThumb, forKey: "dbg.A")
            if legacyThumb { PinchStickRouter.shared.suspend() } else { PinchStickRouter.shared.resume() }
            DualThumbController.shared.isHandTrackingInputEnabled = legacyThumb
        }
    }
    /// B: skip AutonomyController and Palm, joystick goes straight to TelloLink.
    var bypassAutonomy = UserDefaults.standard.bool(forKey: "dbg.B") {
        didSet { UserDefaults.standard.set(bypassAutonomy, forKey: "dbg.B") }
    }
    /// C: TelloLink sends rc on every change and every tick (no rate gate).
    var rawRC = UserDefaults.standard.bool(forKey: "dbg.C") {
        didSet {
            UserDefaults.standard.set(rawRC, forKey: "dbg.C")
            RealDroneBridge.shared.link.rawRC = rawRC
        }
    }

    private init() {}

    /// Called from RealDroneBridge.init, so it must not touch RealDroneBridge.shared (recursive once crash).
    func applyStored(link: TelloLink) {
        link.rawRC = rawRC
        if UserDefaults.standard.bool(forKey: "dbg.A") {
            Task { @MainActor in self.legacyThumb = true }
        }
    }
}

struct StickDebugPanel: View {
    @Bindable private var f = StickDebugFlags.shared
    private let bridge = RealDroneBridge.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("A  Legacy thumb input", isOn: $f.legacyThumb)
            Toggle("B  Bypass autonomy", isOn: $f.bypassAutonomy)
            Toggle("C  Raw rc send", isOn: $f.rawRC)
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                let c = DualThumbController.shared
                let j = bridge.readJoystick()
                let s = bridge.sticks
                Text(String(format: "in L%@ R%@ y%.2f t%.2f r%.2f p%.2f",
                            c.leftIsActive ? "+" : "-", c.rightIsActive ? "+" : "-",
                            j.yaw, j.throttle, j.roll, j.pitch))
                Text(String(format: "out y%.2f t%.2f r%.2f p%.2f", s.yaw, s.throttle, s.roll, s.pitch))
                Text("armed \(bridge.link.sticksEnabled ? "Y" : "N")  \(String(describing: bridge.link.state))  \(bridge.link.lastRC)")
            }
            .font(.system(size: 11, design: .monospaced))
        }
    }
}
#endif
