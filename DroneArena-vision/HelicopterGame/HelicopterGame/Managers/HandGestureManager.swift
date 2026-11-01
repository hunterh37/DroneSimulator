//
//  HandGestureManager.swift
//  HelicopterGame
//
//  Created by Claude Code
//

import Foundation
import simd
import Combine

#if os(visionOS)
import ARKit
import RealityKit
import UIKit
import DicyaninARKitSession

/// Hand side enumeration
public enum HandSide {
    case left
    case right
}

/// Hand tracking update structure
public struct HandAnchorUpdate {
    public var left: HandAnchor?
    public var right: HandAnchor?
}

/// Convert HandAnchor to usable hand data
struct HandAnchorConverter {
    static func convert(_ anchor: HandAnchor) -> Hand {
        guard let handSkeleton = anchor.handSkeleton else {
            return Hand(thumbTip: nil, indexTip: nil, middleTip: nil, wrist: nil)
        }

        let originTransform = anchor.originFromAnchorTransform

        let thumbTipJoint = handSkeleton.joint(.thumbTip)
        let indexTipJoint = handSkeleton.joint(.indexFingerTip)
        let middleTipJoint = handSkeleton.joint(.middleFingerTip)
        let wristJoint = handSkeleton.joint(.wrist)

        let thumbTipTransform = matrix_multiply(originTransform, thumbTipJoint.anchorFromJointTransform)
        let indexTipTransform = matrix_multiply(originTransform, indexTipJoint.anchorFromJointTransform)
        let middleTipTransform = matrix_multiply(originTransform, middleTipJoint.anchorFromJointTransform)
        let wristTransform = matrix_multiply(originTransform, wristJoint.anchorFromJointTransform)

        let thumbTipPos = SIMD3<Float>(thumbTipTransform.columns.3.x,
                                      thumbTipTransform.columns.3.y,
                                      thumbTipTransform.columns.3.z)
        let indexTipPos = SIMD3<Float>(indexTipTransform.columns.3.x,
                                      indexTipTransform.columns.3.y,
                                      indexTipTransform.columns.3.z)
        let middleTipPos = SIMD3<Float>(middleTipTransform.columns.3.x,
                                       middleTipTransform.columns.3.y,
                                       middleTipTransform.columns.3.z)
        let wristPos = SIMD3<Float>(wristTransform.columns.3.x,
                                   wristTransform.columns.3.y,
                                   wristTransform.columns.3.z)

        return Hand(thumbTip: thumbTipPos, indexTip: indexTipPos, middleTip: middleTipPos, wrist: wristPos)
    }
}

/// Hand data structure
public struct Hand {
    public let thumbTip: SIMD3<Float>?
    public let indexTip: SIMD3<Float>?
    public let middleTip: SIMD3<Float>?
    public let wrist: SIMD3<Float>?

    public init(thumbTip: SIMD3<Float>?, indexTip: SIMD3<Float>?, middleTip: SIMD3<Float>?, wrist: SIMD3<Float>?) {
        self.thumbTip = thumbTip
        self.indexTip = indexTip
        self.middleTip = middleTip
        self.wrist = wrist
    }
}

/// Gesture types that can be detected
public enum GestureType {
    case pinch(hand: HandSide)
    case indexFingerTouch
    case doublePinch
    case palmFacing(hand: HandSide)
}

/// Gesture event structure
public struct GestureEvent {
    public let type: GestureType
    public let position: SIMD3<Float>?
    public let timestamp: Date

    public init(type: GestureType, position: SIMD3<Float>? = nil) {
        self.type = type
        self.position = position
        self.timestamp = Date()
    }
}

/// Main hand gesture manager
@MainActor
public class HandGestureManager: ObservableObject {
    // Backing store for GameContext — fileprivate so this is the only file
    // that can reach `HandGestureManager.shared` directly; everyone else
    // must go through GameContext.shared.handGesture.
    fileprivate static let shared = HandGestureManager()

