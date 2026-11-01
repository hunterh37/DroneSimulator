// Fold Freight: crates rain onto the grid, the drone hooks one and drops it on
// its matching pad, which pulses and stacks.
const rand = E.rng(5);
scene.add(D.makeGridFloor(30, 30, D.CYAN, 0.45));
const pads = D.CRATE_COLORS.map((c, i) => {
  const p = D.makePad(c);
  p.root.position.set(-1.6 + i * 1.6, 0.02, -2.6);
  scene.add(p.root);
  return p;
});
const crates = [];
for (let i = 0; i < 9; i++) {
  const ci = i % 3;
  const c = D.makeCrate(D.CRATE_COLORS[ci]);
  const x = rand() * 3.4 - 1.7;
  const z = rand() * 1.6 - 0.2;
  c.userData = { x, z, drop: 0.05 + i * 0.07, rot: rand() * 3, ci };
  scene.add(c);
  crates.push(c);
}
const hero = D.makeCrate(D.CRATE_COLORS[1]);
scene.add(hero);
const drone = D.makeDrone();
scene.add(drone.root);
const cable = new THREE.Mesh(new THREE.CylinderGeometry(0.01, 0.01, 1, 6), new THREE.MeshBasicMaterial({ color: "#f2ecdd" }));
scene.add(cable);
const burst = D.makeBurst(rand, ["#3d8bff", "#ffffff", "#38e6f5"]);
burst.root.position.set(0, 0.5, -2.6);
scene.add(burst.root);
const A = new THREE.Vector3(0.3, 1.25, 0.6);
const B = new THREE.Vector3(0, 1.35, -2.6);
function draw(t) {
  for (const c of crates) {
    const { x, z, drop, rot } = c.userData;
    const k = E.seg(t, drop, drop + 0.42);
    const bounce = k < 1 ? 0 : Math.max(0, Math.sin((t - drop - 0.42) * 14) * 0.05 * Math.exp(-(t - drop - 0.42) * 6));
    c.position.set(x, E.lerp(4, 0.15, E.easeIn(k)) + bounce, z);
    c.rotation.set(0, rot + (1 - k) * 2, 0);
  }
  const fly = E.easeInOut(E.seg(t, 0.75, 1.65));
  drone.root.position.lerpVectors(A, B, fly);
  drone.root.position.y += Math.sin(fly * Math.PI) * 0.35;
  drone.root.rotation.set(E.lerp(0, -0.25, Math.sin(fly * Math.PI)), 0.2, 0);
  D.animateDrone(drone, t);
  const reach = E.lerp(0.75, 0.32, E.easeOut(E.seg(t, 0.45, 0.75)));
  const released = t > 1.7;
  const fall = E.easeIn(E.seg(t, 1.7, 1.95));
  if (!released) hero.position.set(drone.root.position.x, drone.root.position.y - reach - 0.15, drone.root.position.z);
  else hero.position.set(B.x, E.lerp(B.y - 0.47, 0.17, fall), B.z);
  hero.rotation.y = 0.2;
  cable.visible = !released;
  cable.scale.y = reach;
  cable.position.set(drone.root.position.x, drone.root.position.y - reach / 2, drone.root.position.z);
  pads.forEach((p, i) => (p.beam.material.opacity = 0.16 + (i === 1 ? E.seg(t, 1.9, 2.0) * 0.5 * (1 - E.seg(t, 2.0, 2.23)) : 0)));
  burst.update(E.seg(t, 1.93, 2.23));
  camera.position.set(E.lerp(2.2, 1.2, E.easeInOut(E.seg(t, 0, 2.23))), 2.6, E.lerp(4.4, 3.2, E.easeInOut(E.seg(t, 0, 2.23))));
  camera.lookAt(0, 0.7, -1.2);
  renderer.render(scene, camera);
}
