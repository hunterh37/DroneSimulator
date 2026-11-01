// Shared Three.js helpers for the Drone Arena "paper arena" promo scenes.
import * as THREE from "https://cdn.jsdelivr.net/npm/three@0.181.2/+esm";
export { THREE };

export const PAPER = new THREE.Color("#ECE8DF");
export const INK = new THREE.Color("#0C0C0E");
export const ACID = new THREE.Color("#D4FF3A");
export const CORAL = new THREE.Color("#FF5A36");
export const DEG = Math.PI / 180;

export const clamp01 = (x) => Math.min(1, Math.max(0, x));
export const lerp = (a, b, t) => a + (b - a) * t;
export const seg = (t, a, b) => clamp01((t - a) / (b - a));
export const easeInOut = (x) => (x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2);
export const easeOut = (x) => 1 - Math.pow(1 - x, 3);
export const easeIn = (x) => x * x * x;
export const expoOut = (x) => (x >= 1 ? 1 : 1 - Math.pow(2, -10 * x));
export const backOut = (x) => {
  const c = 1.9;
  return 1 + (c + 1) * Math.pow(x - 1, 3) + c * Math.pow(x - 1, 2);
};

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

// Renderer sized from the composition root's declared canvas, soft shadows on.
export function makeRenderer(canvas, root) {
  const W = parseInt(root.dataset.width, 10) || 1920;
  const H = parseInt(root.dataset.height, 10) || 1080;
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false, preserveDrawingBuffer: true });
  renderer.setPixelRatio(1);
  renderer.setSize(W, H, false);
  renderer.setClearColor(PAPER, 1);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  return { renderer, W, H, aspect: W / H };
}

// Registers a seek-driven draw function for a scene and resolves its build hold.
export function registerScene(id, draw) {
  window.__eeScenes = window.__eeScenes || {};
  window.__eeScenes[id] = draw;
  const t = (window.__eeTime && window.__eeTime[id]) || 0;
  draw(t);
  if (window.__eeResolve && window.__eeResolve[id]) window.__eeResolve[id]();
}
