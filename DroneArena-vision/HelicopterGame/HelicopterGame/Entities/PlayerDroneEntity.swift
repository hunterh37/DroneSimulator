//
//  PlayerDroneEntity.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import RealityKit
import UIKit
import simd
import Combine
import SwiftUI

public class PlayerDroneEntity: Entity, HasModel, HasPhysics {
    public var droneState: DroneState = .idle
    public var parcelMountPoint: Entity?
    public var attachedParcel: PackageEntity?

    // Animation properties
    private var animationController: AnimationPlaybackController?
    private var droneModelEntity: Entity?

    // Particle trail
    private var trailEntity: DroneTrailParticleEntity?

    // Debug toggle for collision visualization (set to true to see collision shapes)
    public static var showCollisionDebug: Bool = false

    // MARK: - Active drone cache
    // Weakly-held reference to the most recently created player drone. Set in init()
    // and automatically cleared by ARC when the drone is deallocated, so it stays
    // correct across respawns (a new drone overwrites it) and teardown (it nils out).
    // Systems use this to avoid an O(all entities) scene walk every frame.
    private static weak var _current: PlayerDroneEntity?

    /// The active player drone, or nil if there isn't one currently in a scene.
    /// Validated against `scene` so a removed-but-not-yet-deallocated drone is treated
    /// as absent, matching the previous scene-scan behavior.
    public static var current: PlayerDroneEntity? {
        if let drone = _current, drone.scene != nil {
            return drone
        }
        return nil
    }

    // Health system
    public var currentHealth: Int = 4
    public var maxHealth: Int = 4

    /// True while the drone is crashed in Time Trial: the course system owns the
    /// transform (fall + rest on pad) and normal flight input must be suppressed.
    public var isCrashActive: Bool = false

    public required init() {
        super.init()
        // Register as the active player drone for the shared cache.
        PlayerDroneEntity._current = self
        setupDroneVisual()
        setupPhysics()
        setupParcelMount()
        setupParticleTrail()
    }

    private func setupDroneVisual() {
        // Get selected drone model from LoadoutManager, fallback to "Drone"
        let selectedDrone = GameContext.shared.loadout.selectedDrone
        let selectedModelName = selectedDrone?.modelName ?? "Drone"

        if let style = LowPolyDroneStyle.from(modelName: selectedModelName) {
            let livery = DroneLivery(primary: UIColor(hexString: selectedDrone?.primaryColor ?? "ED3833"),
                                     accent: UIColor(hexString: selectedDrone?.accentColor ?? "FFD933"))
            let visual = LowPolyDroneFactory.make(style, livery: livery)
            addChild(visual)
            droneModelEntity = visual
            GameContext.shared.sound.playDroneSound(entity: visual)
            addDroneHover(to: visual)
            gameLog("[PlayerDrone] Built low-poly drone \(style.rawValue)")
            return
        }

        // Load the selected drone .usdz model
        guard let droneURL = Bundle.main.url(forResource: selectedModelName, withExtension: "usdz") else {
            gameLog("Error: Could not find \(selectedModelName).usdz in bundle")
            setupFallbackDroneVisual()
            return
        }

        Task {
            do {
                let droneEntity = try await Entity(contentsOf: droneURL)

                GameContext.shared.sound.playDroneSound(entity: droneEntity)

                // Scale the drone to appropriate size if needed
                droneEntity.transform.scale = [1, 1, 1] // Adjust scale as needed

                // Set the model component and start animations
                await MainActor.run {
                    self.addChild(droneEntity)
                    self.droneModelEntity = droneEntity
                    if let modelComponent = droneEntity.components[ModelComponent.self] {
                        self.components.set(modelComponent)
                    }
                    self.applyPlayerColor(to: droneEntity)
                    self.startDroneAnimation()
                    // Realistic idle micro-hover + motion banking on the visual model.
                    self.addDroneHover(to: droneEntity)
                }

                gameLog("✅ [PlayerDrone] Loaded selected drone model: \(selectedModelName).usdz")
            } catch {
                gameLog("Error loading \(selectedModelName).usdz: \(error)")
                await MainActor.run {
                    self.setupFallbackDroneVisual()
                }
            }
        }
    }

    private func setupFallbackDroneVisual() {
        // Missing USDZ: use the procedural Razor so the drone still reads as a real quad.
        let visual = LowPolyDroneFactory.make(.razor, livery: DroneLivery.presets[1])
        addChild(visual)
        droneModelEntity = visual
        addDroneHover(to: visual)
    }

