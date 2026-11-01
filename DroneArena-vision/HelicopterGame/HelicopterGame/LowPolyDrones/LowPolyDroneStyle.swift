//
//  LowPolyDroneStyle.swift
//  HelicopterGame
//
//  Renderer-agnostic part lists for procedural low-poly drones.
//  One spec feeds both the RealityKit builder (in-game) and the SceneKit builder (menu preview).
//  Units are meters, forward is -Z, up is +Y. Motor-to-motor span is roughly 0.26 m (5 inch class).
//

import Foundation
import simd

enum DronePartRole: CaseIterable {
    case body, accent, carbon, metal, glow, canopy, prop, rubber
}

enum DronePartShape {
    case box(SIMD3<Float>)
    /// Faceted cylinder or frustum, centered on its own origin, axis along +Y.
    case frustum(bottom: Float, top: Float, height: Float, segments: Int)
    case ico(radius: Float, subdivisions: Int)
    /// Rotor disc: hub + blades, spins about +Y.
    case rotor(radius: Float, blades: Int)
    /// Thin ring (prop duct), axis along +Y.
    case duct(radius: Float, height: Float, thickness: Float)
}

struct DronePart {
    var shape: DronePartShape
    var position: SIMD3<Float>
    var euler: SIMD3<Float> = .zero
    var role: DronePartRole
    /// Rotor spin direction (+1 CCW, -1 CW, 0 static).
    var spin: Float = 0
}

enum LowPolyDroneStyle: String, CaseIterable, Codable, Identifiable {
    case razor      // 5 inch true-X freestyle racer
    case hornet     // stretched-X race frame with canopy
    case cinewhoop  // ducted cinematic whoop
    case falcon     // hexacopter
    case wasp       // H-frame speed build
    case titan      // X8 coaxial heavy lifter

    var id: String { rawValue }
    var modelName: String { "lp.\(rawValue)" }

    static func from(modelName: String) -> LowPolyDroneStyle? {
        guard modelName.hasPrefix("lp.") else { return nil }
        return LowPolyDroneStyle(rawValue: String(modelName.dropFirst(3)))
    }

    var displayName: String {
        switch self {
        case .razor: return "Razor X5"
        case .hornet: return "Hornet SX"
        case .cinewhoop: return "Cinewhoop Duo"
        case .falcon: return "Falcon Hex"
        case .wasp: return "Wasp H-Frame"
        case .titan: return "Titan X8"
        }
    }

    /// Racing performance used by CPU pilots and the league (1.0 = baseline).
    var raceSpeedFactor: Float {
        switch self {
        case .razor: return 1.02
        case .hornet: return 1.05
        case .cinewhoop: return 0.94
        case .falcon: return 0.98
        case .wasp: return 1.07
        case .titan: return 0.92
        }
    }

    var parts: [DronePart] {
        switch self {
        case .razor: return Self.xFrame(arm: 0.13, angle: .pi / 4, stretch: 1.0, canopy: false)
        case .hornet: return Self.xFrame(arm: 0.135, angle: .pi / 5.2, stretch: 1.25, canopy: true)
        case .cinewhoop: return Self.cinewhoopParts()
        case .falcon: return Self.multiRotor(count: 6, arm: 0.15, coaxial: false)
        case .wasp: return Self.hFrameParts()
        case .titan: return Self.multiRotor(count: 4, arm: 0.16, coaxial: true)
        }
    }

    // MARK: - Shared builders

    private static func motor(at p: SIMD3<Float>, spin: Float, propRadius: Float, blades: Int = 3, flip: Bool = false) -> [DronePart] {
        let dir: Float = flip ? -1 : 1
        return [
            DronePart(shape: .frustum(bottom: 0.014, top: 0.012, height: 0.018, segments: 8), position: p + [0, 0.009 * dir, 0], role: .metal),
            DronePart(shape: .frustum(bottom: 0.006, top: 0.004, height: 0.012, segments: 6), position: p + [0, 0.024 * dir, 0], role: .accent),
            DronePart(shape: .rotor(radius: propRadius, blades: blades), position: p + [0, 0.030 * dir, 0], role: .prop, spin: spin)
        ]
    }

