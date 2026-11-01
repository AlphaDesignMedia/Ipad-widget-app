// Makes Blobby Pip's flipbook frames from the 3D page (app/design/pip-3d.html), so the app can show
// the real render cheaply: pictures, no 3D maths on the iPad (Aaron, 1 Nov: "i liked the renders we made a lot more").
// Each frame is drawn twice, over black and over grey, and the difference gives see-through edges (true glass alpha).
// Run: node app/tools/pip-frames.js [outDir]   (needs Playwright + Chromium; uses Aaron's final settings)
const fs = require('fs'), path = require('path');
const { chromium } = require('playwright');

const ROOT = path.join(__dirname, '..', '..');
const OUT = process.argv[2] || path.join(ROOT, 'nat', 'pip-frames');
const SIZE = 560;           // render size (px); cropped afterwards
const FLAPS = 16;           // frames in one wing beat
const BEAT = 9;             // the page's flying beat (rad/s)

let html = fs.readFileSync(path.join(ROOT, 'app', 'design', 'pip-3d.html'), 'utf8');
const swap = (a, b) => { if (!html.includes(a)) throw new Error('page changed, not found: ' + a.slice(0, 60)); html = html.replace(a, b); };
// a plain backdrop we can swap (the matte), no room glow, no bob, his head in the middle, flying pose, no panel
swap("uniform vec2 res;", "uniform float matteU; uniform vec2 res;");
swap(": room(ro, rd, 0.);", ": vec3(matteU);");
swap("if (!ink) col += glowCol * exp(-md * 3.2) * .12 * glowAmt;", "");
swap("const bob = reduce || P.pose ? 0 : Math.sin(t * 1.6) * .06;", "const bob = 0;");
swap("const home = W > 700 ? v3(left - 1.7, .7, .6) : v3(.9, S * .3, .6);", "const home = v3(.3, -.9, .6);");
swap("try { Object.assign(P, JSON.parse(localStorage.getItem('pip3d.v3') || '{}')); } catch {}", "Object.assign(P, window.OVR || {});");
swap("getContext('webgl', { antialias: false })", "getContext('webgl', { antialias: false, preserveDrawingBuffer: true })");
// time and frames by hand
const pre = `<script>
window.__now = 0; performance.now = () => window.__now;
window.__cb = null; window.requestAnimationFrame = cb => { window.__cb = cb; return 1; };
window.OVR = { pose: 0, panel: false, auto: false, emoji: '', eonly: false, env: 1, face: 1, yaw: 0 };
</script>`;
html = html.replace('<head>', '<head>' + pre);
const tmp = path.join(require('os').tmpdir(), 'pip-frames.html');
fs.writeFileSync(tmp, html);

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 48, height: 48 }, deviceScaleFactor: 1 });   // tiny while he settles
  page.on('pageerror', e => console.error('page:', e.message));
  await page.goto('file://' + tmp);
  await page.waitForFunction(() => window.__cb);
  // settle: let him glide to the middle and his tail hang (frames at 60 fps; t kept clear of blinks)
  await page.evaluate(() => { for (let i = 0; i < 360; i++) { window.__now = i * 1000 / 60; const cb = window.__cb; cb(window.__now); } });
  await page.setViewportSize({ width: SIZE, height: SIZE });
  await page.evaluate(() => new Promise(r => setTimeout(r, 200)));
  console.log('settled');

  // one frame = draw over black, then grey; work out colour + alpha
  const grab = async (ms) => page.evaluate((ms) => {
    window.__now = ms; const cb = window.__cb;
    const loc = gl.getUniformLocation(prog, 'matteU');
    gl.uniform1f(loc, 0); cb(ms);                     // tick draws over black
    const read = () => { const c = document.createElement('canvas'); c.width = cv.width; c.height = cv.height;
      const x = c.getContext('2d'); x.drawImage(cv, 0, 0); return x.getImageData(0, 0, c.width, c.height); };
    const A = read();
    gl.uniform1f(loc, .5); gl.drawArrays(gl.TRIANGLES, 0, 3);   // same frame over grey
    const B = read();
    const o = new ImageData(A.width, A.height);
    for (let i = 0; i < A.data.length; i += 4) {
      let d = 0; for (let k = 0; k < 3; k++) d += (B.data[i + k] - A.data[i + k]); d /= 3 * 127.5;
      const a = Math.min(1, Math.max(0, 1 - d));
      o.data[i + 3] = Math.round(a * 255);
      for (let k = 0; k < 3; k++) o.data[i + k] = a > .01 ? Math.min(255, Math.round(A.data[i + k] / a)) : 0;
    }
    const c = document.createElement('canvas'); c.width = o.width; c.height = o.height; c.getContext('2d').putImageData(o, 0, 0);
    // bounding box of anything visible
    let x0 = 1e9, y0 = 1e9, x1 = -1, y1 = -1;
    for (let y = 0; y < o.height; y++) for (let x = 0; x < o.width; x++) if (o.data[(y * o.width + x) * 4 + 3] > 3) {
      if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
    window.__frames = window.__frames || []; window.__frames.push(c);
    return [x0, y0, x1, y1];
  }, ms);

  const start = 360 * 1000 / 60;
  const period = 2 * Math.PI / BEAT * 1000;
  const boxes = [];
  for (let f = 0; f < FLAPS; f++) boxes.push(await grab(start + f * period / FLAPS));
  boxes.push(await grab(4300 * 2 + 30));                           // a blink (the page blinks every 4.3 s)
  const TURNS = [0, 45, 90, 135, 180, 225, 270, 315];              // turned round his head: he's round, not a flat plane
  for (const y of TURNS) { await page.evaluate(y => { P.yaw = y; }, y); boxes.push(await grab(start)); }
  await page.evaluate(() => { P.yaw = 0; });
  const pad = 6;
  const bx = [Math.min(...boxes.map(b => b[0])) - pad, Math.min(...boxes.map(b => b[1])) - pad,
              Math.max(...boxes.map(b => b[2])) + pad, Math.max(...boxes.map(b => b[3])) + pad];
  // save each frame cropped to the same box, plus a preview strip on the app's blue
  const out = await page.evaluate(([x0, y0, x1, y1]) => {
    const w = x1 - x0, h = y1 - y0, list = window.__frames.map(c => {
      const k = document.createElement('canvas'); k.width = w; k.height = h; k.getContext('2d').drawImage(c, -x0, -y0); return k.toDataURL('image/png'); });
    const cols = 9, sc = .5, rows = Math.ceil(list.length / cols), s = document.createElement('canvas');
    s.width = cols * w * sc; s.height = rows * h * sc; const x = s.getContext('2d');
    const g = x.createLinearGradient(0, 0, 0, s.height); g.addColorStop(0, '#1d5f86'); g.addColorStop(1, '#123e66');
    x.fillStyle = g; x.fillRect(0, 0, s.width, s.height);
    window.__frames.forEach((c, i) => x.drawImage(c, x0, y0, w, h, (i % cols) * w * sc, Math.floor(i / cols) * h * sc, w * sc, h * sc));
    return { list, strip: s.toDataURL('image/png'), w, h };
  }, bx);
  const save = (name, url) => fs.writeFileSync(path.join(OUT, name), Buffer.from(url.split(',')[1], 'base64'));
  out.list.forEach((u, i) => save(i < FLAPS ? `fly-${String(i).padStart(2, '0')}.png` : i === FLAPS ? 'blink.png' : `turn-${String((i - FLAPS - 1) * 45).padStart(3, '0')}.png`, u));
  save('preview-strip.png', out.strip);
  console.log(`frames: ${out.list.length}, ${out.w}×${out.h}px → ${OUT}`);
  await browser.close();
})();
