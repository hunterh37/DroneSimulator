//
//  CrateDeliveryModels.swift
//  HelicopterGame
//
//  Crate Delivery ("FOLD FREIGHT"): data, lore, ECS components.
//
//  Lore: Sortation Hub 9, the interdimensional freight exchange of the
//  Courier Guild, collapsed during a shift change. Its intake rifts now
//  open onto whatever room is nearest, and yours is nearest. Cargo meant
//  for three sister realms phases through your ceiling, still humming
//  with transit charge, so it bounces and skitters until it is sorted.
//  The Guild has licensed your drone as an emergency Sorter. Hook each
//  crate with the claw and set it on the Relay Gate of its realm. Every
//  correct delivery bleeds charge out of the rift and buys the Fold more
//  time. Misroutes feed it. The Hub never stops sending.
//

import RealityKit
import UIKit
import simd

enum CrateColor: Int, CaseIterable {
    case red, blue, green

    var ui: UIColor {
        switch self {
        case .red: return UIColor(red: 1.0, green: 0.25, blue: 0.2, alpha: 1)
        case .blue: return UIColor(red: 0.2, green: 0.55, blue: 1.0, alpha: 1)
        case .green: return UIColor(red: 0.2, green: 1.0, blue: 0.5, alpha: 1)
        }
    }

    /// Realm the crate is bound for.
    var realm: String {
        switch self {
        case .red: return "Ember Reach"
        case .blue: return "Tidewell"
        case .green: return "Verdance"
        }
    }

    var manifest: String {
        switch self {
        case .red: return "Forge cores, sealed heat"
        case .blue: return "Pressurized tide glass"
        case .green: return "Live seed vaults"
        }
    }

    /// Gate position on the floor in front of the player (root space).
    var gatePosition: SIMD3<Float> {
        switch self {
        case .red: return [-0.42, 0.0, -0.95]
        case .blue: return [0.0, 0.0, -1.15]
        case .green: return [0.42, 0.0, -0.95]
        }
    }
}

enum CrateLore {
    static let title = "Fold Freight"
    static let kicker = "Courier Guild emergency contract"
    static let briefing = """
    Sortation Hub 9 has collapsed. Its intake rifts are opening into your room.
    Crates bound for three realms are falling through, still charged and bouncing.
    Hook each crate with the claw and set it on the Relay Gate of its color.
    Correct deliveries drain the rift and buy time. Misroutes cost time.
    The Hub never stops sending. Hold the Fold as long as you can.
    """
    static let rankTitles = [
        "Temp Sorter", "Sorter", "Senior Sorter", "Rift Handler",
        "Gate Warden", "Fold Keeper", "Hub Legend",
    ]

    static func rank(for level: Int) -> String {
        rankTitles[min(max(level - 1, 0), rankTitles.count - 1)]
    }
}

/// Endless difficulty curve. Level rises every few deliveries.
struct CrateDifficulty {
    let level: Int

    var timeBonus: Double { max(3.0, 11.0 - Double(level - 1) * 0.9) }
    var misroutePenalty: Double { min(12.0, 5.0 + Double(level - 1) * 0.8) }
    var maxLooseCrates: Int { min(9, 3 + level / 2) }
    var spawnInterval: Double { max(1.4, 4.5 - Double(level - 1) * 0.35) }
    /// Transit charge: how hard loose crates get kicked around.
    var jitterImpulse: Float { min(0.9, 0.25 + Float(level - 1) * 0.07) }
    var jitterInterval: Double { max(1.2, 3.5 - Double(level - 1) * 0.25) }
    /// Clock drain multiplier: time moves faster the deeper the shift goes.
    var drainRate: Double { 1.0 + Double(level - 1) * 0.06 }

    static let deliveriesPerLevel = 4
    static let startTime: Double = 45
}

enum CrateTutorialStep: Int, CaseIterable {
    case hover, drop, deliver, stack, done

    var headline: String {
        switch self {
        case .hover: return "Hover over the crate"
        case .drop: return "Tap the red button"
        case .deliver: return "Carry it to its gate"
        case .stack: return "Stack a second crate"
        case .done: return "Contract signed"
        }
    }

    var detail: String {
        switch self {
        case .hover: return "Fly the drone directly above the glowing training crate."
        case .drop: return "The red button on the control panel drops the claw. It hooks anything right under it."
        case .deliver: return "Fly over the matching Relay Gate. The claw releases on its own."
        case .stack: return "Crates stacked on a gate score a multiplier. Drop the next one on top."
        case .done: return "The rifts are open. Keep the Fold alive."
        }
    }
}

// MARK: - Components

struct CrateComponent: Component {
    enum State { case loose, carried, delivered }
    var color: CrateColor
    var state: State = .loose
    var isTraining = false
    /// Seconds since the crate settled on a gate, used for stack checks.
    var settledFor: Float = 0
}

struct CrateClawComponent: Component {
    enum Phase { case idle, lowering, raising }
    var phase: Phase = .idle
    var reach: Float = CrateClawComponent.rest
    var carrying: Entity.ID?
    var grip: Float = 0

    static let rest: Float = 0.1
    static let maxReach: Float = 1.1
    static let lowerSpeed: Float = 1.6
    static let raiseSpeed: Float = 1.2
    static let grabRadius: Float = 0.11
}

struct CrateGateComponent: Component {
    var color: CrateColor
    var pulse: Float = 0
}

struct CratePopComponent: Component {
    var age: Float = 0
    var life: Float = 1.3
    var rise: Float = 0.35
    var baseY: Float
    var peakScale: Float = 1
}

struct CratePropComponent: Component {
    enum Motion { case spin(Float), pulse(Float), blink(Float), sway(Float) }
    var motion: Motion
    var phase: Float = .random(in: 0...6)
    var baseScale: SIMD3<Float> = .one
    var baseOrientation: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0])
    var captured = false
}
