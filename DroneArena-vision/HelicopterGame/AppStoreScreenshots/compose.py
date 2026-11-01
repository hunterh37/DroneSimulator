# Composes App Store visionOS screenshots (3840x2160) from raw simulator captures.
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os
D = os.path.dirname(os.path.abspath(__file__))
FONT = "/System/Library/Fonts/Supplemental/Futura.ttc"
def f(size, idx): return ImageFont.truetype(FONT, size, index=idx)
VOLT, GO, HEAT = (228, 255, 26), (43, 255, 142), (255, 74, 28)

SHOTS = [
    ("race_3_ui1", "RACE LEAGUE", VOLT, ["Race drones", "in your room"], "Full-scale circuits against CPU pilots."),
    ("race_0_ui0", "LIVE HUD", VOLT, ["Every gate.", "Every lap."], "Position, lap times and standings at a glance."),
    ("race_1_ui1", "ARENA", HEAT, ["A stadium", "that fits anywhere"], "Stands, lights and gates built around you."),
    ("safari_3_ui1", "SAFARI", GO, ["Fly a tiny", "island safari"], "Five zones of critters to find and pop."),
    ("safari_0_ui0", "COMBOS", GO, ["Chain combos,", "beat the clock"], "Score big before the timer runs out."),
    ("safari_1_ui1", "EXPLORE", GO, ["Low-poly worlds", "made for flight"], "Hidden paths, forests and critters."),
]

def shade(img):
    import numpy as np
    w, h = img.size
    xs = np.linspace(0, 1, w)[None, :]
    ys = np.linspace(0, 1, h)[:, None]
    v = np.clip(1 - xs / 0.62, 0, 1) ** 1.6 * 0.82 + np.clip((ys - 0.55) / 0.45, 0, 1) * 0.35
    g = Image.fromarray((np.clip(v, 0, 1) * 255).astype("uint8"), "L")
    dark = Image.new("RGB", (w, h), (8, 10, 14))
    return Image.composite(dark, img, g)

def compose(name, tag, tint, lines, sub, i):
    img = Image.open(f"{D}/raw/{name}.png").convert("RGB").resize((3840, 2160), Image.LANCZOS)
    img = shade(img)
    d = ImageDraw.Draw(img)
    x, y = 220, 1180
    tf = f(54, 2)
    tw = d.textlength(tag, font=tf)
    d.rounded_rectangle([x, y, x + tw + 72, y + 96], radius=48, fill=tint)
    d.text((x + 36, y + 14), tag, font=tf, fill=(10, 10, 10))
    hf = f(200, 4)
    yy = y + 150
    for j, ln in enumerate(lines):
        d.text((x, yy), ln, font=hf, fill=tint if j == 1 else (255, 255, 255))
        yy += 215
    d.text((x + 4, yy + 30), sub, font=f(64, 0), fill=(215, 220, 228))
    # subtle checker accent, top-left
    for k in range(14):
        for r in range(2):
            if (k + r) % 2 == 0:
                d.rectangle([220 + k * 22, 200 + r * 22, 242 + k * 22, 222 + r * 22], fill=tint)
    d.text((220, 262), "DRONE ARENA", font=f(46, 2), fill=(255, 255, 255))
    img.save(f"{D}/final/{i:02d}_{name}.png", optimize=True)

for i, s in enumerate(SHOTS, 1): compose(*s, i)
print("done")
