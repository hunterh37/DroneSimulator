#if os(visionOS)
import SwiftUI
import AVFoundation
import RealityKit
import ShaderGraphCoder

/// DicyaninLabs studio splash + asset-loading flow, ported from ZombieShooter and
/// re-themed for DroneArena. Two phases:
///   1. The 3D "DicyaninLabs" studio title (glitch chrome + retro TV) for ~5 s.
///   2. A spinning drone centerpiece over a cyber loading bar while assets preload.
/// When loading finishes it opens the main window and dismisses itself.
///
/// Hosted in a `.windowStyle(.plain)` window so the background is fully transparent
/// and the logo/bar float in space like a native visionOS launch screen.
struct DroneSplashView: View {
    @Environment(\.openWindow) private var openWindow

    @State private var loadProgress: Double = 0
    @State private var loadLabel: String = "INITIALIZING..."
    @State private var logoPhase = false      // true after the studio title fades out
    @State private var textAppear = false
    @State private var logoAppear = false
    @State private var glitching = false
    @State private var glitchPlayer: AVAudioPlayer?

    var body: some View {
        ZStack {
            // Phase 2: drone centerpiece + loading bar
            VStack(spacing: 0) {
                Spacer()

                DroneSplashCenterpiece()
                    .frame(maxWidth: 780, maxHeight: 360)
                    .padding(.bottom, 120)

                CyberLoadingBar(progress: loadProgress, label: loadLabel)
                    .frame(width: 700)
                    .padding(.bottom, 112)
                    .padding(.horizontal, 20)
            }
            .opacity(logoAppear ? 1 : 0)
            .scaleEffect(logoAppear ? 1 : 0.88)
            .animation(.easeOut(duration: 0.6), value: logoAppear)

            // Phase 1: retro TV behind the studio title
            RetroTVView(glitching: glitching)
                .frame(width: 360, height: 360)
                .opacity(textAppear && !logoPhase ? 1 : 0)
                .animation(.easeIn(duration: 0.35), value: logoPhase)

            // Phase 1: 3D blocky studio title
            BlockyStudioText(glitching: glitching)
                .opacity(textAppear && !logoPhase ? 1 : 0)
                .scaleEffect(textAppear && !logoPhase ? 1 : 0.92)
                .animation(.easeOut(duration: 0.45), value: textAppear)
                .animation(.easeIn(duration: 0.35), value: logoPhase)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { textAppear = true }
        }
        .task { await runGlitch() }
        .task {
            // Glitch sound at the midpoint of the studio-title phase.
            try? await Task.sleep(for: .milliseconds(1500))
            playGlitchSound()
        }
        .task {
            // Show studio title for ~5 s.
            try? await Task.sleep(for: .milliseconds(5000))
            logoPhase = true
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation { logoAppear = true }

            await DroneAssetPreloader.preloadAll { p, label in
                loadProgress = p
                loadLabel = label
            }

            try? await Task.sleep(for: .milliseconds(600))

            // Hand off to the main window. The main window dismisses this splash
            // from its own `onAppear` (dismissing a window's own initial scene from
            // inside itself is unreliable).
            openWindow(id: "MainWindow")
        }
    }

    private func playGlitchSound() {
        guard let url = Bundle.main.url(forResource: "glitch-sound1", withExtension: "mp3") else { return }
        glitchPlayer = try? AVAudioPlayer(contentsOf: url)
        glitchPlayer?.play()
    }

    @MainActor
    private func runGlitch() async {
        try? await Task.sleep(for: .milliseconds(150))
        for _ in 0..<4 {
            glitching = true
            try? await Task.sleep(for: .milliseconds(Int.random(in: 60...100)))
            glitching = false
            try? await Task.sleep(for: .milliseconds(Int.random(in: 50...130)))
        }
    }
}

// MARK: — 3D blocky "DicyaninLabs" studio title

private struct BlockyStudioText: View {
    var glitching: Bool = false

    private let depth = 6
    private let text = "DicyaninLabs"
    private let blockFont = CyberTheme.font(84, weight: .black)
        .lowercaseSmallCaps()

