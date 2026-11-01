//
//  EnemyDroneBossEntity.swift
//  HelicopterGame
//
//  Created by Claude on 10/14/25.
//  Boss enemy drone with multiple attack patterns
//

import RealityKit
import Foundation
import QuartzCore
import UIKit

/// Boss enemy drone that spawns projectile swarms to attack the player
public class EnemyDroneBossEntity: Entity, HasModel, HasCollision {
    public let bossID: String
    public var aiMode: BossAIMode = .patrol
    public var currentAttackType: BossAttackType = .swarm

    // Debug visualization
    public var showDebugVisualization: Bool = false {
        didSet {
            updateDebugVisualization()
        }
    }
    private var debugCollisionBox: ModelEntity?

    // AI state
    private var targetPosition: SIMD3<Float>?
    private var patrolCenter: SIMD3<Float>
    private var patrolAngle: Float = 0
    private var lastAttackTime: TimeInterval = 0
    private var attackCooldown: TimeInterval = 8.0 // 8 seconds between attacks (more downtime for movement)

    // Boss stats
    public var health: Float = 2000.0 // Much higher health than regular enemies
    public let maxHealth: Float = 2000.0

    // Movement parameters (slower than regular enemies)
    private let moveSpeed: Float = 1.2 // Slower, more methodical movement
    private let rotationSpeed: Float = 1.0

    public init(bossID: String, spawnPosition: SIMD3<Float>) {
        self.bossID = bossID
        self.patrolCenter = spawnPosition

        super.init()

        self.name = "Boss_\(bossID)"
        self.position = spawnPosition

        // Add boss AI component
        self.components.set(EnemyAIBossComponent())

        // Setup visual representation (larger than regular enemies)
        setupBossVisual()

        // Add menacing red glowing particle trail
        setupBossParticleTrail()

    }

    required init() {
        fatalError("Use init(bossID:spawnPosition:) instead")
    }

    private func setupBossVisual() {
        // Try to load Boss.usdz model asynchronously
        Task {
            do {
                if let bossURL = Bundle.main.url(forResource: "DroneBoss", withExtension: "usdz") {
                    let bossModel = try await Entity(contentsOf: bossURL)

                    await MainActor.run {
                        // Scale boss to be much larger than regular enemies
                        bossModel.scale = SIMD3<Float>(repeating: 1.9)
                        self.addChild(bossModel)
                    }
                } else {
                    // Fallback to procedural boss if USDZ not found
                    await MainActor.run {
                        self.setupFallbackBossVisual()
                    }
                }
            } catch {
                await MainActor.run {
                    self.setupFallbackBossVisual()
                }
            }
        }

        // Setup collision (larger collision box for boss)
        let collisionShape = ShapeResource.generateBox(width: 3, height: 4, depth: 4)

        // Collision groups:
        // - Group 0 (bit 0, value 1): Player drones (own drone)
        // - Group 1 (bit 1, value 2): Missiles/projectiles
        // - Group 2 (bit 2, value 4): Enemy drones (including boss)
        // - Group 3 (bit 3, value 8): Remote player drones

        // Boss is in group 2 (enemy drones) and collides with group 1 (missiles)
        let bossGroup = CollisionGroup(rawValue: 1 << 2) // Group 2 (value 4) - ENEMIES ONLY
        let missileCollisionMask = CollisionGroup(rawValue: 1 << 1) // Group 1 (value 2)

        self.components.set(CollisionComponent(
            shapes: [collisionShape],
            mode: .trigger,
            filter: .default
        ))
        
        var physicsBody = PhysicsBodyComponent(
            massProperties: .default,
            material: .default,
            mode: .kinematic
        )
        //physicsBody.isContinuousCollisionDetectionEnabled = true
        self.components.set(physicsBody)
        
        if showDebugVisualization {
            addCollisionDebugVisualizer(collisionShape: collisionShape)
        }

    }
    
