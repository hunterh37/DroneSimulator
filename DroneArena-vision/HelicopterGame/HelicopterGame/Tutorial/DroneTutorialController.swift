//
//  DroneTutorialController.swift
//  HelicopterGame
//
//  Orchestrates the first-launch flight tutorial. It runs ONCE on first launch
//  (gated by UserDefaults), immediately after the player clears the ARKit
//  permissions gate and the immersive world comes up — throwing the player
//  straight into a guided flight.
//
//  Responsibilities:
//   - First-run gating (`shouldRun` / `startIfNeeded`).
//   - Ensuring the drone + 3D gamepad are present so the player can follow along.
//   - Driving an ordered list of `DroneTutorialStep`s: showing each step's
//     floating 3D instruction text, ticking it for completion, advancing.
//   - Tearing everything down when the last step is cleared.
//
//  Adding a beat = add a `DroneTutorialStep` to `makeSteps()`. The controller
//  stays unchanged.
//
//  Reached via `GameContext.shared.droneTutorial` (accessor at file end),
//  matching the project's single-seam manager convention.
//

#if os(visionOS)
import RealityKit
import Foundation
import UIKit
import simd

@MainActor
public final class DroneTutorialController {

    fileprivate static let shared = DroneTutorialController()

    /// Persisted flag so the first-launch tutorial only auto-runs once.
    private let seenKey = "HasSeenDroneTutorial"

    // Active-run state.
    private var context: DroneTutorialContext?
    private var steps: [DroneTutorialStep] = []
    private var index = 0
    private var isRunning = false

    private var overlayRoot: Entity?
    private var instructionEntity: Entity?

    private var ticker: Timer?
    private var lastTick = Date()

    private init() {}

    // MARK: - Step roster (the one place beats are declared)

    /// The ordered tutorial. Append steps here to extend the flow.
    public static func makeSteps() -> [DroneTutorialStep] {
        [
            RaiseAltitudeTutorialStep(),
            FlyForwardTutorialStep(),
        ]
    }

    // MARK: - Entry points

    /// True until the first-launch tutorial has been completed/seen once.
    public var shouldRun: Bool { !UserDefaults.standard.bool(forKey: seenKey) }

    /// First-launch auto-entry. No-op if already seen or already running.
    /// Call once the immersive world is set up (see ImmersiveView).
    public func startIfNeeded(in worldScene: WorldSceneController) {
        guard shouldRun else { return }
        start(in: worldScene)
    }

    /// Force-start the tutorial regardless of the seen flag (e.g. a Help button).
    public func start(in worldScene: WorldSceneController) {
        guard !isRunning else { return }
        isRunning = true
        UserDefaults.standard.set(true, forKey: seenKey)

        // Make sure the things the tutorial talks about actually exist.
        worldScene.setupGamepad3DIfNeeded()

        let root = Entity()
        worldScene.rootEntity.addChild(root)
        overlayRoot = root

        let ctx = DroneTutorialContext(worldScene: worldScene, overlayRoot: root)
        context = ctx

        steps = Self.makeSteps()
        index = 0

        guard !steps.isEmpty else { finish(); return }

        beginCurrentStep()
        startTicker()
        gameLog("🎓 Drone tutorial started (\(steps.count) steps)")
    }

    /// Stop and tear down immediately (e.g. the player leaves the immersive space).
    public func stop() {
        guard isRunning else { return }
        finish()
    }

    // MARK: - Step lifecycle

    private func beginCurrentStep() {
        guard let ctx = context, steps.indices.contains(index) else { return }
        let step = steps[index]
        presentInstruction(step.instruction, in: ctx)
        step.activate(context: ctx)
        gameLog("🎓 Tutorial step \(index + 1)/\(steps.count): \(step.id)")
    }

    private func advance() {
        guard let ctx = context, steps.indices.contains(index) else { return }
        steps[index].deactivate(context: ctx)
        clearInstruction()

        index += 1
        if steps.indices.contains(index) {
            beginCurrentStep()
        } else {
            finish()
        }
    }

    private func finish() {
        ticker?.invalidate()
        ticker = nil

        if let ctx = context, steps.indices.contains(index) {
            steps[index].deactivate(context: ctx)
        }
        clearInstruction()
        overlayRoot?.removeFromParent()
        overlayRoot = nil
        context = nil
        steps = []
        index = 0
        isRunning = false
        gameLog("🎓 Drone tutorial finished")
    }

    // MARK: - Ticker

    private func startTicker() {
        lastTick = Date()
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard isRunning, let ctx = context, steps.indices.contains(index) else { return }

        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now

        let step = steps[index]
        step.update(context: ctx, deltaTime: dt)

        if step.isComplete(context: ctx) {
            advance()
        }
    }

    // MARK: - Instruction text

    private func presentInstruction(_ text: String, in ctx: DroneTutorialContext) {
        clearInstruction()
        let entity = TutorialText.make(text, color: .white, fontSize: 0.05)
        // Comfortable reading spot, in front of and slightly above the gamepad.
        entity.position = SIMD3<Float>(0, 1.55, -1.0)
        ctx.overlayRoot.addChild(entity)
        instructionEntity = entity
    }

    private func clearInstruction() {
        instructionEntity?.removeFromParent()
        instructionEntity = nil
    }
}

// MARK: - GameContext seam

extension GameContext {
    /// The first-launch flight tutorial controller.
    public var droneTutorial: DroneTutorialController { DroneTutorialController.shared }
}
#endif
