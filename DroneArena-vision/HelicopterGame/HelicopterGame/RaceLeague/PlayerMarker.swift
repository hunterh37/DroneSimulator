//
//  PlayerMarker.swift
//  HelicopterGame
//
//  Race Practice: downward arrow hovering over the player drone. ECS driven,
//  world space (does not inherit drone roll/pitch), bobs and spins for visibility.
//

import RealityKit
import UIKit
import simd

struct PlayerMarkerComponent: Component {
    weak var target: Entity?
    var height: Float = 0.22
    var phase: Float = 0
}

struct PlayerMarkerSystem: System {
    private static let query = EntityQuery(where: .has(PlayerMarkerComponent.self))

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        for e in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var m = e.components[PlayerMarkerComponent.self] else { continue }
            guard let target = m.target else { continue }
            m.phase += dt
            let base = target.position(relativeTo: nil)
            let bob = sinf(m.phase * 4) * 0.025
            e.setPosition(base + [0, m.height + bob, 0], relativeTo: nil)
            e.setOrientation(simd_quatf(angle: m.phase * 2.2, axis: [0, 1, 0]), relativeTo: nil)
            e.components.set(m)
        }
    }
}

@MainActor
enum PlayerMarker {
    private static weak var marker: Entity?

    static func attach(to parent: Entity, tracking drone: Entity?) {
        detach()
        guard let drone else { return }
        let root = Entity()
        root.name = "PlayerMarker"
        root.components.set(PlayerMarkerComponent(target: drone))
        root.addChild(makeArrow())
        parent.addChild(root)
        marker = root
    }

    static func detach() {
        marker?.removeFromParent()
        marker = nil
    }

    private static func makeArrow() -> Entity {
        let color = UIColor(red: 1.0, green: 0.85, blue: 0.1, alpha: 1)
        let mat = UnlitMaterial(color: color)
        let arrow = Entity()
        // Head: cone flipped so the tip points down at the drone.
        let head = ModelEntity(mesh: .generateCone(height: 0.07, radius: 0.045), materials: [mat])
        head.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        head.position = [0, 0.035, 0]
        let shaft = ModelEntity(mesh: .generateBox(size: [0.03, 0.07, 0.03]), materials: [mat])
        shaft.position = [0, 0.105, 0]
        arrow.addChild(head)
        arrow.addChild(shaft)
        return arrow
    }
}
