// Shared rig for the mode scenes: renderer, maquette, drone, the camera
// excursion that leaves and returns to the footage pose, and the wipe handoff.
import * as E from "./scene3d.js";
import * as R from "./room.js";
import * as P from "./props.js";
const { THREE } = E;

export async function setup(id) {
  const { canvas, root } = await E.findStage(id);
  const { renderer, aspect } = E.makeRenderer(canvas, root);
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(R.FOV, aspect, 0.05, 100);
  const room = R.buildRoom(scene);
  const drone = P.makeDrone();
  scene.add(drone.root);
  return { renderer, scene, camera, room, drone };
}

const look = new THREE.Vector3();
/** Room pose at t<=a and t>=b; in between an eased arc out by `off`, looking at `focus`. */
export function cameraArc(camera, t, a, b, off, focus) {
  const k = Math.sin(Math.PI * E.easeInOut(E.seg(t, a, b)));
  camera.position.copy(R.EYE).addScaledVector(off, k);
  look.set(0, R.EYE.y, -10).lerp(focus, k * 0.85);
  camera.lookAt(look);
  camera.fov = R.FOV + 6 * k;
  camera.updateProjectionMatrix();
}

/** Drone along a curve with banking toward travel direction. */
const ahead = new THREE.Vector3();
export function flyDrone(drone, curve, k, t, scale = 1) {
  curve.getPointAt(k, drone.root.position);
  curve.getPointAt(Math.min(1, k + 0.015), ahead);
  if (k >= 1) curve.getPointAt(0.985, ahead).sub(drone.root.position).negate().add(drone.root.position);
  const dx = ahead.x - drone.root.position.x, dz = ahead.z - drone.root.position.z;
  const yaw = Math.atan2(-dx, -dz);
  drone.root.rotation.set(-0.25, yaw, E.clamp01(Math.abs(dx) * 8) * Math.sign(dx) * -0.3);
  drone.root.scale.setScalar(scale);
  P.animateDrone(drone, t);
}

/** Furniture sinks through the floor (k=1 gone) or rises back. */
export function sinkProps(room, k) {
  room.props.position.y = -2.4 * E.easeIn(k);
  room.props.visible = k < 0.999;
}
