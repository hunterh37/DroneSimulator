//
//  CourseGateEntity.swift
//  HelicopterGame
//
//  A "hoop on a post" race gate for the Time Trial obstacle course.
//
//  Geometry (gate-local space):
//    - The hoop ring lies in the local XY plane; the fly-through axis is local +Z.
//    - The post is a vertical cylinder hanging straight down from the bottom of
//      the hoop along local -Y (gates are only ever yaw-rotated, so local Y stays
//      world-vertical).
//
//  Collision / scoring is driven analytically by CourseObstacleSystem using the
//  values stored in CourseGateComponent (see TimeTrialComponent.swift). Real
//  RealityKit CollisionComponents are also attached to the rim segments and the
//  post so the gate is a solid object in the scene.
//

import RealityKit
import simd
import Foundation
import UIKit

// MARK: - Component

/// Per-gate runtime + geometry, read every frame by the course system.
public struct CourseGateComponent: Component {
    public let index: Int
    public let ringRadius: Float
    /// Crash band half-thickness around the rim centerline (tube + drone radius).
    public let crashBand: Float
    public let postRadius: Float
    public let postHeight: Float
    public let droneRadius: Float

    public var passed: Bool = false
    /// Drone's local-Z from the previous frame, for plane-crossing detection.
    public var prevLocalZ: Float = 0
    public var hasPrevZ: Bool = false

    public init(index: Int,
                ringRadius: Float,
                crashBand: Float,
                postRadius: Float,
                postHeight: Float,
                droneRadius: Float) {
        self.index = index
        self.ringRadius = ringRadius
        self.crashBand = crashBand
        self.postRadius = postRadius
        self.postHeight = postHeight
        self.droneRadius = droneRadius
    }
}

// MARK: - Entity

public class CourseGateEntity: Entity, HasModel, HasCollision {

    public static let tubeRadius: Float = 0.055
    public static let droneRadius: Float = 0.12
    public static let postRadius: Float = 0.05
    public static let postHeight: Float = 1.15
    private static let segmentCount: Int = 28

    public let index: Int
    public let ringRadius: Float

    private var rimSegments: [ModelEntity] = []
    private var hasBeenPassed = false

    public required init() {
        self.index = 0
        self.ringRadius = 0.55
        super.init()
        build()
    }

    public init(index: Int, ringRadius: Float) {
        self.index = index
        self.ringRadius = ringRadius
        super.init()
        build()
        // Geometry/runtime the course system reads each frame.
        components.set(CourseGateComponent(
            index: index,
            ringRadius: ringRadius,
            crashBand: Self.tubeRadius + Self.droneRadius,
            postRadius: Self.postRadius,
            postHeight: Self.postHeight,
            droneRadius: Self.droneRadius
        ))
    }

    public var isPassed: Bool { hasBeenPassed }

    // MARK: - Build

    private func build() {
        buildRim()
        buildPost()
    }

    private func buildRim() {
        let tube = Self.tubeRadius
        let segLen = (2 * Float.pi * ringRadius / Float(Self.segmentCount)) * 1.18
        let mesh = MeshResource.generateBox(width: segLen, height: tube * 2, depth: tube * 2, cornerRadius: tube)

        for i in 0..<Self.segmentCount {
            let a = (2 * Float.pi * Float(i)) / Float(Self.segmentCount)
            let segment = ModelEntity(mesh: mesh, materials: [Self.rimMaterial(color: .cyan)])
            segment.position = SIMD3<Float>(ringRadius * cos(a), ringRadius * sin(a), 0)
            // Orient the box so its long (X) axis is tangent to the ring.
            segment.orientation = simd_quatf(angle: a + .pi / 2, axis: SIMD3<Float>(0, 0, 1))
            // Real collision on each rim segment so the hoop frame is solid.
            segment.collision = CollisionComponent(
                shapes: [.generateBox(width: segLen, height: tube * 2, depth: tube * 2)],
                mode: .default,
                filter: CollisionFilter(group: .init(rawValue: 1 << 5), mask: .all)
            )
            addChild(segment)
            rimSegments.append(segment)
        }
    }

    private func buildPost() {
        let h = Self.postHeight
        let mesh = MeshResource.generateCylinder(height: h, radius: Self.postRadius)
        let post = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: .init(white: 0.7, alpha: 1.0), isMetallic: true)])
        // Hang straight down from the bottom of the hoop.
        post.position = SIMD3<Float>(0, -ringRadius - h / 2, 0)
        post.collision = CollisionComponent(
            shapes: [.generateCapsule(height: h, radius: Self.postRadius)],
            mode: .default,
            filter: CollisionFilter(group: .init(rawValue: 1 << 5), mask: .all)
        )
        addChild(post)

        // A small base foot so the post reads as a stand.
        let footMesh = MeshResource.generateCylinder(height: 0.06, radius: Self.postRadius * 2.4)
        let foot = ModelEntity(mesh: footMesh, materials: [SimpleMaterial(color: .init(white: 0.55, alpha: 1.0), isMetallic: true)])
        foot.position = SIMD3<Float>(0, -ringRadius - h, 0)
        addChild(foot)
    }

    private static func rimMaterial(color: UIColor) -> UnlitMaterial {
        var m = UnlitMaterial()
        m.color = .init(tint: color, texture: nil)
        return m
    }

    // MARK: - State changes

    public func markPassed() {
        guard !hasBeenPassed else { return }
        hasBeenPassed = true
        recolorRim(.green)
        if var c = components[CourseGateComponent.self] {
            c.passed = true
            components.set(c)
        }
    }

    /// Briefly flash the rim red to signal a crash.
    public func flashCrash() {
        recolorRim(.red)
        let gate = self
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            gate.recolorRim(gate.hasBeenPassed ? .green : .cyan)
        }
    }

    private func recolorRim(_ color: UIColor) {
        let mat = Self.rimMaterial(color: color)
        for seg in rimSegments {
            seg.model?.materials = [mat]
        }
    }
}
