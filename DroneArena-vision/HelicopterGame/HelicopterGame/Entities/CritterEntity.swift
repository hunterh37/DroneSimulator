//
//  CritterEntity.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import RealityKit
import UIKit
import simd

public enum CritterType: String, CaseIterable {
    case bunny = "bunny"
    case bird = "bird"
    case cat = "cat"
    case robot = "robot"

    public var displayName: String {
        switch self {
        case .bunny: return "Bunny"
        case .bird: return "Bird"
        case .cat: return "Cat"
        case .robot: return "Robot"
        }
    }

    public var movementSpeed: Float {
        switch self {
        case .bunny: return 0.8
        case .bird: return 1.5
        case .cat: return 1.0
        case .robot: return 0.6
        }
    }

    public var bounceHeight: Float {
        switch self {
        case .bunny: return 0.3
        case .bird: return 0.5
        case .cat: return 0.15
        case .robot: return 0.1
        }
    }
}

public enum CritterState {
    case idle
    case wandering
    case curious(target: SIMD3<Float>)
    case celebrating
    case fleeing(from: SIMD3<Float>)
    case grabbed
}

public enum CritterReaction: String, CaseIterable {
    case happy = "happy"
    case excited = "excited"
    case scared = "scared"
    case curious = "curious"
    case sleepy = "sleepy"

    public var emoteIcon: String {
        switch self {
        case .happy: return "😊"
        case .excited: return "🎉"
        case .scared: return "😱"
        case .curious: return "🤔"
        case .sleepy: return "😴"
        }
    }

    public var bubbleColor: UIColor {
        switch self {
        case .happy: return .systemYellow
        case .excited: return .systemOrange
        case .scared: return .systemRed
        case .curious: return .systemBlue
        case .sleepy: return .systemPurple
        }
    }
}

public class CritterEntity: Entity, HasCollision, HasPhysics {
    public let critterID: String
    public let critterType: CritterType
    public var currentState: CritterState = .idle
    public var currentReaction: CritterReaction?

    private var bodyEntity: ModelEntity?
    private var reactionBubble: Entity?
    private var animationTimer: Timer?
    private var stateTimer: Timer?
    private var wanderTarget: SIMD3<Float>?
    private var lastPosition: SIMD3<Float> = .zero

    // Movement properties
    private var velocity: SIMD3<Float> = .zero
    private let maxWanderDistance: Float = 5.0
    private let personalSpace: Float = 1.0

    public required init() {
        self.critterID = UUID().uuidString
        self.critterType = .bunny
        super.init()
        setupCritter()
    }

    public init(id: String = UUID().uuidString, type: CritterType, position: SIMD3<Float>) {
        self.critterID = id
        self.critterType = type
        super.init()
        self.transform.translation = position
        self.lastPosition = position
        setupCritter()
    }

    private func setupCritter() {
        setupVisuals()
        setupPhysics()
        setupCollision()
        startBehaviorLoop()
    }

    private func setupVisuals() {
        // Create main body based on critter type
        let (mesh, material) = createCritterMesh()
        bodyEntity = ModelEntity(mesh: mesh, materials: [material])

        if let body = bodyEntity {
            addChild(body)
        }

        // Set initial scale based on type
        let scale: Float = critterType == .bird ? 0.8 : 1.0
        transform.scale = SIMD3<Float>(scale, scale, scale)
    }

    private func createCritterMesh() -> (MeshResource, Material) {
        let mesh: MeshResource
        let material: SimpleMaterial

        switch critterType {
        case .bunny:
            // Create bunny-like shape (oval body + sphere head)
            mesh = MeshResource.generateSphere(radius: 0.15)
            material = SimpleMaterial(color: .white, roughness: 0.3, isMetallic: false)

        case .bird:
            // Create bird-like shape (elongated sphere)
            mesh = MeshResource.generateSphere(radius: 0.12)
            material = SimpleMaterial(color: .systemBlue, roughness: 0.2, isMetallic: false)

        case .cat:
            // Create cat-like shape (rounded box)
            mesh = MeshResource.generateBox(width: 0.2, height: 0.15, depth: 0.3)
            material = SimpleMaterial(color: .systemOrange, roughness: 0.4, isMetallic: false)

        case .robot:
            // Create robot-like shape (geometric box)
            mesh = MeshResource.generateBox(width: 0.18, height: 0.2, depth: 0.18)
            material = SimpleMaterial(color: .systemGray, roughness: 0.1, isMetallic: true)
        }

        return (mesh, material)
    }

