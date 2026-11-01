//
//  GamepadHandOffsetSettings.swift
//  HelicopterGame
//
//  Single source of truth for where the world-joystick rig (3D gamepad / pillar)
//  sits relative to the user's right-hand anchor.
//
//  The rig is parented to an `AnchorEntity(.hand(.right, …))`, and this object's
//  `offset` is written straight onto the rig's local `position`. Editing any of
//  the X/Y/Z values (e.g. from the in-game debug sliders) calls `apply()` so the
//  controller moves live in the immersive scene, and the value is persisted to
//  UserDefaults so it survives relaunches.
//

import Foundation
import simd
import RealityKit
import Observation

@MainActor
@Observable
public final class GamepadHandOffsetSettings {

    public static let shared = GamepadHandOffsetSettings()

    private static let keyX = "gamepad.hand.offset.x"
    private static let keyY = "gamepad.hand.offset.y"
    private static let keyZ = "gamepad.hand.offset.z"

    /// Sensible starting pose: a little below and in front of the palm anchor.
    public static let defaultOffset = SIMD3<Float>(0.0, -0.05, -0.08)

    public var x: Float { didSet { persist(); apply() } }
    public var y: Float { didSet { persist(); apply() } }
    public var z: Float { didSet { persist(); apply() } }

    /// The hand-anchored rig whose local position tracks this offset. Weak so we
    /// never keep a torn-down immersive scene alive.
    public weak var anchoredEntity: Entity?

    private init() {
        let d = UserDefaults.standard
        x = (d.object(forKey: Self.keyX) as? Float) ?? Self.defaultOffset.x
        y = (d.object(forKey: Self.keyY) as? Float) ?? Self.defaultOffset.y
        z = (d.object(forKey: Self.keyZ) as? Float) ?? Self.defaultOffset.z
    }

    public var offset: SIMD3<Float> { SIMD3<Float>(x, y, z) }

    /// Attach the rig that should follow the offset and snap it into place.
    public func attach(_ entity: Entity) {
        anchoredEntity = entity
        apply()
    }

    public func reset() {
        x = Self.defaultOffset.x
        y = Self.defaultOffset.y
        z = Self.defaultOffset.z
    }

    /// Push the current offset onto the anchored rig.
    public func apply() {
        anchoredEntity?.position = offset
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(x, forKey: Self.keyX)
        d.set(y, forKey: Self.keyY)
        d.set(z, forKey: Self.keyZ)
    }
}
