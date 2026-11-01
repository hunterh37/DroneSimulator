//
//  RemoteDroneEntity.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/2/25.
//

import RealityKit
import UIKit
import simd
import Combine

public class RemoteDroneEntity: Entity, HasModel {
    public let playerID: String
    public var playerName: String
    public var playerColor: String
    public var droneState: DroneState = .idle
    public var droneModelName: String // The .usdz model file name

    // Visual components
    private var droneModelEntity: Entity?

    // Particle trail
    private var trailEntity: DroneTrailParticleEntity?

    // Debug toggle for collision visualization (set to true to see collision shapes)
    public static var showCollisionDebug: Bool = false

    // Note: Position interpolation is now handled by RemoteDronePositionSystem

    public init(playerID: String, playerName: String, playerColor: String = "#FFFFFF", droneModelName: String = "Drone") {
        self.playerID = playerID
        self.playerName = playerName
        self.playerColor = playerColor
        self.droneModelName = droneModelName
        super.init()

        // Initialize at origin - will be updated when first position message arrives
        self.position = SIMD3<Float>(0, 0, 0)

        setupRemoteDroneVisual()
        setupParticleTrail()

        // Add ECS position tracking for smooth interpolation
        addRemoteDronePositionTracking()

        // Add collision detection for missiles
        setupCollisionDetection()

        // Set proper entity name for identification
        self.name = "RemoteDrone_\(playerID)"

        // Ensure the entity is enabled and visible
        self.isEnabled = true

        gameLog("🚁 [RemoteDroneEntity] Created remote drone for '\(playerName)' (ID: \(playerID))")
    }

    required init() {
        fatalError("Use init(playerID:playerName:) instead")
    }
    
    private var animationController: AnimationPlaybackController?
    
    private func startDroneAnimation() {
        guard let droneEntity = droneModelEntity else {
            gameLog("⚠️ [EnemyDrone] No drone model entity found for animation")
            return
        }

        // Start the first available animation on repeat
        if let firstAnimation = droneEntity.availableAnimations.first {
            animationController = droneEntity.playAnimation(firstAnimation.repeat())
        }
    }

    private func setupRemoteDroneVisual() {
        if let style = LowPolyDroneStyle.from(modelName: droneModelName) {
            let visual = LowPolyDroneFactory.make(style, livery: DroneLivery.presets[abs(droneModelName.hashValue) % DroneLivery.presets.count])
            addChild(visual)
            droneModelEntity = visual
            return
        }
        // Load the specified drone model (.usdz file)
        guard let droneURL = Bundle.main.url(forResource: droneModelName, withExtension: "usdz") else {
            gameLog("Error: Could not find \(droneModelName).usdz in bundle for remote drone")
            setupFallbackRemoteDroneVisual()
            return
        }

        Task {
            do {
                let droneEntity = try await Entity(contentsOf: droneURL)

                // Scale the drone slightly smaller to distinguish from local drone
                droneEntity.transform.scale = [0.25, 0.25, 0.25]

                // Add a different material/tint to distinguish remote drones
                await MainActor.run {
                    self.addChild(droneEntity)
                    self.droneModelEntity = droneEntity
                    if let modelComponent = droneEntity.components[ModelComponent.self] {
                        self.components.set(modelComponent)
                    }
                    self.startDroneAnimation()

                    // Add a subtle tint to distinguish remote drones
                  //  self.addRemoteDroneTint()
                }
            } catch {
                gameLog("Error loading \(droneModelName).usdz for remote drone: \(error)")
                await MainActor.run {
                    self.setupFallbackRemoteDroneVisual()
                }
            }
        }
    }

    private func setupFallbackRemoteDroneVisual() {
        // Fallback to simple shape with different color
        let bodyMesh = MeshResource.generateBox(width: 0.25, height: 0.08, depth: 0.25)
        let bodyMaterial = SimpleMaterial(color: .orange, roughness: 0.3, isMetallic: true)
        let body = ModelEntity(mesh: bodyMesh, materials: [bodyMaterial])

        self.components.set(body.model!)
        addChild(body)
    }