    private func setupPhysics() {
        let mass: Float = critterType == .bird ? 0.5 : 1.0
        let material = PhysicsMaterialResource.generate(friction: 0.8, restitution: 0.4)
        let massProperties = PhysicsMassProperties(mass: mass, inertia: SIMD3<Float>(0.5, 0.5, 0.5))

        self.components.set(PhysicsBodyComponent(
            massProperties: massProperties,
            material: material,
            mode: .dynamic
        ))
    }

    private func setupCollision() {
        let radius: Float = critterType == .bird ? 0.12 : 0.15
        let shape = ShapeResource.generateSphere(radius: radius)
        self.components.set(CollisionComponent(shapes: [shape]))
    }

    // MARK: - Behavior System

    private func startBehaviorLoop() {
        stateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateBehavior()
        }
    }

    private func updateBehavior() {
        switch currentState {
        case .idle:
            handleIdleState()
        case .wandering:
            handleWanderingState()
        case .curious(let target):
            handleCuriousState(target: target)
        case .celebrating:
            handleCelebratingState()
        case .fleeing(let threat):
            handleFleeingState(threat: threat)
        case .grabbed:
            handleGrabbedState()
        }

        // Update position tracking
        lastPosition = transform.translation
    }

    private func handleIdleState() {
        // Randomly decide to start wandering
        if Float.random(in: 0...1) < 0.02 { // 2% chance per frame
            startWandering()
        }

        // Small idle animation
        applyIdleAnimation()
    }

    private func handleWanderingState() {
        guard let target = wanderTarget else {
            startWandering()
            return
        }

        let currentPos = transform.translation
        let direction = normalize(target - currentPos)
        let distance = length(target - currentPos)

        if distance < 0.5 {
            // Reached target, pick new one or go idle
            if Float.random(in: 0...1) < 0.3 {
                currentState = .idle
                wanderTarget = nil
            } else {
                startWandering()
            }
        } else {
            // Move toward target
            let speed = critterType.movementSpeed * 0.01 // Scale for frame rate
            velocity = direction * speed
            transform.translation += velocity

            // Add small bounce for bunny
            if critterType == .bunny {
                applyBounceAnimation()
            }
        }
    }

    private func handleCuriousState(target: SIMD3<Float>) {
        let currentPos = transform.translation
        let direction = normalize(target - currentPos)
        let distance = length(target - currentPos)

        if distance < personalSpace {
            // Close enough, show reaction
            showReaction(.curious)
            // Transition to idle after investigating
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.currentState = .idle
            }
        } else {
            // Move closer cautiously
            let speed = critterType.movementSpeed * 0.005 // Slower when curious
            velocity = direction * speed
            transform.translation += velocity
        }
    }

    private func handleCelebratingState() {
        // Bounce excitedly
        applyBounceAnimation(multiplier: 2.0)
        showReaction(.excited)

        // Return to wandering after celebration
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.currentState = .wandering
            self.startWandering()
        }
    }

    private func handleFleeingState(threat: SIMD3<Float>) {
        let currentPos = transform.translation
        let fleeDirection = normalize(currentPos - threat)
        let distance = length(currentPos - threat)

        if distance > 3.0 {
            // Safe distance reached
            currentState = .idle
            showReaction(.sleepy) // Tired from running
        } else {
            // Keep fleeing
            let speed = critterType.movementSpeed * 0.02 // Faster when scared
            velocity = fleeDirection * speed
            transform.translation += velocity
            showReaction(.scared)
        }
    }

    private func handleGrabbedState() {
        // Stop all movement when grabbed
        velocity = .zero
        // Could add wiggle animation here
    }

    private func startWandering() {
        let currentPos = transform.translation
        let randomAngle = Float.random(in: 0...(2 * Float.pi))
        let randomDistance = Float.random(in: 1.0...maxWanderDistance)

        wanderTarget = currentPos + SIMD3<Float>(
            cos(randomAngle) * randomDistance,
            0,
            sin(randomAngle) * randomDistance
        )

        currentState = .wandering
    }

    // MARK: - Animation Methods

    private func applyIdleAnimation() {
        // Subtle breathing/bobbing animation
        let time = CACurrentMediaTime()
        let bobOffset = sin(Float(time * 2.0)) * 0.02
        var currentTransform = transform
        currentTransform.translation.y += bobOffset
        transform = currentTransform
    }

    private func applyBounceAnimation(multiplier: Float = 1.0) {
        let time = CACurrentMediaTime()
        let bounceHeight = critterType.bounceHeight * multiplier
        let bounceOffset = abs(sin(Float(time * 8.0))) * bounceHeight
        var currentTransform = transform
        currentTransform.translation.y += bounceOffset
        transform = currentTransform
    }

    // MARK: - Reaction System

    public func showReaction(_ reaction: CritterReaction) {
        currentReaction = reaction
        createReactionBubble(reaction)

        // Auto-hide reaction after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.hideReaction()
        }
    }

    private func createReactionBubble(_ reaction: CritterReaction) {
        // Remove existing bubble
        reactionBubble?.removeFromParent()

        // Create bubble with emoji
        let bubbleSize: Float = 0.3
        let bubbleMesh = MeshResource.generateSphere(radius: bubbleSize / 2)
        let bubbleMaterial = SimpleMaterial(
            color: reaction.bubbleColor,
            roughness: 0.0,
            isMetallic: false
        )

        let bubble = ModelEntity(mesh: bubbleMesh, materials: [bubbleMaterial])
        bubble.transform.translation = SIMD3<Float>(0, 0.5, 0) // Above critter

        // Add emoji text (simplified - in real implementation would use TextMesh)
        reactionBubble = bubble
        addChild(bubble)

        // Animate bubble appearance
        animateBubbleAppearance(bubble)
    }

    private func animateBubbleAppearance(_ bubble: Entity) {
        // Simple scale animation
        bubble.transform.scale = SIMD3<Float>(0.1, 0.1, 0.1)

        // In real implementation, would use proper animation system
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            bubble.transform.scale = SIMD3<Float>(1.0, 1.0, 1.0)
        }
    }

    public func hideReaction() {
        reactionBubble?.removeFromParent()
        reactionBubble = nil
        currentReaction = nil
    }

    // MARK: - Interaction Methods

    public func notifyOfNearbyActivity(position: SIMD3<Float>, type: ActivityType) {
        let distance = length(transform.translation - position)

        if distance < 2.0 { // Within notice range
            switch type {
            case .packageDelivery:
                currentState = .celebrating
                showReaction(.happy)
            case .packagePickup:
                currentState = .curious(target: position)
                showReaction(.curious)
            case .droneFlying:
                if distance < 1.0 {
                    currentState = .fleeing(from: position)
                    showReaction(.scared)
                }
            case .crateDrop:
                currentState = .curious(target: position)
                showReaction(.curious)
            }
        }
    }

    public func grab() {
        currentState = .grabbed
        // Stop physics simulation
        if var physicsBody = components[PhysicsBodyComponent.self] {
            physicsBody.mode = .kinematic
            components.set(physicsBody)
        }
    }

    public func release(at position: SIMD3<Float>) {
        transform.translation = position
        currentState = .fleeing(from: position) // Run away after being dropped
        showReaction(.scared)

        // Re-enable physics
        if var physicsBody = components[PhysicsBodyComponent.self] {
            physicsBody.mode = .dynamic
            components.set(physicsBody)
        }
    }

    // MARK: - Cleanup

    deinit {
        stateTimer?.invalidate()
        animationTimer?.invalidate()
    }
}

