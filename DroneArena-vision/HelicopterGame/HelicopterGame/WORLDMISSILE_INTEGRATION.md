# World Missile System Integration Guide

## Overview

The World Missile System allows users to tap a grid to select positions in the game world and fire missiles from above onto those positions. It uses the same missile logic and selected weapons from the LoadoutManager as the player drone system.

## Components Created

### 1. `WorldMissileEntity.swift`
- **WorldMissileComponent**: Component for tracking world missiles
- **WorldMissileEntity**: Entity class for missiles fired from above
- **WorldMissileSystem**: RealityKit system that updates world missiles, checks collisions, and handles damage

### 2. `WorldMissileShooter.swift`
- **WorldMissileShooter**: Singleton manager for firing missiles from above
- Integrates with `LoadoutManager` to use selected weapons
- Supports both weapon slots (slot 1 and slot 2)
- Fires missiles in grid patterns matching weapon configurations

### 3. `WorldMissileGridView.swift`
- **WorldMissileGridView**: SwiftUI grid view for selecting world positions
- **GridCoordinate**: Structure representing grid cell coordinates
- Converts grid taps to SIMD3 world positions
- Provides visual feedback for tapped cells

### 4. `WorldMissileControlView.swift`
- **WorldMissileControlView**: Full-featured UI for the world missile system
- **CompactWorldMissileGridView**: Compact version suitable for in-game overlay
- Includes weapon slot selection, grid size adjustment, and statistics

## Integration Steps

### Step 1: Register the WorldMissileSystem

In your RealityKit scene setup (e.g., `ImmersiveView.swift` or your main scene controller):

```swift
import RealityKit

// Register the WorldMissileSystem alongside other systems
RealityKitContent.registerComponent(WorldMissileComponent.self)
```

### Step 2: Set the Root Entity

After creating your RealityKit scene's root entity:

```swift
// In your ImmersiveView or scene setup
let rootEntity = Entity()
scene.addEntity(rootEntity)

// Set the root entity for WorldMissileShooter
WorldMissileShooter.shared.setRootEntity(rootEntity)
```

### Step 3: Add the UI

#### Option A: Full Control View (for testing or settings screen)

```swift
import SwiftUI

struct YourGameView: View {
    @State private var showMissileControls = false

    var body: some View {
        ZStack {
            // Your game view
            RealityView { content in
                // ...
            }

            // Overlay the missile control view
            if showMissileControls {
                WorldMissileControlView()
                    .frame(width: 400, height: 600)
                    .position(x: 200, y: 300)
            }
        }
    }
}
```

#### Option B: Compact Overlay (for in-game use)

```swift
struct YourGameOverlay: View {
    var body: some View {
        VStack {
            HStack {
                Spacer()

                // Compact grid view in top-right corner
                CompactWorldMissileGridView()
                    .padding()
            }

            Spacer()
        }
    }
}
```

#### Option C: Direct Grid Integration

```swift
struct CustomGameUI: View {
    var body: some View {
        WorldMissileGridView(
            gridSize: 10,
            worldBounds: SIMD2<Float>(20, 20),
            weaponSlot: 1
        ) { position in
            print("Fired at position: \(position)")
            // Additional custom logic here
        }
        .frame(width: 300, height: 300)
    }
}
```

### Step 4: Manual Firing (Optional)

You can also fire missiles programmatically without the grid UI:

```swift
// Fire at a specific world position
let targetPosition = SIMD3<Float>(5.0, 0, -3.0)
WorldMissileShooter.shared.fireMissilesAt(targetPosition: targetPosition, slot: 1)

// Or use grid coordinates (0-1 normalized)
WorldMissileShooter.shared.fireMissilesAtGrid(
    gridX: 0.5,  // Center X
    gridY: 0.5,  // Center Z
    worldBounds: SIMD2<Float>(20, 20),
    slot: 1
)
```

## Configuration

### World Bounds
The world bounds define the size of the playable area:

```swift
let worldBounds = SIMD2<Float>(20, 20) // 20m x 20m world
```

### Grid Size
The grid size determines the number of cells:

```swift
let gridSize = 10 // 10x10 grid = 100 cells
```

### Spawn Height
Missiles spawn 10 meters above the target by default. Modify in `WorldMissileShooter.swift`:

```swift
private let spawnHeight: Float = 10.0 // Change this value
```

### Missile Speed
Missiles fall at 8 m/s by default. Modify in `WorldMissileShooter.swift`:

```swift
private let missileSpeed: Float = 8.0 // Change this value
```

## How It Works

### 1. Grid Tap
User taps a grid cell in `WorldMissileGridView`

