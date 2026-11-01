//
//  JoystickPreview
//
//  A tiny macOS app that renders one DicyaninVirtualJoystick rig on a full-screen
//  black scene, then screenshots itself and exits. Used to generate README media.
//
//  Driven entirely by environment variables so it can run headlessly:
//    JOYSTICK_MODE = "pillar" | "gamepad"   (which rig to show)
//    JOYSTICK_OUT  = /absolute/path/out.png (where to write the screenshot)
//

import SwiftUI
import RealityKit
import AppKit
import DicyaninVirtualJoystick

let mode = ProcessInfo.processInfo.environment["JOYSTICK_MODE"] ?? "pillar"
let outPath = ProcessInfo.processInfo.environment["JOYSTICK_OUT"]
    ?? FileManager.default.currentDirectoryPath + "/joystick-\(mode).png"

// MARK: - Scene building

@MainActor
func buildRig(mode: String) -> (rig: Entity, cameraFrom: SIMD3<Float>, lookAt: SIMD3<Float>) {
    switch mode {
    case "gamepad":
        let pad = Gamepad3DEntity.make(at: .zero)
        // Close 3/4 view looking down onto the two sticks.
        return (pad, SIMD3<Float>(0.17, 0.20, 0.34), SIMD3<Float>(0, 0.0, 0))
    default: // "pillar"
        let pillar = GamepadPillarEntity.make(at: SIMD3<Float>(0, 0.9, 0))
        pillar.updateReadouts(speedMph: 128, altitudeFt: 340, missiles: 6)
        // 3/4 view framing the whole stand from deck to floor.
        return (pillar, SIMD3<Float>(0.85, 0.78, 1.45), SIMD3<Float>(0, 0.45, 0))
    }
}

struct PreviewView: View {
    let mode: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RealityView { content in
                let (rig, camFrom, lookAt) = buildRig(mode: mode)
                content.add(rig)

                // Camera framing the rig.
                let cam = PerspectiveCamera()
                cam.camera.fieldOfViewInDegrees = 55
                cam.look(at: lookAt, from: camFrom, relativeTo: nil)
                content.add(cam)

                // Key + fill directional lights so the metal/PBR surfaces read,
                // while the rig's own emissive accents pop against the black.
                let key = DirectionalLight()
                key.light.intensity = 6500
                key.light.color = .white
                key.look(at: lookAt, from: lookAt + SIMD3<Float>(0.6, 1.1, 0.9), relativeTo: nil)
                content.add(key)

                let fill = DirectionalLight()
                fill.light.intensity = 2600
                fill.light.color = .init(white: 0.85, alpha: 1.0)
                fill.look(at: lookAt, from: lookAt + SIMD3<Float>(-0.9, 0.4, 0.5), relativeTo: nil)
                content.add(fill)

                let rim = DirectionalLight()
                rim.light.intensity = 3000
                rim.look(at: lookAt, from: lookAt + SIMD3<Float>(-0.2, 0.3, -1.0), relativeTo: nil)
                content.add(rim)
            }
            .ignoresSafeArea()
        }
        .onAppear { configureWindowThenCapture() }
    }

    /// Make the window a full-screen opaque black panel, then (after RealityKit has
    /// drawn a few frames) screenshot the main display and quit.
    private func configureWindowThenCapture() {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first,
                  let screen = NSScreen.main else { return }
            window.styleMask = [.borderless]
            window.setFrame(screen.frame, display: true)
            window.isOpaque = true
            window.backgroundColor = .black
            window.level = .init(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        // Allow Metal a moment to render the first frames before capturing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-x", "-m", outPath]
            try? p.run()
            p.waitUntilExit()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

struct JoystickPreviewApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }
    var body: some SwiftUI.Scene {
        WindowGroup {
            PreviewView(mode: mode)
        }
    }
}

JoystickPreviewApp.main()
