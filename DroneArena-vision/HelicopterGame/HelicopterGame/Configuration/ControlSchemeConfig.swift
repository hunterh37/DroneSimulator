//
//  ControlSchemeConfig.swift
//  HelicopterGame
//
//  The two shipping control schemes:
//   - .handJoystick     : hand-tracking thumb stick (DicyaninThumbController).
//   - .physicalJoystick : world-anchored pillar stand with two physics joysticks
//                         and fire buttons (DicyaninVirtualJoystick).
//
//  Both feed the same DualThumbController pipeline. The value is persisted and
//  changes apply live: `didChangeNotification` is posted on every change and the
//  immersive scene swaps the rig and input source in place.
//

import Foundation
#if os(visionOS)
import DicyaninThumbController
#endif

public enum DroneControlScheme: String, CaseIterable, Identifiable, Sendable {
    /// Raw values kept from earlier builds so stored preferences survive.
    case handJoystick = "thumbController"
    case physicalJoystick = "gamepadPillar"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .handJoystick:     return "Hand Joystick"
        case .physicalJoystick: return "Joystick Stand"
        }
    }

    public var shortName: String {
        switch self {
        case .handJoystick:     return "HAND"
        case .physicalJoystick: return "STAND"
        }
    }

    public var subtitle: String {
        switch self {
        case .handJoystick:     return "Tilt your thumbs to fly"
        case .physicalJoystick: return "Grab the sticks, press to fire"
        }
    }

    public var symbolName: String {
        switch self {
        case .handJoystick:     return "hand.raised.fingers.spread.fill"
        case .physicalJoystick: return "gamecontroller.fill"
        }
    }
}

public enum ControlSchemeConfig {

    public static let defaultScheme: DroneControlScheme = .physicalJoystick
    public static let didChangeNotification = Notification.Name("drone.controlScheme.didChange")

    private static let storageKey = "drone.controlScheme"

    /// The currently selected control scheme. Persisted across launches.
    /// Legacy "gamepad3D" values migrate to the joystick stand.
    public static var current: DroneControlScheme {
        get {
            guard let raw = UserDefaults.standard.string(forKey: storageKey) else { return defaultScheme }
            return DroneControlScheme(rawValue: raw) ?? .physicalJoystick
        }
        set {
            guard newValue != current || UserDefaults.standard.string(forKey: storageKey) == nil else { return }
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
            syncHandTrackingGate(for: newValue)
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }

    /// Keeps raw hand-tracking writes suppressed while the joystick stand is the
    /// sole writer of the shared input channels.
    public static func syncHandTrackingGate(for scheme: DroneControlScheme = current) {
#if os(visionOS)
        DualThumbController.shared.isHandTrackingInputEnabled = scheme == .handJoystick
#endif
    }

    public static var useGamepadPillar: Bool { current == .physicalJoystick }
    public static var useWorldJoystickRig: Bool { current == .physicalJoystick }
    public static var useThumbController: Bool { current == .handJoystick }
}
