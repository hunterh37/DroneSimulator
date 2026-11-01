//
//  DroneTutorialContext.swift
//  HelicopterGame
//
//  Shared, read-mostly handle passed to every tutorial step. It exposes the
//  live game objects a step needs (the player drone, the 3D gamepad) plus an
//  `overlayRoot` entity that owns all tutorial visuals so teardown is a single
//  `removeFromParent()`.
//

#if os(visionOS)
import RealityKit
import simd

@MainActor
public final class DroneTutorialContext {

    /// The live world scene. Held weakly-ish (unowned) — the controller owns the
    /// scene's lifetime and tears the context down first.
    public unowned let worldScene: WorldSceneController

    /// All tutorial-spawned entities (3D text, goal orbs) hang off this node,
    /// which itself lives under `worldScene.rootEntity` so visuals share the
    /// drone's coordinate space.
    public let overlayRoot: Entity

    public init(worldScene: WorldSceneController, overlayRoot: Entity) {
        self.worldScene = worldScene
        self.overlayRoot = overlayRoot
    }

    /// The player's drone, if the scene has spawned it.
    public var playerDrone: Entity? { worldScene.playerDrone }

    /// The joystick stand, if the current control scheme uses it.
    public var gamepad: Entity? { worldScene.gamepadPillar }

    /// The drone's current world-space position.
    public func dronePosition() -> SIMD3<Float>? {
        worldScene.playerDrone?.position(relativeTo: nil)
    }
}
#endif