    private func addCollisionDebugVisualizer(collisionShape: ShapeResource) {
        // USE THE EXACT COLLISION SHAPE FROM THE COLLISION COMPONENT
        // Extract shape bounds to visualize the EXACT same collision volume
        let shapeBounds = collisionShape.bounds
        let shapeSize = shapeBounds.extents


        // Create a box mesh that matches the exact bounding box of the collision shape
        let debugMesh = MeshResource.generateBox(size: shapeSize)

        var debugMaterial = UnlitMaterial(color: .red)
        debugMaterial.color = .init(tint: .red.withAlphaComponent(0.3))

        let debugEntity = Entity()
        debugEntity.name = "CollisionDebugVisualizer"
        debugEntity.components.set(ModelComponent(mesh: debugMesh, materials: [debugMaterial]))

        // Position at the shape's center offset
        debugEntity.position = shapeBounds.center

        self.addChild(debugEntity)

    }

    private func setupFallbackBossVisual() {
        // Create a large, menacing boss drone using basic shapes

        // Main body (large red sphere)
        let bodyMesh = MeshResource.generateSphere(radius: 0.5)
        var bodyMaterial = SimpleMaterial(color: .red, roughness: 0.3, isMetallic: true)
        let bodyModel = ModelEntity(mesh: bodyMesh, materials: [bodyMaterial])

        // Add glowing eyes
        let eyeMesh = MeshResource.generateSphere(radius: 0.1)
        var eyeMaterial = UnlitMaterial(color: .yellow)

        let leftEye = ModelEntity(mesh: eyeMesh, materials: [eyeMaterial])
        leftEye.position = SIMD3<Float>(-0.2, 0.1, -0.4)

        let rightEye = ModelEntity(mesh: eyeMesh, materials: [eyeMaterial])
        rightEye.position = SIMD3<Float>(0.2, 0.1, -0.4)

        // Add crown/spikes on top to indicate boss status
        let spikeMesh = MeshResource.generateBox(width: 0.1, height: 0.3, depth: 0.1)
        var spikeMaterial = SimpleMaterial(color: .orange, roughness: 0.2, isMetallic: true)

        for i in 0..<4 {
            let angle = Float(i) * (2 * .pi / 4)
            let spike = ModelEntity(mesh: spikeMesh, materials: [spikeMaterial])
            spike.position = SIMD3<Float>(
                cos(angle) * 0.4,
                0.6,
                sin(angle) * 0.4
            )
            self.addChild(spike)
        }

        self.addChild(bodyModel)
        self.addChild(leftEye)
        self.addChild(rightEye)

    }

    private func setupBossParticleTrail() {
        // Create menacing red glowing particle trail for boss
        var particles = ParticleEmitterComponent()

        // Emit particles in a wide area around boss for intimidating presence
        particles.emitterShape = .sphere
        particles.emitterShapeSize = [0.3, 0.3, 0.3] // Larger emission area than missile trail

        // High birth rate for thick, menacing trail
        particles.mainEmitter.birthRate = 300 // More particles than missile for thick trail
        particles.mainEmitter.lifeSpan = 0.8 // Particles last longer for persistent trail
        particles.mainEmitter.size = 0.04 // Larger particles than missile (4cm vs 2cm)

        // Red color with blue tint that fades to transparent
        // Create a glowing red-blue effect
        let startColor = UIColor(red: 1.0, green: 0.0, blue: 0.3, alpha: 1.0) // Red with slight blue tint
        let endColor = UIColor(red: 0.2, green: 0.0, blue: 0.8, alpha: 0.0) // Blue fade to transparent

        particles.mainEmitter.color = .evolving(
            start: .single(startColor),
            end: .single(endColor)
        )

        // Slow speed so particles linger around boss
        particles.speed = 0.2 // Slightly faster than missile trail for dynamic effect

        // Additive blend mode for glowing effect
        particles.mainEmitter.blendMode = .additive

        // Add slight angular velocity for swirling effect
        particles.mainEmitter.angleVariation = .pi * 2 // Full rotation variance
        particles.mainEmitter.spreadingAngle = .pi * 2 // Emit in all directions

        components.set(particles)

    }

