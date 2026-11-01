#!/usr/bin/env python3
"""Writes compositions/<id>.html for each 3D scene from a shared shell.

Scene bodies live in tools/scenes/<id>.js: module code that receives
E (scene3d.js), D (drone3d.js), THREE, renderer, scene, camera, aspect,
and must define `function draw(t)` plus optionally `await ready`.
Run after editing a scene body or the table below.
"""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCENES = [
    # id, duration, kicker, title words (last word glows), title exit time
    ("room", 2.8, "DRONE ARENA / FREE FLIGHT", ["Your", "room", "is", "the", "runway."], 2.2),
    ("race", 2.23, "RACE LEAGUE / SEASON 1", ["Race", "the", "league."], 1.75),
    ("safari", 2.23, "SAFARI / CRITTER HUNT", ["Pop", "the", "critters."], 1.75),
    ("freight", 2.23, "FOLD FREIGHT / SORTATION", ["Sort", "the", "freight."], 1.75),
]

SHELL = """<!doctype html>
<html>
  <head>
    <meta charset="UTF-8" />
  </head>
  <body>
    <template>
      <style>
        #{id}-root {{ position: absolute; inset: 0; overflow: hidden; background: #0d0820; container-type: size; }}
        #{id}-canvas {{ position: absolute; inset: 0; width: 100%; height: 100%; display: block; z-index: 0; }}
        #{id}-scrim {{ position: absolute; inset: 0; z-index: 1;
          background: linear-gradient(to bottom, rgba(13, 8, 32, 0.72) 0%, rgba(13, 8, 32, 0) 32%); }}
        #{id}-copy {{ z-index: 2; position: absolute; left: 0; right: 0; top: 7cqh; display: flex;
          flex-direction: column; align-items: center; gap: 1.6cqmin; padding: 0 6cqw; text-align: center; }}
        .{id}-kicker {{ font-family: "JetBrains Mono", monospace; font-weight: 700; font-size: calc(1.1cqw + 1cqh);
          letter-spacing: 0.24em; color: #38e6f5; }}
        .{id}-title {{ font-family: "Archivo Black", sans-serif; font-size: calc(4.4cqw + 3.2cqh); line-height: 1;
          letter-spacing: -0.035em; color: #f2ecdd; text-transform: uppercase; display: flex; flex-wrap: wrap;
          justify-content: center; column-gap: 0.26em; max-width: 92cqw; }}
        .{id}-w {{ display: block; overflow: hidden; padding-bottom: 0.06em; }}
        .{id}-w > span {{ display: block; }}
        .{id}-glow {{ color: #ff8a1f; text-shadow: 0 0 0.35em rgba(255, 138, 31, 0.55); }}
      </style>

      <div id="{id}-root" data-composition-id="{id}" data-width="1920" data-height="1080">
        <canvas id="{id}-canvas" data-ee-canvas="{id}" data-layout-bleed></canvas>
        <div id="{id}-scrim"></div>
        <div id="{id}-copy">
          <div class="{id}-kicker" id="{id}-kicker">{kicker}</div>
          <div class="{id}-title" data-layout-allow-occlusion>
{words}
          </div>
        </div>
      </div>

      <script>
        (function () {{
          const ID = "{id}";
          const DUR = {dur};
          window.__eeTime = window.__eeTime || {{}};
          window.__eeResolve = window.__eeResolve || {{}};
          window.__hf = window.__hf || {{}};
          window.__hf.buildReady = window.__hf.buildReady || {{}};
          window.__hf.buildReady[ID] = new Promise((r) => (window.__eeResolve[ID] = r));
          const st = {{ t: 0 }};
          const tl = gsap.timeline({{ paused: true }});
          tl.to(st, {{ t: DUR, duration: DUR, ease: "none", onUpdate() {{
            window.__eeTime[ID] = st.t;
            const f = window.__eeScenes && window.__eeScenes[ID];
            if (f) f(st.t);
          }} }}, 0);
          tl.fromTo("#{id}-kicker", {{ opacity: 0, y: 12 }}, {{ opacity: 1, y: 0, duration: 0.45, ease: "expo.out" }}, 0.08);
          tl.fromTo(".{id}-w > span", {{ yPercent: 110 }}, {{ yPercent: 0, duration: 0.45, ease: "expo.out", stagger: 0.06 }}, 0.15);
          tl.to(".{id}-w > span", {{ yPercent: -110, duration: 0.28, ease: "power3.in", stagger: 0.035 }}, {exit});
          tl.to("#{id}-kicker", {{ opacity: 0, duration: 0.22 }}, {exit});
          window.__timelines[ID] = tl;
        }})();
      </script>
      <script type="module">
        import * as E from "./assets/scene3d.js";
        import * as D from "./assets/drone3d.js";
        const {{ THREE }} = E;
        const {{ canvas, root }} = await E.findStage("{id}");
        const {{ renderer, aspect }} = E.makeRenderer(canvas, root);
        const scene = new THREE.Scene();
        scene.fog = new THREE.Fog(D.VOID, 9, 26);
        const camera = new THREE.PerspectiveCamera(E.fovFor(aspect, 40, 52), aspect, 0.05, 200);
        D.addLights(scene);
{body}
        E.registerScene("{id}", draw);
      </script>
    </template>
  </body>
</html>
"""


def words_html(sid, words):
    out = []
    for i, w in enumerate(words):
        cls = f' class="{sid}-glow"' if i == len(words) - 1 else ""
        out.append(f'            <span class="{sid}-w" data-layout-allow-overflow><span{cls}>{w}</span></span>')
    return "\n".join(out)


for sid, dur, kicker, words, exit_t in SCENES:
    body = (ROOT / "tools" / "scenes" / f"{sid}.js").read_text()
    body = "\n".join(("        " + ln) if ln.strip() else "" for ln in body.splitlines())
    html = SHELL.format(id=sid, dur=dur, kicker=kicker, words=words_html(sid, words), exit=exit_t, body=body)
    (ROOT / "compositions" / f"{sid}.html").write_text(html)
    print("wrote", sid, len(html.splitlines()), "lines")
