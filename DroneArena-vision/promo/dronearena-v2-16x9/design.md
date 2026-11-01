# Drone Arena, paper arena

Concept: the capture room rebuilt as a clay and ink maquette. The 3D camera lands on the exact pose of
the simulator camera, so an acid scan bar can sweep between the maquette and the real footage.
Each mode transforms the maquette first (gates and stands, forest, cargo pads), then the bar reveals it for real.

Palette
- paper #ECE8DF (backgrounds, 3D clear color)
- ink #0C0C0E (type, outlines, chips)
- acid #D4FF3A (highlight blocks, scan bar, flight ribbon; the in-app lime)
- coral #FF5A36 (drone tips, cargo accent)

Type
- Display: League Gothic 400, uppercase, line-height 0.92, acid block behind the key word.
- Labels: Space Mono 700, uppercase, tracking 0.18em.

Camera calibration (room.js)
- Eye (0, 1.473, 0), looking -Z, vertical FOV 56 deg, f = 1015 px at 1080p. Back wall z -5.58, walls x -2.07 / 2.08, ceiling 2.6.
- Footage pixel (x, y) at depth z -> world: ((x-960)/1015*z, 1.473-(y-540)/1015*z, -z).

Motion
- 123 bpm grid (0.4878s). Scan sweeps 0.488s power2.inOut. Acid full-frame swipe on intro and outro seams.
