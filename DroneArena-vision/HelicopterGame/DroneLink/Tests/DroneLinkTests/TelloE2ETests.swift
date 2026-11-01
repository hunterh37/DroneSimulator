import Foundation
import Network
import Testing
@testable import DroneLink

/// UDP Tello stand-in on 127.0.0.1. Replies "ok", records commands, pushes state packets.
final class MockTello: @unchecked Sendable {
    let cmdPort: UInt16
    let statePort: UInt16
    private let lock = NSLock()
    private var log: [String] = []
    private var listener: NWListener?
    private var conns: [NWConnection] = []
    private var stateConn: NWConnection?
    private var timer: DispatchSourceTimer?
    private let q = DispatchQueue(label: "mock.tello")
    private var statePacket: String?
    private var scripted: [String] = []
    private var failing: [String: Int] = [:]

    // Sequential and below the ephemeral range: random ports collided with each other and with client sockets.
    nonisolated(unsafe) private static var nextPort = UInt16(20000 + getpid() % 10000)
    private static let portLock = NSLock()

    init() {
        Self.portLock.lock()
        let base = Self.nextPort
        Self.nextPort += 2
        Self.portLock.unlock()
        cmdPort = base
        statePort = base + 1
    }

    /// Replies "error" to the next `count` commands starting with `prefix`, whatever else arrives meanwhile.
    func fail(_ prefix: String, count: Int) { lock.lock(); failing[prefix] = count; lock.unlock() }

    /// Commands starting with these prefixes get no reply (real Tello during takeoff climb).
    private var muted: Set<String> = []
    func mute(_ prefix: String) { lock.lock(); muted.insert(prefix); lock.unlock() }

    /// The next replies, in order, before falling back to "ok".
    func script(_ replies: [String]) { lock.lock(); scripted = replies; lock.unlock() }

    var commands: [String] { lock.lock(); defer { lock.unlock() }; return log }
    func commands(prefix: String) -> [String] { commands.filter { $0.hasPrefix(prefix) } }

    func start() throws {
        let l = try NWListener(using: .udp, on: NWEndpoint.Port(rawValue: cmdPort)!)
        l.newConnectionHandler = { [weak self] c in
            guard let self else { return }
            self.lock.lock(); self.conns.append(c); self.lock.unlock()
            c.start(queue: self.q)
            self.read(c)
        }
        l.start(queue: q)
        listener = l
        let sc = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: statePort)!, using: .udp)
        sc.start(queue: q)
        stateConn = sc
    }

    private func read(_ c: NWConnection) {
        c.receiveMessage { [weak self] data, _, _, err in
            guard let self else { return }
            if let data, let s = String(data: data, encoding: .utf8) {
                self.lock.lock(); self.log.append(s); self.lock.unlock()
                self.lock.lock()
                var reply = self.scripted.isEmpty ? "ok" : self.scripted.removeFirst()
                if let k = self.failing.keys.first(where: { s.hasPrefix($0) }), self.failing[k]! > 0 {
                    self.failing[k]! -= 1
                    reply = "error"
                }
                let silent = self.muted.contains(where: { s.hasPrefix($0) })
                self.lock.unlock()
                if !silent { c.send(content: Data(reply.utf8), completion: .contentProcessed { _ in }) }
            }
            if err == nil { self.read(c) }
        }
    }

    /// Sends this state at 20 Hz until changed or stopped.
    func pushState(h: Int, bat: Int = 80, vgx: Int = 0, vgy: Int = 0, yaw: Int = 0) {
        lock.lock(); statePacket = "pitch:0;roll:0;yaw:\(yaw);vgx:\(vgx);vgy:\(vgy);vgz:0;templ:60;temph:62;tof:\(h);h:\(h);bat:\(bat);baro:0.0;time:0;agx:0.0;agy:0.0;agz:0.0;"
        lock.unlock()
        if timer == nil {
            let t = DispatchSource.makeTimerSource(queue: q)
            t.schedule(deadline: .now(), repeating: .milliseconds(50))
            t.setEventHandler { [weak self] in
                guard let self else { return }
                self.lock.lock(); let p = self.statePacket; self.lock.unlock()
                if let p { self.stateConn?.send(content: Data(p.utf8), completion: .contentProcessed { _ in }) }
            }
            t.resume()
            timer = t
        }
    }

    func stopState() {
        timer?.cancel(); timer = nil
    }

    func stop() {
        stopState()
        listener?.cancel(); stateConn?.cancel()
        lock.lock(); conns.forEach { $0.cancel() }; lock.unlock()
    }
}

