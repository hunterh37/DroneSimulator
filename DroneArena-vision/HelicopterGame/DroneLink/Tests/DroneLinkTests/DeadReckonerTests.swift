import Foundation
import Testing
@testable import DroneLink

struct DeadReckonerTests {
    let t0 = Date(timeIntervalSince1970: 1000)
    func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }

    func moved(_ c: VelocityCalibration = .init(), vgx: Int = 10, vgy: Int = 0, yaw: Int = 0) -> DeadReckoner {
        var d = DeadReckoner(); d.calibration = c
        d.add(vgx: vgx, vgy: vgy, yaw: yaw, at: t0)
        d.add(vgx: vgx, vgy: vgy, yaw: yaw, at: t0.addingTimeInterval(1))
        return d
    }

    @Test func firstSampleDoesNotMove() {
        var d = DeadReckoner(); d.add(vgx: 10, vgy: 10, yaw: 0, at: t0)
        #expect(d.xCM == 0 && d.yCM == 0)
    }
    @Test func integratesForward() { let d = moved(); #expect(near(d.xCM, 100) && near(d.yCM, 0)) }
    @Test func bodyFrameRotatesByYaw() { let d = moved(yaw: 90); #expect(near(d.xCM, 0) && near(d.yCM, 100)) }
    @Test func worldFrameIgnoresYaw() {
        let d = moved(.init(bodyFrame: false), yaw: 90); #expect(near(d.xCM, 100) && near(d.yCM, 0))
    }
    @Test func signAndSwapApply() {
        #expect(near(moved(.init(xSign: -1)).xCM, -100))
        #expect(near(moved(.init(swapAxes: true)).yCM, 100))
    }
    @Test func gapInvalidatesUntilReset() {
        var d = moved()
        d.add(vgx: 10, vgy: 0, yaw: 0, at: t0.addingTimeInterval(2.5))
        #expect(!d.isValid && near(d.xCM, 100))
        d.add(vgx: 10, vgy: 0, yaw: 0, at: t0.addingTimeInterval(2.6))
        #expect(!d.isValid)
        d.reset()
        #expect(d.isValid && d.xCM == 0)
    }
    @Test func sticksPointHome() throws {
        let s = try #require(moved().homeSticks(yaw: 0))
        #expect(s.pitch < 0 && abs(s.roll) < 0.01 && s.throttle == 0 && s.yaw == 0)
    }
    @Test func sticksAccountForYaw() throws {
        let s = try #require(moved().homeSticks(yaw: 90))
        #expect(s.roll > 0 && abs(s.pitch) < 0.01)
    }
    @Test func nilWhenArrived() {
        #expect(moved(vgx: 4).homeSticks(yaw: 0) == nil)
    }
    @Test func stickMagnitudeClamped() throws {
        let slow = try #require(moved(vgx: 6).homeSticks(yaw: 0))
        let far = try #require(moved(vgx: 100).homeSticks(yaw: 0))
        #expect(abs(slow.pitch + 0.4) < 0.01 && abs(far.pitch + 1) < 0.01)
    }
}
