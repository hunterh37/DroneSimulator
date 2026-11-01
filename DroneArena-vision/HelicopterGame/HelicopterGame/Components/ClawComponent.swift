//
//  ClawComponent.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/2/25.
//

import RealityKit
import simd
import Foundation

/// Component that marks an entity as a claw and tracks its state
public struct ClawComponent: Component {
    public var state: ClawState
    public var animationStartTime: TimeInterval
    public var targetPosition: SIMD3<Float>
    public var originalPosition: SIMD3<Float>
    public var animationDuration: Float
    public var maxGrabDistance: Float
    public var grabRadius: Float
    public var attachedPackageID: String?

    public init(
        state: ClawState = .stowed,
        animationDuration: Float = 0.3,
        maxGrabDistance: Float = 1.0,
        grabRadius: Float = 0.5
    ) {
        self.state = state
        self.animationStartTime = 0
        self.targetPosition = .zero
        self.originalPosition = SIMD3<Float>(0, 0.1, 0) // Default claw position - close to drone
        self.animationDuration = animationDuration
        self.maxGrabDistance = maxGrabDistance
        self.grabRadius = grabRadius
        self.attachedPackageID = nil
    }
}

/// Component that marks an entity as grabbable by a claw
public struct GrabbableComponent: Component {
    public var isPickedUp: Bool
    public var gripRadius: Float
    public var attachedToClawID: UInt64?

    public init(gripRadius: Float = 0.18, isPickedUp: Bool = false) {
        self.gripRadius = gripRadius
        self.isPickedUp = isPickedUp
        self.attachedToClawID = nil
    }
}

/// Component that tracks claw input intents
public struct ClawInputComponent: Component {
    public var pendingIntent: ClawIntent?
    public var lastProcessedTime: TimeInterval

    public init() {
        self.pendingIntent = nil
        self.lastProcessedTime = 0
    }
}
