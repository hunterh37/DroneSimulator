//
//  SafariCritterFactory.swift
//  HelicopterGame
//
//  Builds cute low-poly critters from faceted primitives. Real-world sizes (25-70 cm).
//

import RealityKit
import UIKit
import simd

enum SafariCritterKind: String, CaseIterable {
    case bunny, chick, bee, owlet, frog, shroomling, slime

    var points: Int {
        switch self {
        case .bunny, .chick, .frog: return 10
        case .owlet, .shroomling: return 15
        case .slime: return 20
        case .bee: return 25
        }
    }

    /// Body radius in meters; also drives missile hit radius.
    var size: Float {
        switch self {
        case .bunny: return 0.28
        case .chick: return 0.2
        case .bee: return 0.16
        case .owlet: return 0.24
        case .frog: return 0.22
        case .shroomling: return 0.26
        case .slime: return 0.34
        }
    }

    var flies: Bool { self == .bee || self == .owlet }
    var speed: Float { flies ? 2.2 : (self == .slime ? 0.9 : 1.6) }

    var color: UIColor {
        switch self {
        case .bunny: return UIColor(red: 0.98, green: 0.95, blue: 0.93, alpha: 1)
        case .chick: return UIColor(red: 1, green: 0.86, blue: 0.3, alpha: 1)
        case .bee: return UIColor(red: 1, green: 0.78, blue: 0.2, alpha: 1)
        case .owlet: return UIColor(red: 0.72, green: 0.56, blue: 0.44, alpha: 1)
        case .frog: return UIColor(red: 0.5, green: 0.85, blue: 0.42, alpha: 1)
        case .shroomling: return UIColor(red: 0.97, green: 0.93, blue: 0.86, alpha: 1)
        case .slime: return UIColor(red: 0.55, green: 0.8, blue: 1, alpha: 1)
        }
    }
}

@MainActor
enum SafariCritterFactory {
    private static let blush = UIColor(red: 1, green: 0.55, blue: 0.62, alpha: 1)
    private static let eyeBlack = UIColor(red: 0.08, green: 0.07, blue: 0.1, alpha: 1)