    // MARK: - Published Properties
    @Published public private(set) var latestHandTracking: HandAnchorUpdate = .init(left: nil, right: nil)
    @Published public private(set) var isLeftPinching: Bool = false
    @Published public private(set) var isRightPinching: Bool = false
    @Published public private(set) var isIndexFingersTouching: Bool = false
    @Published public private(set) var isBothHandsPinching: Bool = false
    @Published public private(set) var isLeftPalmFacing: Bool = false
    @Published public private(set) var isRightPalmFacing: Bool = false

    // MARK: - Gesture Positions
    @Published public private(set) var leftPinchPosition: SIMD3<Float>?
    @Published public private(set) var rightPinchPosition: SIMD3<Float>?
    @Published public private(set) var indexTouchPosition: SIMD3<Float>?

    // MARK: - Configuration
    public var pinchDistanceThreshold: Float = 0.02 // 2cm
    public var indexTouchDistanceThreshold: Float = 0.03 // 3cm
    public var enableDiagnostics: Bool = true // Enable diagnostics by default for debugging

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()

    // Gesture event publisher
    private let gestureEventSubject = PassthroughSubject<GestureEvent, Never>()
    public var gestureEvents: AnyPublisher<GestureEvent, Never> {
        gestureEventSubject.eraseToAnyPublisher()
    }

    private init() {}

    // MARK: - Lifecycle

    public func start() async throws {
        gameLog("🖐️ [HandGestureManager] Starting - subscribing to ARKitSessionManager.shared.handTrackingUpdates")

        // Subscribe to existing hand tracking updates from ARKitSessionManager
        ARKitSessionManager.shared.handTrackingUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                guard let self = self else { return }

                // Process left hand
                if let leftHand = update.left {
                    self.latestHandTracking.left = leftHand
                    self.checkLeftHandGestures(leftHand)
                }

                // Process right hand
                if let rightHand = update.right {
                    self.latestHandTracking.right = rightHand
                    self.checkRightHandGestures(rightHand)
                }

                // Check cross-hand gestures (requires both hands)
                self.checkCrossHandGestures()
            }
            .store(in: &cancellables)