### 2. Coordinate Conversion
- Grid cell (row, col) → Normalized coordinates (0-1)
- Normalized → World position SIMD3(x, 0, z)

### 3. Missile Spawning
`WorldMissileShooter` spawns missiles:
- Position: 10m above target
- Velocity: Straight down (-Y direction)
- Uses selected weapon from `LoadoutManager`
- Fires in grid pattern (barrage weapons fire multiple missiles)

### 4. Missile Update
`WorldMissileSystem` updates each frame:
- Moves missiles downward
- Checks collisions with targets (drones, bosses, players)
- Handles damage and explosions
- Removes missiles after hitting or expiring

### 5. Collision Detection
Uses distance-based collision checking:
- Boss: 2.0m radius
- Player/Remote drones: 0.6m radius
- Enemy drones: 0.5m radius

## Weapon Integration

The system fully integrates with `LoadoutManager`:

- **Missile models**: Uses selected weapon's USDZ model
- **Damage**: Uses weapon damage stat
- **Collision radius**: Uses weapon collision size
- **Trail color**: Uses weapon trail color
- **Grid pattern**: Barrage weapons fire multiple missiles in patterns
- **Missile count**: Respects weapon's missileCount property

## Example Use Cases

### 1. Strategic Targeting View
Show the grid during pause or planning phase:

```swift
if gameState == .planning {
    WorldMissileControlView()
}
```

### 2. Quick Access Overlay
Small grid in corner for quick strikes:

```swift
VStack {
    HStack {
        Spacer()
        CompactWorldMissileGridView()
    }
    Spacer()
}
```

### 3. AI/Automated Firing
Fire at computed positions:

```swift
func fireAtNearestEnemy(enemies: [EnemyDrone]) {
    guard let nearest = enemies.first else { return }
    WorldMissileShooter.shared.fireMissilesAt(
        targetPosition: nearest.position,
        slot: 1
    )
}
```

### 4. Scripted Events
Fire at predetermined locations:

```swift
let strikeLocations = [
    SIMD3<Float>(5, 0, 5),
    SIMD3<Float>(-5, 0, 5),
    SIMD3<Float>(5, 0, -5),
    SIMD3<Float>(-5, 0, -5)
]

for location in strikeLocations {
    WorldMissileShooter.shared.fireMissilesAt(
        targetPosition: location,
        slot: 1
    )
}
```

## Visual Customization

### Grid Cell Colors
Modify in `WorldMissileGridView.swift` > `GridCellView`:

```swift
private var cellColor: Color {
    if isLastTapped {
        return Color.red.opacity(0.6)      // Just tapped
    } else if isHighlighted {
        return Color.yellow.opacity(0.4)   // Highlighted
    } else {
        return Color.blue.opacity(0.2)     // Default
    }
}
```

### Grid Cell Border
```swift
private var borderColor: Color {
    if isLastTapped {
        return Color.red
    } else if isHighlighted {
        return Color.yellow
    } else {
        return Color.white.opacity(0.3)
    }
}
```

## Debugging

Enable collision debug visualizers:

```swift
// Show collision shapes for world missiles
WorldMissileEntity.showCollisionDebug = true
```

## Performance Considerations

- **Grid size**: Larger grids (15x15+) may impact SwiftUI performance
- **Fire rate**: Default 0.5s cooldown prevents spam
- **Missile lifetime**: 5 seconds (enough time to fall from 10m)
- **Collision checks**: Uses efficient distance-based checking

## Testing

Preview the views in Xcode:
1. Open `WorldMissileGridView.swift` or `WorldMissileControlView.swift`
2. Use Xcode previews to test interaction
3. Note: Missile firing won't work in preview mode (requires RealityKit scene)

## Troubleshooting

### Missiles not firing
- Ensure `WorldMissileShooter.shared.setRootEntity()` was called
- Check that `WorldMissileSystem` is registered
- Verify LoadoutManager has weapons selected

### Missiles not hitting targets
- Check collision radii in `WorldMissileSystem.getCollisionRadius()`
- Verify target entities have required components
- Enable debug visualization to see collision shapes

### Grid coordinates wrong
- Verify `worldBounds` matches your actual game world size
- Check that world is centered at origin (0, 0, 0)

## File Locations

```
HelicopterGame/
├── Entities/
│   └── WorldMissileEntity.swift          (Missile entity and system)
├── Managers/
│   └── WorldMissileShooter.swift         (Firing manager)
└── UI/
    ├── WorldMissileGridView.swift        (Grid view component)
    └── WorldMissileControlView.swift     (Example integration views)
```
