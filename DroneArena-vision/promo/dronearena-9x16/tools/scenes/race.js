// Gate slalom: chase camera rides behind the drone through a curving line of gates.
const floor = D.makeGridFloor(80, 80, D.CYAN, 0.4);
scene.add(floor);
const rand = E.rng(7);
const track = new THREE.CatmullRomCurve3(
  Array.from({ length: 9 }, (_, i) => new THREE.Vector3(Math.sin(i * 0.9) * 2.6, 1.6 + Math.sin(i * 1.7) * 0.35, -i * 4.2)),
);
const gates = [];
for (let i = 1; i < 8; i++) {
  const u = i / 8;
  const g = D.makeGate(1.6, i % 3 === 0 ? D.HEAT : D.GATE);
  track.getPointAt(u, g.root.position);
  const tan = track.getTangentAt(u);
  g.root.rotation.y = Math.atan2(tan.x, tan.z);
  g.inner.children.forEach((m) => (m.userData.c = m.material.color.clone()));
  scene.add(g.root);
  gates.push({ g, u });
}
// Grandstands: rows of tiny colored fans on both sides.
const fanGeo = new THREE.BoxGeometry(0.16, 0.26, 0.16);
const fanCols = ["#ff3d5a", "#3d8bff", "#ffd23d", "#3ddc6b", "#ffffff"];
for (const side of [-1, 1]) {
  for (let r = 0; r < 4; r++) {
    for (let i = 0; i < 70; i++) {
      const m = new THREE.Mesh(fanGeo, new THREE.MeshBasicMaterial({ color: fanCols[Math.floor(rand() * 5)] }));
      m.position.set(side * (6.5 + r * 0.45), 0.15 + r * 0.32, 2 - i * 0.48);
      scene.add(m);
    }
  }
}
const WHITE = new THREE.Color("#ffffff");
const drone = D.makeDrone();
scene.add(drone.root);
const camPos = new THREE.Vector3();
const look = new THREE.Vector3();
function draw(t) {
  const u = 0.02 + E.easeIn(E.seg(t, 0, 0.6)) * 0.08 + E.seg(t, 0.6, 2.23) * 0.62;
  track.getPointAt(u, drone.root.position);
  const tan = track.getTangentAt(u);
  const yaw = Math.atan2(-tan.x, -tan.z);
  const bank = track.getTangentAt(Math.min(1, u + 0.03)).x - tan.x;
  drone.root.rotation.set(-0.28, yaw, Math.max(-0.25, Math.min(0.25, -bank * 4)));
  D.animateDrone(drone, t);
  const back = Math.max(0, u - 0.075);
  track.getPointAt(back, camPos);
  camPos.y += 0.75;
  camPos.x += Math.sin(t * 1.3) * 0.25;
  camera.position.copy(camPos);
  track.getPointAt(Math.min(1, u + 0.05), look);
  camera.lookAt(look);
  for (const { g, u: gu } of gates) {
    const passed = u > gu;
    g.inner.children.forEach((m) => m.material.color.copy(passed ? WHITE : m.userData.c));
    g.inner.scale.setScalar(passed ? 1 + Math.min(0.25, (u - gu) * 8) : 1);
  }
  renderer.render(scene, camera);
}
