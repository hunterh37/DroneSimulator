// Props for the maquette scenes, modeled after the in-game meshes seen in the
// footage (faceted ink drone, square race gates, peg crowd, low-poly forest,
// cargo crates on pads). Motion is driven by each scene's draw(t).
import { THREE } from "./scene3d.js";
import { clay, block, inkEdges } from "./room.js";

const flat = (c, extra = {}) => clay(c, { flatShading: true, ...extra });
const basic = (c, opacity = 1, extra = {}) =>
  new THREE.MeshBasicMaterial({ color: c, transparent: opacity < 1, opacity, depthWrite: opacity >= 1, ...extra });

/** Quad drone like the in-game one, ~1.0 across the rotor tips. */
export function makeDrone() {
  const root = new THREE.Group();
  root.rotation.order = "YXZ";
  const body = new THREE.Mesh(new THREE.IcosahedronGeometry(0.15, 0), flat("#2A2A30", { roughness: 0.5 }));
  body.scale.set(1.1, 0.85, 1.1);
  body.castShadow = true;
  root.add(body);
  const eye = new THREE.Mesh(new THREE.SphereGeometry(0.035, 12, 8), basic("#D4FF3A"));
  eye.position.set(0, -0.01, -0.15);
  root.add(eye);
  const rotors = [];
  for (const [x, z] of [[0.33, -0.33], [-0.33, -0.33], [0.33, 0.33], [-0.33, 0.33]]) {
    const len = Math.hypot(x, z);
    const arm = new THREE.Mesh(new THREE.BoxGeometry(0.035, 0.03, len), flat("#4A4A52"));
    arm.position.set(x / 2, 0, z / 2);
    arm.rotation.y = Math.atan2(x, z);
    arm.castShadow = true;
    root.add(arm);
    const motor = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.04, 0.09, 8), flat("#8E8E96"));
    motor.position.set(x, 0.02, z);
    root.add(motor);
    const tip = new THREE.Mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.03, 8), basic("#FF5A36"));
    tip.position.set(x, 0.075, z);
    root.add(tip);
    const disc = new THREE.Mesh(new THREE.CylinderGeometry(0.17, 0.17, 0.004, 32), basic("#BFC2C8", 0.35));
    disc.position.set(x, 0.07, z);
    root.add(disc);
    const blade = new THREE.Mesh(new THREE.BoxGeometry(0.32, 0.006, 0.03), basic("#1A1A1E", 0.85));
    blade.position.set(x, 0.072, z);
    root.add(blade);
    rotors.push(blade);
  }
  for (const s of [-1, 1]) {
    const leg = new THREE.Mesh(new THREE.BoxGeometry(0.02, 0.02, 0.26), flat("#1A1A1E"));
    leg.position.set(s * 0.09, -0.14, 0);
    root.add(leg);
  }
  return { root, rotors, body };
}

export function animateDrone(d, t) {
  d.rotors.forEach((b, i) => (b.rotation.y = t * 41 * (i % 2 ? -1 : 1) + i));
  d.body.position.y = Math.sin(t * 9) * 0.006;
}

/** Acid flight ribbon along a curve; reveal(k) draws the first k of it. */
export function makeTrail(curve, radius = 0.014, color = "#D4FF3A") {
  const SEG = 240, RAD = 6;
  const geo = new THREE.TubeGeometry(curve, SEG, radius, RAD, false);
  const mesh = new THREE.Mesh(geo, basic(color));
  return {
    mesh,
    reveal(a, b = 0) {
      const s = Math.floor(b * SEG), e = Math.floor(a * SEG);
      mesh.visible = e > s;
      geo.setDrawRange(s * RAD * 6, Math.max(0, e - s) * RAD * 6);
    },
  };
}

