// Clay + ink maquette of the living room from the capture footage.
// Calibrated against the fixed simulator camera: pinhole at (0, 1.473, 0)
// looking down -Z, vertical FOV 56 deg (f = 1015 px at 1920x1080). Every
// object below was back-projected from its pixel extents in the footage, so
// a camera at ROOM_POSE renders the maquette on top of the real room.
import { THREE } from "./scene3d.js";

export const FOV = 56;
export const EYE = new THREE.Vector3(0, 1.473, 0);
export const ROOM = { x0: -2.07, x1: 2.08, h: 2.6, back: -5.58, front: 0.6 };

/** Footage pixel (1920x1080 space) at distance z in front of the eye -> world point. */
export function px(x, y, z) {
  return new THREE.Vector3(((x - 960) / 1015) * z, EYE.y - ((y - 540) / 1015) * z, -z);
}

export function setRoomPose(camera) {
  camera.position.copy(EYE);
  camera.up.set(0, 1, 0);
  camera.lookAt(EYE.x, EYE.y, -10);
  camera.fov = FOV;
  camera.updateProjectionMatrix();
}

export const clay = (color, extra = {}) =>
  new THREE.MeshStandardMaterial({ color, roughness: 0.92, metalness: 0, ...extra });
const INK_MAT = new THREE.MeshBasicMaterial({ color: "#0C0C0E" });

/** Box from min/max corners, optional ink edge beams. */
export function block(group, [x0, y0, z0], [x1, y1, z1], mat, ink = 0.012) {
  const w = x1 - x0, h = y1 - y0, d = z1 - z0;
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
  m.position.set((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2);
  m.castShadow = true;
  m.receiveShadow = true;
  group.add(m);
  if (ink > 0) m.add(inkEdges(w, h, d, ink));
  return m;
}

/** Twelve thin ink beams on a box's edges (WebGL lines are 1px, beams scale). */
export function inkEdges(w, h, d, t = 0.012, mat = INK_MAT) {
  const g = new THREE.Group();
  const add = (sx, sy, sz, x, y, z) => {
    const b = new THREE.Mesh(new THREE.BoxGeometry(sx, sy, sz), mat);
    b.position.set(x, y, z);
    g.add(b);
  };
  for (const sy of [-1, 1]) for (const sz of [-1, 1]) add(w + t, t, t, 0, (sy * h) / 2, (sz * d) / 2);
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) add(t, h + t, t, (sx * w) / 2, 0, (sz * d) / 2);
  for (const sx of [-1, 1]) for (const sy of [-1, 1]) add(t, t, d + t, (sx * w) / 2, (sy * h) / 2, 0);
  return g;
}

function plane(group, w, h, mat, pos, rotY = 0, rotX = 0) {
  const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), mat);
  m.position.copy(pos);
  m.rotation.set(rotX, rotY, 0, "YXZ");
  m.receiveShadow = true;
  group.add(m);
  return m;
}

function lamp(group, x, z, h, shadeR, shadeH, mat) {
  block(group, [x - 0.12, 0, z - 0.12], [x + 0.12, 0.03, z + 0.12], mat.ink, 0);
  block(group, [x - 0.012, 0, z - 0.012], [x + 0.012, h, z + 0.012], mat.ink, 0);
  const shade = new THREE.Mesh(new THREE.CylinderGeometry(shadeR * 0.82, shadeR, shadeH, 20, 1, true), mat.shade);
  shade.position.set(x, h + shadeH / 2 - 0.05, z);
  shade.castShadow = true;
  group.add(shade);
}

