import Testing
import Foundation
import simd
@testable import PinchStickCore

private func sample(_ p: SIMD3<Float>, gap: Float = 0.01, t: Double) -> PinchSample {
    PinchSample(thumbTip: p - SIMD3(gap / 2, 0, 0), indexTip: p + SIMD3(gap / 2, 0, 0), time: t)
}

private func held(_ side: StickSide = .right, yaw: Float = 0) -> PinchStickMachine {
    var m = PinchStickMachine(side: side)
    m.update(sample: sample(.zero, t: 0), headYaw: yaw)
    return m
}

/// Drives the machine at 90 Hz until the filter settles.
private func settle(_ m: inout PinchStickMachine, at p: SIMD3<Float>, from t0: Double = 0.01) -> Double {
    var t = t0
    for _ in 0..<900 { m.update(sample: sample(p, t: t), headYaw: 0); t += 1.0 / 90 }
    return t
}

@Test func engageReleaseHysteresis() {
    var m = PinchStickMachine(side: .right)
    m.update(sample: sample(.zero, gap: 0.02, t: 0), headYaw: 0)
    #expect(!m.state.held)
    m.update(sample: sample(.zero, gap: 0.014, t: 0.01), headYaw: 0)
    #expect(m.state.held)
    m.update(sample: sample(.zero, gap: 0.02, t: 0.02), headYaw: 0)
    #expect(m.state.held)
    m.update(sample: sample(.zero, gap: 0.026, t: 0.03), headYaw: 0)
    #expect(!m.state.held)
    m.update(sample: sample(.zero, gap: 0.02, t: 0.04), headYaw: 0)
    #expect(!m.state.held)
}

@Test func releaseIsExactZeroSameUpdate() {
    var m = held()
    _ = settle(&m, at: SIMD3(0.05, 0, 0))
    #expect(m.state.output != .zero)
    let s = m.update(sample: sample(SIMD3(0.05, 0, 0), gap: 0.03, t: 100), headYaw: 0)
    #expect(s.output == .zero)
    #expect(s.knobPlane == .zero)
    #expect(!s.held)
}

@Test func trackingLossIsZero() {
    var m = held()
    _ = settle(&m, at: SIMD3(0, 0, -0.05))
    let s = m.update(sample: nil, headYaw: 0)
    #expect(s.output == .zero && !s.held)
}

@Test func deadzone() {
    var m = held()
    _ = settle(&m, at: SIMD3(0.011, 0, 0))
    #expect(m.state.output == .zero)
    #expect(StickMapping.map(SIMD2(0.0121, 0), config: PinchStickConfig()).x > 0)
    #expect(StickMapping.map(SIMD2(0.012, 0), config: PinchStickConfig()) == .zero)
}

@Test func fullThrowClampsToUnitCircle() {
    let c = PinchStickConfig()
    #expect(abs(StickMapping.map(SIMD2(0.06, 0), config: c).x - 1) < 1e-5)
    #expect(abs(StickMapping.map(SIMD2(0.5, 0), config: c).x - 1) < 1e-5)
    let diag = StickMapping.map(SIMD2(0.3, 0.3), config: c)
    #expect(simd_length(diag) <= 1.0001)
    var m = held()
    _ = settle(&m, at: SIMD3(0.3, 0, -0.3))
    #expect(simd_length(m.state.output) <= 1.0001)
    #expect(simd_length(m.state.knobPlane) <= 0.06 + 1e-5)
}

@Test func expoCurve() {
    let c = PinchStickConfig()
    let r = c.deadzone + 0.5 * (c.fullThrow - c.deadzone)  // m = 0.5
    let mid = StickMapping.map(SIMD2(r, 0), config: c).x
    let expected: Float = (1 - c.expo) * 0.5 + c.expo * 0.125
    #expect(abs(mid - expected) < 1e-5)
    #expect(mid < 0.5)
}

@Test func filterDoesNotOvershootStep() {
    var f = OneEuroFilter(minCutoff: 1.0, beta: 0.02)
    f.reset(to: 0, time: 0)
    var t = 0.0
    var maxV: Float = 0
    var prev: Float = 0
    for _ in 0..<2000 {
        t += 1.0 / 90
        let v = f.filter(0.05, time: t)
        maxV = max(maxV, v)
        #expect(v >= prev - 1e-7)
        prev = v
    }
    #expect(maxV <= 0.05 + 1e-6)
    #expect(abs(prev - 0.05) < 1e-4)
}

@Test func headYawFrameRotation() {
    // Head turned 90 degrees left (forward = -X). Moving toward -X is forward.
    let yaw = StickMapping.yaw(forward: SIMD3(-1, 0, 0))
    let l = StickMapping.localize(SIMD3(-0.05, 0, 0), yaw: yaw)
    #expect(abs(l.z - 0.05) < 1e-5 && abs(l.x) < 1e-5)
    // Right of that head is -Z.
    let r = StickMapping.localize(SIMD3(0, 0, -0.05), yaw: yaw)
    #expect(abs(r.x - 0.05) < 1e-5 && abs(r.z) < 1e-5)
    #expect(abs(StickMapping.yaw(forward: SIMD3(0, 0, -1))) < 1e-6)

    var m = held(.right, yaw: yaw)
    var t = 0.01
    for _ in 0..<900 { m.update(sample: sample(SIMD3(-0.06, 0, 0), t: t), headYaw: yaw); t += 1.0 / 90 }
    #expect(m.state.output.y > 0.9 && abs(m.state.output.x) < 0.01)
}

@Test func leftRightAxisMapping() {
    var right = held(.right)
    _ = settle(&right, at: SIMD3(0.06, 0.06, -0.06))
    #expect(right.state.output.x > 0.5)   // roll
    #expect(right.state.output.y > 0.5)   // forward = pitch, height ignored

    var left = held(.left)
    _ = settle(&left, at: SIMD3(0.06, 0.06, -0.06))
    #expect(left.state.output.x > 0.5)    // yaw
    #expect(left.state.output.y > 0.5)    // up = throttle, depth ignored

    var rightUp = held(.right)
    _ = settle(&rightUp, at: SIMD3(0, 0.06, 0))
    #expect(rightUp.state.output == .zero)
    var leftFwd = held(.left)
    _ = settle(&leftFwd, at: SIMD3(0, 0, -0.06))
    #expect(leftFwd.state.output == .zero)
}

@Test func regrabRecenters() {
    var m = held()
    var t = settle(&m, at: SIMD3(0.06, 0, 0))
    m.update(sample: sample(SIMD3(0.06, 0, 0), gap: 0.03, t: t), headYaw: 0); t += 0.01
    m.update(sample: sample(SIMD3(0.06, 0, 0), t: t), headYaw: 0)
    #expect(m.state.held && m.state.output == .zero)
    #expect(m.state.origin.x == 0.06)
}
