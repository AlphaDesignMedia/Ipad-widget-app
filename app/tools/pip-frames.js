// Makes Blobby Pip's flipbook from the 3D page (app/design/pip-3d.html), old-game style: he's rendered once here,
// and the app just flips pictures (Aaron, 1 Nov: "i liked the renders we made a lot more" · "think old games").
// Each frame is drawn twice, over black and over grey; the difference gives true see-through glass edges.
//
//   node app/tools/pip-frames.js            → app/GlassClock/Plugins/blobby-sheet.png (+ its numbers in app/tools/blobby-sheet.json,
//                                              copy them into BlobbySheet in PipBlobbyLook.swift if they change)
//   node app/tools/pip-frames.js /tmp/x     → same files in /tmp/x, plus preview-strip.png (on the app's blue)
//
// Sets (rows of the sheet): side = his best silhouette (tail, both wings, an eye; the app mirrors it for left),
// front = looking at you, frontBlank = looking at you with no face (a face emoji becomes his face).
// Each row: FLAPS frames of one wing beat, then a blink (the blank row repeats its first frame).
const fs = require('fs'), path = require('path'), os = require('os');
const { chromium } = require('playwright');

const ROOT = path.join(__dirname, '..', '..');
const OUT = process.argv[2] || path.join(ROOT, 'app', 'GlassClock', 'Plugins');
const PREVIEW = !!process.argv[2];
const SIZE = 560;                         // render size (px)
const FLAPS = +(process.env.FLAPS || 12); // frames in one wing beat
const BEAT = 9;                           // the page's flying beat (rad/s)
const HEAD_PX = 40;                       // head radius in the sheet (px): 13 pt at 3×
const SETS = process.env.SETS ? process.env.SETS.split(',').map(x => { const [n, y, b] = x.split(':'); return [n, +y, b === 'blank']; })
  : [['side', 20, false], ['front', 280, false], ['frontBlank', 280, true]];