/** Builds the maquette. Returns handles the scenes animate. */
export function buildRoom(scene) {
  const R = ROOM;
  const mat = {
    wall: clay("#EFEBE3", { side: THREE.FrontSide }),
    wallL: clay("#F1E6D2", { side: THREE.FrontSide }),
    floor: clay("#D9C7A6"),
    ceil: clay("#F4F2EE", { side: THREE.FrontSide }),
    wood: clay("#CDB48C"),
    sofa: clay("#E4E0D8"),
    teal: clay("#2E7D6B"),
    ink: clay("#1A1A1E", { roughness: 0.6 }),
    shade: clay("#F6F1E6", { side: THREE.DoubleSide, emissive: "#FFF6DF", emissiveIntensity: 0.25 }),
    art: clay("#E7B55A"),
    artNavy: clay("#3B3F66"),
  };
  const room = new THREE.Group();
  scene.add(room);
  const W = R.x1 - R.x0, D = R.front - R.back, cx = (R.x0 + R.x1) / 2, cz = (R.front + R.back) / 2;

  const floor = plane(room, W, D, mat.floor, new THREE.Vector3(cx, 0, cz), 0, -Math.PI / 2);
  plane(room, W, R.h, mat.wall, new THREE.Vector3(cx, R.h / 2, R.back));
  plane(room, D, R.h, mat.wallL, new THREE.Vector3(R.x0, R.h / 2, cz), Math.PI / 2);
  plane(room, D, R.h, mat.wall, new THREE.Vector3(R.x1, R.h / 2, cz), -Math.PI / 2);
  const ceiling = plane(room, W, D, mat.ceil, new THREE.Vector3(cx, R.h, cz), 0, Math.PI / 2);

  // Ink room seams: back corners, ceiling and floor lines.
  const seams = new THREE.Group();
  room.add(seams);
  const beam = (a, b, t = 0.016) => {
    const len = a.distanceTo(b);
    const m = new THREE.Mesh(new THREE.BoxGeometry(t, t, len), INK_MAT);
    m.position.copy(a).add(b).multiplyScalar(0.5);
    m.lookAt(b);
    seams.add(m);
  };
  const v = (x, y, z) => new THREE.Vector3(x, y, z);
  for (const x of [R.x0, R.x1]) {
    beam(v(x, 0, R.back), v(x, R.h, R.back));
    beam(v(x, 0, R.back), v(x, 0, R.front));
    beam(v(x, R.h, R.back), v(x, R.h, R.front));
  }
  beam(v(R.x0, 0, R.back), v(R.x1, 0, R.back));
  beam(v(R.x0, R.h, R.back), v(R.x1, R.h, R.back));

  const props = new THREE.Group();
  room.add(props);
  // Back wall: TV stand, TV, framed mountain print, floor lamps.
  block(props, [-0.91, 0, -5.55], [1.0, 0.42, -5.1], mat.wood);
  block(props, [-0.66, 0.45, -5.44], [0.71, 1.19, -5.38], mat.ink);
  block(props, [-0.06, 0.42, -5.44], [0.1, 0.45, -5.3], mat.ink, 0);
  block(props, [-0.51, 1.32, -5.58], [0.56, 1.98, -5.54], mat.wood);
  block(props, [-0.44, 1.38, -5.55], [0.49, 1.92, -5.52], mat.artNavy, 0);
  lamp(props, -1.93, -5.42, 1.3, 0.2, 0.3, mat);
  lamp(props, 1.77, -5.12, 1.3, 0.18, 0.28, mat);
  // Coffee table + plant.
  block(props, [-0.54, 0.36, -3.5], [0.58, 0.42, -2.97], mat.wood);
  block(props, [-0.5, 0, -3.46], [0.54, 0.06, -3.01], mat.wood);
  for (const [x, z] of [[-0.5, -3.46], [0.54, -3.46], [-0.5, -3.01], [0.54, -3.01]])
    block(props, [x - 0.02, 0, z - 0.02], [x + 0.02, 0.36, z + 0.02], mat.wood, 0);
  const pot = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.07, 0.14, 10), clay("#C87A4E"));
  pot.position.set(-0.12, 0.49, -3.3);
  pot.castShadow = true;
  props.add(pot);
  const leaf = new THREE.Mesh(new THREE.IcosahedronGeometry(0.13, 0), clay("#5E9A62", { flatShading: true }));
  leaf.position.set(-0.12, 0.64, -3.3);
  leaf.scale.set(1, 0.7, 1);
  leaf.castShadow = true;
  props.add(leaf);
  // Sofa seen from behind, console table behind it.
  block(props, [-0.78, 0, -1.87], [0.78, 0.8, -1.64], mat.sofa);
  block(props, [-0.78, 0, -2.6], [0.78, 0.44, -1.87], mat.sofa);
  block(props, [-0.62, 0.7, -1.56], [0.66, 0.76, -1.3], mat.wood);
  for (const x of [-0.6, 0.64]) block(props, [x - 0.02, 0, -1.54], [x + 0.02, 0.7, -1.32], mat.ink, 0);
  // Left sofa against the left wall, teal cushion, side table + lamp.
  block(props, [-1.62, 0, -3.4], [-1.38, 0.85, -2.6], mat.sofa);
  block(props, [-1.38, 0, -3.4], [-0.95, 0.45, -2.6], mat.sofa);
  block(props, [-1.38, 0, -3.42], [-0.92, 0.62, -3.22], mat.sofa);
  const cushion = block(props, [-1.36, 0.45, -2.95], [-1.2, 0.78, -2.65], mat.teal, 0);
  cushion.rotation.z = -0.25;
  block(props, [-1.47, 0.5, -2.4], [-0.9, 0.55, -2.04], mat.wood);
  for (const x of [-1.45, -0.92]) block(props, [x - 0.02, 0, -2.38], [x + 0.02, 0.5, -2.06], mat.ink, 0);
  lamp(props, -1.2, -2.15, 0.72, 0.17, 0.26, mat);
  // Right shelf: three boards on ink posts, a run of books.
  for (const y of [0.0, 0.6, 1.18, 1.82])
    block(props, [1.65, y, -3.47], [2.05, y + 0.04, -2.45], mat.wood);
  for (const z of [-3.44, -2.48]) block(props, [1.66, 0, z - 0.02], [1.7, 1.86, z + 0.02], mat.ink, 0);
  block(props, [1.7, 1.22, -3.4], [1.95, 1.45, -2.95], clay("#9C8A6C"), 0.008);
  // Left wall prints, right wall curtain.
  for (const [z0, z1] of [[-2.73, -2.2], [-3.51, -2.96], [-4.29, -3.73]]) {
    block(props, [-2.07, 1.27, z0], [-2.04, 1.97, z1], mat.wood, 0.01);
    block(props, [-2.05, 1.33, z0 + 0.06], [-2.03, 1.91, z1 - 0.06], mat.art, 0);
  }
  block(props, [1.98, 0.3, -5.45], [2.06, 2.45, -4.06], clay("#F7F4EE", { transparent: true, opacity: 0.85 }), 0);

  // Lights: soft sky + sun through the window on the right.
  const hemi = new THREE.HemisphereLight("#FFFDF7", "#C9BCA4", 1.7);
  scene.add(hemi);
  const sun = new THREE.DirectionalLight("#FFF3DC", 2.1);
  sun.position.set(4.5, 6, -3.2);
  sun.target.position.set(0, 0, -2.6);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  Object.assign(sun.shadow.camera, { left: -5, right: 5, top: 5, bottom: -5, near: 0.5, far: 20 });
  sun.shadow.bias = -0.0006;
  sun.shadow.radius = 4;
  scene.add(sun, sun.target);

  return { room, floor, ceiling, props, seams, mat };
}
