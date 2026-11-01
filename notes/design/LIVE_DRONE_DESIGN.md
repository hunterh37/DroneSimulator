# Live drone design (monochrome command center, after Weald)

Reference: Weald `Sources/UI/Theme.swift`. No accent hue. White marks the current action or live state; gray carries hierarchy.

## Tokens (`RealDrone/LiveTheme.swift`)
- bg #000000, surface white 4 percent, surfaceHi white 8 percent, hairline white 10 percent, hairlineHi white 18 percent.
- text white, textDim white 60 percent, textFaint white 35 percent.
- danger red (Kill, ceiling breach) is the only hue. Warning = white on black, inverted chip.
- Type: SF Mono (`.system(size:, weight:, design: .monospaced)`) for all numbers, state words, labels (uppercase, tracking 1.2). SF Pro for nothing else but the title.
- Motion: spring(response 0.22, damping 0.86). Hover lifts surface to surfaceHi and hairline to hairlineHi.
- Shapes: 10 pt radius rects with 1 px hairline borders. No shadows, no gradients, no glass material on panels (set window background to black, `.glassBackgroundEffect` off).

## Layout (feed window)
- Video fills the window edge to edge, 4:3 (Tello 960x720). No-signal state: black with centered mono "NO SIGNAL" in textFaint and a thin white scan line.
- Top bar overlaid on video: left `TELLO` + state word (OFFLINE / READY / FLYING); right battery percent and link fps. Mono 13, textDim, live values white.
- Left edge: vertical altitude tape 0 to 10 ft, white tick every ft, hairline track, white marker at current height, ceiling line at 10 ft. Value in ft, one decimal.
- Bottom: two small stick readouts (circles with a white dot) for left and right sticks, and the rc out line in textFaint.
- Bottom-right control row: CONNECT, ARM (toggle chip, white fill when armed), TAKE OFF, LAND, KILL (red outline, red fill on hover). Speed limit as a thin segmented row 20/40/60/80/100. Invert pitch moves to a small gear popover.
- Safety banner: full-width strip under the top bar. Warning = inverted white strip with black text "ALT 8.4 FT. NEAR CEILING". Ceiling/over = red strip. No telemetry = white outline strip.
- EXIT in top-left as plain mono text button.
- Home button "Live drone": black capsule, hairline border, mono uppercase "LIVE DRONE".
Copy: uppercase, short, no subtitles or helper sentences.
