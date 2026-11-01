// Low-poly meadow: the drone sweeps through bumblebees that pop into confetti.
const rand = E.rng(21);
const ground = new THREE.Mesh(new THREE.CircleGeometry(14, 48), new THREE.MeshStandardMaterial({ color: "#7fd35a", flatShading: true, roughness: 0.9 }));
ground.rotation.x = -Math.PI / 2;
scene.add(ground);
const ring = D.makeGridFloor(40, 40, D.CYAN, 0.25);
ring.position.y = -0.02;
scene.add(ring);
for (let i = 0; i < 46; i++) {
  const tr = D.makeTree(rand);
  const a = rand() * Math.PI * 2;
  const r = 3 + rand() * 9;
  tr.position.set(Math.cos(a) * r, 0, Math.sin(a) * r - 3);
  if (Math.abs(tr.position.x) < 1.2 && tr.position.z > -6) tr.position.x += 2.6;
  scene.add(tr);
}
for (let i = 0; i < 60; i++) {
  const f = new THREE.Mesh(new THREE.IcosahedronGeometry(0.06, 0), new THREE.MeshBasicMaterial({ color: ["#ff6fb5", "#c45bff", "#ffffff", "#ff8a1f"][i % 4] }));
  f.position.set(rand() * 12 - 6, 0.12, rand() * -12 + 3);
  scene.add(f);
}
const bees = [];
const beeSpots = [
  [-0.9, 1.1, -1.5, 0.75],
  [0.8, 1.35, -3.6, 1.15],
  [-0.4, 1.0, -5.8, 1.6],
  [1.6, 1.6, -2.4, 9],
  [-2.2, 1.4, -4.4, 9],
];
for (const [x, y, z, popAt] of beeSpots) {
  const b = D.makeBee();
  b.position.set(x, y, z);
  scene.add(b);
  const burst = D.makeBurst(rand, ["#ffc928", "#ffffff", "#ff8a1f", "#38e6f5"]);
  burst.root.position.set(x, y, z);
  scene.add(burst.root);
  bees.push({ b, burst, x, y, z, popAt, ph: rand() * 6 });
}
const drone = D.makeDrone();
scene.add(drone.root);
const path = new THREE.CatmullRomCurve3([
  new THREE.Vector3(0, 1.4, 1.5),
  new THREE.Vector3(-0.9, 1.1, -1.5),
  new THREE.Vector3(0.8, 1.35, -3.6),
  new THREE.Vector3(-0.4, 1.0, -5.8),
  new THREE.Vector3(0.6, 1.5, -8),
]);
const tmp = new THREE.Vector3();
function draw(t) {
  const u = E.seg(t, 0.1, 2.0) * 0.85;
  path.getPointAt(u, drone.root.position);
  const tan = path.getTangentAt(Math.max(0.001, u));
  drone.root.rotation.set(-0.3, Math.atan2(-tan.x, -tan.z), -tan.x * 0.6);
  D.animateDrone(drone, t);
  camera.position.set(drone.root.position.x * 0.5 + 0.9, drone.root.position.y + 0.9, drone.root.position.z + 3.1);
  camera.lookAt(tmp.copy(drone.root.position).add(new THREE.Vector3(0, -0.1, -1.2)));
  for (const s of bees) {
    const k = E.seg(t, s.popAt, s.popAt + 0.6);
    s.b.visible = t < s.popAt;
    s.b.position.set(s.x + Math.sin(t * 2 + s.ph) * 0.15, s.y + Math.abs(Math.sin(t * 6 + s.ph)) * 0.12, s.z);
    s.b.rotation.y = Math.sin(t * 3 + s.ph) * 0.6;
    s.b.scale.setScalar(t < s.popAt ? 1 + E.seg(t, s.popAt - 0.12, s.popAt) * 0.4 : 1);
    s.burst.update(k);
  }
  renderer.render(scene, camera);
}
