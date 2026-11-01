import Foundation
import simd

/// Per-hand grab state machine. Pass nil for a lost hand; that releases.
public struct PinchStickMachine: Sendable {
    public let side: StickSide
    public var config: PinchStickConfig
    public private(set) var state = PinchStickState()
    private var filter: OneEuroFilter3

    public init(side: StickSide, config: PinchStickConfig = PinchStickConfig()) {
        self.side = side
        self.config = config
        filter = OneEuroFilter3(minCutoff: config.minCutoff, beta: config.beta,
                                derivativeCutoff: config.derivativeCutoff)
    }

    @discardableResult
    public mutating func update(sample: PinchSample?, headYaw: Float) -> PinchStickState {
        guard let sample else { return release() }
        let distance = sample.distance
        if state.held {
            if distance > config.releaseDistance { return release() }
        } else {
            guard distance < config.engageDistance else { return state }
            engage(at: sample, headYaw: headYaw)
            return state
        }
        let p = filter.filter(sample.pinchPoint, time: sample.time)
        let local = StickMapping.localize(p - state.origin, yaw: state.yaw)
        let plane = StickMapping.plane(local, side: side)
        state.output = StickMapping.map(plane, config: config)
        state.knobPlane = StickMapping.clampKnob(plane, config: config)
        return state
    }

    private mutating func engage(at sample: PinchSample, headYaw: Float) {
        state = PinchStickState()
        state.held = true
        state.origin = sample.pinchPoint
        state.yaw = headYaw
        filter = OneEuroFilter3(minCutoff: config.minCutoff, beta: config.beta,
                                derivativeCutoff: config.derivativeCutoff)
        filter.reset(to: sample.pinchPoint, time: sample.time)
    }

    private mutating func release() -> PinchStickState {
        state.held = false
        state.output = .zero
        state.knobPlane = .zero
        return state
    }
}