        gameLog("✅ [HandGestureManager] Successfully subscribed to hand tracking updates")
    }

    public func stop() {
        cancellables.removeAll()
        gameLog("🛑 [HandGestureManager] Stopped and cancelled all subscriptions")
    }

    public func reset() {
        isLeftPinching = false
        isRightPinching = false
        isIndexFingersTouching = false
        isBothHandsPinching = false
        isLeftPalmFacing = false
        isRightPalmFacing = false
        leftPinchPosition = nil
        rightPinchPosition = nil
        indexTouchPosition = nil
    }

    // MARK: - Left Hand Gestures

    private func checkLeftHandGestures(_ anchor: HandAnchor) {
        checkPinchGesture(anchor, isLeftHand: true)
        checkPalmFacingGesture(anchor, isLeftHand: true)
    }

    // MARK: - Right Hand Gestures

    private func checkRightHandGestures(_ anchor: HandAnchor) {
        checkPinchGesture(anchor, isLeftHand: false)
        checkPalmFacingGesture(anchor, isLeftHand: false)
    }

    // MARK: - Cross Hand Gestures

    private func checkCrossHandGestures() {
        checkIndexFingerTouchGesture()
        checkDoublePinchGesture()
    }

    // MARK: - Pinch Gesture Detection

    private func checkPinchGesture(_ anchor: HandAnchor, isLeftHand: Bool) {
        guard let handSkeleton = anchor.handSkeleton else {
            if isLeftHand {
                isLeftPinching = false
                leftPinchPosition = nil
            } else {
                isRightPinching = false
                rightPinchPosition = nil
            }
            return
        }

        let indexFinger = handSkeleton.joint(.indexFingerTip)
        let thumbTip = handSkeleton.joint(.thumbTip)
        let originTransform = anchor.originFromAnchorTransform

        let indexFingerPos = matrix_multiply(originTransform, indexFinger.anchorFromJointTransform).translation
        let thumbTipPos = matrix_multiply(originTransform, thumbTip.anchorFromJointTransform).translation

        let distance = simd_distance(indexFingerPos, thumbTipPos)
        let isPinching = distance < pinchDistanceThreshold

        if isLeftHand {
            let wasPinching = isLeftPinching
            isLeftPinching = isPinching
            leftPinchPosition = isPinching ? thumbTipPos : nil

            if isPinching && !wasPinching {
                gestureEventSubject.send(GestureEvent(type: .pinch(hand: .left), position: thumbTipPos))
            }
        } else {
            let wasPinching = isRightPinching
            isRightPinching = isPinching
            rightPinchPosition = isPinching ? thumbTipPos : nil

            if isPinching && !wasPinching {
                gestureEventSubject.send(GestureEvent(type: .pinch(hand: .right), position: thumbTipPos))
            }
        }

        if enableDiagnostics {
            let handName = isLeftHand ? "LEFT" : "RIGHT"
            gameLog("🤏 [\(handName)] Pinch distance: \(distance) | Pinching: \(isPinching)")
        }
    }

    // MARK: - Index Finger Touch Gesture Detection

    private func checkIndexFingerTouchGesture() {
        guard let leftHand = latestHandTracking.left,
              let rightHand = latestHandTracking.right,
              let leftSkeleton = leftHand.handSkeleton,
              let rightSkeleton = rightHand.handSkeleton else {
            isIndexFingersTouching = false
            indexTouchPosition = nil
            return
        }

        let leftIndexTip = leftSkeleton.joint(.indexFingerTip)
        let rightIndexTip = rightSkeleton.joint(.indexFingerTip)

        let leftOriginTransform = leftHand.originFromAnchorTransform
        let rightOriginTransform = rightHand.originFromAnchorTransform

        let leftIndexPos = matrix_multiply(leftOriginTransform, leftIndexTip.anchorFromJointTransform).translation
        let rightIndexPos = matrix_multiply(rightOriginTransform, rightIndexTip.anchorFromJointTransform).translation

        let distance = simd_distance(leftIndexPos, rightIndexPos)
        let wasTouching = isIndexFingersTouching
        isIndexFingersTouching = distance < indexTouchDistanceThreshold

        if isIndexFingersTouching {
            // Calculate midpoint between the two fingers
            indexTouchPosition = (leftIndexPos + rightIndexPos) / 2.0

            if !wasTouching {
                gameLog("🔥 [HandGestureManager] Publishing indexFingerTouch event!")
                gestureEventSubject.send(GestureEvent(type: .indexFingerTouch, position: indexTouchPosition))
                gameLog("✅ [HandGestureManager] Event sent successfully")
            }
        } else {
            indexTouchPosition = nil
        }

        if enableDiagnostics {
            gameLog("👆 Index finger touch distance: \(distance) | Touching: \(isIndexFingersTouching) | Was touching: \(wasTouching)")
        }
    }

    // MARK: - Double Pinch Gesture Detection

    private func checkDoublePinchGesture() {
        let wasBothPinching = isBothHandsPinching
        isBothHandsPinching = isLeftPinching && isRightPinching

        if isBothHandsPinching && !wasBothPinching {
            gestureEventSubject.send(GestureEvent(type: .doublePinch))
        }
    }

    // MARK: - Palm Facing Gesture Detection

    private func checkPalmFacingGesture(_ anchor: HandAnchor, isLeftHand: Bool) {
        guard let palmNormal = calculatePalmNormal(anchor: anchor) else {
            if isLeftHand {
                isLeftPalmFacing = false
            } else {
                isRightPalmFacing = false
            }
            return
        }

        // Simple forward vector (user's viewing direction)
        let forwardVector = SIMD3<Float>(0, 0, -1)

        // Check if palm is facing the user
        let dotWithForward = simd_dot(palmNormal, forwardVector)
        let isPalmFacing = dotWithForward > 0.7 // Palm facing user threshold

        if isLeftHand {
            let wasFacing = isLeftPalmFacing
            isLeftPalmFacing = isPalmFacing

            if isPalmFacing && !wasFacing {
                gestureEventSubject.send(GestureEvent(type: .palmFacing(hand: .left)))
            }
        } else {
            let wasFacing = isRightPalmFacing
            isRightPalmFacing = isPalmFacing

            if isPalmFacing && !wasFacing {
                gestureEventSubject.send(GestureEvent(type: .palmFacing(hand: .right)))
            }
        }

        if enableDiagnostics {
            let handName = isLeftHand ? "LEFT" : "RIGHT"
            gameLog("🖐️ [\(handName)] Palm dot: \(dotWithForward) | Facing: \(isPalmFacing)")
        }
    }

    private func calculatePalmNormal(anchor: HandAnchor) -> SIMD3<Float>? {
        guard let wrist = anchor.handSkeleton?.joint(.wrist),
              let middleMCP = anchor.handSkeleton?.joint(.middleFingerMetacarpal),
              let ringMCP = anchor.handSkeleton?.joint(.ringFingerMetacarpal),
              let indexMCP = anchor.handSkeleton?.joint(.indexFingerMetacarpal) else {
            return nil
        }

        let wristPos = matrix_multiply(anchor.originFromAnchorTransform, wrist.anchorFromJointTransform).translation
        let middleMCPPos = matrix_multiply(anchor.originFromAnchorTransform, middleMCP.anchorFromJointTransform).translation
        let ringMCPPos = matrix_multiply(anchor.originFromAnchorTransform, ringMCP.anchorFromJointTransform).translation
        let indexMCPPos = matrix_multiply(anchor.originFromAnchorTransform, indexMCP.anchorFromJointTransform).translation

        // Calculate palm center
        let palmCenter = (middleMCPPos + ringMCPPos + indexMCPPos) / 3.0

        // Calculate vectors
        let vector1 = indexMCPPos - ringMCPPos
        let vector2 = middleMCPPos - wristPos

        // Calculate normal
        let normal = simd_normalize(simd_cross(vector1, vector2))

        // Ensure the normal is pointing out from the palm
        let towardsPalm = simd_normalize(palmCenter - wristPos)
        return simd_dot(normal, towardsPalm) > 0 ? -normal : normal
    }

    // MARK: - Helper Methods

    public func getLeftHand() -> Hand? {
        guard let leftAnchor = latestHandTracking.left else { return nil }
        return HandAnchorConverter.convert(leftAnchor)
    }

    public func getRightHand() -> Hand? {
        guard let rightAnchor = latestHandTracking.right else { return nil }
        return HandAnchorConverter.convert(rightAnchor)
    }
}