    var body: some View {
        ZStack {
            // Extruded shadow layers — offset diagonally to fake 3-D depth
            ForEach(1..<depth, id: \.self) { i in
                Text(text)
                    .font(blockFont)
                    .foregroundStyle(shadowColor(layer: i))
                    .offset(x: CGFloat(i) * 1.6, y: CGFloat(i) * 1.6)
            }

            // Chromatic aberration: red/blue channels split hard for a strong RGB-shift look.
            let redShift: CGFloat = glitching ? CGFloat.random(in: -28 ... -16) : -7
            let blueShift: CGFloat = glitching ? CGFloat.random(in: 16...28) : 7
            let jitterY: CGFloat = glitching ? CGFloat.random(in: -6...6) : 0

            // Red channel shifted left
            Text(text)
                .font(blockFont)
                .foregroundStyle(Color.red.opacity(glitching ? 0.95 : 0.7))
                .offset(x: redShift, y: jitterY)
                .blendMode(.screen)
                .blur(radius: glitching ? 1.2 : 0.6)

            // Green channel ghost — opposite slight shift for richer fringing
            Text(text)
                .font(blockFont)
                .foregroundStyle(Color.green.opacity(glitching ? 0.7 : 0.45))
                .offset(x: glitching ? CGFloat.random(in: -6...6) : 0, y: -jitterY)
                .blendMode(.screen)

            // Blue/cyan channel shifted right
            Text(text)
                .font(blockFont)
                .foregroundStyle(Color.cyan.opacity(glitching ? 0.9 : 0.65))
                .offset(x: blueShift, y: -jitterY)
                .blendMode(.screen)
                .blur(radius: glitching ? 1.2 : 0.6)

            // Front face — Matrix Glitch Chrome shader treatment
            MatrixGlitchChrome(size: 84) {
                Text(text)
                    .font(blockFont)
            }
            .offset(
                x: glitching ? CGFloat.random(in: -4...4) : 0,
                y: glitching ? CGFloat.random(in: -2...2) : 0
            )
            .opacity(glitching ? Double.random(in: 0.6...1.0) : 1.0)
        }
        .shadow(color: .black.opacity(0.5), radius: 12, x: 4, y: 8)
        .animation(glitching ? .none : .easeOut(duration: 0.08), value: glitching)
    }

    private func shadowColor(layer: Int) -> Color {
        let t = Double(layer) / Double(depth)
        return Color(
            red: 0.08 + 0.04 * (1 - t),
            green: 0.08 + 0.04 * (1 - t),
            blue: 0.12 + 0.06 * (1 - t)
        )
    }
}

// MARK: — Retro TV behind the studio title

private final class GlitchBox { var value: Bool = false }

private struct RetroTVView: View {
    var glitching: Bool = false

    @State private var root: Entity? = nil
    @State private var animTimer: Timer? = nil
    @State private var t: Float = 0
    @State private var glitchBox = GlitchBox()

    var body: some View {
        RealityView { content in
            let r = await buildScene()
            content.add(r)
            root = r
            startTimer()
        } update: { _ in
            glitchBox.value = glitching
        }
        .onDisappear { animTimer?.invalidate() }
    }