    /// Returns critter root. Visual body lives in child "body" so the system can squash/stretch it.
    static func make(_ kind: SafariCritterKind) -> Entity {
        let root = Entity()
        root.name = "SafariCritter_\(kind.rawValue)"
        let body = Entity()
        body.name = "body"
        root.addChild(body)

        let s = kind.size
        let mainColor = kind.color
        let torso = part(LowPolyMesh.icosphere(radius: s, subdivisions: 1), mainColor, [0, s, 0])
        torso.components.set(GroundingShadowComponent(castsShadow: true))
        body.addChild(torso)
        addFace(to: body, size: s, eyeHeight: s * 1.15, forward: s * 0.9)

        switch kind {
        case .bunny:
            for x: Float in [-1, 1] {
                let ear = part(LowPolyMesh.icosphere(radius: s * 0.22, subdivisions: 0), mainColor, [x * s * 0.35, s * 2.1, -s * 0.1])
                ear.scale = [0.8, 2.6, 0.6]
                ear.orientation = simd_quatf(angle: x * 0.2, axis: [0, 0, 1])
                ear.addChild(part(LowPolyMesh.icosphere(radius: s * 0.13, subdivisions: 0), blush, [0, 0, s * 0.1]))
                body.addChild(ear)
            }
            body.addChild(part(LowPolyMesh.icosphere(radius: s * 0.25, subdivisions: 0), .white, [0, s * 0.7, -s]))
        case .chick:
            body.addChild(part(LowPolyMesh.frustum(bottomRadius: s * 0.16, topRadius: 0, height: s * 0.3, segments: 4), .systemOrange, [0, s * 0.95, s * 0.95]).then {
                $0.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            })
            body.addChild(part(LowPolyMesh.icosphere(radius: s * 0.12, subdivisions: 0), mainColor, [0, s * 2.05, 0]))
        case .bee:
            for i in 0..<2 {
                body.addChild(part(LowPolyMesh.frustum(bottomRadius: s * 1.01, topRadius: s * 1.01, height: s * 0.18, segments: 10), eyeBlack, [0, s * (0.55 + Float(i) * 0.55), 0]).then {
                    $0.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                    $0.position.z = -s * 0.2 - Float(i) * s * 0.35
                    $0.position.y = s
                })
            }
            for x: Float in [-1, 1] {
                let wing = part(LowPolyMesh.icosphere(radius: s * 0.5, subdivisions: 0), UIColor(white: 1, alpha: 1), [x * s * 0.7, s * 1.8, -s * 0.2])
                wing.scale = [1, 0.15, 0.6]
                wing.name = "wing"
                if var m = wing.model?.materials.first as? PhysicallyBasedMaterial {
                    m.blending = .transparent(opacity: 0.6); wing.model?.materials = [m]
                }
                body.addChild(wing)
            }
        case .owlet:
            for x: Float in [-1, 1] {
                body.addChild(part(LowPolyMesh.frustum(bottomRadius: s * 0.15, topRadius: 0, height: s * 0.45, segments: 4), mainColor, [x * s * 0.55, s * 1.75, 0]))
                let wing = part(LowPolyMesh.icosphere(radius: s * 0.45, subdivisions: 0), UIColor(red: 0.55, green: 0.4, blue: 0.3, alpha: 1), [x * s * 0.95, s * 0.95, 0])
                wing.scale = [0.4, 1, 0.8]
                wing.name = "wing"
                body.addChild(wing)
            }
            body.addChild(part(LowPolyMesh.icosphere(radius: s * 0.7, subdivisions: 1), UIColor(red: 0.95, green: 0.88, blue: 0.76, alpha: 1), [0, s * 0.8, s * 0.42]).then { $0.scale = [1, 1, 0.5] })
        case .frog:
            torso.scale = [1.15, 0.8, 1]
            for x: Float in [-1, 1] {
                body.addChild(part(LowPolyMesh.icosphere(radius: s * 0.32, subdivisions: 1), kind.color, [x * s * 0.45, s * 1.45, s * 0.35]))
            }
        case .shroomling:
            let cap = part(LowPolyMesh.icosphere(radius: s * 1.25, subdivisions: 1), UIColor(red: 0.92, green: 0.26, blue: 0.3, alpha: 1), [0, s * 1.85, 0])
            cap.scale = [1, 0.55, 1]
            body.addChild(cap)
            for i in 0..<5 {
                let a = Float(i) * 1.25
                body.addChild(part(LowPolyMesh.icosphere(radius: s * 0.14, subdivisions: 0), .white, [cos(a) * s * 0.7, s * 2.3, sin(a) * s * 0.7]))
            }
        case .slime:
            torso.scale = [1.15, 0.85, 1.15]
            if var m = torso.model?.materials.first as? PhysicallyBasedMaterial {
                m.blending = .transparent(opacity: 0.8); m.roughness = .init(floatLiteral: 0.08); m.clearcoat = .init(floatLiteral: 1)
                torso.model?.materials = [m]
            }
            body.addChild(part(LowPolyMesh.icosphere(radius: s * 0.18, subdivisions: 0), .white, [s * 0.4, s * 1.5, s * 0.4]).then {
                $0.model?.materials = [LowPolyMesh.material(.white, roughness: 0.1, emissive: 0.4)]
            })
        }
        return root
    }

    private static func part(_ mesh: MeshResource, _ color: UIColor, _ pos: SIMD3<Float>) -> ModelEntity {
        let e = ModelEntity(mesh: mesh, materials: [LowPolyMesh.material(color)])
        e.position = pos
        return e
    }

    /// Big glossy eyes with specular highlights + blush cheeks. Critter faces +Z.
    private static func addFace(to body: Entity, size s: Float, eyeHeight: Float, forward: Float) {
        for x: Float in [-1, 1] {
            let eye = ModelEntity(mesh: LowPolyMesh.icosphere(radius: s * 0.17, subdivisions: 1),
                                  materials: [LowPolyMesh.material(eyeBlack, roughness: 0.05, clearcoat: 1)])
            eye.position = [x * s * 0.36, eyeHeight, forward * 0.92]
            eye.scale = [0.9, 1.15, 0.7]
            let shine = ModelEntity(mesh: LowPolyMesh.icosphere(radius: s * 0.06, subdivisions: 0),
                                    materials: [LowPolyMesh.material(.white, roughness: 0, emissive: 0.8)])
            shine.position = [s * 0.05, s * 0.07, s * 0.12]
            eye.addChild(shine)
            body.addChild(eye)

            let cheek = ModelEntity(mesh: LowPolyMesh.icosphere(radius: s * 0.12, subdivisions: 0),
                                    materials: [LowPolyMesh.material(blush, roughness: 0.8)])
            cheek.position = [x * s * 0.6, eyeHeight - s * 0.28, forward * 0.78]
            cheek.scale = [1, 0.6, 0.3]
            body.addChild(cheek)
        }
    }
}
