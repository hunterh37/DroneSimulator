//
//  EnemyDroneEntity.swift
//  HelicopterGame
//
//  Created by Claude on 10/5/25.
//

import RealityKit
import UIKit
import simd
import Combine
import Foundation

public class EnemyDroneEntity: Entity, HasModel, HasPhysics {
    public let enemyID: String
    public var droneState: DroneState = .idle
    public var aiMode: EnemyAIMode = .patrol
    public var targetPlayer: Entity?

    // AI behavior properties
    public var lastMissileFireTime: TimeInterval = 0
    public var missileFireRate: TimeInterval = 2.0 // Fire every 2 seconds
    public var detectionRange: Float = 15.0 // 15 meters detection range
    public var attackRange: Float = 10.0 // 10 meters optimal attack range
    public var maxSpeed: Float = 3.0
    public var aggroTimer: TimeInterval = 0
    public var aggroDuration: TimeInterval = 10.0 // Stay aggressive for 10 seconds after losing target

    // Movement AI
    public var currentVelocity: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    public var patrolCenter: SIMD3<Float>
    public var patrolRadius: Float = 8.0
    public var patrolDirection: Float = 0.0
    public var patrolHeight: Float = 2.0

    // Visual components
    private var droneModelEntity: Entity?
    private var nameTagEntity: Entity?
    
    public var showDebugVisualization: Bool = false

    // Animation properties
    private var animationController: AnimationPlaybackController?

    public init(enemyID: String, spawnPosition: SIMD3<Float> = SIMD3<Float>(0, 2, 0)) {
        gameLog("🎯 [EnemyDroneEntity] Creating enemy drone \(enemyID) at position \(spawnPosition)")

        self.enemyID = enemyID
        self.patrolCenter = spawnPosition
        self.patrolHeight = Float.random(in: 1.5...4.0) // Random patrol height
        super.init()

        // Set initial position
        self.position = spawnPosition
        gameLog("🎯 [EnemyDroneEntity] Set initial position to \(self.position)")

        // Start in chase mode to immediately pursue player
        self.aiMode = .chase
        self.detectionRange = 1000.0 // Essentially unlimited detection
        self.attackRange = 12.0 // Attack from distance

        setupEnemyDroneVisual()
        setupPhysics()
        setupAIComponents()
        addNameTag()
        addMissileCapability()

        gameLog("🎯 [EnemyDroneEntity] Enemy drone \(enemyID) initialization complete - starting in CHASE mode")
    }

    required init() {
        fatalError("Use init(enemyID:spawnPosition:) instead")
    }

    private func setupEnemyDroneVisual() {
        // Randomly choose between EnemyDrone1 and EnemyDrone2
        let randomChoice = Int.random(in: 1...2)
        let modelName = "EnemyDrone\(randomChoice)"

        gameLog("🎯 [EnemyDroneEntity] Attempting to load \(modelName).usdz for enemy \(enemyID)")

        guard let droneURL = Bundle.main.url(forResource: modelName, withExtension: "usdz") else {
            gameLog("⚠️ [EnemyDroneEntity] \(modelName).usdz not found, falling back to Drone.usdz")
            loadFallbackDroneModel()
            return
        }

        Task {
            do {
                let droneEntity = try await Entity(contentsOf: droneURL)
                droneEntity.transform.scale = [1.4, 1.4, 1.4]

                await MainActor.run {
                    self.addChild(droneEntity)
                    self.droneModelEntity = droneEntity
                    self.applyEnemyTint()
                    self.startDroneAnimation()
                    gameLog("✅ [EnemyDroneEntity] Successfully loaded \(modelName).usdz for enemy \(self.enemyID)")
                }
            } catch {
                gameLog("❌ [EnemyDroneEntity] Failed to load \(modelName).usdz: \(error.localizedDescription)")
                await MainActor.run {
                    self.loadFallbackDroneModel()
                }
            }
        }
    }

