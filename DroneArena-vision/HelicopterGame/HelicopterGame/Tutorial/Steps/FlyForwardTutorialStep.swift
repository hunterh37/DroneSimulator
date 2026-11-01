//
//  FlyForwardTutorialStep.swift
//  HelicopterGame
//
//  Step 2: teach the RIGHT joystick's pitch axis. We drop a glowing target orb
//  ahead of the drone (world -Z) at its current height and complete once the
//  drone has flown forward to it.
//
//  Control mapping reminder (see Gamepad3DSystem): the RIGHT/orange stick drives
//  position (pitch + roll); pushing it forward = fly ahead.
//

#if os(visionOS)
import Foundation
import RealityKit
import simd

public final class FlyForwardTutorialStep: DroneTutorialStep {

    public let id = "fly-forward"
    public let instruction = "Now push the right joystick forward to fly ahead"

    /// How far ahead (meters, world -Z) the target sits.
    private let forwardDistance: Float = 1.0
    private let arriveSlack: Float = 0.2

    private var targetZ: Float = -.greatestFiniteMagnitude
    private var orb: TutorialGoalOrb?

    public init() {}

    public func activate(context: DroneTutorialContext) {
        guard let drone = context.dronePosition() else { return }
        targetZ = drone.z - forwardDistance

        let orb = TutorialGoalOrb()
        orb.position = SIMD3<Float>(drone.x, drone.y, targetZ)
        context.overlayRoot.addChild(orb)
        self.orb = orb
    }

    public func update(context: DroneTutorialContext, deltaTime: TimeInterval) {
        orb?.update(deltaTime: deltaTime)
    }

    public func isComplete(context: DroneTutorialContext) -> Bool {
        guard let drone = context.dronePosition() else { return false }
        // Forward is -Z, so completion means the drone's z has dropped to target.
        return drone.z <= targetZ + arriveSlack
    }

    public func deactivate(context: DroneTutorialContext) {
        orb?.removeFromParent()
        orb = nil
    }
}
#endif