    public func updateAI(deltaTime: Float, playerDrone: Entity?) {
        // Update boss AI behavior
        switch aiMode {
        case .patrol:
            updatePatrolBehavior(deltaTime: deltaTime, playerDrone: playerDrone)
        case .chase:
            updateChaseBehavior(deltaTime: deltaTime, playerDrone: playerDrone)
        case .attack:
            updateAttackBehavior(deltaTime: deltaTime, playerDrone: playerDrone)
        }

        // Check if we should attack
        let currentTime = CACurrentMediaTime()
        if currentTime - lastAttackTime >= attackCooldown, let playerDrone = playerDrone {
            // Choose attack type based on distance to player
            let distanceToPlayer = distance(self.position, playerDrone.position)

            if distanceToPlayer < 3.0 {
                currentAttackType = .burst // Close range - rapid burst
            } else if distanceToPlayer < 8.0 {
                currentAttackType = .wave // Medium range - wave attack
            } else {
                currentAttackType = .swarm // Long range - swarm attack
            }

            // Trigger attack (will be handled by the system)
            aiMode = .attack
            lastAttackTime = currentTime

            // Play boss attack sound based on attack type
            GameContext.shared.sound.playBossAttackSound(entity: self, attackType: currentAttackType)

        }
    }

    private func updatePatrolBehavior(deltaTime: Float, playerDrone: Entity?) {
        // Check if player is in detection range
        if let playerDrone = playerDrone {
            let distanceToPlayer = distance(self.position, playerDrone.position)

            if distanceToPlayer < 15.0 { // Boss has larger detection range
                aiMode = .chase
                return
            }
        }

        // Circle patrol around spawn point
        patrolAngle += deltaTime * 0.5 // Slow circle
        let patrolRadius: Float = 5.0

        targetPosition = SIMD3<Float>(
            patrolCenter.x + cos(patrolAngle) * patrolRadius,
            patrolCenter.y,
            patrolCenter.z + sin(patrolAngle) * patrolRadius
        )

        moveTowardsTarget(deltaTime: deltaTime)
    }

    private func updateChaseBehavior(deltaTime: Float, playerDrone: Entity?) {
        guard let playerDrone = playerDrone else {
            aiMode = .patrol
            return
        }

        let distanceToPlayer = distance(self.position, playerDrone.position)

        // If player is too far, return to patrol
        if distanceToPlayer > 20.0 {
            aiMode = .patrol
            return
        }

        // Maintain optimal attack distance (don't get too close)
        let optimalDistance: Float = 6.0

        if distanceToPlayer > optimalDistance {
            // Move towards player
            targetPosition = playerDrone.position
        } else {
            // Maintain distance - strafe around player
            let directionToPlayer = normalize(playerDrone.position - self.position)
            let strafeDirection = SIMD3<Float>(-directionToPlayer.z, 0, directionToPlayer.x)
            targetPosition = self.position + strafeDirection * 2.0
        }

        moveTowardsTarget(deltaTime: deltaTime)
        faceTarget(playerDrone.position, deltaTime: deltaTime)
    }

    private func updateAttackBehavior(deltaTime: Float, playerDrone: Entity?) {
        // Attack behavior is handled by the system spawning projectiles
        // After attack cooldown, switch back to chase
        let currentTime = CACurrentMediaTime()

        if currentTime - lastAttackTime > 1.0 { // 1 second attack duration
            aiMode = .chase
        }

        // Face player during attack
        if let playerDrone = playerDrone {
            faceTarget(playerDrone.position, deltaTime: deltaTime)
        }
    }