    private func loadFallbackDroneModel() {
        // Try to load standard Drone.usdz as fallback
        guard let droneURL = Bundle.main.url(forResource: "Drone", withExtension: "usdz") else {
            gameLog("❌ [EnemyDroneEntity] Even fallback Drone.usdz not found")
            return
        }

        Task {
            do {
                let droneEntity = try await Entity(contentsOf: droneURL)
                droneEntity.transform.scale = [1.4, 1.4, 1.4]

                await MainActor.run {
                    self.addChild(droneEntity)
                    self.droneModelEntity = droneEntity
                    self.applyEnemyTint()
                    self.startDroneAnimation()
                    gameLog("✅ [EnemyDroneEntity] Loaded fallback Drone.usdz for enemy \(self.enemyID)")
                }
            } catch {
                gameLog("❌ [EnemyDroneEntity] Failed to load even fallback Drone.usdz: \(error.localizedDescription)")
            }
        }
    }


    private func applyEnemyTint() {
        // Tint the enemy drone red to distinguish from player drones
        guard let droneModel = droneModelEntity else { return }

        // Recursively apply red tint to all model components
        applyTintRecursively(to: droneModel, tint: UIColor.red)
    }

    private func applyTintRecursively(to entity: Entity, tint: UIColor) {
        // Apply tint to this entity's model if it has one
        if var modelComponent = entity.components[ModelComponent.self] {
            let tintedMaterials: [Material] = modelComponent.materials.map { material in
                if var simpleMaterial = material as? SimpleMaterial {
                    simpleMaterial.color = .init(tint: tint.withAlphaComponent(0.7))
                    return simpleMaterial
                }
                return material
            }
            modelComponent.materials = tintedMaterials
            entity.components[ModelComponent.self] = modelComponent
        }

        // Recursively apply to children
        for child in entity.children {
            applyTintRecursively(to: child, tint: tint)
        }
    }

    private func setupPhysics() {
        // Set up physics for collision detection
        let physicsShape = ShapeResource.generateSphere(radius: 2)
        var physicsBodyComponent = PhysicsBodyComponent(
            massProperties: .default,
            material: .default,
            mode: .kinematic
        )
        //physicsBodyComponent.isContinuousCollisionDetectionEnabled = true

        let collisionComponent = CollisionComponent(
            shapes: [physicsShape],
            mode: .trigger,
            filter: .default
        )
        

        self.components.set(physicsBodyComponent)
        self.components.set(collisionComponent)
        
        if showDebugVisualization {
            addCollisionDebugVisualizer(collisionShape: physicsShape)
        }
    }
    
    private func addCollisionDebugVisualizer(collisionShape: ShapeResource) {
        // Visualize the ACTUAL collision shape (capsule), not just bounding box
        let shapeBounds = collisionShape.bounds

        // For capsule: height and radius from the actual shape
        // The collision shape was created with specific height and radius
        // We'll visualize it as a capsule mesh to match exactly

        let debugMesh: MeshResource = MeshResource.generateCylinder(height: 0.3, radius: shapeBounds.extents.x / 2)

        var debugMaterial = UnlitMaterial(color: .red)
        debugMaterial.color = .init(tint: .red.withAlphaComponent(0.3))

        let debugEntity = Entity()
        debugEntity.name = "CollisionDebugVisualizer"
        debugEntity.components.set(ModelComponent(mesh: debugMesh, materials: [debugMaterial]))

        self.addChild(debugEntity)
    }

    private func setupAIComponents() {
        // Add AI behavior component
        let aiComponent = EnemyAIComponent(
            aiMode: aiMode,
            detectionRange: detectionRange,
            attackRange: attackRange,
            maxSpeed: maxSpeed,
            patrolCenter: patrolCenter,
            patrolRadius: patrolRadius
        )
        self.components.set(aiComponent)

        // Set entity name for identification
        self.name = "EnemyDrone_\(enemyID)"
    }

    private func addNameTag() {
        // Create a 3D text name tag similar to remote drones
        let nameText = "ENEMY"
        let textMesh = MeshResource.generateText(
            nameText,
            extrusionDepth: 0.007,
            font: .systemFont(ofSize: 0.1),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )

        let redMaterial = SimpleMaterial(color: .red, isMetallic: false)
        let nameTagEntity = Entity()
        nameTagEntity.components.set(ModelComponent(mesh: textMesh, materials: [redMaterial]))

        nameTagEntity.scale = .init(repeating: 0.3)

        // Position above the drone
        nameTagEntity.transform.translation = SIMD3<Float>(-0.03, 0.08, 0)

        // Make it always face the camera (billboard effect)
        nameTagEntity.components.set(BillboardComponent.init())

        self.addChild(nameTagEntity)
        self.nameTagEntity = nameTagEntity
    }