// MARK: - Errors

public enum HandGestureError: Error {
    case notSupported
    case sessionFailed
}

// MARK: - Extensions

extension simd_float4x4 {
    var translation: SIMD3<Float> {
        return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}

#else

// MARK: - Mock Implementation for non-visionOS platforms

@MainActor
public class HandGestureManager: ObservableObject {
    // Backing store for GameContext — fileprivate so this is the only file
    // that can reach `HandGestureManager.shared` directly; everyone else
    // must go through GameContext.shared.handGesture.
    fileprivate static let shared = HandGestureManager()

    @Published public private(set) var isLeftPinching: Bool = false
    @Published public private(set) var isRightPinching: Bool = false
    @Published public private(set) var isIndexFingersTouching: Bool = false
    @Published public private(set) var isBothHandsPinching: Bool = false
    @Published public private(set) var isLeftPalmFacing: Bool = false
    @Published public private(set) var isRightPalmFacing: Bool = false

    @Published public private(set) var leftPinchPosition: SIMD3<Float>?
    @Published public private(set) var rightPinchPosition: SIMD3<Float>?
    @Published public private(set) var indexTouchPosition: SIMD3<Float>?

    public var pinchDistanceThreshold: Float = 0.02
    public var indexTouchDistanceThreshold: Float = 0.03
    public var enableDiagnostics: Bool = false

    private init() {}

    public func start() async throws {}
    public func stop() {}
    public func reset() {}
}

#endif

extension GameContext {
    public var handGesture: HandGestureManager { HandGestureManager.shared }
}
