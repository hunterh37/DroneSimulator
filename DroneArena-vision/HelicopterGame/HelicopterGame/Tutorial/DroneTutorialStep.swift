//
//  DroneTutorialStep.swift
//  HelicopterGame
//
//  The unit of the first-launch flight tutorial. Each concrete step owns one
//  teachable goal (raise altitude, fly forward, …): the instruction copy shown
//  as floating 3D text, the in-world goal visuals it spawns (e.g. a glowing
//  target orb), and the completion test the controller polls each tick.
//
//  Adding a new tutorial beat is intentionally cheap: implement this protocol
//  and append the step to `DroneTutorialController.makeSteps()`. Steps never
//  touch UserDefaults, the ticker, or the instruction text entity directly —
//  the controller drives all of that, so steps stay small and testable.
//

#if os(visionOS)
import Foundation

@MainActor
public protocol DroneTutorialStep: AnyObject {
    /// Stable identifier, handy for logging / analytics.
    var id: String { get }

    /// Copy rendered as floating 3D text while this step is active.
    var instruction: String { get }

    /// Called once when the step becomes active. Spawn any goal visuals into
    /// `context.overlayRoot` and capture whatever baseline the completion test
    /// needs (e.g. the drone's starting altitude).
    func activate(context: DroneTutorialContext)

    /// Polled every tick. Return `true` once the player has satisfied the goal;
    /// the controller then deactivates this step and advances to the next.
    func isComplete(context: DroneTutorialContext) -> Bool

    /// Called when the step ends (completed or the whole tutorial is torn down).
    /// Remove any visuals spawned in `activate`.
    func deactivate(context: DroneTutorialContext)

    /// Optional per-frame hook for animating goal visuals (orb pulse, etc.).
    func update(context: DroneTutorialContext, deltaTime: TimeInterval)
}

public extension DroneTutorialStep {
    func update(context: DroneTutorialContext, deltaTime: TimeInterval) {}
}
#endif
