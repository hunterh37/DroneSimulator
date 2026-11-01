// Wireframe living room on a neon grid; the drone carves a loop and lands on
// the framing of footage shot 1 (drone at 1220,790 r220 on 1920x1080).
const room = new THREE.Group();
scene.add(room);
const floor = D.makeGridFloor(8, 16, D.CYAN, 0.35);
room.add(floor);
const shell = D.edges(7, 3, 9, D.CYAN, 0.55);
shell.position.set(0, 1.5, -1.5);
room.add(shell);
const furniture = [
  [2.4, 0.5, 0.9, 0, 0.25, 1.0, D.HEAT],
  [1.6, 0.45, 0.8, 0, 0.22, -0.4, D.HEAT],
  [1.5, 0.9, 0.08, 0, 1.0, -5.9, D.CYAN],
  [1.8, 0.4, 0.5, 0, 0.2, -5.6, D.CYAN],
  [0.5, 2.2, 1.6, 3.2, 1.1, -3.0, D.CYAN],
  [0.7, 0.6, 0.7, -2.9, 0.3, 0.2, D.HEAT],
];
for (const [w, h, d, x, y, z, c] of furniture) {
  const e = D.edges(w, h, d, c, 0.8);
  e.position.set(x, y, z);
  room.add(e);
}
const drone = D.makeDrone();
drone.root.scale.setScalar(1.9);
scene.add(drone.root);
const path = new THREE.CatmullRomCurve3([
  new THREE.Vector3(-2.6, 2.3, -5.2),
  new THREE.Vector3(-0.8, 2.0, -3.6),
  new THREE.Vector3(1.9, 1.7, -2.6),
  new THREE.Vector3(1.6, 1.25, -0.9),
  new THREE.Vector3(0.598, 0.926, 0.19),
]);
const C_END = new THREE.Vector3(0, 1.5, 3.6);
const C_START = new THREE.Vector3(-1.6, 3.4, 7.5);
const LAND = 2.3;
const tmp = new THREE.Vector3();
function draw(t) {
  const p = E.easeInOut(E.seg(t, 0, LAND));
  camera.position.lerpVectors(C_START, C_END, p);
  const look = tmp.set(E.lerp(-0.6, 0, p), E.lerp(1.0, 1.5, p), E.lerp(-2.5, 2.6, p));
  camera.lookAt(look);
  const k = E.easeOut(E.seg(t, 0, LAND));
  path.getPointAt(k, drone.root.position);
  const ahead = path.getPointAt(Math.min(1, k + 0.02));
  const yawTravel = Math.atan2(-(ahead.x - drone.root.position.x), -(ahead.z - drone.root.position.z));
  const face = E.seg(t, 1.6, LAND);
  drone.root.rotation.set(E.lerp(-0.35, -0.12, face), E.lerp(yawTravel, 2.6, E.easeInOut(face)), E.lerp(0.25, 0, face));
  D.animateDrone(drone, t);
  shell.material.opacity = 0.55 * (1 - 0.6 * E.seg(t, 1.8, LAND));
  floor.material.opacity = 0.35 * (1 - 0.5 * E.seg(t, 1.8, LAND));
  renderer.render(scene, camera);
}