    private func addRemoteDroneTint() {
        // Add a translucent colored overlay to distinguish remote drones
        let overlayMesh = MeshResource.generateBox(width: 0.3, height: 0.12, depth: 0.3)
        var overlayMaterial = UnlitMaterial(color: .orange)
        overlayMaterial.color.tint = UIColor.orange.withAlphaComponent(0.3)

        let overlay = ModelEntity(mesh: overlayMesh, materials: [overlayMaterial])
        overlay.transform.translation.y = 0.01 // Slightly above the main model
        addChild(overlay)
    }

    public func updateFromNetwork(_ positionMessage: DronePositionMessage) {
        // Update drone state
        droneState = positionMessage.droneState

        // Update the RemoteDronePositionComponent directly on this entity
        if var component = self.components[RemoteDronePositionComponent.self] {
            component.updateTarget(position: positionMessage.position, rotation: positionMessage.rotation)
            self.components[RemoteDronePositionComponent.self] = component
            gameLog("🎯 [RemoteDroneEntity] Updated position component for player \(playerID): pos=\(positionMessage.position)")
        } else {
            gameLog("⚠️ [RemoteDroneEntity] No RemoteDronePositionComponent found on entity for player \(playerID)")
        }

        // Add a subtle visual indicator based on drone state
        updateStateVisual()
    }

    private func updateStateVisual() {
        // Optional: Add visual indicators based on drone state
        // For example, change glow color or add particle effects
        switch droneState {
        case .idle:
            // Default appearance
            break
        case .flying:
            // Maybe add a subtle glow
            break
        case .carryingParcel:
            // Add indication that this drone is carrying something
            break
        case .recharging:
            // Add charging effect
            break
        case .emergency:
            // Add warning effect
            break
        }
    }

    // Add a name tag above the drone
    public func addNameTag() {
        // Convert hex color to UIColor
        let textColor = UIColor(hex: playerColor) ?? .white

        // Create a simple text entity for the player name with player's color
        let nameText = ModelEntity(
            mesh: .generateText(playerName, extrusionDepth: 0.01, font: .systemFont(ofSize: 0.1)),
            materials: [SimpleMaterial(color: textColor, isMetallic: false)]
        )
        nameText.scale = .init(repeating: 0.3)

        // Position above the drone
        nameText.transform.translation = SIMD3<Float>(0, 0.08, 0)
        nameText.transform.scale = SIMD3<Float>(0.3, 0.3, 0.3)

        // Make text always face the user (simplified billboard effect)
        // Note: Real billboard effect would require continuous updates
        addChild(nameText)

        gameLog("🎨 [RemoteDroneEntity] Added name tag for \(playerName) with color \(playerColor)")
    }

    // MARK: - Position Tracking

    func addRemoteDronePositionTracking() {

        self.components[RemoteDronePositionComponent.self] = RemoteDronePositionComponent(
            playerID: self.playerID,
            interpolationSpeed: 8.0 // Smooth but responsive interpolation
        )

        gameLog("🎯 [RemoteDroneEntity] Added position tracking for player \(playerID)")
    }

    func removeRemoteDronePositionTracking() {
        self.components[RemoteDronePositionComponent.self] = nil
        gameLog("🎯 [RemoteDroneEntity] Removed position tracking for player \(playerID)")
    }

    // MARK: - Collision Detection

