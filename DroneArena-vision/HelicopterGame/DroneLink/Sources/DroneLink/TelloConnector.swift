import Foundation
import Observation

/// One-button connect flow: join the drone Wi-Fi, handshake (`command` until `ok`),
/// then stay connected. Wi-Fi join is injected via `joiner`. Without one the user joins
/// TELLO-XXXXXX in Settings and the connector polls the handshake until it answers.
@MainActor @Observable
public final class TelloConnector {
    public enum State: Equatable, Sendable {
        case idle, joiningWiFi, handshaking, ready
        case failed(reason: String, hint: String)
    }

    public private(set) var state: State = .idle
    /// True while waiting for the user to join the drone Wi-Fi by hand.
    public private(set) var needsManualJoin = false
    public private(set) var reconnects = 0

    /// Joins the TELLO- network. Throws when denied or failed. Nil means manual join.
    @ObservationIgnored public var joiner: (@MainActor () async throws -> Void)?
    /// Starts the video stream on every ready transition.
    public var startsVideo = false
    public var handshakeRetries = 3
    public var retryInterval: TimeInterval = 0.5
    public var pollInterval: TimeInterval = 1
    public var pollTimeout: TimeInterval = 60
    /// No reply or telemetry for this long while not flying triggers a reconnect.
    public var silenceTimeout: TimeInterval = 3
    public var batteryWait: TimeInterval = 0.5

    public let link: TelloLink
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var monitor: Task<Void, Never>?

    public init(link: TelloLink) { self.link = link }

    public var wifiDone: Bool { state == .handshaking || state == .ready }
    public var linkDone: Bool { state == .ready }
    public var isBusy: Bool { state == .joiningWiFi || state == .handshaking }

    public func connect() {
        guard !isBusy else { return }
        cancel()
        state = .joiningWiFi
        needsManualJoin = joiner == nil
        task = Task { await run() }
    }

    public func cancel() {
        task?.cancel(); task = nil
        monitor?.cancel(); monitor = nil
        needsManualJoin = false
        state = .idle
    }

    // MARK: flow

    private func run() async {
        state = .joiningWiFi
        needsManualJoin = false
        if let joiner {
            do { try await joiner() } catch {
                fail("Wi-Fi join failed", "Join TELLO- in Settings > Wi-Fi")
                return
            }
            state = .handshaking
            if await handshake(attempts: handshakeRetries) { await finish() }
            else if !Task.isCancelled { fail("No reply", "Power on the drone and join its TELLO- Wi-Fi") }
        } else {
            needsManualJoin = true
            let deadline = Date().addingTimeInterval(pollTimeout)
            while !Task.isCancelled {
                if await handshake(attempts: 1) { needsManualJoin = false; await finish(); return }
                if Date() >= deadline {
                    needsManualJoin = false
                    fail("Wi-Fi not joined", "Open Settings > Wi-Fi and join TELLO-")
                    return
                }
                try? await Task.sleep(for: .seconds(pollInterval))
            }
        }
    }

    private func finish() async {
        state = .ready
        if let b = await batteryReading(), b < TelloLink.minTakeoffBattery {
            fail("Battery low", "Charge the drone, \(b) percent")
            return
        }
        if startsVideo { link.startVideo() }
        startMonitor()
    }

    private func batteryReading() async -> Int? {
        let end = Date().addingTimeInterval(batteryWait)
        while link.battery == nil, Date() < end, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(25))
        }
        return link.battery
    }

    /// Sends `command` until `ok` arrives. Opens the socket first when needed.
    private func handshake(attempts: Int) async -> Bool {
        if link.state != .connected {
            link.connect()
            for _ in 0..<20 where link.state != .connected {
                try? await Task.sleep(for: .milliseconds(15))
            }
        }
        if Task.isCancelled { return false }
        return await link.insist("command", attempts: attempts, gap: retryInterval)
    }

    private func fail(_ reason: String, _ hint: String) {
        monitor?.cancel(); monitor = nil
        state = .failed(reason: reason, hint: hint)
    }

    /// Reconnects on link loss while not flying. While flying the drone's own
    /// 15 s auto-land is the failsafe.
    private func startMonitor() {
        monitor?.cancel()
        monitor = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, !Task.isCancelled else { return }
                guard self.state == .ready, !self.link.isFlying else { continue }
                let heard = [self.link.stateAt, self.link.lastReplyAt].compactMap { $0 }.max() ?? .distantPast
                if Date().timeIntervalSince(heard) > self.silenceTimeout {
                    self.reconnects += 1
                    self.monitor = nil
                    self.state = .handshaking
                    if await self.handshake(attempts: self.handshakeRetries) { await self.finish() }
                    else if !Task.isCancelled { self.fail("Link lost", "Check the drone is on and in range") }
                    return
                }
            }
        }
    }
}
