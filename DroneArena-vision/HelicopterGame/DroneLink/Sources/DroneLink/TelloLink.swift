import Foundation
import Network
import Observation

/// DJI Tello SDK 2.0 over UDP. The headset joins the Tello Wi-Fi (TELLO-XXXXXX);
/// commands go to 192.168.10.1:8889, replies come back on the same socket,
/// telemetry state arrives on UDP 8890.
///
/// Feed sticks with `update(_:)` at any rate. The link sends `rc` at `sendRate` Hz.
/// Failsafe: sticks older than `staleAfter` are sent as zero (hover).
@MainActor @Observable
public final class TelloLink {
    public enum State: Equatable, Sendable { case disconnected, connecting, connected, flying, failed(String) }

    public private(set) var state: State = .disconnected
    public private(set) var battery: Int?
    public private(set) var heightCM: Int?
    public private(set) var lastReply: String = ""
    public private(set) var lastRC: String = "rc 0 0 0 0"

    /// Master switch. When false, no rc packets go out.
    public var sticksEnabled = false
    /// Per-axis output cap, 0...100. Lower = gentler.
    public var speedLimit = 60
    public var deadzone: Float = 0.08
    public var sendRate: Double = 20
    public var staleAfter: TimeInterval = 0.4

    public let host: String
    public let port: UInt16

    private var cmdConn: NWConnection?
    private var stateListener: NWListener?
    private var sticks = DroneSticks.zero
    private var sticksAt = Date.distantPast
    private var timer: Timer?
    private var keepAliveAt = Date()

    public init(host: String = "192.168.10.1", port: UInt16 = 8889) {
        self.host = host
        self.port = port
    }

    public var isFlying: Bool { state == .flying }

    public func connect() {
        disconnect()
        state = .connecting
        let params = NWParameters.udp
        params.requiredInterfaceType = .wifi
        let c = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: params)
        c.stateUpdateHandler = { [weak self] s in
            Task { @MainActor in self?.handle(s) }
        }
        c.start(queue: .main)
        cmdConn = c
        receiveLoop(c)
        listenState()
    }

    public func disconnect() {
        timer?.invalidate(); timer = nil
        cmdConn?.cancel(); cmdConn = nil
        stateListener?.cancel(); stateListener = nil
        state = .disconnected
    }

    public func takeoff() {
        guard state == .connected else { return }
        sticks = .zero
        send("takeoff")
        state = .flying
    }

    public func land() {
        sticks = .zero
        send("rc 0 0 0 0")
        send("land")
        if state == .flying { state = .connected }
    }

    /// Cuts motors immediately. The drone falls.
    public func emergency() {
        send("emergency")
        if state == .flying { state = .connected }
    }

    public func update(_ s: DroneSticks) {
        sticks = s
        sticksAt = Date()
    }

    // MARK: internals

    private func handle(_ s: NWConnection.State) {
        switch s {
        case .ready:
            send("command")
            state = .connected
            startTimer()
        case .failed(let e):
            state = .failed(e.localizedDescription)
        case .waiting(let e):
            state = .failed("waiting: \(e.localizedDescription)")
        default:
            break
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1 / sendRate, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        let now = Date()
        if state == .flying, sticksEnabled {
            let live = now.timeIntervalSince(sticksAt) < staleAfter ? sticks : .zero
            lastRC = live.rcCommand(limit: max(0, min(100, speedLimit)), deadzone: deadzone)
            send(lastRC)
            keepAliveAt = now
        } else if state == .flying, now.timeIntervalSince(keepAliveAt) > 0.5 {
            lastRC = "rc 0 0 0 0"
            send(lastRC)
            keepAliveAt = now
        } else if now.timeIntervalSince(keepAliveAt) > 5 {
            send("battery?")   // Tello auto-lands after 15 s without commands
            keepAliveAt = now
        }
    }

    private func send(_ text: String) {
        cmdConn?.send(content: Data(text.utf8), completion: .contentProcessed { _ in })
    }

    private func receiveLoop(_ c: NWConnection) {
        c.receiveMessage { [weak self] data, _, _, error in
            Task { @MainActor in
                guard let self, self.cmdConn === c else { return }
                if let data, let s = String(data: data, encoding: .utf8) {
                    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.lastReply = t
                    if let b = Int(t) { self.battery = b }
                }
                if error == nil { self.receiveLoop(c) }
            }
        }
    }

    private func listenState() {
        guard let l = try? NWListener(using: .udp, on: 8890) else { return }
        l.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .main)
            self?.readState(conn)
        }
        l.start(queue: .main)
        stateListener = l
    }

    nonisolated private func readState(_ conn: NWConnection) {
        conn.receiveMessage { [weak self] data, _, _, error in
            if let data, let s = String(data: data, encoding: .utf8) {
                let f = TelloState.parse(s)
                Task { @MainActor in
                    if let b = f["bat"] { self?.battery = b }
                    if let h = f["h"] { self?.heightCM = h }
                }
            }
            if error == nil { self?.readState(conn) }
        }
    }
}

public enum TelloState {
    /// Parses "pitch:0;roll:0;yaw:0;...;bat:87;h:0;..." into integer fields.
    public static func parse(_ s: String) -> [String: Int] {
        var out: [String: Int] = [:]
        for part in s.split(separator: ";") {
            let kv = part.split(separator: ":", maxSplits: 1)
            if kv.count == 2, let v = Int(kv[1].trimmingCharacters(in: .whitespacesAndNewlines)) {
                out[String(kv[0])] = v
            }
        }
        return out
    }
}
