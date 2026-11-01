import Testing
@testable import DroneLink

@Test func zeroSticks() { #expect(DroneSticks.zero.rcCommand() == "rc 0 0 0 0") }

@Test func axisOrderAndLimit() {
    let s = DroneSticks(yaw: 1, throttle: -1, roll: 0.5, pitch: 1)
    let (a, b, c, d) = s.rcValues(limit: 60, deadzone: 0)
    #expect(a == 30 && b == 60 && c == -60 && d == 60)
}

@Test func deadzoneAndClamp() {
    let s = DroneSticks(yaw: 0.04, throttle: 5, roll: .nan, pitch: -0.05)
    #expect(s.rcCommand(limit: 100, deadzone: 0.05) == "rc 0 0 100 0")
}

@Test func stateParse() {
    let f = TelloState.parse("pitch:0;roll:-1;bat:87;h:30;templ:60;\r\n")
    #expect(f["bat"] == 87 && f["h"] == 30 && f["roll"] == -1)
}
