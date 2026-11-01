#if os(visionOS)
import DroneLink
import RealityKit
import UIKit

/// Room-scale view of the live drone. The takeoff spot is `home` on the floor, drone nose facing -Z
/// (away from the user at space open). Dead-reckoning (x forward, y right) maps to RealityKit (y, h, -x).
struct LiveWorldComponent: Component {
    static let defaultHome = SIMD3<Float>(0, 0, -1.5)
    /// Takeoff spot in scene space. Dragging the drone orb moves it (and the whole live world),
    /// so the orb can be re-centered on the real drone. Persisted across launches.
    @MainActor static var home: SIMD3<Float> = {
        let a = UserDefaults.standard.array(forKey: "liveWorldHome") as? [Float]
        return a?.count == 3 ? SIMD3(a![0], a![1], a![2]) : defaultHome
    }() {
        didSet { UserDefaults.standard.set([home.x, home.y, home.z], forKey: "liveWorldHome") }
    }
    var pathVersion = -1
    var time: Float = 0

    @MainActor static func toScene(_ p: SIMD2<Double>, height: Double = 0) -> SIMD3<Float> {
        home + SIMD3(Float(p.y), Float(height), -Float(p.x))
    }
    @MainActor static func fromScene(_ s: SIMD3<Float>) -> SIMD2<Double> {
        let d = s - home
        return SIMD2(Double(-d.z), Double(d.x))
    }
}

enum LiveWorldBuilder {
    static let blue = UIColor(red: 0.25, green: 0.55, blue: 1, alpha: 1)

    @MainActor static func make() -> Entity {
        let root = Entity()
        root.name = "live-world"
        root.components.set(LiveWorldComponent())

        // Invisible tap floor, 20 x 20 m.
        let floor = Entity()
        floor.name = "floor"
        floor.components.set(CollisionComponent(shapes: [.generateBox(width: 20, height: 0.02, depth: 20)]))
        floor.components.set(InputTargetComponent())
        floor.position = [0, -0.01, 0]
        root.addChild(floor)

        let pad = ModelEntity(mesh: .generateCylinder(height: 0.004, radius: 0.25), materials: [mat(.white, 0.15)])
        pad.name = "pad"
        pad.position = LiveWorldComponent.home
        root.addChild(pad)

        let drone = ModelEntity(mesh: .generateSphere(radius: 0.07), materials: [mat(blue, 1)])
        drone.name = "drone"
        // Grab target for the re-center drag (larger than the orb for easy pinch).
        drone.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.14)]))
        drone.components.set(InputTargetComponent())
        drone.components.set(HoverEffectComponent())
        let halo = ModelEntity(mesh: .generateSphere(radius: 0.11), materials: [mat(blue, 0.25)])
        drone.addChild(halo)
        let nose = ModelEntity(mesh: .generateBox(width: 0.015, height: 0.015, depth: 0.25), materials: [mat(.white, 0.9)])
        nose.position = [0, 0, -0.16]
        drone.addChild(nose)
        root.addChild(drone)

        let shadow = ModelEntity(mesh: .generateCylinder(height: 0.003, radius: 0.12), materials: [mat(blue, 0.35)])
        shadow.name = "shadow"
        root.addChild(shadow)

        let target = ModelEntity(mesh: .generateCylinder(height: 0.006, radius: 0.3), materials: [mat(blue, 0.45)])
        target.name = "target"
        let core = ModelEntity(mesh: .generateCylinder(height: 0.008, radius: 0.08), materials: [mat(blue, 1)])
        target.addChild(core)
        target.isEnabled = false
        root.addChild(target)

        let impact = ModelEntity(mesh: .generateSphere(radius: 0.09), materials: [mat(.red, 0.9)])
        impact.name = "impact"
        impact.isEnabled = false
        root.addChild(impact)
        let ray = ModelEntity(mesh: .generateBox(size: 1), materials: [mat(.red, 0.5)])
        ray.name = "ray"
        ray.isEnabled = false
        root.addChild(ray)

        for name in ["path", "obstacles"] {
            let g = Entity(); g.name = name; root.addChild(g)
        }
        return root
    }

    static func mat(_ c: UIColor, _ a: CGFloat) -> UnlitMaterial {
        var m = UnlitMaterial(color: c)
        if a < 1 { m.blending = .transparent(opacity: .init(floatLiteral: Float(a))) }
        return m
    }

    /// Thin box from a to b.
    static func place(_ e: Entity, from a: SIMD3<Float>, to b: SIMD3<Float>, thickness: Float) {
        let d = b - a
        let len = max(simd_length(d), 0.001)
        e.position = (a + b) / 2
        e.orientation = simd_quatf(from: [0, 0, 1], to: d / len)
        e.scale = [thickness, thickness, len]
    }
}

