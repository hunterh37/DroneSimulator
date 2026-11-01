//
//  DronePermissionsGate.swift
//  HelicopterGame
//
//  First-launch gating for the ARKit permissions prompt. We show
//  `DroneARKitPermissionsView` exactly once — before the first immersive
//  mission, and therefore before the flight tutorial — then never auto-show it
//  again. The actual authorization state still lives with ARKit; this flag only
//  controls whether we proactively surface the prompt UI.
//

import Foundation

public enum DronePermissionsGate {

    private static let promptedKey = "HasShownDronePermissionsGate"

    /// True until we've shown the permissions gate once.
    public static var needsPrompt: Bool {
        !UserDefaults.standard.bool(forKey: promptedKey)
    }

    /// Record that the gate has been shown (player granted or skipped).
    public static func markPrompted() {
        UserDefaults.standard.set(true, forKey: promptedKey)
    }

    /// Clears the prompted flag so the gate shows again on the next mission launch.
    public static func reset() {
        UserDefaults.standard.removeObject(forKey: promptedKey)
    }
}

/// One-call reset for the whole first-launch onboarding (permissions gate +
/// flight tutorial). Handy for QA: set the `RESET_ONBOARDING` env var (or scheme
/// argument) to "1" and relaunch to replay onboarding from scratch.
public enum DroneOnboarding {

    public static func resetAll() {
        DronePermissionsGate.reset()
        // Mirror of DroneTutorialController.seenKey — kept in sync intentionally.
        UserDefaults.standard.removeObject(forKey: "HasSeenDroneTutorial")
    }

    /// Honors the `RESET_ONBOARDING=1` environment variable at startup.
    public static func resetIfRequested() {
        if ProcessInfo.processInfo.environment["RESET_ONBOARDING"] == "1" {
            resetAll()
        }
    }
}