/** Square race gate: ink frame, acid inner rim, two legs to the floor. */
export function makeGate(inner = 1.09, legY = 1.36) {
  const root = new THREE.Group();
  const ink = flat("#1A1A1E");
  const b = 0.12, o = inner / 2 + b;
  block(root, [-o, inner / 2, -0.05], [o, o, 0.05], ink, 0);
  block(root, [-o, -o, -0.05], [o, -inner / 2, 0.05], ink, 0);
  block(root, [-o, -inner / 2, -0.05], [-inner / 2, inner / 2, 0.05], ink, 0);
  block(root, [inner / 2, -inner / 2, -0.05], [o, inner / 2, 0.05], ink, 0);
  const rim = new THREE.Group();
  const r = inner / 2, t = 0.035, acid = basic("#D4FF3A");
  for (const [x, y, w, h] of [[0, r, inner, t], [0, -r, inner, t], [r, 0, t, inner], [-r, 0, t, inner]]) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, 0.11), acid);
    m.position.set(x, y, 0);
    rim.add(m);
  }
  root.add(rim);
  for (const s of [-1, 1]) block(root, [s * (o - 0.06) - 0.025, -legY - o, -0.025], [s * (o - 0.06) + 0.025, -o, 0.025], ink, 0);
  return { root, rim };
}

/** Stepped grandstand with a seeded peg crowd. Length along local X. */
export function makeStand(rand, len = 3, rows = 4) {
  const root = new THREE.Group();
  const step = clay("#2B2D36");
  const cols = ["#E84A3C", "#3A7BE0", "#F2C230", "#F5F3EE", "#3EC4C9"];
  const peg = new THREE.BoxGeometry(0.07, 0.13, 0.07);
  const mats = cols.map((c) => clay(c));
  for (let r = 0; r < rows; r++) {
    block(root, [-len / 2, 0, r * 0.22], [len / 2, 0.12 + r * 0.14, r * 0.22 + 0.22], step, 0.008);
    for (let x = -len / 2 + 0.08; x < len / 2 - 0.05; x += 0.11) {
      const m = new THREE.Mesh(peg, mats[Math.floor(rand() * mats.length)]);
      m.position.set(x, 0.12 + r * 0.14 + 0.065, r * 0.22 + 0.11);
      root.add(m);
    }
  }
  return root;
}

export function makeTree(rand) {
  const root = new THREE.Group();
  const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.06, 0.4, 6), flat("#7A4B2A"));
  trunk.position.y = 0.2;
  trunk.castShadow = true;
  root.add(trunk);
  const pine = rand() < 0.45;
  const crown = pine
    ? new THREE.Mesh(new THREE.ConeGeometry(0.3, 0.9, 7), flat("#4FA25A"))
    : new THREE.Mesh(new THREE.IcosahedronGeometry(0.36, 0), flat("#7CCB5B"));
  crown.position.y = pine ? 0.8 : 0.68;
  crown.castShadow = true;
  root.add(crown);
  return root;
}

export function makeBee() {
  const root = new THREE.Group();
  root.add(new THREE.Mesh(new THREE.IcosahedronGeometry(0.11, 1), flat("#FFC928")));
  for (const z of [-0.03, 0.04]) {
    const s = new THREE.Mesh(new THREE.TorusGeometry(0.1, 0.018, 6, 16), flat("#1A1A1E"));
    s.position.z = z;
    root.add(s);
  }
  for (const x of [-0.07, 0.07]) {
    const w = new THREE.Mesh(new THREE.SphereGeometry(0.055, 8, 6), basic("#FFFFFF", 0.75));
    w.scale.set(1, 0.25, 0.6);
    w.position.set(x, 0.1, 0);
    root.add(w);
  }
  return root;
}

export const CARGO = ["#FF5A36", "#3A7BE0", "#4CD964"];

export function makeCrate(color, s = 0.22) {
  const root = new THREE.Group();
  const box = new THREE.Mesh(new THREE.BoxGeometry(s, s, s), clay(color, { roughness: 0.6 }));
  box.castShadow = true;
  root.add(box);
  root.add(inkEdges(s, s, s, 0.008));
  return root;
}

export function makePad(color) {
  const root = new THREE.Group();
  const ring = new THREE.Mesh(new THREE.TorusGeometry(0.3, 0.025, 8, 40), basic(color));
  ring.rotation.x = Math.PI / 2;
  root.add(ring);
  const disc = new THREE.Mesh(new THREE.CircleGeometry(0.3, 40), basic(color, 0.35));
  disc.rotation.x = -Math.PI / 2;
  disc.position.y = 0.005;
  root.add(disc);
  const beam = new THREE.Mesh(
    new THREE.CylinderGeometry(0.22, 0.3, 1.1, 32, 1, true),
    basic(color, 0.07, { side: THREE.DoubleSide, blending: THREE.AdditiveBlending }),
  );
  beam.position.y = 0.55;
  root.add(beam);
  return { root, beam };
}