let html = fs.readFileSync(path.join(ROOT, 'app', 'design', 'pip-3d.html'), 'utf8');
const swap = (a, b) => { if (!html.includes(a)) throw new Error('page changed, not found: ' + a.slice(0, 60)); html = html.replace(a, b); };
// a plain backdrop we can swap (the matte), no room glow (the app draws its own), no bob, flying pose, no panel
swap("uniform vec2 res;", "uniform float matteU; uniform vec2 res;");
swap(": room(ro, rd, 0.);", ": vec3(matteU);");
swap("if (!ink) col += glowCol * exp(-md * 3.2) * .12 * glowAmt;", "");
swap("const bob = reduce || P.pose ? 0 : Math.sin(t * 1.6) * .06;", "const bob = 0;");
swap("const home = W > 700 ? v3(left - 1.7, .7, .6) : v3(.9, S * .3, .6);", "const home = v3(.3, -1.4, .6);");
swap("gl.uniform1f(U.faceOff, emo.on", "gl.uniform1f(U.faceOff, window.__faceOff ? 1 : emo.on");
swap("try { Object.assign(P, JSON.parse(localStorage.getItem('pip3d.v3') || '{}')); } catch {}", "Object.assign(P, window.OVR || {});");
swap("getContext('webgl', { antialias: false })", "getContext('webgl', { antialias: false, preserveDrawingBuffer: true })");
const HEAD = [.3, -1.4, .6], CAM = 8, TAN = 3.2 / 8;  // where his head sits, the page's camera
html = html.replace('<head>', `<head><script>
window.__now = 0; performance.now = () => window.__now;
window.__cb = null; window.requestAnimationFrame = cb => { window.__cb = cb; return 1; };
window.OVR = { pose: 0, panel: false, auto: false, emoji: '', eonly: false, env: 1, face: 1, yaw: 0 };
</script>`);
const tmp = path.join(os.tmpdir(), 'pip-frames.html');
fs.writeFileSync(tmp, html);

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 48, height: 48 }, deviceScaleFactor: 1 });   // tiny while he settles
  page.on('pageerror', e => console.error('page:', e.message));
  await page.goto('file://' + tmp);
  await page.waitForFunction(() => window.__cb);
  await page.evaluate(() => { for (let i = 0; i < 360; i++) { window.__now = i * 1000 / 60; window.__cb(window.__now); } });
  await page.setViewportSize({ width: SIZE, height: SIZE });
  await page.evaluate(() => new Promise(r => setTimeout(r, 200)));

  // one frame: over black, then grey → colour + alpha; kept on a canvas in the page
  const grab = (ms, yaw, blank) => page.evaluate(([ms, yaw, blank]) => {
    P.yaw = yaw; window.__faceOff = blank; window.__now = ms;
    const loc = gl.getUniformLocation(prog, 'matteU');
    gl.uniform1f(loc, 0); window.__cb(ms);
    const read = () => { const c = document.createElement('canvas'); c.width = cv.width; c.height = cv.height;
      const x = c.getContext('2d'); x.drawImage(cv, 0, 0); return x.getImageData(0, 0, c.width, c.height); };
    const A = read();
    gl.uniform1f(loc, .5); gl.drawArrays(gl.TRIANGLES, 0, 3);
    const B = read(), o = new ImageData(A.width, A.height);
    let x0 = 1e9, y0 = 1e9, x1 = -1, y1 = -1;
    for (let i = 0; i < A.data.length; i += 4) {
      let d = 0; for (let k = 0; k < 3; k++) d += B.data[i + k] - A.data[i + k];
      const a = Math.min(1, Math.max(0, 1 - d / (3 * 127.5)));
      o.data[i + 3] = Math.round(a * 255);
      for (let k = 0; k < 3; k++) o.data[i + k] = a > .01 ? Math.min(255, Math.round(A.data[i + k] / a)) : 0;
      if (o.data[i + 3] > 3) { const p = i / 4, x = p % A.width, y = (p / A.width) | 0;
        if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
    }
    const c = document.createElement('canvas'); c.width = o.width; c.height = o.height; c.getContext('2d').putImageData(o, 0, 0);
    (window.__frames = window.__frames || []).push(c);
    return [x0, y0, x1, y1];
  }, [ms, yaw, blank]);

  const start = 360 * 1000 / 60, period = 2 * Math.PI / BEAT * 1000, blinkAt = 4300 * 2 + 30;
  const boxes = [];
  for (const [, yaw, blank] of SETS) {
    for (let f = 0; f < FLAPS; f++) boxes.push(await grab(start + f * period / FLAPS, yaw, blank));
    boxes.push(await grab(blank ? start : blinkAt, yaw, blank));
  }
  // one box for every frame, so his head stays put; then scale so the head radius is HEAD_PX
  const pad = 4, bx = [Math.min(...boxes.map(b => b[0])) - pad, Math.min(...boxes.map(b => b[1])) - pad,
                      Math.max(...boxes.map(b => b[2])) + pad, Math.max(...boxes.map(b => b[3])) + pad];
  const k = SIZE / 2 / TAN / (CAM - HEAD[2]);
  const headR = k, headX = SIZE / 2 + HEAD[0] * k, headY = SIZE / 2 - HEAD[1] * k;
  const sc = HEAD_PX / headR, cols = FLAPS + 1;
  const out = await page.evaluate(([x0, y0, x1, y1, sc, cols, rows, preview]) => {
    const w = Math.ceil((x1 - x0) * sc), h = Math.ceil((y1 - y0) * sc);
    const s = document.createElement('canvas'); s.width = w * cols; s.height = h * rows; const x = s.getContext('2d');
    x.imageSmoothingQuality = 'high';
    window.__frames.forEach((c, i) => x.drawImage(c, x0, y0, x1 - x0, y1 - y0, (i % cols) * w, ((i / cols) | 0) * h, w, h));
    let strip = null;
    if (preview) {
      const p = document.createElement('canvas'); p.width = s.width; p.height = s.height; const q = p.getContext('2d');
      const g = q.createLinearGradient(0, 0, 0, p.height); g.addColorStop(0, '#1d5f86'); g.addColorStop(1, '#123e66');
      q.fillStyle = g; q.fillRect(0, 0, p.width, p.height); q.drawImage(s, 0, 0); strip = p.toDataURL('image/png');
    }
    return { sheet: s.toDataURL('image/png'), strip, w, h };
  }, [...bx, sc, cols, SETS.length, PREVIEW]);
  const save = (name, url) => fs.writeFileSync(path.join(OUT, name), Buffer.from(url.split(',')[1], 'base64'));
  save('blobby-sheet.png', out.sheet);
  if (out.strip) save('preview-strip.png', out.strip);
  const meta = { frameW: out.w, frameH: out.h, scale: 3, cols, rows: SETS.map(s => s[0]), flaps: FLAPS,
                 beatSeconds: +(period / 1000).toFixed(4), headX: +((headX - bx[0]) * sc).toFixed(1),
                 headY: +((headY - bx[1]) * sc).toFixed(1), headR: HEAD_PX };
  fs.writeFileSync(path.join(PREVIEW ? OUT : __dirname, 'blobby-sheet.json'), JSON.stringify(meta, null, 1) + '\n');
  console.log(JSON.stringify(meta));
  await browser.close();
})();