    private func startTimer() {
        let box = glitchBox
        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            Task { @MainActor in
                t += 1.0 / 60.0
                guard let r = root else { return }
                animate(root: r, t: t, glitching: box.value)
            }
        }
    }

    @MainActor
    private func buildScene() async -> Entity {
        let container = Entity()
        container.name = "RetroTVRoot"
        container.position = [0, 0, -0.06]

        if let loaded = try? await Entity.load(named: "tv2") {
            let tv = loaded.clone(recursive: true)
            tv.name = "RetroTVModel"

            let bounds = tv.visualBounds(relativeTo: nil)
            let maxDim = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
            let targetSize: Float = 0.13
            let s = maxDim > 0 ? targetSize / maxDim : 1.0
            tv.scale = SIMD3<Float>(repeating: 0.34)
            let c = bounds.center
            tv.position = [-c.x * s, (-c.y * s) - 0.05, -(c.z * s) - 0.091]

            if let mat = try? await makeWiremeshCyberGreenShader() {
                applyCyberMaterial(mat, to: tv)
            }
            container.addChild(tv)
        } else {
            var mat = UnlitMaterial(color: UIColor(red: 0.0, green: 1.0, blue: 0.25, alpha: 0.6))
            mat.blending = .transparent(opacity: .init(floatLiteral: 0.6))
            let fallback = ModelEntity(mesh: .generateBox(width: 0.22, height: 0.16, depth: 0.16), materials: [mat])
            fallback.name = "RetroTVModel"
            container.addChild(fallback)
        }

        // Cyber green screen glow
        var tvLight = PointLightComponent()
        tvLight.color = UIColor(red: 0.0, green: 1.0, blue: 0.3, alpha: 1)
        tvLight.intensity = 500
        tvLight.attenuationRadius = 0.9
        let tvLightE = Entity()
        tvLightE.name = "RetroTVLight"
        tvLightE.components.set(tvLight)
        tvLightE.position = [0, 0.04, 0.16]
        container.addChild(tvLightE)

        return container
    }

    private func applyCyberMaterial(_ mat: ShaderGraphMaterial, to entity: Entity) {
        if let model = entity as? ModelEntity {
            model.model?.materials = model.model?.materials.map { _ in mat as any RealityKit.Material } ?? [mat]
        }
        for child in entity.children {
            applyCyberMaterial(mat, to: child)
        }
    }

    @MainActor
    private func animate(root: Entity, t: Float, glitching: Bool) {
        let hoverY = sin(t * 0.6) * 0.006

        if glitching {
            root.position.x = sin(t * 300.0) * 0.012
            root.position.y = hoverY + sin(t * 260.0) * 0.009
            root.orientation = simd_quatf(angle: sin(t * 280.0) * 0.045, axis: [0, 0, 1])
        } else {
            root.position.x = 0
            root.position.y = hoverY
            root.orientation = simd_quatf(angle: sin(t * 0.4) * 0.03, axis: [0, 1, 0])
        }

        if let tvModel = root.findEntity(named: "RetroTVModel") {
            let flicker = 0.82 + sin(t * 1.7) * 0.1 + sin(t * 9.3) * 0.05
            let opacity: Float = glitching ? (sin(t * 320.0) > 0 ? 0.45 : 1.0) : flicker
            tvModel.components.set(OpacityComponent(opacity: min(1, opacity)))
        }

        if let lightE = root.findEntity(named: "RetroTVLight") {
            var lc = lightE.components[PointLightComponent.self] ?? PointLightComponent()
            lc.intensity = glitching ? 1800 : 420 + sin(t * 2.2) * 140
            lightE.components.set(lc)
        }
    }
}

// MARK: — Drone centerpiece (phase 2)

private struct DroneSplashCenterpiece: View {
    @State private var root: Entity? = nil
    @State private var animTimer: Timer? = nil
    @State private var t: Float = 0

    var body: some View {
        RealityView { content in
            let r = await buildScene()
            content.add(r)
            root = r
            startTimer()
        }
        .onDisappear { animTimer?.invalidate() }
    }

