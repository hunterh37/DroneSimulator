//
//  GameLog.swift
//  HelicopterGame
//
//  Centralized logging shim. Replaces raw print() calls throughout the app.
//
//  Why this exists:
//  - Routes all diagnostic output through OSLog/Logger (structured, level-aware,
//    visible in Console.app and Instruments instead of just the Xcode console).
//  - In RELEASE builds every call compiles to nothing. The message is taken as an
//    @autoclosure, so the string (and any interpolation like CACurrentMediaTime())
//    is never even evaluated. This removes per-frame logging cost from hot paths
//    such as the AI/boss/indicator systems and the networking layer.
//
//  Usage is a drop-in replacement for print:
//      gameLog("🚁 spawned drone at \(position)")          // .debug (default)
//      gameLog("Connection lost, retrying…", level: .info)
//      gameLog("Failed to decode packet: \(error)", level: .error)
//

import Foundation
import os

/// Shared logger for the game. Subsystem defaults to the app's bundle id.
let gameLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "DroneArena",
    category: "Game"
)

/// Severity levels mapped onto OSLog. Defaults to `.debug` so existing chatty
/// print() sites stay out of the release/persistent log store.
enum GameLogLevel {
    case debug
    case info
    case notice
    case warning   // mapped to OSLog `.error` so it surfaces and persists
    case error     // mapped to OSLog `.fault`
}

/// Drop-in replacement for `print(...)`.
///
/// In DEBUG the message is formatted and emitted through `gameLogger`.
/// In RELEASE the call body is empty and `message` is never evaluated, so the
/// entire statement — including string interpolation — compiles away.
@inline(__always)
func gameLog(_ message: @autoclosure () -> String, level: GameLogLevel = .debug) {
    #if DEBUG
    let text = message()
    switch level {
    case .debug:   gameLogger.debug("\(text, privacy: .public)")
    case .info:    gameLogger.info("\(text, privacy: .public)")
    case .notice:  gameLogger.notice("\(text, privacy: .public)")
    case .warning: gameLogger.error("\(text, privacy: .public)")
    case .error:   gameLogger.fault("\(text, privacy: .public)")
    }
    #endif
}

/// Opt-in toggle for high-frequency / per-message diagnostic logging (e.g. the
/// networking layer's per-packet socket traffic). Defaults to `false` so normal
/// DEBUG sessions aren't drowned out by per-message chatter; flip it at runtime
/// when you actually need to trace individual packets.
///
/// In RELEASE this is unused — `gameLogVerbose` compiles away entirely.
#if DEBUG
nonisolated(unsafe) var gameLogVerboseEnabled = false
#endif

/// Like `gameLog`, but additionally gated behind `gameLogVerboseEnabled`.
///
/// Use for chatty, per-message hot paths where the output is only useful while
/// actively debugging that subsystem. In RELEASE the call body is empty and
/// `message` is never evaluated, exactly like `gameLog`.
@inline(__always)
func gameLogVerbose(_ message: @autoclosure () -> String, level: GameLogLevel = .debug) {
    #if DEBUG
    guard gameLogVerboseEnabled else { return }
    gameLog(message(), level: level)
    #endif
}