// MARK: - Supporting Types

public enum ActivityType {
    case packageDelivery
    case packagePickup
    case droneFlying
    case crateDrop
}

// MARK: - Critter Manager

@MainActor
@Observable
public class CritterManager {
    public private(set) var activeCritters: [CritterEntity] = []
    private weak var worldScene: Entity?
    private let maxCritters: Int = 8

    public init() {}

    public func setup(worldScene: Entity) {
        self.worldScene = worldScene
    }

    public func spawnCritter(type: CritterType, at position: SIMD3<Float>) -> CritterEntity? {
        guard activeCritters.count < maxCritters else {
            gameLog("Maximum critters reached")
            return nil
        }

        let critter = CritterEntity(type: type, position: position)
        activeCritters.append(critter)
        worldScene?.addChild(critter)

        gameLog("Spawned \(type.displayName) critter at \(position)")
        return critter
    }

    public func spawnRandomCritters(count: Int = 3) {
        for _ in 0..<count {
            let randomType = CritterType.allCases.randomElement() ?? .bunny
            let randomPosition = SIMD3<Float>(
                Float.random(in: -3...3),
                0.2,
                Float.random(in: -3...3)
            )
            spawnCritter(type: randomType, at: randomPosition)
        }
    }

    public func notifyActivity(position: SIMD3<Float>, type: ActivityType) {
        for critter in activeCritters {
            critter.notifyOfNearbyActivity(position: position, type: type)
        }
    }

    public func clearAllCritters() {
        for critter in activeCritters {
            critter.removeFromParent()
        }
        activeCritters.removeAll()
    }

    public func findNearestCritter(to position: SIMD3<Float>) -> CritterEntity? {
        return activeCritters.min { critter1, critter2 in
            let dist1 = length(critter1.transform.translation - position)
            let dist2 = length(critter2.transform.translation - position)
            return dist1 < dist2
        }
    }
}