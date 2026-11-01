//
//  GameContext.swift
//  HelicopterGame
//
//  Single, canonical access point for the game's shared managers.
//
//  Background:
//  The game previously exposed ~20 independent `static let shared` singletons
//  spread across Managers/, Systems/, and Components/. That made ordering bugs
//  and test isolation painful. `GameContext` consolidates access to all of them
//  behind one object so call sites depend on a single seam instead of reaching
//  into many globals directly.
//
//  Design notes:
//  - `GameContext` is intentionally NOT actor-isolated. The underlying managers
//    have mixed isolation: some are `@MainActor` (LoadoutManager,
//    GameSessionManager, the preloaders, …), others are deliberately
//    non-isolated so RealityKit `System`s can touch them off the main actor
//    (CollisionManager, WaveManager, the *PositionData blobs, …). Each accessor
//    carries the same isolation as the manager it returns, so existing call
//    sites compile with identical isolation requirements.
//  - This file only declares the empty `GameContext` shell. Each manager's
//    `static let shared` is `fileprivate` to that manager's own source file,
//    and the corresponding `GameContext.shared.x` accessor is declared as an
//    extension in that same file (e.g. `extension GameContext { public var
//    loadout: LoadoutManager { LoadoutManager.shared } }` lives in
//    LoadoutManager.swift). That makes the seam compiler-enforced: no file
//    other than the manager's own can reference `Type.shared` directly, so
//    `GameContext.shared.x` really is the only path to each manager.
//
//  Usage:
//      GameContext.shared.loadout
//      GameContext.shared.collision
//      GameContext.shared.health
//
import Foundation

public final class GameContext {

    /// The single shared game context. Replaces the previous per-manager singletons.
    public static let shared = GameContext()

    private init() {}
}