    private func startTimer() {
        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            Task { @MainActor in
                t += 1.0 / 60.0
                guard let r = root else { return }
                animate(root: r, t: t)
            }
        }
    }

    @MainActor
    private func buildScene() async -> Entity {
        let r = Entity()
        r.name = "DroneSplashRoot"

        // Drone — centered, slowly spinning, green hologram tint.
        let droneRoot = Entity()
        droneRoot.name = "SplashDrone"
        if let model = try? await Entity.load(named: "Drone") {
            let m = model.clone(recursive: true)
            let bounds = m.visualBounds(relativeTo: nil)
            let maxDim = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
            let target: Float = 0.22
            m.scale = SIMD3<Float>(repeating: maxDim > 0 ? target / maxDim : 0.2)
            applySplashHologram(to: m, color: UIColor(red: 0.05, green: 1.0, blue: 0.55, alpha: 0.9))
            if let anim = m.availableAnimations.first { m.playAnimation(anim.repeat()) }
            droneRoot.addChild(m)
        } else {
            droneRoot.addChild(ModelEntity(mesh: .generateSphere(radius: 0.08),
                                           materials: [SimpleMaterial(color: .green, isMetallic: true)]))
        }
        droneRoot.position = [0, 0.02, 0]
        r.addChild(droneRoot)

        // Orbiting particle orbs
        for i in 0..<16 {
            let baseAngle = Float(i) / 16.0 * .pi * 2
            let radius: Float = [0.14, 0.20, 0.26][i % 3]
            let orb = Entity()
            orb.name = "SplashOrb_\(i)"
            orb.position = [cos(baseAngle) * radius, sin(Float(i) * 1.1) * 0.04, sin(baseAngle) * radius * 0.5]
            let size: Float = 0.003 + Float(i % 4) * 0.001
            var mat = UnlitMaterial(color: UIColor(red: 0.15, green: 1.0, blue: 0.45, alpha: 0.9))
            mat.blending = .transparent(opacity: .init(floatLiteral: 0.9))
            orb.addChild(ModelEntity(mesh: .generateSphere(radius: size), materials: [mat]))
            r.addChild(orb)
        }

        // Ground projection disc
        var discMat = UnlitMaterial(color: UIColor(red: 0.0, green: 1.0, blue: 0.55, alpha: 0.20))
        discMat.blending = .transparent(opacity: .init(floatLiteral: 0.20))
        let disc = ModelEntity(mesh: .generateCylinder(height: 0.002, radius: 0.13), materials: [discMat])
        disc.name = "SplashDisc"
        disc.position = [0, -0.13, 0]
        r.addChild(disc)

        // Key light
        var keyLight = PointLightComponent()
        keyLight.color = UIColor(red: 0.1, green: 1.0, blue: 0.55, alpha: 1)
        keyLight.intensity = 2000
        keyLight.attenuationRadius = 1.2
        let lightE = Entity()
        lightE.name = "SplashDroneLight"
        lightE.components.set(keyLight)
        lightE.position = [0, 0.18, 0.2]
        r.addChild(lightE)

        return r
    }

    @MainActor
    private func animate(root: Entity, t: Float) {
        if let drone = root.findEntity(named: "SplashDrone") {
            let hover = sin(t * 1.5) * 0.012 + sin(t * 3.3) * 0.003
            drone.position = [0, 0.02 + hover, 0]
            drone.orientation = simd_quatf(angle: t * 0.9, axis: [0, 1, 0])
        }

        if let lightE = root.findEntity(named: "SplashDroneLight") {
            var lc = lightE.components[PointLightComponent.self] ?? PointLightComponent()
            lc.intensity = 1800 + sin(t * 1.3) * 400
            lightE.components.set(lc)
        }

        for i in 0..<16 {
            if let orb = root.findEntity(named: "SplashOrb_\(i)") {
                let baseAngle = Float(i) / 16.0 * .pi * 2
                let speed: Float = 0.18 + Float(i % 4) * 0.06
                let angle = baseAngle + t * speed
                let radius: Float = [0.14, 0.20, 0.26][i % 3]
                let vertSpeed: Float = 0.35 + Float(i % 5) * 0.12
                orb.position = [
                    cos(angle) * radius,
                    sin(t * vertSpeed + Float(i) * 0.7) * 0.04,
                    sin(angle) * radius * 0.5,
                ]
            }
        }

        if let disc = root.findEntity(named: "SplashDisc") {
            let pulse = 1.0 + sin(t * 2.1) * 0.12
            disc.scale = SIMD3<Float>(pulse, 1.0, pulse)
        }
    }

    /// Minimal green hologram tint — recursive unlit material swap.
    private func applySplashHologram(to entity: Entity, color: UIColor) {
        if let model = entity as? ModelEntity {
            var mat = UnlitMaterial(color: color)
            mat.blending = .transparent(opacity: .init(floatLiteral: Float(color.cgColor.alpha)))
            model.model?.materials = (model.model?.materials.map { _ in mat as any RealityKit.Material }) ?? [mat]
        }
        for child in entity.children {
            applySplashHologram(to: child, color: color)
        }
    }
}

#Preview {
    DroneSplashView()
}
#endif
