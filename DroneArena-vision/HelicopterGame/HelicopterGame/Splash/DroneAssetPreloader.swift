#if os(visionOS)
import RealityKit
import Foundation

/// Preloads heavy drone/arena USDZ assets up front so the first time they're needed
/// in-game there's no disk-parse hitch. Reports `progress(0.0...1.0, label)` after each
/// step so the splash loading bar reflects real work. Mirrors ZombieShooter's
/// `AssetPreloader.preloadAll`.
@MainActor
final class DroneAssetPreloader {

    /// Parsed entity templates, keyed by asset name. Clone these at spawn time.
    static var bases: [String: Entity] = [:]

    /// Returns a fresh clone of a preloaded asset, falling back to a one-time
    /// synchronous load (then caches) if preloading hasn't reached it yet.
    static func clone(named name: String) -> Entity? {
        if let base = bases[name] { return base.clone(recursive: true) }
        guard let loaded = try? Entity.load(named: name) else { return nil }
        bases[name] = loaded
        return loaded.clone(recursive: true)
    }

    private struct Load {
        let name: String
        let label: String
    }

    /// Preloads all heavy assets. Calls `progress(0.0...1.0, label)` after each step.
    static func preloadAll(progress: (Double, String) -> Void) async {
        progress(0.0, "INITIALIZING SYSTEMS...")

        // Loaded in parallel — independent disk parses.
        let loads: [Load] = [
            Load(name: "Drone",            label: "PLAYER DRONE"),
            Load(name: "EnemyDrone1",      label: "ENEMY DRONES"),
            Load(name: "EnemyDrone2",      label: "ENEMY DRONES"),
            Load(name: "ScoutDrone",       label: "SCOUT DRONE"),
            Load(name: "GuardianDrone",    label: "GUARDIAN DRONE"),
            Load(name: "InterceptorDrone", label: "INTERCEPTOR DRONE"),
            Load(name: "RangerDrone",      label: "RANGER DRONE"),
            Load(name: "DroneBoss",        label: "BOSS DRONE"),
            Load(name: "Spawner",          label: "SPAWNERS"),
            Load(name: "HubZone",          label: "ARENA ZONES"),
            Load(name: "CargoZone",        label: "ARENA ZONES"),
            Load(name: "DeliveryZone",     label: "ARENA ZONES"),
            Load(name: "DockPad",          label: "DOCK PADS"),
            Load(name: "Landmark",         label: "LANDMARKS"),
            Load(name: "Ring",             label: "COURSE RINGS"),
            Load(name: "Coin",             label: "PICKUPS"),
            Load(name: "Claw",             label: "CARGO CLAW"),
            Load(name: "Package1",         label: "CARGO"),
            Load(name: "Package2",         label: "CARGO"),
            Load(name: "Package3",         label: "CARGO"),
            Load(name: "Missiles/StandardMissile", label: "ORDNANCE"),
            Load(name: "Missiles/RapidMissile",    label: "ORDNANCE"),
            Load(name: "Missiles/BigMissile",      label: "ORDNANCE"),
            Load(name: "Missiles/DamageMissile",   label: "ORDNANCE"),
        ]

        let start = 0.05
        let end   = 0.97
        let step  = (end - start) / Double(loads.count)
        progress(start, "LOADING DRONES...")

        await withTaskGroup(of: (Int, Entity?).self) { group in
            for (i, load) in loads.enumerated() {
                group.addTask {
                    let entity = try? await Entity(named: load.name, in: nil)
                    if entity == nil {
                        print("[DroneAssetPreloader] ⚠️ Failed to load: \(load.name)")
                    }
                    return (i, entity)
                }
            }
            for await (i, entity) in group {
                if let entity {
                    // Cache by the leaf name (so "Missiles/StandardMissile" → "StandardMissile").
                    let key = (loads[i].name as NSString).lastPathComponent
                    bases[key] = entity
                }
                let p = start + Double(i) * step
                progress(p, "LOADING \(loads[i].label)...")
            }
        }

        progress(1.0, "READY")
    }
}
#endif
