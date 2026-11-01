//
//  RaiseAltitudeTutorialStep.swift
//  HelicopterGame
//
//  Step 1: teach the LEFT joystick's throttle axis. We capture the drone's
//  starting altitude, float a glowing target orb a fixed climb above it, and
//  complete once the drone has risen to (near) the orb.
//
//  Control mapping reminder (see Gamepad3DSystem): the LEFT/blue stick drives
//  rotation (yaw) + height (throttle); pushing it up = climb.
//

#if os(visionOS)
import Foundation
import RealityKit
import simd

public final class RaiseAltitudeTutorialStep: DroneTutorialStep {

    public let id = "raise-altitude"
    public let instruction = "Touch the left joystick to raise the drone height"

    /// How far the player must climb to clear the step (meters).
    private let climbDistance: Float = 0.5
    /// Slack so the player doesn't have to hit the orb exactly.
    private let arriveSlack: Float = 0.08

    private var targetY: Float = .greatestFiniteMagnitude
    private var orb: TutorialGoalOrb?

    public init() {}

    public func activate(context: DroneTutorialContext) {
        guard let drone = context.dronePosition() else { return }
        targetY = drone.y + climbDistance

        let orb = TutorialGoalOrb()
        orb.position = SIMD3<Float>(drone.x, targetY, drone.z)
        context.overlayRoot.addChild(orb)
        self.orb = orb
    }

    public func update(context: DroneTutorialContext, deltaTime: TimeInterval) {
        orb?.update(deltaTime: deltaTime)
    }

    public func isComplete(context: DroneTutorialContext) -> Bool {
        guard let drone = context.dronePosition() else { return false }
        return drone.y >= targetY - arriveSlack
    }

    public func deactivate(context: DroneTutorialContext) {
        orb?.removeFromParent()
        orb = nil
    }
}
#endif
