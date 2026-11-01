import Testing
import simd
@testable import PinchStickCore

private func s(_ thumb: SIMD3<Float>, t: Double) -> ThumbSample {
    // Hand pointing -Z, index middle at origin.
    ThumbSample(thumbTip: thumb, indexMiddle: .zero, indexKnuckle: SIMD3(0, 0, 0.03),
                wrist: SIMD3(0, 0, 0.12), time: t)
}

@Test func thumbEngagesAndCentersAtRest() {
    var m = ThumbStickMachine(side: .left)
    let st = m.update(sample: s(SIMD3(0.01, 0, 0), t: 0))
    #expect(st.held)
    #expect(st.output == .zero)
}

@Test func thumbFarDoesNotEngage() {
    var m = ThumbStickMachine(side: .right)
    #expect(!m.update(sample: s(SIMD3(0.06, 0, 0), t: 0)).held)
}

@Test func thumbForwardAndRightMapToAxes() {
    var m = ThumbStickMachine(side: .right)
    m.update(sample: s(SIMD3(0.01, 0, 0), t: 0))
    var st = ThumbStickState()
    for i in 1...60 { st = m.update(sample: s(SIMD3(0.01 + 0.02, 0, -0.02), t: Double(i) / 90)) }
    #expect(st.output.x > 0.5)
    #expect(st.output.y > 0.5)
    #expect(simd_length(st.output) <= 1.0001)
}

@Test func thumbReleasesWhenLifted() {
    var m = ThumbStickMachine(side: .left)
    m.update(sample: s(SIMD3(0.01, 0, 0), t: 0))
    let st = m.update(sample: s(SIMD3(0.01, 0.08, 0), t: 0.02))
    #expect(!st.held)
    #expect(st.output == .zero)
}
