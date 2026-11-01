# iPhone visual log

Capture: `SKIP_BUILD=1 bash ~/.claude/skills/vision-screenshot/scripts/shoot.sh screenshots/shots.json`
Sim: Director-DroneArena-iOS (iPhone 17 Pro Max). Install build/demo-dd-ios app first (DroneArena.xcodeproj has two sibling projects, shoot.sh build step needs -project).
Routes: HelicopterGame-iOS/IOSDirectorRoutes.swift (menu/home, fly/<mode>, -P.left/-P.right "x,y", -P.stage garage|armory).

Iteration 1 fixes: joystick Y inversion (InputRouter_iOS), touch-tracking stick (MobileVirtualJoystick), sticks swapped to Mode 2 (left = throttle+yaw), per-frame update moved to SceneEvents.Update, Arena HUD (armor gauge, hardpoints, icon buttons, wave counter, time trial), stats panel overlap.
Iteration 2: garage meter label wrap, armory tag overlap.
Verified: practice with left=(0.8,0.6) climbs 0 to 11 ft, 4 mph.
