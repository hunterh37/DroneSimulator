//
//  CrateRoomDresser.swift
//  HelicopterGame
//
//  Places Fold Freight set dressing on the player's real walls and ceiling
//  by raycasting the scene reconstruction mesh. Falls back to fixed
//  positions when no mesh is available (simulator, unscanned room).
//

import RealityKit
import simd

@MainActor
enum CrateRoomDresser {
    static let defaultRiftPoints: [SIMD3<Float>] = [[-0.8, 2.3, -1.7], [0.8, 2.3, -1.7], [0, 2.3, -2.2]]

    private struct WallSlot {
        let name: String
        let direction: SIMD3<Float>
        let height: Float
        let fallbackDistance: Float
        let make: () -> Entity
    }

    private static let slots: [WallSlot] = [
        WallSlot(name: "Prop_Board", direction: [0, 0, -1], height: 1.55, fallbackDistance: 2.6,
                 make: CrateWorldBuilder.makeDispatchBoard),
        WallSlot(name: "Prop_Gauge", direction: simd_normalize([-1, 0, -0.35]), height: 1.45, fallbackDistance: 2.2,
                 make: CrateWorldBuilder.makeIntegrityGauge),
        WallSlot(name: "Prop_Conduit", direction: simd_normalize([1, 0, -0.35]), height: 1.9, fallbackDistance: 2.2,
                 make: CrateWorldBuilder.makeConduit),
        WallSlot(name: "Prop_Gauge2", direction: simd_normalize([1, 0, -0.9]), height: 1.3, fallbackDistance: 2.4,
                 make: CrateWorldBuilder.makeIntegrityGauge),
    ]

    static func dress(_ world: Entity, rifts: [SIMD3<Float>]) {
        for slot in slots {
            let e = slot.make()
            e.name = slot.name
            place(e, at: slot.direction * slot.fallbackDistance + [0, slot.height, 0], facing: -slot.direction)
            world.addChild(e)
        }
        for (i, p) in rifts.enumerated() {
            let r = CrateWorldBuilder.makeRift()
            r.name = "Rift_\(i)"
            r.position = p
            world.addChild(r)
        }
    }

    /// Snap props onto real surfaces. Returns the rift spawn points actually used.
    @discardableResult
    static func redressOnRoom(_ world: Entity) -> [SIMD3<Float>] {
        guard let scene = world.scene else { return defaultRiftPoints }
        for slot in slots {
            guard let e = world.findEntity(named: slot.name) else { continue }
            let origin = world.convert(position: [0, slot.height, 0], to: nil)
            let dir = world.convert(direction: slot.direction, to: nil)
            if let hit = roomHit(scene, from: origin, dir: dir, maxDist: 4.5) {
                var n = hit.normal
                n.y = 0
                guard simd_length(n) > 0.3 else { continue }
                n = simd_normalize(n)
                let p = world.convert(position: hit.position + n * 0.015, from: nil)
                place(e, at: p, facing: world.convert(direction: n, from: nil))
            }
        }
        var rifts: [SIMD3<Float>] = []
        for (i, fallback) in defaultRiftPoints.enumerated() {
            guard let r = world.findEntity(named: "Rift_\(i)") else { continue }
            let origin = world.convert(position: [fallback.x, 1.3, fallback.z], to: nil)
            if let hit = roomHit(scene, from: origin, dir: world.convert(direction: [0, 1, 0], to: nil), maxDist: 2.5),
               hit.normal.y < -0.6 {
                let p = world.convert(position: hit.position, from: nil) - [0, 0.012, 0]
                r.position = p
                rifts.append(p)
            } else {
                rifts.append(fallback)
            }
        }
        return rifts
    }

    private static func place(_ e: Entity, at p: SIMD3<Float>, facing normal: SIMD3<Float>) {
        e.position = p
        let yaw = atan2(normal.x, normal.z)
        e.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
    }

    private static func roomHit(_ scene: Scene, from origin: SIMD3<Float>, dir: SIMD3<Float>, maxDist: Float) -> CollisionCastHit? {
        scene.raycast(origin: origin, direction: simd_normalize(dir), length: maxDist, query: .all)
            .filter { $0.entity.components.has(WallMeshComponent.self) }
            .min { $0.distance < $1.distance }
    }
}
