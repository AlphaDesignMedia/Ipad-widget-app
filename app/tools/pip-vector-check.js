// Headless check of the vector Pip page: a little flight script, eight stills → /tmp/vtest.png. node app/tools/pip-vector-check.js
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 420, height: 320 }, deviceScaleFactor: 2 });
  p.on('pageerror', e => console.log('ERR', e.message));
  await p.goto('file://' + require('path').join(__dirname, '..', 'design', 'pip-vector.html'));
  await p.evaluate(() => { window.__manual = true; auto = false; document.querySelector('.note').remove(); document.querySelector('.bar').remove(); });
  const keep = { 150: 'flying right', 206: 'turning', 330: 'rest (left)', 405: '😊 coming in', 430: '😊 face', 573: '⭐ coming in', 600: '⭐ inside', 685: '⭐ going' };
  const out = [];
  for (let i = 0; i <= 690; i++) {
    const t = 10 + i / 60;
    const label = await p.evaluate(([i, t, keep]) => {
      // a little script: rest, fly right, turn, fly left, rest, emoji
      if (i < 90) { P.x = 210; } else if (i < 190) { P.x = 210 + (i - 90) * 0.9; } else if (i < 300) { P.x = 300 - (i - 190) * 1.6; }
      if (i === 400) { emoji = '😊'; emoteAt = t; } if (i === 520) { emoji = '⭐'; emoteAt = t; }
      P.y = 160; window.__frame(t);
      return keep[i] || null;
    }, [i, t, keep]);
    if (label) out.push([label, await p.evaluate(() => document.getElementById('c').toDataURL())]);
  }
  await p.setContent(`<body style="margin:0;background:linear-gradient(#1d5f86,#123e66);display:grid;grid-template-columns:repeat(4,420px);color:#fff;font:16px sans-serif">${out.map(([l, u]) => `<div style="position:relative;width:420px;height:320px"><img src="${u}" style="width:420px;height:320px"><div style="position:absolute;bottom:8px;width:100%;text-align:center">${l}</div></div>`).join('')}</body>`);
  await p.setViewportSize({ width: 1680, height: 640 }); await p.screenshot({ path: '/tmp/vtest.png' });
  await b.close();
})();