    private static func stack(stretch: Float, canopy: Bool) -> [DronePart] {
        var p: [DronePart] = [
            // Carbon bottom plate + top plate
            DronePart(shape: .box([0.045, 0.004, 0.09 * stretch]), position: [0, -0.004, 0], role: .carbon),
            DronePart(shape: .box([0.040, 0.003, 0.075 * stretch]), position: [0, 0.030, 0.004], role: .carbon),
            // Flight stack (FC/ESC) between plates
            DronePart(shape: .box([0.030, 0.012, 0.030]), position: [0, 0.008, 0.005], role: .body),
            // Standoffs
            DronePart(shape: .frustum(bottom: 0.0025, top: 0.0025, height: 0.032, segments: 5), position: [0.017, 0.013, -0.03 * stretch], role: .metal),
            DronePart(shape: .frustum(bottom: 0.0025, top: 0.0025, height: 0.032, segments: 5), position: [-0.017, 0.013, -0.03 * stretch], role: .metal),
            DronePart(shape: .frustum(bottom: 0.0025, top: 0.0025, height: 0.032, segments: 5), position: [0.017, 0.013, 0.035 * stretch], role: .metal),
            DronePart(shape: .frustum(bottom: 0.0025, top: 0.0025, height: 0.032, segments: 5), position: [-0.017, 0.013, 0.035 * stretch], role: .metal),
            // FPV camera (tilted up) with lens
            DronePart(shape: .box([0.020, 0.018, 0.018]), position: [0, 0.014, -0.040 * stretch], euler: [0.35, 0, 0], role: .rubber),
            DronePart(shape: .frustum(bottom: 0.007, top: 0.006, height: 0.010, segments: 8), position: [0, 0.017, -0.052 * stretch], euler: [.pi / 2 + 0.35, 0, 0], role: .glow),
            // Battery strapped on top
            DronePart(shape: .box([0.034, 0.024, 0.062 * stretch]), position: [0, 0.045, 0.006], role: .body),
            DronePart(shape: .box([0.036, 0.004, 0.012]), position: [0, 0.058, 0.006], role: .accent),
            // VTX antenna
            DronePart(shape: .frustum(bottom: 0.0015, top: 0.0015, height: 0.04, segments: 4), position: [0, 0.045, 0.055 * stretch], euler: [-0.6, 0, 0], role: .rubber),
            DronePart(shape: .ico(radius: 0.006, subdivisions: 0), position: [0, 0.062, 0.068 * stretch], role: .accent),
            // Rear LED bar
            DronePart(shape: .box([0.03, 0.004, 0.004]), position: [0, 0.002, 0.046 * stretch], role: .glow)
        ]
        if canopy {
            p.append(DronePart(shape: .ico(radius: 0.034, subdivisions: 1), position: [0, 0.028, -0.012], role: .canopy))
        }
        return p
    }

    /// True-X or stretched-X quad.
    private static func xFrame(arm: Float, angle: Float, stretch: Float, canopy: Bool) -> [DronePart] {
        var parts = stack(stretch: stretch, canopy: canopy)
        let angles: [Float] = [angle, .pi - angle, .pi + angle, 2 * .pi - angle]
        let spins: [Float] = [1, -1, 1, -1]
        for (i, a) in angles.enumerated() {
            let dir = SIMD3<Float>(sin(a), 0, -cos(a))
            let tip = dir * arm
            parts.append(DronePart(shape: .box([0.014, 0.005, arm]), position: tip * 0.5, euler: [0, -a, 0], role: .carbon))
            parts += motor(at: tip + [0, 0.002, 0], spin: spins[i], propRadius: 0.064)
        }
        return parts
    }

    private static func hFrameParts() -> [DronePart] {
        var parts = stack(stretch: 1.3, canopy: false)
        // Two long side rails + cross braces
        for x: Float in [-0.075, 0.075] {
            parts.append(DronePart(shape: .box([0.012, 0.006, 0.22]), position: [x, 0, 0], role: .carbon))
        }
        parts.append(DronePart(shape: .box([0.15, 0.005, 0.014]), position: [0, 0, -0.05], role: .carbon))
        parts.append(DronePart(shape: .box([0.15, 0.005, 0.014]), position: [0, 0, 0.05], role: .carbon))
        // Aero nose fin
        parts.append(DronePart(shape: .frustum(bottom: 0.018, top: 0, height: 0.05, segments: 4), position: [0, 0.03, -0.085], euler: [-.pi / 2, 0, 0], role: .accent))
        let spots: [(SIMD3<Float>, Float)] = [([0.075, 0.003, -0.11], 1), ([-0.075, 0.003, -0.11], -1), ([0.075, 0.003, 0.11], -1), ([-0.075, 0.003, 0.11], 1)]
        for (p, s) in spots { parts += motor(at: p, spin: s, propRadius: 0.062, blades: 2) }
        return parts
    }

