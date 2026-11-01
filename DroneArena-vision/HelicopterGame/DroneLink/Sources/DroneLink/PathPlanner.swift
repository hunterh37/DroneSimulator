import Foundation

/// Planar drone pose in the dead-reckoning frame: x forward at takeoff, y right, meters.
/// `yaw` in radians, positive turns x toward y.
public struct DronePose: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var yaw: Double
    public var heightM: Double
    public init(x: Double = 0, y: Double = 0, yaw: Double = 0, heightM: Double = 0) {
        self.x = x; self.y = y; self.yaw = yaw; self.heightM = heightM
    }
    public var xy: SIMD2<Double> { SIMD2(x, y) }

    public func toWorld(forward f: Double, right r: Double) -> SIMD2<Double> {
        SIMD2(x + f * cos(yaw) - r * sin(yaw), y + f * sin(yaw) + r * cos(yaw))
    }
    /// World point to body (forward, right).
    public func toBody(_ p: SIMD2<Double>) -> SIMD2<Double> {
        let d = p - xy
        return SIMD2(d.x * cos(yaw) + d.y * sin(yaw), -d.x * sin(yaw) + d.y * cos(yaw))
    }
}

/// Obstacle remembered in the world frame.
public struct WorldObstacle: Identifiable, Sendable, Equatable {
    public var id: Int
    public var kind: ObstacleKind
    public var center: SIMD2<Double>
    public var radius: Double
    public var heightM: Double
    public var seenAt: TimeInterval
}

/// Fuses tracked obstacles into world positions. Merges within `mergeM`, forgets after `ttl`.
public struct ObstacleMemory: Sendable {
    public private(set) var items: [WorldObstacle] = []
    public var mergeM = 0.6
    public var ttl: TimeInterval = 6
    public var maxRangeM = 8.0
    private var nextID = 1
    public init() {}

    public mutating func reset() { items.removeAll() }

    /// Returns true when an obstacle not seen before was added.
    @discardableResult
    public mutating func ingest(_ obs: [Obstacle], pose: DronePose, at t: TimeInterval) -> Bool {
        var added = false
        for o in obs {
            guard let d = o.distanceM, d < maxRangeM else { continue }
            let p = pose.toWorld(forward: d, right: d * tan(o.bearing))
            let r = o.kind == .wall ? 0.6 : max(0.15, (o.kind.widthM ?? 0.4) / 2)
            if let i = items.firstIndex(where: { simd_len($0.center - p) < mergeM }) {
                items[i].center = items[i].center * 0.7 + p * 0.3
                items[i].seenAt = t
                items[i].kind = o.kind
            } else {
                items.append(WorldObstacle(id: nextID, kind: o.kind, center: p, radius: r, heightM: 2.5, seenAt: t))
                nextID += 1
                added = true
            }
        }
        items.removeAll { t - $0.seenAt > ttl }
        return added
    }
}

@inline(__always) func simd_len(_ v: SIMD2<Double>) -> Double { (v * v).sum().squareRoot() }

/// Detour planner: splits the straight line at the first blocking obstacle and goes around it.
public enum PathPlanner {
    public static func plan(from a: SIMD2<Double>, to b: SIMD2<Double>,
                            obstacles: [WorldObstacle], clearance: Double = 0.5) -> [SIMD2<Double>] {
        [a] + route(a, b, obstacles, clearance, depth: 0)
    }

    private static func route(_ a: SIMD2<Double>, _ b: SIMD2<Double>, _ obs: [WorldObstacle],
                              _ c: Double, depth: Int) -> [SIMD2<Double>] {
        guard depth < 5, let hit = firstBlock(a, b, obs, c) else { return [b] }
        let o = hit.obstacle
        let dir = b - a
        let len = max(simd_len(dir), 1e-6)
        var n = SIMD2(-dir.y, dir.x) / len
        // Go around on the side the line already leans to.
        let side = (o.center - a).x * n.x + (o.center - a).y * n.y
        if side > 0 { n = -n }
        let off = o.radius + c + 0.15
        let along = dir / len
        let w1 = o.center + n * off - along * (o.radius + c)
        let w2 = o.center + n * off + along * (o.radius + c)
        let rest = obs.filter { $0.id != o.id }
        return route(a, w1, rest, c, depth: depth + 1) + [w2] + route(w2, b, rest, c, depth: depth + 1)
    }

    /// Nearest obstacle whose inflated circle the segment crosses.
    public static func firstBlock(_ a: SIMD2<Double>, _ b: SIMD2<Double>, _ obs: [WorldObstacle],
                           _ c: Double) -> (obstacle: WorldObstacle, t: Double)? {
        let d = b - a
        let dd = max((d * d).sum(), 1e-9)
        var best: (WorldObstacle, Double)?
        for o in obs {
            let t = max(0, min(1, ((o.center - a) * d).sum() / dd))
            let p = a + d * t
            guard simd_len(o.center - p) < o.radius + c else { continue }
            if best == nil || t < best!.1 { best = (o, t) }
        }
        return best.map { ($0.0, $0.1) }
    }

    public static func length(_ path: [SIMD2<Double>]) -> Double {
        zip(path, path.dropFirst()).reduce(0) { $0 + simd_len($1.1 - $1.0) }
    }
}

/// Follows a waypoint path with body-frame roll and pitch. Holds yaw and altitude.
public struct PathFollower: Sendable {
    public var path: [SIMD2<Double>] = []
    public var index = 1
    public var arriveM = 0.3
    /// Stick per meter of error, before clamping to `maxStick`.
    public var gain = 0.6
    public var maxStick: Float = 0.5
    public init() {}

    public var isDone: Bool { index >= path.count }
    public var target: SIMD2<Double>? { path.last }

    public mutating func set(_ p: [SIMD2<Double>]) { path = p; index = 1 }

    public mutating func sticks(pose: DronePose) -> DroneSticks {
        while index < path.count, simd_len(path[index] - pose.xy) < arriveM { index += 1 }
        guard index < path.count else { return .zero }
        let b = pose.toBody(path[index])
        let m = Float(gain)
        func c(_ v: Double) -> Float { max(-maxStick, min(maxStick, Float(v) * m)) }
        return DroneSticks(yaw: 0, throttle: 0, roll: c(b.y), pitch: c(b.x))
    }
}
