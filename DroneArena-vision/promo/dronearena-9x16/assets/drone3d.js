// Drone Arena promo: low-poly props in the icon's style (navy body, cyan lens,
// cyan + orange rotors) shared by every 3D scene. All motion is driven by the
// scene's draw(t); nothing here keeps clocks.
import { THREE } from "./scene3d.js";

export const VOID = new THREE.Color("#0D0820");
export const CYAN = new THREE.Color("#38E6F5");
export const HEAT = new THREE.Color("#FF8A1F");
export const GATE = new THREE.Color("#4CF07A");

const flat = (color, extra = {}) =>
  new THREE.MeshStandardMaterial({ color, flatShading: true, roughness: 0.55, metalness: 0.1, ...extra });
const glow = (color, opacity = 1) =>
  new THREE.MeshBasicMaterial({ color, transparent: opacity < 1, opacity, depthWrite: opacity >= 1 });

/** Hemisphere + key + cyan rim, enough for flat-shaded low poly. */
export function addLights(scene) {
  scene.add(new THREE.HemisphereLight(0xd8d0ff, 0x1a1030, 1.4));
  const key = new THREE.DirectionalLight(0xffffff, 2.2);
  key.position.set(3, 6, 4);
  scene.add(key);
  const rim = new THREE.DirectionalLight(CYAN, 1.6);
  rim.position.set(-4, 2, -5);
  scene.add(rim);
}

/** Quad drone ~1.0 unit across the rotors. Returns { root, rotors, lens }. */
export function makeDrone() {
  const root = new THREE.Group();
  root.rotation.order = "YXZ";
  const body = new THREE.Mesh(new THREE.IcosahedronGeometry(0.2, 0), flat("#1b1838"));
  body.scale.set(1.25, 0.7, 1.05);
  root.add(body);
  const canopy = new THREE.Mesh(new THREE.IcosahedronGeometry(0.13, 0), flat("#2c2858"));
  canopy.position.set(0, 0.1, -0.02);
  root.add(canopy);
  const lens = new THREE.Mesh(new THREE.SphereGeometry(0.055, 16, 12), glow(CYAN));
  lens.position.set(0, 0.0, -0.21);
  root.add(lens);
  const ring = new THREE.Mesh(new THREE.TorusGeometry(0.07, 0.012, 8, 24), glow("#ffffff"));
  ring.position.copy(lens.position);
  root.add(ring);
  const tail = new THREE.Mesh(new THREE.ConeGeometry(0.08, 0.12, 4), flat(HEAT));
  tail.rotation.x = Math.PI;
  tail.position.set(0, -0.15, 0.02);
  root.add(tail);
  const rotors = [];
  const arms = [
    [0.36, -0.3, CYAN],
    [-0.36, -0.3, CYAN],
    [0.36, 0.3, HEAT],
    [-0.36, 0.3, HEAT],
  ];
  for (const [x, z, c] of arms) {
    const arm = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.035, Math.hypot(x, z)), flat("#14122a"));
    arm.position.set(x / 2, 0.02, z / 2);
    arm.rotation.y = Math.atan2(x, z);
    root.add(arm);
    const hub = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.06, 8), flat("#14122a"));
    hub.position.set(x, 0.04, z);
    root.add(hub);
    const disc = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.2, 0.008, 32), glow(c, 0.45));
    disc.position.set(x, 0.08, z);
    root.add(disc);
    const blade = new THREE.Mesh(new THREE.BoxGeometry(0.36, 0.01, 0.035), glow("#ffffff", 0.9));
    blade.position.set(x, 0.085, z);
    root.add(blade);
    rotors.push(blade);
  }
  return { root, rotors, lens };
}

/** Rotor spin + hover bob, a pure function of t. */
export function animateDrone(d, t, bob = 0.03) {
  d.rotors.forEach((b, i) => (b.rotation.y = t * 38 * (i % 2 ? -1 : 1) + i));
  d.root.children[0].position.y = Math.sin(t * 7) * bob * 0.2;
}

/** Infinite-looking neon grid floor. */
export function makeGridFloor(size = 60, div = 60, color = CYAN, opacity = 0.55) {
  const g = new THREE.GridHelper(size, div, color, color);
  g.material.transparent = true;
  g.material.opacity = opacity;
  g.material.depthWrite = false;
  return g;
}

/** Square race gate like the in-game ones: dark posts, glowing inner frame. */
export function makeGate(size = 1.6, color = GATE) {
  const root = new THREE.Group();
  const dark = flat("#1d1d24");
  const t = 0.12;
  const half = size / 2;
  const bars = [
    [0, half, size + t, t],
    [0, -half, size + t, t],
    [half, 0, t, size + t],
    [-half, 0, t, size + t],
  ];
  for (const [x, y, w, h] of bars) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, 0.12), dark);
    m.position.set(x, y, 0);
    root.add(m);
  }
  const inner = new THREE.Group();
  const s = size - 0.16;
  for (const [x, y, w, h] of [
    [0, s / 2, s, 0.05],
    [0, -s / 2, s, 0.05],
    [s / 2, 0, 0.05, s],
    [-s / 2, 0, 0.05, s],
  ]) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, 0.14), glow(color));
    m.position.set(x, y, 0);
    inner.add(m);
  }
  root.add(inner);
  const post = new THREE.Mesh(new THREE.BoxGeometry(0.1, 3, 0.1), dark);
  post.position.set(0, -half - 1.5, 0);
  root.add(post);
  return { root, inner };
}