    private func addMissileCapability() {
        // Add missile firing capability using the same system as player drones
        self.addDroneMissileCapability(
            missileSpeed: 4.0, // Slightly slower than player missiles
            missileLifetime: 3.0,
            fireRate: Float(missileFireRate)
        )

        gameLog("🎯 Added missile capability to enemy drone \(enemyID)")
    }

    // MARK: - AI Behavior Methods

    public func updateAI(deltaTime: Float, playerDrone: Entity?) {
        // Debug: Print that updateAI is being called
        if Int(CACurrentMediaTime() * 2) % 10 == 0 { // Every 5 seconds
            // gameLog("🤖 [EnemyDrone] \(enemyID): updateAI called with deltaTime: \(deltaTime), playerDrone: \(playerDrone != nil ? "exists" : "nil")")
        }

        guard let playerDrone = playerDrone else {
            // Debug: Print when no player drone is found
            if Int(CACurrentMediaTime() * 2) % 10 == 0 { // Every 5 seconds
                gameLog("⚠️ [EnemyDrone] \(enemyID): No player drone found for AI update")
            }
            return
        }

        let distanceToPlayer = distance(self.position, playerDrone.position)

        // Debug: Print AI state occasionally
        if Int(CACurrentMediaTime() * 4) % 60 == 0 { // Every 15 seconds
            // gameLog("🤖 [EnemyDrone] \(enemyID): Position \(self.position), Mode: \(aiMode), Distance to player: \(distanceToPlayer)")
        }

        // Update AI mode based on player proximity
        updateAIMode(distanceToPlayer: distanceToPlayer, deltaTime: deltaTime)

        // Execute behavior based on current AI mode
        switch aiMode {
        case .patrol:
            executePatrolBehavior(deltaTime: deltaTime)
        case .chase:
            executeChaseBehavior(targetPosition: playerDrone.position, deltaTime: deltaTime)
        case .attack:
            executeAttackBehavior(targetPosition: playerDrone.position, deltaTime: deltaTime)
        case .retreat:
            executeRetreatBehavior(playerPosition: playerDrone.position, deltaTime: deltaTime)
        }

        // Try to fire missiles if in attack mode
        if aiMode == .attack {
            tryFireMissile(at: playerDrone)
        }

        // Update animation speed based on current AI mode
        updateAnimationSpeed()
    }

    private func updateAIMode(distanceToPlayer: Float, deltaTime: Float) {
        // Simplified AI: Always pursue and attack the player
        if distanceToPlayer <= attackRange {
            aiMode = .attack
        } else {
            aiMode = .chase
        }
    }

    private func executePatrolBehavior(deltaTime: Float) {
        // Debug: Print patrol behavior more frequently
        if Int(CACurrentMediaTime() * 2) % 10 == 0 { // Every 5 seconds
            // gameLog("🔄 [EnemyDrone] \(enemyID): Executing patrol behavior")
            // gameLog("🔄 [EnemyDrone] \(enemyID): Patrol center: \(patrolCenter), radius: \(patrolRadius)")
            // gameLog("🔄 [EnemyDrone] \(enemyID): Current direction: \(patrolDirection), deltaTime: \(deltaTime)")
            // gameLog("🔄 [EnemyDrone] \(enemyID): Current position: \(self.position)")
        }

        // Circular patrol pattern around spawn point
        patrolDirection += deltaTime * 0.5 // Rotation speed

        let targetX = patrolCenter.x + cos(patrolDirection) * patrolRadius
        let targetZ = patrolCenter.z + sin(patrolDirection) * patrolRadius
        let targetPosition = SIMD3<Float>(targetX, patrolHeight, targetZ)

        if Int(CACurrentMediaTime() * 4) % 40 == 0 {
            // gameLog("🔄 [EnemyDrone] \(enemyID): Patrol target position: \(targetPosition)")
        }

        moveTowards(targetPosition: targetPosition, speed: maxSpeed * 0.5, deltaTime: deltaTime)
    }

    private func executeChaseBehavior(targetPosition: SIMD3<Float>, deltaTime: Float) {
        // Move towards player aggressively, matching their height
        var chaseTarget = targetPosition
        chaseTarget.y = targetPosition.y // Match player height

        moveTowards(targetPosition: chaseTarget, speed: maxSpeed, deltaTime: deltaTime)

        // Always face the player while chasing
        lookAt(target: targetPosition)
    }

