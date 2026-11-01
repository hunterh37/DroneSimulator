// Shared Three.js helpers for Earth Eyes Pro promo scenes.
import * as THREE from "https://cdn.jsdelivr.net/npm/three@0.181.2/+esm";
export { THREE };

export const SIGNAL = new THREE.Color("#38E6F5");
export const ICE = new THREE.Color("#CFFBFF");
export const VOID = new THREE.Color("#0D0820");
export const DEG = Math.PI / 180;

export const clamp01 = (x) => Math.min(1, Math.max(0, x));
export const lerp = (a, b, t) => a + (b - a) * t;
export const seg = (t, a, b) => clamp01((t - a) / (b - a));
export const easeInOut = (x) => (x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2);
export const easeOut = (x) => 1 - Math.pow(1 - x, 3);
export const easeIn = (x) => x * x * x;
export const expoOut = (x) => (x >= 1 ? 1 : 1 - Math.pow(2, -10 * x));
export const expoInOut = (x) =>
  x <= 0 ? 0 : x >= 1 ? 1 : x < 0.5 ? Math.pow(2, 20 * x - 10) / 2 : (2 - Math.pow(2, -20 * x + 10)) / 2;

// Seeded PRNG (mulberry32).
export function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Finds the scene canvas + its composition root once the template is mounted.
export function findStage(id) {
  return new Promise((res) => {
    const look = () => {
      const canvas = document.querySelector(`canvas[data-ee-canvas="${id}"]`);
      if (!canvas) return setTimeout(look, 16);
      const root = canvas.closest("[data-width]") || canvas.parentElement;
      res({ canvas, root });
    };
    look();
  });
}

// Renderer sized from the composition root's declared canvas.
export function makeRenderer(canvas, root) {
  const W = parseInt(root.dataset.width, 10) || 1920;
  const H = parseInt(root.dataset.height, 10) || 1080;
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false, preserveDrawingBuffer: true });
  renderer.setPixelRatio(1);
  renderer.setSize(W, H, false);
  renderer.setClearColor(VOID, 1);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  return { renderer, W, H, aspect: W / H };
}

// Vertical FOV that keeps a horizontal FOV of at least `minHFov` degrees (portrait safety).
export function fovFor(aspect, vFov, minHFov) {
  const h = 2 * Math.atan(Math.tan((vFov * DEG) / 2) * aspect) / DEG;
  if (h >= minHFov) return vFov;
  return (2 * Math.atan(Math.tan((minHFov * DEG) / 2) / aspect)) / DEG;
}

export function loadTex(url, opts = {}) {
  const tex = new THREE.TextureLoader().load(url);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 8;
  Object.assign(tex, opts);
  return tex;
}

export function texReady(tex) {
  return new Promise((res) => {
    if (tex.image && tex.image.complete) return res();
    const check = () => (tex.image && tex.image.complete ? res() : setTimeout(check, 30));
    check();
  });
}

// lat/lon (deg) to a point on a unit sphere using Three's SphereGeometry UV convention.
export function ll(lat, lon, r = 1) {
  const phi = ((lon + 180) / 360) * Math.PI * 2;
  const th = ((90 - lat) / 180) * Math.PI;
  return new THREE.Vector3(-Math.cos(phi) * Math.sin(th) * r, Math.cos(th) * r, Math.sin(phi) * Math.sin(th) * r);
}
// Earth rotation.y that puts longitude `lon` facing +Z (the camera).
export const faceLon = (lon) => -(lon + 90) * DEG;

const EARTH_VS = `
varying vec2 vUv; varying vec3 vN; varying vec3 vV; varying vec3 vWN;
void main(){
  vUv = uv;
  vec4 mv = modelViewMatrix * vec4(position,1.0);
  vN = normalize(normalMatrix * normal);
  vWN = normalize(mat3(modelMatrix) * normal);
  vV = normalize(-mv.xyz);
  gl_Position = projectionMatrix * mv;
}`;
const EARTH_FS = `
uniform sampler2D map; uniform vec3 uSun; uniform float uRim; uniform float uNight; uniform vec3 uSignal;
varying vec2 vUv; varying vec3 vN; varying vec3 vV; varying vec3 vWN;
void main(){
  vec3 c = texture2D(map, vUv).rgb;
  float d = dot(normalize(vWN), normalize(uSun));
  float lit = mix(1.0, smoothstep(-0.25, 0.45, d), uNight);
  c *= mix(0.18, 1.12, lit);
  float f = pow(1.0 - max(dot(vN, vV), 0.0), 2.6);
  c += uSignal * f * uRim * 0.38;
  gl_FragColor = vec4(c, 1.0);
  #include <colorspace_fragment>
}`;
const ATMO_VS = `
varying vec3 vN; varying vec3 vV;
void main(){
  vec4 mv = modelViewMatrix * vec4(position,1.0);
  vN = normalize(normalMatrix * normal); vV = normalize(-mv.xyz);
  gl_Position = projectionMatrix * mv;
}`;
const ATMO_FS = `
uniform vec3 uSignal; uniform float uAmt; varying vec3 vN; varying vec3 vV;
void main(){
  float i = pow(clamp(0.62 - dot(vN, vV), 0.0, 1.0), 3.0) * 2.2;
  gl_FragColor = vec4(uSignal * i * uAmt, 1.0);
}`;