/** Wireframe box edges (rooms, furniture) in a line material. */
export function edges(w, h, d, color = CYAN, opacity = 0.7) {
  const geo = new THREE.EdgesGeometry(new THREE.BoxGeometry(w, h, d));
  return new THREE.LineSegments(geo, new THREE.LineBasicMaterial({ color, transparent: true, opacity }));
}

export function makeTree(rand) {
  const root = new THREE.Group();
  const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.09, 0.5, 6), flat("#6b4226"));
  trunk.position.y = 0.25;
  root.add(trunk);
  const pine = rand() < 0.5;
  const crown = pine
    ? new THREE.Mesh(new THREE.ConeGeometry(0.42, 1.2, 7), flat("#3f9a4a"))
    : new THREE.Mesh(new THREE.IcosahedronGeometry(0.5, 0), flat("#67c34e"));
  crown.position.y = pine ? 1.05 : 0.85;
  root.add(crown);
  root.scale.setScalar(0.8 + rand() * 0.7);
  return root;
}

/** Bumblebee critter: striped low-poly ball with wings. */
export function makeBee() {
  const root = new THREE.Group();
  const body = new THREE.Mesh(new THREE.IcosahedronGeometry(0.22, 1), flat("#ffc928"));
  root.add(body);
  for (const z of [-0.06, 0.08]) {
    const s = new THREE.Mesh(new THREE.TorusGeometry(0.2, 0.035, 6, 18), flat("#1b1626"));
    s.position.z = z;
    root.add(s);
  }
  const wingMat = glow("#ffffff", 0.7);
  for (const x of [-0.14, 0.14]) {
    const w = new THREE.Mesh(new THREE.SphereGeometry(0.11, 8, 6), wingMat);
    w.scale.set(1, 0.25, 0.6);
    w.position.set(x, 0.2, 0.02);
    root.add(w);
  }
  for (const x of [-0.07, 0.07]) {
    const e = new THREE.Mesh(new THREE.SphereGeometry(0.03, 8, 6), flat("#111111"));
    e.position.set(x, 0.05, -0.2);
    root.add(e);
  }
  return root;
}

export const CRATE_COLORS = ["#ff3d5a", "#3d8bff", "#3ddc6b"];

export function makeCrate(color) {
  const root = new THREE.Group();
  const box = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.3, 0.3), flat(color, { roughness: 0.4 }));
  root.add(box);
  const band = new THREE.Mesh(new THREE.BoxGeometry(0.31, 0.06, 0.31), flat("#f2ecdd"));
  root.add(band);
  return root;
}

/** Delivery pad: disc + additive light beam in the crate color. */
export function makePad(color) {
  const root = new THREE.Group();
  const disc = new THREE.Mesh(new THREE.CylinderGeometry(0.42, 0.42, 0.03, 32), glow(color));
  root.add(disc);
  const beam = new THREE.Mesh(
    new THREE.CylinderGeometry(0.36, 0.4, 2.2, 32, 1, true),
    new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.18, side: THREE.DoubleSide, depthWrite: false, blending: THREE.AdditiveBlending }),
  );
  beam.position.y = 1.1;
  root.add(beam);
  return { root, beam };
}

/** Seeded burst of confetti shards; call update(k) with burst progress 0..1. */
export function makeBurst(rand, colors, n = 40) {
  const root = new THREE.Group();
  const parts = [];
  for (let i = 0; i < n; i++) {
    const m = new THREE.Mesh(new THREE.TetrahedronGeometry(0.035 + rand() * 0.03), glow(colors[i % colors.length]));
    const dir = new THREE.Vector3(rand() * 2 - 1, rand() * 1.4 - 0.2, rand() * 2 - 1).normalize();
    parts.push({ m, dir, speed: 0.8 + rand() * 1.2, spin: rand() * 10 });
    root.add(m);
  }
  root.visible = false;
  return {
    root,
    update(k) {
      root.visible = k > 0 && k < 1;
      for (const p of parts) {
        const r = p.speed * (1 - Math.pow(1 - k, 3));
        p.m.position.copy(p.dir).multiplyScalar(r);
        p.m.position.y -= k * k * 0.6;
        p.m.rotation.set(p.spin * k, p.spin * k * 0.7, 0);
        p.m.scale.setScalar(1 - k * 0.8);
      }
    },
  };
}