    private func executeAttackBehavior(targetPosition: SIMD3<Float>, deltaTime: Float) {
        // Maintain optimal attack range while circling the player
        let distanceToTarget = distance(self.position, targetPosition)
        let directionToTarget = normalize(targetPosition - self.position)

        // Calculate orbital position around player
        let orbitalAngle = Float(CACurrentMediaTime() * 0.5) // Slow orbit
        let orbitalRadius = attackRange * 0.75 // Stay at 75% of attack range

        // Create orbital offset perpendicular to direction to target
        let strafeDirection = SIMD3<Float>(-directionToTarget.z, 0, directionToTarget.x)
        let orbitalOffset = strafeDirection * sin(orbitalAngle) * orbitalRadius * 0.5

        // Move towards orbital position while maintaining distance
        var attackTarget = targetPosition - directionToTarget * orbitalRadius + orbitalOffset
        attackTarget.y = targetPosition.y // Match player height

        // If too close, back away; if too far, move closer
        if distanceToTarget < attackRange * 0.6 {
            // Too close - back away
            attackTarget = self.position + (self.position - targetPosition) * deltaTime * 2.0
        } else if distanceToTarget > attackRange * 0.9 {
            // Too far - move closer
            attackTarget = targetPosition - directionToTarget * (orbitalRadius * 0.8)
        }

        moveTowards(targetPosition: attackTarget, speed: maxSpeed * 0.5, deltaTime: deltaTime)

        // Always face the player for accurate missile firing
        lookAt(target: targetPosition)
    }

    private func executeRetreatBehavior(playerPosition: SIMD3<Float>, deltaTime: Float) {
        // Move away from player towards patrol center
        let directionAwayFromPlayer = normalize(self.position - playerPosition)
        let retreatTarget = self.position + directionAwayFromPlayer * 5.0

        moveTowards(targetPosition: retreatTarget, speed: maxSpeed, deltaTime: deltaTime)
    }

    private func moveTowards(targetPosition: SIMD3<Float>, speed: Float, deltaTime: Float) {
        let direction = targetPosition - self.position
        let distance = length(direction)

        // Debug: Print movement more frequently for debugging
        if Int(CACurrentMediaTime() * 2) % 10 == 0 { // Every 5 seconds
            // gameLog("🚁 [EnemyDrone] \(enemyID): Moving from \(self.position) to \(targetPosition), distance: \(distance), speed: \(speed)")
        }

        if distance > 0.1 {
            let normalizedDirection = direction / distance
            let moveDistance = min(speed * deltaTime, distance)
            let oldPosition = self.position
            self.position += normalizedDirection * moveDistance

            // Rotate to face movement direction
            let horizontalDirection = SIMD3<Float>(normalizedDirection.x, 0, normalizedDirection.z)
            if length(horizontalDirection) > 0.01 {
                let normalizedHorizontal = normalize(horizontalDirection)
                let angle = atan2(normalizedHorizontal.x, normalizedHorizontal.z)
                self.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
            }

            // Debug: Print actual movement
            if Int(CACurrentMediaTime() * 8) % 40 == 0 {
                // gameLog("🚁 [EnemyDrone] \(enemyID): Moved from \(oldPosition) to \(self.position), moveDistance: \(moveDistance)")
            }

            // Update velocity for physics
            currentVelocity = normalizedDirection * speed
        } else {
            currentVelocity = SIMD3<Float>(0, 0, 0)
        }
    }

    private func lookAt(target: SIMD3<Float>) {
        let direction = normalize(target - self.position)
        // Calculate angle: atan2(x, z) where forward is -Z
        // We need to negate the angle to face the correct direction
        let angle = atan2(direction.x, direction.z)
        self.orientation = simd_quatf(angle: -angle, axis: SIMD3<Float>(0, 1, 0))

        // Debug log
        if Int(CACurrentMediaTime() * 2) % 30 == 0 {
            // gameLog("🎯 [EnemyDrone] \(enemyID): Looking at \(target), direction: \(direction), angle: \(angle)")
            let forward = self.orientation.act(SIMD3<Float>(0, 0, -1))
            // gameLog("🎯 [EnemyDrone] \(enemyID): Current forward vector: \(forward)")
        }
    }