    private func setupPhysics() {
        // Reduced collision box to prevent self-hitting with missiles (was 0.3x0.1x0.3, now 0.12x0.05x0.12)
        let width: Float = 0.12
        let height: Float = 0.05
        let depth: Float = 0.12
        let shape = ShapeResource.generateBox(width: width, height: height, depth: depth)
        let material = PhysicsMaterialResource.generate(friction: 0.1, restitution: 0.2)

        self.components.set(PhysicsBodyComponent(
            massProperties: .default,
            material: material,
            mode: .kinematic
        ))

        // Use collision group 1 (own drone) - missiles in group 2 won't collide with this
        let collisionComponent = CollisionComponent(
            shapes: [shape],
            mode: .default,
            filter: CollisionFilter(group: CollisionGroup(rawValue: 1 << 0), mask: CollisionGroup.all)
        )
        self.components.set(collisionComponent)

        // Add debug collision visualizer if enabled
        if PlayerDroneEntity.showCollisionDebug {
            addCollisionDebugVisualizer(width: width, height: height, depth: depth)
        }
    }

    private func addCollisionDebugVisualizer(width: Float, height: Float, depth: Float) {
        // Create a visual representation of the collision box using a semi-transparent box
        let debugMesh = MeshResource.generateBox(width: width, height: height, depth: depth)

        // Use a bright, semi-transparent material so we can see both the drone and collision shape
        var debugMaterial = UnlitMaterial(color: .green)
        debugMaterial.color = .init(tint: .green.withAlphaComponent(0.3)) // 30% opacity green

        let debugModel = ModelComponent(mesh: debugMesh, materials: [debugMaterial])

        // Create a child entity for the debug visualizer
        let debugEntity = Entity()
        debugEntity.name = "CollisionDebugVisualizer"
        debugEntity.components.set(debugModel)

        self.addChild(debugEntity)

        gameLog("🔍 [PlayerDrone] Added collision debug visualizer: box \(width)x\(height)x\(depth)")
    }

    private func setupParcelMount() {
        let mountPoint = Entity()
        mountPoint.transform.translation = SIMD3<Float>(0, -0.1, 0)
        addChild(mountPoint)
        self.parcelMountPoint = mountPoint
    }

    private func applyPlayerColor(to entity: Entity) {
        // Get the player's cached color from ProfileManager
        let playerColor = GameContext.shared.playerProfile.playerColor

        // Convert SwiftUI Color to UIColor, then to RealityKit color components
        let uiColor = UIColor(playerColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Apply color to material_0 if it exists
        applyColorToEntity(entity, red: Float(red), green: Float(green), blue: Float(blue))
    }

    private func applyColorToEntity(_ entity: Entity, red: Float, green: Float, blue: Float) {
        // Check if this entity has a model component
        if var modelComponent = entity.components[ModelComponent.self] {
            var updatedMaterials: [RealityKit.Material] = []

            for (index, material) in modelComponent.materials.enumerated() {
                if let unlitMaterial = material as? UnlitMaterial {
                    // For UnlitMaterial, update the color using SimpleMaterial approach
                    var newMaterial = unlitMaterial
                    newMaterial.color = .init(tint: UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1.0))
                    updatedMaterials.append(newMaterial)
                    gameLog("🎨 Applied player color to UnlitMaterial at index \(index)")
                } else if let simpleMaterial = material as? SimpleMaterial {
                    // For SimpleMaterial, update the color
                    var newMaterial = simpleMaterial
                    newMaterial.color = .init(tint: UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1.0))
                    updatedMaterials.append(newMaterial)
                    gameLog("🎨 Applied player color to SimpleMaterial at index \(index)")
                } else {
                    // Keep original material if we can't modify it
                    updatedMaterials.append(material)
                }
            }

            // Update the model component with new materials
            modelComponent.materials = updatedMaterials
            entity.components.set(modelComponent)
        }

