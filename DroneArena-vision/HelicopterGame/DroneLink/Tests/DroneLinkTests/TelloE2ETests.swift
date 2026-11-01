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

    init() {
        let base = UInt16.random(in: 30000...60000)
        cmdPort = base
        statePort = base + 1
    }

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
                c.send(content: Data("ok".utf8), completion: .contentProcessed { _ in })
            }
            if err == nil { self.read(c) }
        }
    }

    /// Sends this state at 20 Hz until changed or stopped.
    func pushState(h: Int, bat: Int = 80) {
        lock.lock(); statePacket = "pitch:0;roll:0;yaw:0;vgx:0;vgy:0;vgz:0;templ:60;temph:62;tof:\(h);h:\(h);bat:\(bat);baro:0.0;time:0;agx:0.0;agy:0.0;agz:0.0;"
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
