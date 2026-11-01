//
//  SoundManager.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/2/25.
//

import Foundation
import ARKit
import RealityKit
import SwiftUI
import AVFoundation

class SoundManager {
    // Backing store for GameContext — fileprivate so this is the only file
    // that can reach `SoundManager.shared` directly; everyone else must go
    // through GameContext.shared.sound.
    fileprivate static let shared = SoundManager()

    var hitSoundResource: AudioFileResource? = nil

    var droneSound: AudioFileResource? = nil

    var explosionSound: AudioFileResource? = nil

    var bossAttackSound1: AudioFileResource? = nil
    var bossAttackSound2: AudioFileResource? = nil
    var bossAttackSound3: AudioFileResource? = nil

    var enemyDroneShootSound: AudioFileResource? = nil

    var shootSound: AudioFileResource? = nil

    var damageTakenSound: AudioFileResource? = nil

    var destructionSound: AudioFileResource? = nil

    var missileWhooshSound: AudioFileResource? = nil

    var waveStartSound: AudioFileResource? = nil

    var bossSpawnSound: AudioFileResource? = nil

    var ringCollectSound: AudioFileResource? = nil

    init () {
        loadAudio()
    }

    func loadAudio() {
        Task { @MainActor in

            if let droneSound2 = try? AudioFileResource.load(named: "DroneSound",
                                                             in: .main, configuration: .init(shouldLoop: true)) {
                droneSound = droneSound2
            }

            if let explosionSound2 = try? AudioFileResource.load(named: "Explosion",
                                                                 in: .main, configuration: .init(shouldLoop: false)) {
                explosionSound = explosionSound2
            }

            if let bossAttackSound1Load = try? AudioFileResource.load(named: "BossAttackSound1",
                                                                   in: .main, configuration: .init(shouldLoop: false)) {
                bossAttackSound1 = bossAttackSound1Load
            }

            if let bossAttackSound2Load = try? AudioFileResource.load(named: "BossAttackSound2",
                                                                   in: .main, configuration: .init(shouldLoop: false)) {
                bossAttackSound2 = bossAttackSound2Load
            }

            if let bossAttackSound3Load = try? AudioFileResource.load(named: "BossAttackSound3",
                                                                   in: .main, configuration: .init(shouldLoop: false)) {
                bossAttackSound3 = bossAttackSound3Load
            }

            if let enemyDroneShootSound2 = try? AudioFileResource.load(named: "EnemyDroneShoot",
                                                                        in: .main, configuration: .init(shouldLoop: false)) {
                enemyDroneShootSound = enemyDroneShootSound2
            }

            if let shootSound1 = try? AudioFileResource.load(named: "ShootSound1",
                                                             in: .main, configuration: .init(shouldLoop: false)) {
                shootSound = shootSound1
            }

            if let damageSound = try? AudioFileResource.load(named: "DamageTaken",
                                                              in: .main, configuration: .init(shouldLoop: false)) {
                damageTakenSound = damageSound
            }

            if let destructionSound2 = try? AudioFileResource.load(named: "Destruction",
                                                                    in: .main, configuration: .init(shouldLoop: false)) {
                destructionSound = destructionSound2
            }

            if let whooshSound = try? AudioFileResource.load(named: "MissileWhoosh",
                                                              in: .main, configuration: .init(shouldLoop: false)) {
                missileWhooshSound = whooshSound
            }

            if let waveSound = try? AudioFileResource.load(named: "WaveStart",
                                                            in: .main, configuration: .init(shouldLoop: false)) {
                waveStartSound = waveSound
            }

            if let bossSpawnSound2 = try? AudioFileResource.load(named: "BossSpawn",
                                                                  in: .main, configuration: .init(shouldLoop: false)) {
                bossSpawnSound = bossSpawnSound2
            }

            if let ringCollect = try? AudioFileResource.load(named: "RingCollect",
                                                              in: .main, configuration: .init(shouldLoop: false)) {
                ringCollectSound = ringCollect
            }
        }
    }

    func playDroneSound(entity: Entity) {
        if let droneSound {
            let audioPlaybackController = entity.prepareAudio(droneSound)
            audioPlaybackController
            audioPlaybackController.play()
        }
    }

    func playExplosionSound(entity: Entity) {
        if let explosionSound {
            let audioPlaybackController = entity.prepareAudio(explosionSound)
            audioPlaybackController.play()
        }
    }

    func playBossAttackSound(entity: Entity, attackType: BossAttackType) {
        let sound: AudioFileResource?

        switch attackType {
        case .swarm:
            sound = bossAttackSound1
        case .wave:
            sound = bossAttackSound2
        case .burst:
            sound = bossAttackSound3
        }

        if let sound = sound {
            let audioPlaybackController = entity.prepareAudio(sound)
            audioPlaybackController.play()
            gameLog("🔊 [SoundManager] Playing boss attack sound for \(attackType)")
        } else {
            gameLog("⚠️ [SoundManager] Boss attack sound not loaded for \(attackType)")
        }
    }

    func playEnemyDroneShootSound(entity: Entity) {
        // Play spatial sound for enemy drone shooting
        if let enemyDroneShootSound {
            let audioPlaybackController = entity.prepareAudio(enemyDroneShootSound)
            audioPlaybackController.play()
            gameLog("🔊 [SoundManager] Playing enemy drone shoot sound")
        }
    }

    func playShootSound(entity: Entity) {
        // Play spatial sound for player shooting missiles
        if let shootSound {
            let audioPlaybackController = entity.prepareAudio(shootSound)
            audioPlaybackController.play()
            gameLog("🔊 [SoundManager] Playing player shoot sound")
        }
    }

    func playDamageTakenSound(entity: Entity) {
        if let damageTakenSound {
            let controller = entity.prepareAudio(damageTakenSound)
            controller.play()
            gameLog("🔊 [SoundManager] Playing damage taken sound")
        }
    }

    func playDestructionSound(entity: Entity) {
        if let destructionSound {
            let controller = entity.prepareAudio(destructionSound)
            controller.play()
            gameLog("🔊 [SoundManager] Playing destruction sound")
        }
    }

    func playMissileWhooshSound(entity: Entity) {
        if let missileWhooshSound {
            let controller = entity.prepareAudio(missileWhooshSound)
            controller.play()
            gameLog("🔊 [SoundManager] Playing missile whoosh sound")
        }
    }

    func playWaveStartSound(entity: Entity) {
        if let waveStartSound {
            let controller = entity.prepareAudio(waveStartSound)
            controller.play()
            gameLog("🔊 [SoundManager] Playing wave start sound")
        }
    }

    func playBossSpawnSound(entity: Entity) {
        if let bossSpawnSound {
            let controller = entity.prepareAudio(bossSpawnSound)
            controller.play()
            gameLog("🔊 [SoundManager] Playing boss spawn sound")
        }
    }

    func playRingCollectSound(entity: Entity) {
        if let ringCollectSound {
            let controller = entity.prepareAudio(ringCollectSound)
            controller.play()
            gameLog("🔊 [SoundManager] Playing ring collect sound")
        }
    }
}

extension GameContext {
    var sound: SoundManager { SoundManager.shared }
}