        // Recursively apply to child entities
        for child in entity.children {
            applyColorToEntity(child, red: red, green: green, blue: blue)
        }
    }

    public func attachPackage(_ package: PackageEntity) {
        guard attachedParcel == nil, let mountPoint = parcelMountPoint else { return }

        attachedParcel = package
        package.transform.translation = .zero
        mountPoint.addChild(package)
        droneState = .carryingParcel

        // Disable package physics while attached
        package.components.remove(PhysicsBodyComponent.self)
    }

    public func detachPackage() -> PackageEntity? {
        guard let package = attachedParcel else { return nil }

        // Remove from mount point
        package.removeFromParent()
        attachedParcel = nil
        droneState = .flying

        // Re-enable package physics
        let size: Float = package.spec.size == .medium ? 0.2 : 0.3
        let shape = ShapeResource.generateBox(width: size, height: size, depth: size)
        let material = PhysicsMaterialResource.generate(friction: 0.5, restitution: 0.3)

        let massProperties = PhysicsMassProperties(mass: package.spec.mass, inertia: SIMD3<Float>(1.0, 1.0, 1.0))
        package.components.set(PhysicsBodyComponent(
            massProperties: massProperties,
            material: material,
            mode: .dynamic
        ))

        // Set package position to drone's world position
        package.transform = self.transform

        return package
    }

    // Legacy support
    public func attachParcel(_ parcel: PackageEntity) {
        attachPackage(parcel)
    }

    public func detachParcel() -> PackageEntity? {
        return detachPackage()
    }





    // MARK: - Animation Methods

    private func startDroneAnimation() {
        guard let droneEntity = droneModelEntity else { return }

        // Start the first available animation on repeat
        if let firstAnimation = droneEntity.availableAnimations.first {
            animationController = droneEntity.playAnimation(firstAnimation.repeat())
        }
    }

    private func updateAnimationSpeed() {
        guard let controller = animationController else { return }

        // Since we removed velocity tracking, just use normal animation speed
        let animationSpeed: Float = 1.0

        // Only update if speed changed significantly to avoid constant updates
        if abs(controller.speed - animationSpeed) > 0.1 {
            controller.speed = animationSpeed
        }
    }

    // MARK: - Particle Trail Methods

    private func setupParticleTrail() {
        // Create particle trail using local player's color
        trailEntity = DroneTrailFactory.createLocalPlayerTrail()

        if let trail = trailEntity {
            // Add trail as child (it will emit particles to world space)
            addChild(trail)
            gameLog("🌟 Added particle trail to local player drone")
        }
    }

    public func setTrailWorldParent(_ worldParent: Entity) {
        trailEntity?.setWorldParent(worldParent)
    }

    public func updateTrailColor() {
        // Update trail color when player changes their color
        trailEntity?.setTrailColor(UIColor(swiftUIColor: GameContext.shared.playerProfile.playerColor))
    }

    public func setTrailEnabled(_ enabled: Bool) {
        trailEntity?.setTrailEnabled(enabled)
    }

    // MARK: - Health System

    public func takeDamage() {
        currentHealth -= 1
        gameLog("💔 [PlayerDrone] Took damage! Health: \(currentHealth)/\(maxHealth)")

        GameContext.shared.sound.playDamageTakenSound(entity: self)

        // Post notification for UI update
        NotificationCenter.default.post(
            name: .playerTookDamage,
            object: nil,
            userInfo: ["currentHealth": currentHealth, "maxHealth": maxHealth]
        )

        if currentHealth <= 0 {
            handleDeath()
        }
    }

    private func handleDeath() {
        gameLog("💀 [PlayerDrone] Player died!")

        GameContext.shared.sound.playDestructionSound(entity: self)

        // Post death notification
        NotificationCenter.default.post(
            name: .playerDied,
            object: nil
        )
    }

    public func resetHealth() {
        currentHealth = maxHealth
        gameLog("❤️ [PlayerDrone] Health reset to \(maxHealth)")
    }
}

// MARK: - Player drone lookup

public extension PlayerDroneEntity {
    /// Finds the active player drone in the given scene.
    ///
    /// Fast path: returns the cached `current` drone in O(1) instead of walking
    /// the entire entity tree. Fallback: scans the scene recursively, which is
    /// only reached in the rare window before the drone registers itself or after
    /// teardown. This is the single shared home for the player-drone lookup that
    /// used to be duplicated across several systems.
    static func find(in scene: RealityKit.Scene) -> Entity? {
        if let cached = current {
            return cached
        }

        let allEntitiesQuery = EntityQuery(where: .has(Transform.self))
        for entity in scene.performQuery(allEntitiesQuery) {
            if let drone = findRecursive(in: entity) {
                return drone
            }
        }
        return nil
    }

    /// Recursively searches an entity subtree for the player drone, matching by
    /// type or by a name containing "PlayerDrone".
    static func findRecursive(in entity: Entity) -> Entity? {
        if entity is PlayerDroneEntity || entity.name.contains("PlayerDrone") {
            return entity
        }

        for child in entity.children {
            if let drone = findRecursive(in: child) {
                return drone
            }
        }
        return nil
    }
}