    private func setupCollisionDetection() {
        // Add a collision component so missiles can detect this drone
        let radius: Float = 0.3
        let sphereShape = ShapeResource.generateSphere(radius: radius)
        let collisionComponent = CollisionComponent(
            shapes: [sphereShape],
            mode: .trigger,
            filter: .init(group: .all, mask: .all)
        )
        self.components.set(collisionComponent)

        // Add a DroneMissileComponent so the missile system can find this entity
        // Remote drones can fire missiles when receiving network messages
        let missileComponent = DroneMissileComponent(
            canFireMissiles: true,  // Enable missile firing for network messages
            missileSpeed: 5.0,      // Same as local player
            missileLifetime: 3.0,   // Same as local player
            fireRate: 0.5           // Same as local player
        )
        self.components.set(missileComponent)

        gameLog("🎯 [RemoteDroneEntity] Added collision detection for player \(playerID)")

        // Add debug collision visualizer if enabled
        if RemoteDroneEntity.showCollisionDebug {
            addCollisionDebugVisualizer(radius: radius)
        }
    }

    private func addCollisionDebugVisualizer(radius: Float) {
        // Create a visual representation of the collision sphere using a semi-transparent sphere
        let debugMesh = MeshResource.generateSphere(radius: radius)

        // Use a bright, semi-transparent material so we can see both the drone and collision shape
        var debugMaterial = UnlitMaterial(color: .yellow)
        debugMaterial.color = .init(tint: .yellow.withAlphaComponent(0.3)) // 30% opacity yellow

        let debugModel = ModelComponent(mesh: debugMesh, materials: [debugMaterial])

        // Create a child entity for the debug visualizer
        let debugEntity = Entity()
        debugEntity.name = "CollisionDebugVisualizer"
        debugEntity.components.set(debugModel)

        self.addChild(debugEntity)

        gameLog("🔍 [RemoteDrone] Added collision debug visualizer: sphere radius \(radius)")
    }

    // MARK: - Network Missile Firing

    public func fireNetworkMissile(_ missileMessage: FireDroneMissileMessage, in rootEntity: Entity) {
        gameLog("🚀 [RemoteDroneEntity] Firing network missile for player \(playerID)")

        // Create missile with the exact parameters from the network message
        let missileColor = UIColor(hex: playerColor) ?? UIColor.cyan
        let missile = MissileEntity(
            velocity: missileMessage.velocity,
            lifetime: 3.0, // Standard missile lifetime
            ownerDroneId: missileMessage.playerID, // Use the actual playerID from the message
            playerColor: missileColor
        )

        // Set missile position and orientation based on network message
        missile.position = missileMessage.startPosition

        // Calculate orientation from velocity direction
        let velocityDirection = normalize(missileMessage.velocity)
        let angle = atan2(velocityDirection.x, velocityDirection.z)

        // Combine directional rotation with missile's horizontal rotation
        let directionalRotation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
        let missileHorizontalRotation = simd_quatf(angle: -Float.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        missile.orientation = directionalRotation * missileHorizontalRotation

        // Add to root entity (same as local missile firing)
        rootEntity.addChild(missile)

        gameLog("🚀 [RemoteDroneEntity] Network missile created at \(missileMessage.startPosition) with velocity \(missileMessage.velocity)")
    }

    // MARK: - Particle Trail Methods

    private func setupParticleTrail() {
        // Create particle trail using remote player's color
        trailEntity = DroneTrailFactory.createRemotePlayerTrail(playerColor: playerColor)

        if let trail = trailEntity {
            // Add trail as child (it will emit particles to world space)
            addChild(trail)
            gameLog("🌟 Added particle trail to remote player drone \(playerName) with color \(playerColor)")
        }
    }

    public func setTrailWorldParent(_ worldParent: Entity) {
        trailEntity?.setWorldParent(worldParent)
    }

    public func updateTrailColor(_ newColor: String) {
        playerColor = newColor
        if let color = UIColor(hex: newColor) {
            trailEntity?.setTrailColor(color)
            gameLog("🌟 Updated trail color for \(playerName) to \(newColor)")
        }
    }

    public func setTrailEnabled(_ enabled: Bool) {
        trailEntity?.setTrailEnabled(enabled)
    }
}

