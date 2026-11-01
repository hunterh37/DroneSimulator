import CoreGraphics
import Foundation

public enum ObstacleKind: String, Sendable, Equatable {
    case pole, wall, object

    /// Assumed real width in meters, used for monocular range. Nil means unknown.
    public var widthM: Double? {
        switch self {
        case .pole: 0.25
        case .object: 0.5
        case .wall: nil
        }
    }
}

/// One detection in a frame. `rect` is normalized, origin top-left, y down.
public struct ObstacleDetection: Sendable, Equatable {
    public var rect: CGRect
    public var kind: ObstacleKind
    public var confidence: Float
    public init(rect: CGRect, kind: ObstacleKind, confidence: Float = 1) {
        self.rect = rect; self.kind = kind; self.confidence = confidence
    }
}

public enum ThreatLevel: Int, Sendable, Comparable {
    case clear, watch, warn, brake
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// Tracked obstacle. Body frame: forward, right, up in meters.
public struct Obstacle: Identifiable, Sendable, Equatable {
    public var id: Int
    public var kind: ObstacleKind
    public var rect: CGRect
    public var distanceM: Double?
    /// Time to contact in seconds from image expansion or range over speed.
    public var ttc: Double?
    public var bearing: Double
    public var elevation: Double
    public var inPath: Bool
    public var threat: ThreatLevel

    /// Body-frame position (forward, right, up) in meters. Uses 4 m when range is unknown.
    public var position: SIMD3<Double> {
        let d = distanceM ?? 4
        return SIMD3(d, d * tan(bearing), d * tan(elevation))
    }
}

/// Tello 960x720 camera: 82.6 deg diagonal FOV, about 70 deg horizontal, 56 deg vertical.
public enum TelloCamera {
    public static let hfov = 70.3 * Double.pi / 180
    public static let vfov = 55.7 * Double.pi / 180
    /// Focal length in normalized image widths and heights.
    public static let fx = 0.5 / tan(hfov / 2)
    public static let fy = 0.5 / tan(vfov / 2)

    public static func bearing(x: Double) -> Double { atan((x - 0.5) / fx) }
    public static func elevation(y: Double) -> Double { atan((0.5 - y) / fy) }
    /// Range from apparent width (normalized) and real width (m).
    public static func range(widthNorm: Double, realM: Double) -> Double {
        realM * fx / max(widthNorm, 0.001)
    }
    /// Normalized width of an object of `realM` at `rangeM`.
    public static func widthNorm(realM: Double, rangeM: Double) -> Double { realM * fx / max(rangeM, 0.05) }
}