@MainActor
struct TelloE2ETests {
    /// Polls up to 2 s.
    private func wait(_ what: String = "", _ cond: () -> Bool) async -> Bool {
        for _ in 0..<80 {
            if cond() { return true }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return cond()
    }

    private func lastC(_ m: MockTello) -> Int? {
        guard let rc = m.commands(prefix: "rc ").last else { return nil }
        let p = rc.split(separator: " ")
        return p.count == 5 ? Int(p[3]) : nil
    }

    private func lastB(_ m: MockTello) -> Int? {
        guard let rc = m.commands(prefix: "rc ").last else { return nil }
        let p = rc.split(separator: " ")
        return p.count == 5 ? Int(p[2]) : nil
    }

    /// Flies about 1 m forward on telemetry, stops, and starts a return.
    private func moveAndReturn(_ m: MockTello, _ link: TelloLink, h: Int) async {
        m.pushState(h: h, vgx: 10)
        #expect(await wait { link.reckoner.xCM >= 100 })
        m.pushState(h: h)
        link.returnHome()
        #expect(link.returnStatus == .returning)
    }

    private func makeReturning(h: Int = 100) async throws -> (MockTello, TelloLink) {
        let (m, link) = try await makeFlying(h: h)
        await moveAndReturn(m, link, h: h)
        return (m, link)
    }

    private func makeFlying(h: Int, bat: Int = 80) async throws -> (MockTello, TelloLink) {
        let m = MockTello()
        try m.start()
        m.pushState(h: h, bat: bat)
        let link = TelloLink(host: "127.0.0.1", port: m.cmdPort, statePort: m.statePort)
        link.connect()
        #expect(await wait { link.state == .connected && link.heightCM == h })
        link.sticksEnabled = true
        link.takeoff()
        return (m, link)
    }

    private let fullUp = DroneSticks(yaw: 0, throttle: 1, roll: 0, pitch: 0)

    /// Feeds sticks continuously for the duration of the wait so they are never stale.
    private func fly(_ link: TelloLink, _ m: MockTello, until cond: () -> Bool) async -> Bool {
        for _ in 0..<80 {
            link.update(fullUp)
            if cond() { return true }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return cond()
    }

    /// Real Tello: motors spin, no reply until hover. Climbing telemetry counts as the ack,
    /// and takeoff is sent once (a resend mid-climb gets "error").
    @Test func takeoffAckedByClimbWithoutReply() async throws {
        let m = MockTello(); try m.start()
        m.pushState(h: 0)
        let link = TelloLink(host: "127.0.0.1", port: m.cmdPort, statePort: m.statePort)
        link.connect()
        #expect(await wait { link.state == .connected && link.heightCM == 0 })
        m.mute("takeoff")
        link.takeoff()
        #expect(await wait { m.commands.contains("takeoff") })
        try? await Task.sleep(for: .milliseconds(1500))
        m.pushState(h: 80)
        #expect(await wait { link.heightCM == 80 })
        try? await Task.sleep(for: .milliseconds(200))
        #expect(link.state == .flying)
        #expect(link.commandFailure == nil)
        #expect(m.commands(prefix: "takeoff").count == 1)
        link.disconnect(); m.stop()
    }

    @Test func connectSendsCommand() async throws {
        let m = MockTello(); try m.start()
        let link = TelloLink(host: "127.0.0.1", port: m.cmdPort, statePort: m.statePort)
        link.connect()
        #expect(await wait { m.commands.contains("command") })
        #expect(await wait { link.lastReply == "ok" })
        link.disconnect(); m.stop()
    }

    @Test func throttleUpBelowCeiling() async throws {
        let (m, link) = try await makeFlying(h: 100)
        #expect(await wait { m.commands.contains("takeoff") })
        #expect(await fly(link, m) { (lastC(m) ?? 0) > 0 })
        link.disconnect(); m.stop()
    }

    @Test func throttleZeroAtCeiling() async throws {
        let (m, link) = try await makeFlying(h: 295)
        #expect(await fly(link, m) { m.commands(prefix: "rc ").count > 3 && link.safety == .ceiling })
        #expect(lastC(m) == 0)
        link.disconnect(); m.stop()
    }

    @Test func throttleDownOverCeiling() async throws {
        let (m, link) = try await makeFlying(h: 320)
        #expect(await fly(link, m) { (lastC(m) ?? 0) < 0 })
        #expect(link.safety == .over)
        link.disconnect(); m.stop()
    }

    @Test func staleTelemetryStopsClimb() async throws {
        let (m, link) = try await makeFlying(h: 100)
        #expect(await fly(link, m) { (lastC(m) ?? 0) > 0 })
        m.stopState()
        #expect(await fly(link, m) { link.safety == .noTelemetry && lastC(m) == 0 })
        link.disconnect(); m.stop()
    }

    @Test func staleSticksSendZeroRC() async throws {
        let (m, link) = try await makeFlying(h: 100)
        #expect(await fly(link, m) { (lastC(m) ?? 0) > 0 })
        #expect(await wait { m.commands.last(where: { $0.hasPrefix("rc ") }) == "rc 0 0 0 0" })
        link.disconnect(); m.stop()
    }

    @Test func landSendsLand() async throws {
        let (m, link) = try await makeFlying(h: 100)
        link.land()
        #expect(await wait { m.commands.contains("land") })
        #expect(link.state == .connected)
        link.disconnect(); m.stop()
    }

    @Test func returnFliesHomeAndLands() async throws {
        let (m, link) = try await makeReturning()
        #expect(await wait { (lastB(m) ?? 0) < 0 })
        m.pushState(h: 100, vgx: -10)
        #expect(await wait { link.returnStatus == .arrived })
        #expect(await wait { m.commands.contains("land") })
        link.disconnect(); m.stop()
    }

    @Test func pilotTakesOver() async throws {
        let (m, link) = try await makeReturning()
        #expect(await fly(link, m) { link.returnStatus == .pilotTookOver })
        #expect(link.state == .flying)
        #expect(!m.commands.contains("land"))
        link.disconnect(); m.stop()
    }

    @Test func telemetryLossLands() async throws {
        let (m, link) = try await makeReturning()
        m.stopState()
        #expect(await wait { link.returnStatus == .positionLost })
        #expect(await wait { m.commands.contains("land") })
        link.disconnect(); m.stop()
    }

    @Test func killEndsReturn() async throws {
        let (m, link) = try await makeReturning()
        #expect(await wait { (lastB(m) ?? 0) < 0 })
        link.emergency()
        #expect(link.returnStatus == .idle)
        #expect(await wait { m.commands.contains("emergency") })
        let sent = m.commands(prefix: "rc ").count
        try? await Task.sleep(for: .milliseconds(200))
        #expect(m.commands(prefix: "rc ").count == sent)
        link.disconnect(); m.stop()
    }

    @Test func landEndsReturn() async throws {
        let (m, link) = try await makeReturning()
        link.land()
        #expect(link.returnStatus == .idle)
        #expect(await wait { m.commands.contains("land") })
        link.disconnect(); m.stop()
    }

    @Test func disarmEndsReturn() async throws {
        let (m, link) = try await makeReturning()
        #expect(await wait { (lastB(m) ?? 0) < 0 })
        link.sticksEnabled = false
        #expect(await wait { link.returnStatus == .idle })
        #expect(await wait { m.commands(prefix: "rc ").last == "rc 0 0 0 0" })
        #expect(!m.commands.contains("land"))
        link.disconnect(); m.stop()
    }

    @Test func gapRefusesReturn() async throws {
        let (m, link) = try await makeFlying(h: 100)
        #expect(await wait { link.reckoner.isValid && link.stateAt != nil })
        m.stopState()
        try? await Task.sleep(for: .milliseconds(1200))
        m.pushState(h: 100)
        #expect(await wait { !link.reckoner.isValid })
        #expect(!link.canReturnHome)
        link.returnHome()
        #expect(link.returnStatus == .idle)
        link.disconnect(); m.stop()
    }

    @Test func returnObeysCeilingAndCap() async throws {
        let (m, link) = try await makeReturning(h: 320)
        link.speedLimit = 100
        #expect(await wait { (lastC(m) ?? 0) < 0 && (lastB(m) ?? 0) < 0 })
        let pitches = m.commands(prefix: "rc ").compactMap { Int($0.split(separator: " ")[2]) }
        #expect(pitches.allSatisfy { abs($0) <= TelloLink.returnSpeedLimit })
        link.disconnect(); m.stop()
    }

    @Test func returnTimesOut() async throws {
        let (m, link) = try await makeReturning()
        link.returnTimeout = 0.3
        #expect(await wait { link.returnStatus == .timedOut })
        #expect(await wait { m.commands.contains("land") })
        link.disconnect(); m.stop()
    }

    @Test func newTakeoffResetsHome() async throws {
        let (m, link) = try await makeReturning()
        m.pushState(h: 100, vgx: -10)
        #expect(await wait { link.returnStatus == .arrived })
        link.takeoff()
        #expect(link.reckoner.xCM == 0)
        #expect(link.returnStatus == .idle)
        link.disconnect(); m.stop()
    }

    /// Waits up to 8 s, for the multi-second land retry.
    private func waitLong(_ cond: () -> Bool) async -> Bool {
        for _ in 0..<320 {
            if cond() { return true }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return cond()
    }

    @Test func landKeepsRetryingAfterOutage() async throws {
        let (m, link) = try await makeFlying(h: 100)
        #expect(await wait { m.commands.contains("takeoff") })
        m.fail("land", count: 5)   // sync land, then 4 insist attempts
        link.land()
        // 6th land is the retry after the 4 insist attempts failed; the flag clears within ms of it succeeding.
        #expect(await waitLong { m.commands(prefix: "land").count >= 6 })
        #expect(await waitLong { link.commandFailure == nil })
        link.disconnect(); m.stop()
    }

    @Test func landSurvivesImmediateDisconnect() async throws {
        let (m, link) = try await makeFlying(h: 100)
        link.land(); link.disconnect()
        #expect(await wait { m.commands.contains("land") })
        m.stop()
    }

    @Test func pinchOnReturnButtonDoesNotCancel() async throws {
        let (m, link) = try await makeReturning()
        link.update(fullUp)   // thumb deflection from pressing the chip, then released
        try? await Task.sleep(for: .milliseconds(250))
        #expect(link.returnStatus == .returning)
        link.disconnect(); m.stop()
    }

    @Test func returnKeepsCeilingDescentAuthority() async throws {
        let (m, link) = try await makeReturning(h: 320)
        link.speedLimit = 100
        #expect(await wait { lastC(m) == -24 })   // same as -0.3 throttle in normal flight
        let rolls = m.commands(prefix: "rc ").compactMap { Int($0.split(separator: " ")[1]) }
        #expect(rolls.allSatisfy { abs($0) <= TelloLink.returnSpeedLimit })
        link.disconnect(); m.stop()
    }

    @Test func lowBatteryBlocksTakeoff() async throws {
        let m = MockTello(); try m.start()
        m.pushState(h: 0, bat: 10)
        let link = TelloLink(host: "127.0.0.1", port: m.cmdPort, statePort: m.statePort)
        link.connect()
        #expect(await wait { link.state == .connected && link.battery == 10 })
        link.sticksEnabled = true
        link.takeoff()
        try? await Task.sleep(for: .milliseconds(300))
        #expect(!m.commands.contains("takeoff"))
        #expect(link.state == .connected)
        #expect(link.takeoffBlockedReason != nil)
        link.disconnect(); m.stop()
    }
}