// Earth group: tilt (x) -> spin (y) -> sphere + graticule + atmosphere.
export function makeEarth(earthTex) {
  const tilt = new THREE.Group();
  const spin = new THREE.Group();
  tilt.add(spin);
  const earthMat = new THREE.ShaderMaterial({
    uniforms: {
      map: { value: earthTex },
      uSun: { value: new THREE.Vector3(-0.6, 0.5, 1.0) },
      uRim: { value: 1.0 },
      uNight: { value: 0.0 },
      uSignal: { value: SIGNAL.clone() },
    },
    vertexShader: EARTH_VS,
    fragmentShader: EARTH_FS,
  });
  const sphere = new THREE.Mesh(new THREE.SphereGeometry(1, 128, 96), earthMat);
  spin.add(sphere);

  const pts = [];
  for (let lat = -75; lat <= 75; lat += 15) {
    for (let lon = -180; lon < 180; lon += 3) pts.push(ll(lat, lon, 1.006), ll(lat, lon + 3, 1.006));
  }
  for (let lon = -180; lon < 180; lon += 15) {
    for (let lat = -87; lat < 87; lat += 3) pts.push(ll(lat, lon, 1.006), ll(lat + 3, lon, 1.006));
  }
  const gratMat = new THREE.LineBasicMaterial({ color: SIGNAL, transparent: true, opacity: 0.3, depthWrite: false });
  const grat = new THREE.LineSegments(new THREE.BufferGeometry().setFromPoints(pts), gratMat);
  spin.add(grat);

  const atmoMat = new THREE.ShaderMaterial({
    uniforms: { uSignal: { value: SIGNAL.clone() }, uAmt: { value: 1.0 } },
    vertexShader: ATMO_VS,
    fragmentShader: ATMO_FS,
    side: THREE.BackSide,
    blending: THREE.AdditiveBlending,
    transparent: true,
    depthWrite: false,
  });
  const atmo = new THREE.Mesh(new THREE.SphereGeometry(1.09, 96, 64), atmoMat);
  tilt.add(atmo);
  return { root: tilt, tilt, spin, sphere, earthMat, gratMat, atmoMat };
}

export function makeStars(seed, count = 1600, radius = 60) {
  const r = rng(seed);
  const pos = new Float32Array(count * 3);
  const col = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    const u = r() * 2 - 1;
    const th = r() * Math.PI * 2;
    const s = Math.sqrt(1 - u * u);
    pos.set([Math.cos(th) * s * radius, u * radius, Math.sin(th) * s * radius], i * 3);
    const b = 0.25 + Math.pow(r(), 3) * 0.75;
    const tint = r() < 0.25 ? [0.6 * b, 0.95 * b, b] : [b, b, b];
    col.set(tint, i * 3);
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute("position", new THREE.BufferAttribute(pos, 3));
  g.setAttribute("color", new THREE.BufferAttribute(col, 3));
  const m = new THREE.PointsMaterial({ size: 2.2, sizeAttenuation: false, vertexColors: true, transparent: true, depthWrite: false });
  return new THREE.Points(g, m);
}

// Glow sprite texture (radial gradient) drawn once to a canvas.
export function glowTexture(size = 128) {
  const c = document.createElement("canvas");
  c.width = c.height = size;
  const g = c.getContext("2d");
  const grd = g.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
  grd.addColorStop(0, "rgba(255,255,255,1)");
  grd.addColorStop(0.18, "rgba(200,250,255,0.9)");
  grd.addColorStop(0.45, "rgba(56,230,245,0.35)");
  grd.addColorStop(1, "rgba(56,230,245,0)");
  g.fillStyle = grd;
  g.fillRect(0, 0, size, size);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

// Registers a seek-driven draw function for a scene and resolves its build hold.
export function registerScene(id, draw) {
  window.__eeScenes = window.__eeScenes || {};
  window.__eeScenes[id] = draw;
  const t = (window.__eeTime && window.__eeTime[id]) || 0;
  draw(t);
  if (window.__eeResolve && window.__eeResolve[id]) window.__eeResolve[id]();
}