/// Syncs drone orb, obstacle columns and orbs, impact point, blue path and target ring each frame.
struct LiveWorldSystem: System {
    static let query = EntityQuery(where: .has(LiveWorldComponent.self))

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        MainActor.assumeIsolated {
            for root in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
                sync(root, dt: dt)
            }
        }
    }

    @MainActor private func sync(_ root: Entity, dt: Float) {
        guard var c = root.components[LiveWorldComponent.self] else { return }
        let a = AutonomyController.shared
        c.time += dt
        let pulse = 1 + 0.25 * sin(c.time * 8)
        let h = max(a.pose.heightM, a.demo ? 1.2 : 0.1)

        if let drone = root.findEntity(named: "drone") {
            drone.position = LiveWorldComponent.toScene(a.pose.xy, height: h)
            drone.orientation = simd_quatf(angle: -Float(a.pose.yaw), axis: [0, 1, 0])
        }
        root.findEntity(named: "pad")?.position = LiveWorldComponent.home
        root.findEntity(named: "shadow")?.position = LiveWorldComponent.toScene(a.pose.xy, height: 0.003)

        if let t = root.findEntity(named: "target") {
            t.isEnabled = a.target != nil
            if let p = a.target { t.position = LiveWorldComponent.toScene(p, height: 0.004); t.scale = [pulse, 1, pulse] }
        }

        let impact = root.findEntity(named: "impact"), ray = root.findEntity(named: "ray")
        if let p = a.impact {
            let from = LiveWorldComponent.toScene(a.pose.xy, height: h)
            let to = LiveWorldComponent.toScene(p, height: h)
            impact?.isEnabled = true
            impact?.position = to
            impact?.scale = .init(repeating: pulse)
            ray?.isEnabled = true
            if let ray { LiveWorldBuilder.place(ray, from: from, to: to, thickness: 0.012) }
        } else {
            impact?.isEnabled = false; ray?.isEnabled = false
        }

        if let g = root.findEntity(named: "obstacles") { syncObstacles(g, a.world, pulse: pulse) }
        if c.pathVersion != a.pathVersion, let g = root.findEntity(named: "path") {
            c.pathVersion = a.pathVersion
            syncPath(g, a.path)
        }
        root.components.set(c)
    }

    @MainActor private func syncObstacles(_ g: Entity, _ items: [WorldObstacle], pulse: Float) {
        while g.children.count < items.count {
            let e = Entity()
            let col = ModelEntity(mesh: .generateCylinder(height: 1, radius: 1), materials: [LiveWorldBuilder.mat(.red, 0.22)])
            col.name = "col"
            let orb = ModelEntity(mesh: .generateSphere(radius: 0.1), materials: [LiveWorldBuilder.mat(.red, 1)])
            orb.name = "orb"
            let ring = ModelEntity(mesh: .generateCylinder(height: 0.004, radius: 1), materials: [LiveWorldBuilder.mat(.red, 0.5)])
            ring.name = "ring"
            e.addChild(col); e.addChild(orb); e.addChild(ring)
            g.addChild(e)
        }
        for (i, e) in g.children.enumerated() {
            guard i < items.count else { e.isEnabled = false; continue }
            let o = items[i]
            e.isEnabled = true
            e.position = LiveWorldComponent.toScene(o.center)
            let r = Float(o.radius), hh = Float(o.heightM)
            if let col = e.findEntity(named: "col") { col.scale = [r, hh, r]; col.position = [0, hh / 2, 0] }
            if let orb = e.findEntity(named: "orb") { orb.position = [0, hh + 0.2, 0]; orb.scale = .init(repeating: pulse) }
            if let ring = e.findEntity(named: "ring") { let s = r + 0.5; ring.scale = [s, 1, s]; ring.position = [0, 0.003, 0] }
        }
    }

    @MainActor private func syncPath(_ g: Entity, _ path: [SIMD2<Double>]) {
        g.children.removeAll()
        for (p, q) in zip(path, path.dropFirst()) {
            let seg = ModelEntity(mesh: .generateBox(size: 1), materials: [LiveWorldBuilder.mat(LiveWorldBuilder.blue, 0.85)])
            LiveWorldBuilder.place(seg, from: LiveWorldComponent.toScene(p, height: 0.01),
                                   to: LiveWorldComponent.toScene(q, height: 0.01), thickness: 1)
            seg.scale = [0.06, 0.006, seg.scale.z]
            g.addChild(seg)
            let dot = ModelEntity(mesh: .generateSphere(radius: 0.05), materials: [LiveWorldBuilder.mat(LiveWorldBuilder.blue, 1)])
            dot.position = LiveWorldComponent.toScene(q, height: 0.05)
            g.addChild(dot)
        }
    }
}
#endif
