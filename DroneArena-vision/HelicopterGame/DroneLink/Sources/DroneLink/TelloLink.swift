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
    /// Time of the last telemetry packet.
    public private(set) var stateAt: Date?
    public private(set) var safety: SafetyStatus = .normal
    /// Set when takeoff was refused (low battery).
    public private(set) var takeoffBlockedReason: String?
    public var governor = SafetyGovernor()
    /// Last 200 command and reply lines (rc and state packets are counted, not logged).
    public let log = PacketLog()
    /// All key/value pairs of the latest 8890 state packet.
    public private(set) var stateFields: [String: Int] = [:]
    /// State packets per second over the last full second.
    public private(set) var stateRate: Double = 0
    /// Round trip of the last non-rc command, milliseconds.
    public private(set) var cmdRTT: Int?
    public private(set) var replyCount = 0
    /// Set when an insisted command (takeoff, land, streamon) never got `ok`. Cleared on success.
    public private(set) var commandFailure: String?
    public private(set) var lastReplyAt: Date?
    public static let minTakeoffBattery = 15

    /// Outcome of the current or last return to home. Reset on takeoff.
    public private(set) var returnStatus: ReturnStatus = .idle
    /// Position relative to takeoff. Holds the flight-measured calibration.
    public var reckoner = DeadReckoner()
    public var returnTimeout: TimeInterval = 45
    public static let returnSpeedLimit = 30
    private static let takeoverStick: Float = 0.2
    private var returnStartedAt = Date.distantPast

    /// Master switch. When false, no rc packets go out.
    public var sticksEnabled = false
    /// Per-axis output cap, 0...100. Lower = gentler.
    public var speedLimit = 60
    public var deadzone: Float = 0.08
    public var sendRate: Double = 20
    public var staleAfter: TimeInterval = 0.4

    public let video = TelloVideoStream()
    public let host: String
    public let port: UInt16
    public let statePort: UInt16

    private var cmdConn: NWConnection?
    private var stateListener: NWListener?
    private var sticks = DroneSticks.zero
    private var sticksAt = Date.distantPast
    private var timer: Timer?
    private var keepAliveAt = Date()
    private var cmdSentAt: Date?
    private var stateWindowStart = Date()
    private var stateWindowCount = 0

    public init(host: String = "192.168.10.1", port: UInt16 = 8889, statePort: UInt16 = 8890) {
        self.host = host
        self.port = port
        self.statePort = statePort
    }

    private var isLoopback: Bool { host == "127.0.0.1" || host == "::1" || host == "localhost" }

    public var isFlying: Bool { state == .flying }

    public var canReturnHome: Bool {
        state == .flying && sticksEnabled && reckoner.isValid && returnStatus != .returning
    }

    /// Flies toward the estimated takeoff point at low speed, then lands. Any stick input cancels.
    public func returnHome() {
        guard canReturnHome else { return }
        returnStartedAt = Date()
        returnStatus = .returning
    }

    public func connect() {
        disconnect()
        state = .connecting
        let params = NWParameters.udp
        if !isLoopback { params.requiredInterfaceType = .wifi }
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
        cancelReturn()
    }

    public func takeoff() {
        guard state == .connected else { return }
        if let b = battery, b < Self.minTakeoffBattery {
            takeoffBlockedReason = "battery \(b)% below \(Self.minTakeoffBattery)%"
            return
        }
        takeoffBlockedReason = nil
        governor.reset()
        reckoner.reset()
        // Starts the gap clock now, so missing telemetry right after takeoff also loses home.
        reckoner.add(vgx: 0, vgy: 0, yaw: 0, at: Date())
        returnStatus = .idle
        sticks = .zero
        state = .flying
        Task { [weak self] in
            guard let self else { return }
            if await self.insist("takeoff") { return }
            if self.state == .flying { self.state = .connected }
            self.commandFailure = "TAKEOFF NOT ACKNOWLEDGED"
        }
    }

    public func land() {
        cancelReturn()
        sticks = .zero
        send("rc 0 0 0 0")
        if state == .flying { state = .connected }
        Task { [weak self] in
            guard let self else { return }
            if !(await self.insist("land")) { self.commandFailure = "LAND NOT ACKNOWLEDGED" }
        }
    }

    /// Sends `cmd` until the drone replies `ok`. The Tello often answers `unkown command!`
    /// or nothing to the first try. Every attempt lands in `log`.
    @discardableResult
    public func insist(_ cmd: String, attempts: Int = 4, gap: TimeInterval = 0.4) async -> Bool {
        for _ in 0..<max(1, attempts) {
            let before = replyCount
            send(cmd)
            let end = Date().addingTimeInterval(gap)
            var acked = false
            while Date() < end {
                if replyCount > before {
                    acked = lastReply == "ok"
                    break
                }
                try? await Task.sleep(for: .milliseconds(20))
            }
            if acked { commandFailure = nil; return true }
            let rest = end.timeIntervalSinceNow
            if rest > 0 { try? await Task.sleep(for: .seconds(rest)) }
        }
        return false
    }

    /// Opens the UDP 11111 listener and tells the drone to stream.
    /// The listener starts only after `streamon` returns `ok`.
    public func startVideo() {
        Task { [weak self] in
            guard let self else { return }
            if await self.insist("streamon") { self.video.start() }
            else { self.commandFailure = "VIDEO NOT ACKNOWLEDGED" }
        }
    }

    public func stopVideo() {
        send("streamoff")
        video.stop()
    }

    /// Cuts motors immediately. The drone falls.
    public func emergency() {
        cancelReturn()
        send("emergency")
        if state == .flying { state = .connected }
    }

    /// Sends a raw SDK command (used by the connector handshake).
    public func sendCommand(_ text: String) { send(text) }

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
        if state != .flying {
            safety = .normal
            cancelReturn()
        }
        if state == .flying {
            if returnStatus == .returning, stepReturn(now) { return }
            let age = stateAt.map { now.timeIntervalSince($0) }
            let g = governor.apply(sticksEnabled && now.timeIntervalSince(sticksAt) < staleAfter ? sticks : .zero,
                                   heightCM: heightCM, telemetryAge: age)
            safety = g.status
            if sticksEnabled {
                lastRC = g.sticks.rcCommand(limit: max(0, min(100, speedLimit)), deadzone: deadzone)
                send(lastRC)
                keepAliveAt = now
                return
            }
        }
        if state == .flying, !sticksEnabled, now.timeIntervalSince(keepAliveAt) > 0.5 {
            lastRC = "rc 0 0 0 0"
            send(lastRC)
            keepAliveAt = now
        } else if state != .flying, now.timeIntervalSince(keepAliveAt) > 5 {
            send("battery?")   // Tello auto-lands after 15 s without commands
            keepAliveAt = now
        }
    }

    private func cancelReturn() {
        if returnStatus == .returning { returnStatus = .idle }
    }

    /// One return tick. False hands the tick back to normal stick handling.
    private func stepReturn(_ now: Date) -> Bool {
        guard sticksEnabled else {
            returnStatus = .idle
            return false
        }
        let pilot = max(abs(sticks.yaw), abs(sticks.throttle), abs(sticks.roll), abs(sticks.pitch))
        if now.timeIntervalSince(sticksAt) < staleAfter, pilot > Self.takeoverStick {
            returnStatus = .pilotTookOver
            return false
        }
        guard let at = stateAt, now.timeIntervalSince(at) <= governor.telemetryMaxAge, reckoner.isValid else {
            finishReturn(.positionLost)
            return true
        }
        guard now.timeIntervalSince(returnStartedAt) <= returnTimeout else {
            finishReturn(.timedOut)
            return true
        }
        guard let home = reckoner.homeSticks(yaw: stateFields["yaw"] ?? 0) else {
            finishReturn(.arrived)
            return true
        }
        let g = governor.apply(home, heightCM: heightCM, telemetryAge: now.timeIntervalSince(at))
        safety = g.status
        lastRC = g.sticks.rcCommand(limit: max(0, min(speedLimit, Self.returnSpeedLimit)), deadzone: deadzone)
        send(lastRC)
        keepAliveAt = now
        return true
    }

    private func finishReturn(_ status: ReturnStatus) {
        land()
        returnStatus = status
    }

    private func send(_ text: String) {
        if !text.hasPrefix("rc ") {
            cmdSentAt = Date()
            log.append(.tx, text)
        }
        cmdConn?.send(content: Data(text.utf8), completion: .contentProcessed { _ in })
    }

    private func receiveLoop(_ c: NWConnection) {
        c.receiveMessage { [weak self] data, _, _, error in
            Task { @MainActor in
                guard let self, self.cmdConn === c else { return }
                if let data, let s = String(data: data, encoding: .utf8) {
                    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.lastReply = t
                    self.replyCount += 1
                    self.lastReplyAt = Date()
                    self.log.append(.rx, t)
                    if let at = self.cmdSentAt { self.cmdRTT = Int(Date().timeIntervalSince(at) * 1000) }
                    if let b = Int(t) { self.battery = b }
                }
                if error == nil { self.receiveLoop(c) }
            }
        }
    }

    private func listenState() {
        guard let l = try? NWListener(using: .udp, on: NWEndpoint.Port(rawValue: statePort)!) else { return }
        l.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .main)
            self?.readState(conn)
        }
        l.start(queue: .main)
        stateListener = l
    }

    private func noteState(_ f: [String: Int]) {
        stateFields = f
        stateWindowCount += 1
        let now = Date()
        if state == .flying, let vgx = f["vgx"], let vgy = f["vgy"], let yaw = f["yaw"] {
            reckoner.add(vgx: vgx, vgy: vgy, yaw: yaw, at: now)
        }
        let dt = now.timeIntervalSince(stateWindowStart)
        if dt >= 1 {
            stateRate = Double(stateWindowCount) / dt
            stateWindowCount = 0
            stateWindowStart = now
        }
    }

    nonisolated private func readState(_ conn: NWConnection) {
        conn.receiveMessage { [weak self] data, _, _, error in
            if let data, let s = String(data: data, encoding: .utf8) {
                let f = TelloState.parse(s)
                Task { @MainActor in
                    self?.noteState(f)
                    if let b = f["bat"] { self?.battery = b }
                    if let h = f["h"] { self?.heightCM = h }
                    self?.stateAt = Date()
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
