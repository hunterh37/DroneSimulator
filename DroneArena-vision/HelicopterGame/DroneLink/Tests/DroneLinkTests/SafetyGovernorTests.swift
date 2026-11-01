import Testing
@testable import DroneLink

struct SafetyGovernorTests {
    private let up = DroneSticks(yaw: 0.2, throttle: 1, roll: 0.3, pitch: 0.4)

    private func run(_ h: Int?, age: Double? = 0.1, _ s: DroneSticks? = nil,
                     g: SafetyGovernor = SafetyGovernor()) -> (DroneSticks, SafetyStatus) {
        var g = g
        let r = g.apply(s ?? up, heightCM: h, telemetryAge: age)
        return (r.sticks, r.status)
    }

    @Test func thresholdsDeriveFromCeiling() {
        let g = SafetyGovernor()
        #expect(g.ceilingCM == 305 && g.warnCM == 240 && g.clampCM == 290)
    }

    @Test func belowWarningPassesThrough() {
        let (s, st) = run(239)
        #expect(st == .normal && s == up)
    }

    @Test func warningStartsAt240FullThrottle() {
        let (s, st) = run(240)
        #expect(st == .warning && s.throttle == 1)
    }

    @Test func warningScalesLinearly() {
        let (s, st) = run(265)
        #expect(st == .warning && abs(s.throttle - 0.5) < 0.001)
        #expect(run(289).0.throttle < 0.03)
    }

    @Test func warningLeavesDownThrottleAndOtherAxes() {
        let down = DroneSticks(yaw: 0.2, throttle: -0.7, roll: 0.3, pitch: 0.4)
        let (s, st) = run(270, down)
        #expect(st == .warning && s == down)
        #expect(run(270).0.pitch == 0.4 && run(270).0.roll == 0.3 && run(270).0.yaw == 0.2)
    }

    @Test func ceilingClampsUpAt290() {
        let (s, st) = run(290)
        #expect(st == .ceiling && s.throttle == 0)
        #expect(run(305).1 == .ceiling)
    }

    @Test func ceilingAllowsDescend() {
        let down = DroneSticks(yaw: 0, throttle: -0.5, roll: 0, pitch: 0)
        #expect(run(295, down).0.throttle == -0.5)
    }

    @Test func overForcesDescent() {
        let (s, st) = run(306)
        #expect(st == .over && s.throttle == -0.3)
        #expect(run(400).0.throttle == -0.3)
    }

    @Test func overLatchesUntilBelowClamp() {
        var g = SafetyGovernor()
        _ = g.apply(up, heightCM: 320, telemetryAge: 0.1)
        let mid = g.apply(up, heightCM: 295, telemetryAge: 0.1)
        #expect(mid.status == .over && mid.sticks.throttle == -0.3)
        let low = g.apply(up, heightCM: 289, telemetryAge: 0.1)
        #expect(low.status == .warning)
        let again = g.apply(up, heightCM: 295, telemetryAge: 0.1)
        #expect(again.status == .ceiling)
    }

    @Test func staleTelemetryClampsUp() {
        let (s, st) = run(100, age: 1.5)
        #expect(st == .noTelemetry && s.throttle == 0)
        let down = DroneSticks(yaw: 0, throttle: -0.5, roll: 0, pitch: 0)
        #expect(run(100, age: 1.5, down).0.throttle == -0.5)
    }

    @Test func telemetryAtMaxAgeIsFresh() {
        #expect(run(100, age: 1.0).1 == .normal)
    }

    @Test func missingTelemetryIsNoTelemetry() {
        #expect(run(nil).1 == .noTelemetry)
        #expect(run(100, age: nil).1 == .noTelemetry)
    }

    @Test func customCeilingMovesThresholds() {
        let g = SafetyGovernor(ceilingCM: 200)
        #expect(run(134, g: g).1 == .normal)
        #expect(run(135, g: g).1 == .warning)
        #expect(run(185, g: g).1 == .ceiling)
        #expect(run(201, g: g).1 == .over)
    }
}