    private func moveTowardsTarget(deltaTime: Float) {
        guard let targetPosition = targetPosition else { return }

        let direction = targetPosition - self.position
        let distance = length(direction)

        if distance > 0.1 {
            let normalizedDirection = normalize(direction)
            let movement = normalizedDirection * moveSpeed * deltaTime

            // Only move if we won't overshoot
            if length(movement) < distance {
                self.position += movement
            } else {
                self.position = targetPosition
            }
        }
    }

    private func faceTarget(_ targetPosition: SIMD3<Float>, deltaTime: Float) {
        let direction = targetPosition - self.position

        // Calculate target rotation (only rotate around Y axis)
        let targetRotation = atan2(direction.x, direction.z)

        // Get current rotation
        let currentRotation = atan2(self.transform.matrix.columns.2.x, self.transform.matrix.columns.2.z)

        // Smoothly interpolate rotation
        var rotationDiff = targetRotation - currentRotation

        // Normalize rotation difference to [-π, π]
        while rotationDiff > .pi { rotationDiff -= 2 * .pi }
        while rotationDiff < -.pi { rotationDiff += 2 * .pi }

        let rotationStep = rotationDiff * rotationSpeed * deltaTime
        let newRotation = currentRotation + rotationStep

        // Apply rotation
        self.orientation = simd_quatf(angle: newRotation, axis: SIMD3<Float>(0, 1, 0))
    }

    public func takeDamage(_ damage: Float) {
        health -= damage

        if health <= 0 {
            destroy()
        }
    }

    private func destroy() {
        GameContext.shared.sound.playDestructionSound(entity: self)

        // Create massive explosion effect at boss position
        let bossPosition = self.position(relativeTo: nil)
        let bigExplosion = ExplosionEntity.createLargeExplosion(at: bossPosition)
        if let parent = self.parent {
            parent.addChild(bigExplosion)
        }

        // Notify game of boss destruction
        NotificationCenter.default.post(
            name: .bossDestroyed,
            object: nil,
            userInfo: ["bossID": bossID]
        )

        // Remove from scene
        self.removeFromParent()
    }

    // MARK: - Debug Visualization

    private func updateDebugVisualization() {
        if showDebugVisualization {
            // Create debug collision box if it doesn't exist
            if debugCollisionBox == nil {
                createDebugCollisionBox()
            }
        } else {
            // Remove debug collision box if it exists
            debugCollisionBox?.removeFromParent()
            debugCollisionBox = nil
        }
    }

    private func createDebugCollisionBox() {
        // Match the exact collision box dimensions from setupBossVisual()
        let width: Float = 1.0
        let height: Float = 0.8
        let depth: Float = 1.0

        // Create a wireframe box using the exact same dimensions as the collision component
        let boxMesh = MeshResource.generateBox(width: width, height: height, depth: depth)

        // Create red semi-transparent material for debug visualization
        var debugMaterial = SimpleMaterial()
        debugMaterial.color = .init(tint: .red.withAlphaComponent(0.3), texture: nil)
        debugMaterial.roughness = .init(floatLiteral: 1.0)
        debugMaterial.metallic = .init(floatLiteral: 0.0)

        // Create the debug model entity
        let debugBox = ModelEntity(mesh: boxMesh, materials: [debugMaterial])
        debugBox.name = "DebugCollisionBox"

        // Add to boss entity
        self.addChild(debugBox)
        debugCollisionBox = debugBox

    }
}

// MARK: - Boss AI Component

public struct EnemyAIBossComponent: Component {
    public var lastUpdateTime: TimeInterval = 0
    public var lastAttackTime: TimeInterval = 0

    public init() {}
}

// MARK: - Boss AI Mode

public enum BossAIMode {
    case patrol
    case chase
    case attack
}

// MARK: - Boss Attack Type

public enum BossAttackType {
    case swarm   // Many small projectiles in a spread pattern
    case wave    // Medium-sized projectiles in a wave formation
    case burst   // Large fast projectiles in rapid succession
}

// MARK: - Notification Names

extension Notification.Name {
    static let bossDestroyed = Notification.Name("bossDestroyed")
}
