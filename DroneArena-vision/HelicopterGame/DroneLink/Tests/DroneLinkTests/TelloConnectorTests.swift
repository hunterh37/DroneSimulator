import Foundation
import Testing
@testable import DroneLink

@MainActor
struct TelloConnectorTests {
    private func wait(_ cond: () -> Bool, ms: Int = 4000) async -> Bool {
        for _ in 0..<(ms / 25) {
            if cond() { return true }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return cond()
    }

    private func make(_ m: MockTello) -> TelloConnector {
        let link = TelloLink(host: "127.0.0.1", port: m.cmdPort, statePort: m.statePort)
        let c = TelloConnector(link: link)
        c.retryInterval = 0.1
        c.batteryWait = 0.2
        c.pollInterval = 0.1
        return c
    }

    @Test func handshakeReachesReady() async throws {
        let m = MockTello(); try m.start(); m.pushState(h: 0)
        let c = make(m)
        c.joiner = {}
        c.connect()
        #expect(await wait { c.state == .ready })
        #expect(c.wifiDone && c.linkDone)
        #expect(m.commands.contains("command"))
        c.cancel(); c.link.disconnect(); m.stop()
    }

    @Test func noReplyFailsAfterRetries() async throws {
        let c = TelloConnector(link: TelloLink(host: "127.0.0.1", port: 9, statePort: UInt16.random(in: 30000...60000)))
        c.retryInterval = 0.05
        c.joiner = {}
        c.connect()
        #expect(await wait { if case .failed = c.state { return true } else { return false } })
        if case .failed(let reason, let hint) = c.state { #expect(reason == "No reply"); #expect(!hint.isEmpty) }
        #expect(c.link.log.entries.filter { $0.text == "command" }.count >= 3)
        c.link.disconnect()
    }

    @Test func joinFailureFails() async throws {
        struct Denied: Error {}
        let c = TelloConnector(link: TelloLink(host: "127.0.0.1", port: 9))
        c.joiner = { throw Denied() }
        c.connect()
        #expect(await wait { if case .failed = c.state { return true } else { return false } })
        if case .failed(let reason, _) = c.state { #expect(reason == "Wi-Fi join failed") }
    }

    @Test func manualJoinTimesOut() async throws {
        let c = TelloConnector(link: TelloLink(host: "127.0.0.1", port: 9, statePort: UInt16.random(in: 30000...60000)))
        c.retryInterval = 0.05; c.pollInterval = 0.05; c.pollTimeout = 0.4
        c.connect()
        #expect(c.state == .joiningWiFi)
        #expect(await wait { if case .failed = c.state { return true } else { return false } })
        if case .failed(let reason, _) = c.state { #expect(reason == "Wi-Fi not joined") }
        #expect(!c.needsManualJoin)
        c.link.disconnect()
    }

    @Test func manualPollConnectsWhenDroneAppears() async throws {
        let m = MockTello()
        let link = TelloLink(host: "127.0.0.1", port: m.cmdPort, statePort: m.statePort)
        let c = TelloConnector(link: link)
        c.retryInterval = 0.05; c.pollInterval = 0.1; c.batteryWait = 0.1
        c.connect()
        try await Task.sleep(for: .milliseconds(300))
        #expect(c.state == .joiningWiFi && c.needsManualJoin)
        try m.start(); m.pushState(h: 0)
        #expect(await wait { c.state == .ready })
        c.cancel(); link.disconnect(); m.stop()
    }

    @Test func lowBatteryFails() async throws {
        let m = MockTello(); try m.start(); m.pushState(h: 0, bat: 8)
        let c = make(m)
        c.joiner = {}
        c.connect()
        #expect(await wait { if case .failed = c.state { return true } else { return false } })
        if case .failed(let reason, _) = c.state { #expect(reason == "Battery low") }
        c.cancel(); c.link.disconnect(); m.stop()
    }

    @Test func silenceTriggersReconnect() async throws {
        let m = MockTello(); try m.start(); m.pushState(h: 0)
        let c = make(m)
        c.joiner = {}
        c.silenceTimeout = 0.4
        c.connect()
        #expect(await wait { c.state == .ready })
        let before = m.commands(prefix: "command").count
        m.stopState()
        #expect(await wait { c.reconnects >= 1 })
        #expect(await wait { m.commands(prefix: "command").count > before })
        #expect(await wait { c.state == .ready })
        c.cancel(); c.link.disconnect(); m.stop()
    }

    @Test func packetLogKeepsLastN() {
        let log = PacketLog(capacity: 200)
        for i in 0..<250 { log.append(i % 2 == 0 ? .tx : .rx, "m\(i)") }
        #expect(log.entries.count == 200)
        #expect(log.entries.first?.text == "m50")
        #expect(log.entries.last?.text == "m249")
        #expect(log.text.split(separator: "\n").count == 200)
        log.clear()
        #expect(log.entries.isEmpty)
    }

    @Test func linkRecordsStatsAndLog() async throws {
        let m = MockTello(); try m.start(); m.pushState(h: 12, bat: 70)
        let link = TelloLink(host: "127.0.0.1", port: m.cmdPort, statePort: m.statePort)
        link.connect()
        #expect(await wait { link.stateFields["bat"] == 70 && link.cmdRTT != nil })
        #expect(await wait { link.stateRate > 5 })
        #expect(link.log.entries.contains { $0.direction == .tx && $0.text == "command" })
        #expect(link.log.entries.contains { $0.direction == .rx && $0.text == "ok" })
        link.disconnect(); m.stop()
    }

    @Test func insistRetriesAfterUnknownCommand() async throws {
        let m = MockTello(); try m.start()
        m.script(["unkown command!"])
        let link = TelloLink(host: "127.0.0.1", port: m.cmdPort, statePort: m.statePort)
        link.connect()
        #expect(await wait { link.state == .connected })
        // Drain the reply to the implicit connect handshake first.
        #expect(await wait { link.replyCount >= 1 })
        m.script(["unkown command!"])
        let ok = await link.insist("streamon", attempts: 4, gap: 0.1)
        #expect(ok)
        #expect(m.commands(prefix: "streamon").count == 2)
        #expect(link.log.entries.filter { $0.text == "streamon" }.count == 2)
        #expect(link.log.entries.contains { $0.text == "unkown command!" })
        link.disconnect(); m.stop()
    }

    @Test func insistFailsAfterFourAttempts() async throws {
        let m = MockTello(); try m.start()
        let link = TelloLink(host: "127.0.0.1", port: m.cmdPort, statePort: m.statePort)
        link.connect()
        #expect(await wait { link.replyCount >= 1 })
        m.script(Array(repeating: "error", count: 6))
        #expect(await link.insist("land", attempts: 4, gap: 0.05) == false)
        #expect(m.commands(prefix: "land").count == 4)
        link.disconnect(); m.stop()
    }
}
