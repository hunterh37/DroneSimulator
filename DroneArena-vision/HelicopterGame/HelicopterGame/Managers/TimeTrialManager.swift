//
//  TimeTrialManager.swift
//  HelicopterGame
//
//  Created by Claude on 10/6/25.
//

import Foundation
import RealityKit
import simd
import QuartzCore
#if os(visionOS)
import DicyaninThumbController
#endif

public enum TimeTrialState {
    case waiting
    case active
    case gameOver
    case paused
}

public struct TimeTrialLevel {
    let levelNumber: Int
    let ringCount: Int
    let timeLimit: TimeInterval
    let spawnPattern: RingSpawnPattern
    let difficulty: Float // 0.0 to 1.0

    public init(levelNumber: Int, ringCount: Int, timeLimit: TimeInterval, spawnPattern: RingSpawnPattern, difficulty: Float) {
        self.levelNumber = levelNumber
        self.ringCount = ringCount
        self.timeLimit = timeLimit
        self.spawnPattern = spawnPattern
        self.difficulty = difficulty
    }
}

public enum RingSpawnPattern {
    case straightLine
    case archingCurve
    case zigzag
    case spiral
    case random
}

public struct TimeTrialSession {
    let sessionID: String
    var currentLevel: Int = 1
    var totalRingsCollected: Int = 0
    var totalScore: Int = 0
    var bestTime: TimeInterval = 0
    let startTime: TimeInterval

    public init() {
        self.sessionID = UUID().uuidString
        self.startTime = CACurrentMediaTime()
    }
}

@MainActor
@Observable
public class TimeTrialManager {
    // Game state
    public var currentState: TimeTrialState = .waiting
    public var currentSession: TimeTrialSession?
    public var currentLevel: TimeTrialLevel?

    // Current level state
    public var ringsRemaining: Int = 0
    public var timeRemaining: TimeInterval = 0
    public var levelStartTime: TimeInterval = 0
    public var score: Int = 0

    // World references
    private weak var worldScene: Entity?
    public weak var playerDrone: Entity?
    private var timeTrialEntity: Entity?

    // Obstacle-course state
    private var currentCourse: DroneCourse?
    /// Origin the course is laid out from (drone position when the level starts).
    private var courseOrigin: SIMD3<Float> = .zero
    /// Landing pad spawned under a crashed drone.
    public weak var crashPad: CrashPadEntity?

    // Configuration
    public var maxConcurrentRings: Int = 8
    public var baseTimeLimit: TimeInterval = 60.0
    public var difficultyScaling: Float = 1.2

    public init() {}

    // MARK: - Setup

    public func setup(worldScene: Entity, playerDrone: Entity) {
        self.worldScene = worldScene
        self.playerDrone = playerDrone

        // Create time trial entity with ECS component
        setupTimeTrialEntity()

    }

    private func setupTimeTrialEntity() {
        guard let worldScene = worldScene else { return }

        // Create a dedicated entity for time trial management
        timeTrialEntity = Entity()
        timeTrialEntity?.name = "TimeTrialController"

        // Add the time trial component
        timeTrialEntity?.addTimeTrialComponent()

        // Set reference to this manager in the system
        TimeTrialSystem.timeTrialManager = self

        // Add to world scene
        worldScene.addChild(timeTrialEntity!)

    }

    // MARK: - Session Management

    public func startNewSession() {
        currentSession = TimeTrialSession()
        score = 0
        currentState = .waiting


        // Start with level 1
        startLevel(1)
    }

    public func startLevel(_ levelNumber: Int) {
        guard let worldScene = worldScene,
              let timeTrialEntity = timeTrialEntity else {
            return
        }


        // Create level configuration
        currentLevel = generateLevel(levelNumber)
        guard let level = currentLevel else {
            return
        }

        // Update ECS component state
        guard var component = timeTrialEntity.components[TimeTrialComponent.self] else {
            return
        }

        component.currentLevel = level
        component.ringsRemaining = level.ringCount
        component.timeRemaining = level.timeLimit
        component.levelStartTime = CACurrentMediaTime()
        component.currentState = .active
        component.score = score

        timeTrialEntity.components[TimeTrialComponent.self] = component

        // Reset local state for compatibility
        ringsRemaining = level.ringCount
        timeRemaining = level.timeLimit
        levelStartTime = CACurrentMediaTime()
        currentState = .active

        // Clear any existing course and lay out the new one.
        clearCourse()
        spawnCourse()

    }