    private func tryFireMissile(at target: Entity) {
        let currentTime = CACurrentMediaTime()

        if currentTime - lastMissileFireTime >= missileFireRate {
            // Fire missile using the same system as player drones
            gameLog("🚀 Enemy drone \(enemyID) firing missile at player!")

            // Play spatial shoot sound
            GameContext.shared.sound.playEnemyDroneShootSound(entity: self)

            // Get the world scene from the parent hierarchy
            if let rootEntity = findRootEntity() {
                DroneMissileSystem.fireMissile(from: self, addingTo: rootEntity)
                lastMissileFireTime = currentTime
            }
        }
    }

    private func findRootEntity() -> Entity? {
        var current: Entity? = self
        while let parent = current?.parent {
            current = parent
        }
        return current
    }

    // MARK: - Animation Methods

    private func startDroneAnimation() {
        guard let droneEntity = droneModelEntity else {
            gameLog("⚠️ [EnemyDrone] No drone model entity found for animation")
            return
        }

        // Start the first available animation on repeat
        if let firstAnimation = droneEntity.availableAnimations.first {
            animationController = droneEntity.playAnimation(firstAnimation.repeat())
            gameLog("🎬 [EnemyDrone] Started animation for enemy \(enemyID)")
        } else {
            gameLog("⚠️ [EnemyDrone] No animations found in drone model for enemy \(enemyID)")
        }
    }

    private func updateAnimationSpeed() {
        guard let controller = animationController else { return }

        // Adjust animation speed based on AI mode
        let animationSpeed: Float
        switch aiMode {
        case .patrol:
            animationSpeed = 0.8 // Slower when patrolling
        case .chase, .attack:
            animationSpeed = 1.5 // Faster when chasing/attacking
        case .retreat:
            animationSpeed = 1.2 // Medium speed when retreating
        }

        // Only update if speed changed significantly to avoid constant updates
        if abs(controller.speed - animationSpeed) > 0.1 {
            controller.speed = animationSpeed
        }
    }
}

// MARK: - Enemy AI Component

public struct EnemyAIComponent: Component {
    public var aiMode: EnemyAIMode
    public var detectionRange: Float
    public var attackRange: Float
    public var maxSpeed: Float
    public var patrolCenter: SIMD3<Float>
    public var patrolRadius: Float
    public var lastUpdateTime: TimeInterval

    public init(aiMode: EnemyAIMode, detectionRange: Float, attackRange: Float, maxSpeed: Float, patrolCenter: SIMD3<Float>, patrolRadius: Float) {
        self.aiMode = aiMode
        self.detectionRange = detectionRange
        self.attackRange = attackRange
        self.maxSpeed = maxSpeed
        self.patrolCenter = patrolCenter
        self.patrolRadius = patrolRadius
        self.lastUpdateTime = CACurrentMediaTime()
    }
}

// MARK: - Enemy AI Modes

public enum EnemyAIMode {
    case patrol    // Flying around patrol area
    case chase     // Moving towards detected player
    case attack    // Engaging player with missiles
    case retreat   // Moving away from player
}

// MARK: - Extensions

extension EnemyDroneEntity {
    public func takeDamage() {
        // Simple destruction - remove from scene
        gameLog("💥 Enemy drone \(enemyID) destroyed!")

        // 💥 SPAWN EXPLOSION at enemy drone position
        spawnDestructionExplosion()

        // Post kill notification for UI
        NotificationCenter.default.post(
            name: .playerKilledEnemy,
            object: nil,
            userInfo: ["killedPlayerName": "ENEMY"]
        )
        gameLog("💀 [EnemyDroneEntity] Posted kill notification for enemy drone \(enemyID)")

        self.removeFromParent()

        // TODO: Award points to player
        // TODO: Spawn new enemy after delay
    }

    private func spawnDestructionExplosion() {
        // Find the root entity to add explosion to
        guard let rootEntity = findRootEntity() else {
            gameLog("⚠️ [EnemyDroneEntity] Cannot spawn explosion: no root entity found")
            return
        }

        // Get current position before removal
        let explosionPosition = self.position

        // Play destruction sound before removing
        GameContext.shared.sound.playDestructionSound(entity: self)

        // Create explosion at the enemy drone's position
        let explosion = ExplosionEntity.createDroneExplosion(at: explosionPosition)
        rootEntity.addChild(explosion)

        gameLog("💥 [EnemyDroneEntity] Spawned explosion for destroyed enemy drone \(enemyID) at position \(explosionPosition)")
    }
}