    private static func cinewhoopParts() -> [DronePart] {
        var parts: [DronePart] = [
            DronePart(shape: .box([0.08, 0.006, 0.08]), position: [0, 0, 0], euler: [0, .pi / 4, 0], role: .carbon),
            DronePart(shape: .ico(radius: 0.038, subdivisions: 1), position: [0, 0.028, 0], role: .body),
            DronePart(shape: .box([0.028, 0.022, 0.03]), position: [0, 0.02, -0.042], role: .rubber),
            DronePart(shape: .frustum(bottom: 0.011, top: 0.009, height: 0.012, segments: 8), position: [0, 0.02, -0.06], euler: [.pi / 2, 0, 0], role: .glow),
            DronePart(shape: .box([0.03, 0.02, 0.05]), position: [0, 0.058, 0.004], role: .accent)
        ]
        let d: Float = 0.078
        let spots: [(SIMD3<Float>, Float)] = [([d, 0, -d], 1), ([-d, 0, -d], -1), ([d, 0, d], -1), ([-d, 0, d], 1)]
        for (p, s) in spots {
            parts.append(DronePart(shape: .duct(radius: 0.058, height: 0.026, thickness: 0.006), position: p + [0, 0.018, 0], role: .body))
            parts.append(DronePart(shape: .box([0.012, 0.004, 0.11]), position: p * 0.5, euler: [0, atan2(p.x, p.z), 0], role: .carbon))
            parts += motor(at: p, spin: s, propRadius: 0.05, blades: 5)
        }
        return parts
    }

    /// Hex or coaxial X8.
    private static func multiRotor(count: Int, arm: Float, coaxial: Bool) -> [DronePart] {
        var parts: [DronePart] = [
            DronePart(shape: .frustum(bottom: 0.06, top: 0.05, height: 0.02, segments: count * 2), position: [0, 0.005, 0], role: .carbon),
            DronePart(shape: .ico(radius: 0.045, subdivisions: 1), position: [0, 0.035, 0], role: .canopy),
            DronePart(shape: .box([0.05, 0.03, 0.08]), position: [0, -0.022, 0], role: .body),
            DronePart(shape: .ico(radius: 0.018, subdivisions: 1), position: [0, -0.045, -0.03], role: .glow)
        ]
        // Landing skids
        for x: Float in [-0.05, 0.05] {
            parts.append(DronePart(shape: .box([0.006, 0.06, 0.006]), position: [x, -0.05, 0], euler: [0, 0, x > 0 ? -0.35 : 0.35], role: .metal))
            parts.append(DronePart(shape: .box([0.008, 0.006, 0.14]), position: [x * 1.4, -0.08, 0], role: .rubber))
        }
        for i in 0..<count {
            let a = (Float(i) + 0.5) / Float(count) * 2 * .pi
            let dir = SIMD3<Float>(sin(a), 0, -cos(a))
            let tip = dir * arm
            let spin: Float = i % 2 == 0 ? 1 : -1
            parts.append(DronePart(shape: .frustum(bottom: 0.006, top: 0.006, height: arm, segments: 6), position: tip * 0.5 + [0, 0.008, 0], euler: [.pi / 2, -a, 0], role: .carbon))
            // Arm tip LED (front arms accent, rear arms glow)
            parts.append(DronePart(shape: .ico(radius: 0.007, subdivisions: 0), position: tip + [0, -0.012, 0], role: dir.z < 0 ? .accent : .glow))
            parts += motor(at: tip + [0, 0.01, 0], spin: spin, propRadius: coaxial ? 0.07 : 0.06, blades: 2)
            if coaxial { parts += motor(at: tip + [0, -0.004, 0], spin: -spin, propRadius: 0.07, blades: 2, flip: true) }
        }
        return parts
    }
}