    public func endLevel(completed: Bool) {
        guard var session = currentSession, let level = currentLevel else { return }

        let levelTime = CACurrentMediaTime() - levelStartTime
        let ringsCollected = level.ringCount - ringsRemaining

        // Calculate score for this level
        let timeBonus = max(0, Int((timeRemaining / level.timeLimit) * 100))
        let ringBonus = ringsCollected * 50
        let levelScore = ringBonus + timeBonus
        score += levelScore

        // Update session
        session.totalRingsCollected += ringsCollected
        session.totalScore = score
        if levelTime < session.bestTime || session.bestTime == 0 {
            session.bestTime = levelTime
        }

        // Save session updates
        currentSession = session

        if completed && timeRemaining > 0 {
            // Level completed successfully with time remaining - advance to next level!
            let nextLevelNumber = level.levelNumber + 1

            // Clear all existing gates before starting next level
            clearCourse()

            // Start next level with a brief delay for satisfaction
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startLevel(nextLevelNumber)
            }
            return
        }

        // Only set game over if time ran out or completion with no time remaining
        currentState = .gameOver


        if completed && ringsCollected == level.ringCount {
            // Level completed successfully, advance to next level after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.startLevel(level.levelNumber + 1)
            }
        } else {
            // Level failed, show game over
            clearCourse()
            resetDronePosition()
        }
    }

    public func syncStateFromECS() {
        guard let timeTrialEntity = timeTrialEntity,
              let component = timeTrialEntity.components[TimeTrialComponent.self] else { return }

        // Sync state from ECS component to local properties for compatibility
        currentState = component.currentState
        timeRemaining = component.timeRemaining
        ringsRemaining = component.ringsRemaining
        score = component.score
    }

    private func clearAllRings() {
        guard let timeTrialEntity = timeTrialEntity else { return }

        // Remove all ring entities
        let ringChildren = timeTrialEntity.children.compactMap { $0 as? RingEntity }

        for ring in ringChildren {
            ring.removeFromParent()
        }
    }

    // MARK: - Ring Management

    private func spawnInitialRingsECS(for level: TimeTrialLevel) {
        guard let timeTrialEntity = timeTrialEntity else { return }

        let initialRingCount = min(level.ringCount, maxConcurrentRings / 2)


        for i in 0..<initialRingCount {
            spawnRingECS(for: level, index: i, in: timeTrialEntity)
        }

    }

    private func spawnRingECS(for level: TimeTrialLevel, index: Int, in timeTrialEntity: Entity) {
        let position = calculateRingPosition(for: level, index: index)

        let ring = RingEntity(ringID: "ring_\(level.levelNumber)_\(index)")
        ring.transform.translation = position

        // Add RingComponent for ECS tracking
        ring.components.set(RingComponent(ringID: "ring_\(level.levelNumber)_\(index)", value: 100, levelIndex: index))


        timeTrialEntity.addChild(ring)

    }

    public func calculateRingPosition(for level: TimeTrialLevel, index: Int) -> SIMD3<Float> {
        let baseDistance: Float = 1.0 + (Float(index) * 0.8) // Start 1m away, 0.8m between rings - much closer!
        let angle = Float(index) * (Float.pi / 4) // 45 degrees between rings
        let height: Float = 0.5 + Float.random(in: -0.3...0.8) // Lower, closer to eye level

        switch level.spawnPattern {
        case .straightLine:
            return SIMD3<Float>(0, height, -baseDistance)

        case .archingCurve:
            let radius = baseDistance * 0.8
            return SIMD3<Float>(
                sin(angle) * radius,
                height + sin(angle) * 1.0, // Reduced arch effect
                -cos(angle) * radius
            )

        case .zigzag:
            let side: Float = (index % 2 == 0) ? -1.0 : 1.0
            return SIMD3<Float>(
                side * (1.0 + Float(index) * 0.3), // Reduced zigzag spread
                height,
                -baseDistance
            )

        case .spiral:
            let spiralRadius = 1.0 + Float(index) * 0.2 // Tighter spiral
            let spiralAngle = Float(index) * 0.8
            return SIMD3<Float>(
                cos(spiralAngle) * spiralRadius,
                height + Float(index) * 0.3, // Reduced vertical progression
                -sin(spiralAngle) * spiralRadius - Float(index) * 0.5 // Reduced depth progression
            )

        case .random:
            return SIMD3<Float>(
                Float.random(in: -2.0...2.0), // Reduced random spread
                Float.random(in: 0.2...1.5), // Reduced height range
                -Float.random(in: 0.5...3.0) // Much closer random depth range
            )
        }
    }

    // MARK: - Level Generation

    private func generateLevel(_ levelNumber: Int) -> TimeTrialLevel {
        let difficulty = min(1.0, Float(levelNumber - 1) * 0.1)

        // Build the handcrafted hoop course for this level. The number of gates
        // and the time budget come straight from the course definition; the
        // legacy ring fields are reused so the existing HUD/timer keep working
        // ("ringsRemaining" now means "gates remaining").
        let course = DroneCourse.handcrafted(level: levelNumber)
        currentCourse = course

        return TimeTrialLevel(
            levelNumber: levelNumber,
            ringCount: course.gates.count,
            timeLimit: course.timeLimit,
            spawnPattern: .straightLine,
            difficulty: difficulty
        )
    }

    // MARK: - Obstacle course

    private func spawnCourse() {
        guard let timeTrialEntity = timeTrialEntity, let course = currentCourse else { return }

        // Anchor the course to the drone's current world position, facing -Z.
        courseOrigin = playerDrone?.position(relativeTo: nil) ?? .zero

        for (i, spec) in course.gates.enumerated() {
            let gate = CourseGateEntity(index: i, ringRadius: spec.ringRadius)
            gate.setPosition(courseOrigin + spec.position, relativeTo: nil)
            gate.setOrientation(simd_quatf(angle: spec.yawDegrees * .pi / 180,
                                           axis: SIMD3<Float>(0, 1, 0)), relativeTo: nil)
            timeTrialEntity.addChild(gate)
        }
    }

    private func clearCourse() {
        guard let timeTrialEntity = timeTrialEntity else { return }
        for gate in timeTrialEntity.children.compactMap({ $0 as? CourseGateEntity }) {
            gate.removeFromParent()
        }
        // Clear any in-progress crash so a new level starts clean.
        if let drone = playerDrone as? PlayerDroneEntity,
           drone.components[DroneCrashComponent.self] != nil {
            recoverCrash(drone: drone)
        }
        crashPad?.removeFromParent()
        crashPad = nil
    }

    // MARK: - Crash handling

    /// Begin a crash: tumble the drone down onto a spawned pad and suppress flight
    /// input until the player lifts off. Called by TimeTrialSystem on a hit.
    public func beginCrash(drone: PlayerDroneEntity, gateRoot: Entity) {
        guard drone.components[DroneCrashComponent.self] == nil else { return }

        drone.isCrashActive = true
        #if os(visionOS)
        drone.removeDualThumbControl()
        #endif

        let pos = drone.position(relativeTo: nil)
        let fallDistance: Float = 1.2

        var crash = DroneCrashComponent()
        crash.startPos = pos
        crash.startOrientation = drone.orientation(relativeTo: nil)
        crash.landPos = SIMD3<Float>(pos.x, pos.y - fallDistance, pos.z)
        crash.spinAxis = simd_normalize(SIMD3<Float>(Float.random(in: -1...1), 0, Float.random(in: -1...1)) + SIMD3<Float>(0.01, 0, 0))
        drone.components.set(crash)

        // Spawn a landing surface just under the rest position.
        let pad = CrashPadEntity()
        pad.setPosition(SIMD3<Float>(pos.x, pos.y - fallDistance - 0.06, pos.z), relativeTo: nil)
        gateRoot.addChild(pad)
        crashPad = pad
    }

    /// Recover from a crash: restore flight control and remove the landing pad.
    public func recoverCrash(drone: PlayerDroneEntity) {
        drone.components[DroneCrashComponent.self] = nil
        drone.isCrashActive = false
        #if os(visionOS)
        drone.addDualThumbControl(
            throttleSpeed: 2.0,
            yawSpeed: 1.5,
            pitchSpeed: 2.0,
            rollSpeed: 2.0
        )
        #endif
        crashPad?.fadeAndRemove()
        crashPad = nil
    }

    // MARK: - Utility

    private func resetDronePosition() {
        guard let playerDrone = playerDrone else { return }
        playerDrone.transform.translation = SIMD3<Float>(0, 0, 0)
        playerDrone.transform.rotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    }

    public func pauseGame() {
        if currentState == .active {
            currentState = .paused
        }
    }

    public func resumeGame() {
        if currentState == .paused {
            currentState = .active
        }
    }

    public func getGameOverData() -> TimeTrialGameOverData? {
        guard let session = currentSession, let level = currentLevel else { return nil }

        return TimeTrialGameOverData(
            levelReached: level.levelNumber,
            totalRingsCollected: session.totalRingsCollected,
            totalScore: session.totalScore,
            bestTime: session.bestTime,
            finalTime: CACurrentMediaTime() - session.startTime
        )
    }
}

// MARK: - Supporting Types

public struct TimeTrialGameOverData {
    let levelReached: Int
    let totalRingsCollected: Int
    let totalScore: Int
    let bestTime: TimeInterval
    let finalTime: TimeInterval
}

// MARK: - Extensions

extension TimeTrialManager {
    public var isGameActive: Bool {
        return currentState == .active
    }

    public var currentLevelNumber: Int {
        return currentLevel?.levelNumber ?? 1
    }

    public var formattedTimeRemaining: String {
        // Always sync from ECS before returning UI values
        syncStateFromECS()

        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // Override property getters to ensure ECS sync
    public var currentRingsRemaining: Int {
        syncStateFromECS()
        return ringsRemaining
    }

    public var currentScore: Int {
        syncStateFromECS()
        return score
    }
}
