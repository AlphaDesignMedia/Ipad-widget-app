/* =====================================================================
  IPAD CHECK · plugin v1   (Trial shelf)
  Loaded by the sandbox loader (see PLUGINS in index.html). Where: 🩺 in the plugin bar.
  - One button runs a health check of this device: screen, safe areas, touch and Pencil,
    motion sensors (tilt the iPad and Pip rolls), sound, glass support, speed, storage, plugins.
  - The report is saved to the sandbox's own database (collection "checks"), so Claude can read it
    next session. Also kept on this device, and "Copy report" puts it on the clipboard.
  - Motion needs a tap to allow it on iPad. If the page frame blocks motion, the report says so.
  Switch it off in the Plugins panel, or remove it from PLUGINS.
  ===================================================================== */
(() => {
const H=window.PipHost;
if(!H||!H.registerPlugin){ console.warn('iPad Check: needs PipHost (host.js).'); return; }
const {N,S,stage}=H;
if(!H.registerPlugin({id:'ipad-check',name:'iPad Check',icon:'🩺',shelf:'trial',desc:'Tests this device (sensors, Pencil, glass, speed) and saves a report Claude can read.'})) return;
/* ---- shared plugin toolbar + cards (created once, reused by every plugin) ---- */
const PB=window.PipPlugBar||(window.PipPlugBar=(()=>{
  const st=document.createElement('style'); st.textContent=`
#plugbar{position:absolute;left:max(16px,env(safe-area-inset-left,0px));bottom:calc(14px + env(safe-area-inset-bottom,0px));z-index:36;display:flex;gap:2px;padding:4px;border-radius:22px}
#plugbar button{width:40px;height:40px;border:0;border-radius:17px;background:transparent;font-size:19px;line-height:1;cursor:pointer;transition:background .2s, scale .15s}
#plugbar button:active{scale:.92}
#plugbar button[aria-pressed="true"]{background:var(--glass-strong)}
.plugcard{position:absolute;left:max(16px,env(safe-area-inset-left,0px));bottom:calc(70px + env(safe-area-inset-bottom,0px));z-index:37;width:min(310px,calc(100% - 32px));max-height:calc(100% - 160px);overflow:auto;box-sizing:border-box;padding:14px;border-radius:22px;display:grid;gap:10px;color:var(--ink)}
.plugcard h3{margin:0;font:700 16px/1.2 var(--ui)}
.plugcard p{margin:0;font:400 13.5px/1.4 var(--ui);color:var(--ink2)}
.plugcard .pr{display:flex;gap:6px;flex-wrap:wrap}
.plugcard button.pc{min-height:36px;border:0;border-radius:12px;padding:0 12px;background:var(--wash);color:var(--ink);font:600 13px/1 var(--ui);cursor:pointer}
.plugcard button.pc.on{background:var(--accent);color:#fff}
.plugcard input.pin{min-height:36px;border:1px solid var(--hair);border-radius:10px;background:var(--wash);padding:0 10px;font:500 15px var(--ui);color:var(--ink)}`;
  document.head.appendChild(st);
  const bar=document.createElement('div'); bar.id='plugbar'; bar.className='glass'; bar.setAttribute('role','toolbar'); bar.setAttribute('aria-label','Plugins');
  bar.addEventListener('pointerdown',e=>e.stopPropagation()); window.PipHost.stage.appendChild(bar);
  const cards=[];
  return {
    button(icon,label,onClick){ const b=document.createElement('button'); b.textContent=icon; b.title=label; b.setAttribute('aria-label',label); b.addEventListener('click',onClick); bar.appendChild(b); return b; },
    card(html){ const c=document.createElement('section'); c.className='plugcard glass'; c.hidden=true; c.innerHTML=html; c.addEventListener('pointerdown',e=>e.stopPropagation()); window.PipHost.stage.appendChild(c); cards.push(c); return c; },
    toggle(c,btn){ const open=c.hidden; cards.forEach(x=>{x.hidden=true;}); bar.querySelectorAll('button').forEach(x=>x.setAttribute('aria-pressed','false')); c.hidden=!open; if(btn) btn.setAttribute('aria-pressed',String(open)); return open; }
  };
})());
const emote=(c,o)=>window.PipSpatial?.emote(c,o);
const css=document.createElement('style'); css.textContent=`
.ick-list{display:grid;gap:4px;font:500 13px/1.35 var(--ui)}
.ick-row{display:grid;grid-template-columns:20px 1fr;gap:6px;align-items:start}
.ick-row small{display:block;color:var(--ink3);font-weight:400}
.ick-tilt{height:70px;border-radius:14px;background:var(--wash);position:relative;overflow:hidden}
.ick-tilt i{position:absolute;left:50%;top:50%;width:22px;height:22px;margin:-11px;border-radius:50%;background:var(--accent);box-shadow:0 2px 6px rgba(0,0,0,.25)}
.ick-st{font:600 12.5px/1.3 var(--ui);color:var(--ink2)}`;
document.head.appendChild(css);

/* things seen since load: pointer kinds, Pencil pressure and tilt */
const seen={types:new Set(),pressure:0,tilt:false,coalesced:false,hover:false};
addEventListener('pointerdown',e=>{ seen.types.add(e.pointerType); if(e.pointerType==='pen'){ seen.pressure=Math.max(seen.pressure,e.pressure); if(e.tiltX||e.tiltY||e.altitudeAngle!=null) seen.tilt=true; } },true);
addEventListener('pointermove',e=>{ if(e.pointerType==='pen'){ seen.pressure=Math.max(seen.pressure,e.pressure); if(e.buttons===0) seen.hover=true; if(e.getCoalescedEvents&&e.getCoalescedEvents().length>1) seen.coalesced=true; } },true);

const card=PB.card(`<h3>🩺 iPad Check</h3>
  <p>Tests what this device can do and saves a report Claude can read next time. Tilt the iPad during the motion step.</p>
  <div class="pr"><button class="pc on" id="ickRun">Run check</button><button class="pc" id="ickCopy" hidden>Copy report</button></div>
  <div class="ick-tilt" id="ickTilt" hidden><i></i></div>
  <p class="ick-st" id="ickSt" aria-live="polite"></p>
  <div class="ick-list" id="ickList"></div>`);
const btn=PB.button('🩺','iPad Check',()=>{ if(PB.toggle(card,btn)) show(H.store.get('ick-last',null)); });
const $=s=>card.querySelector(s);
const status=t=>{ $('#ickSt').textContent=t; };

/* motion: ask (iPad needs a tap), listen for a few seconds, roll Pip and the dot with the tilt */
async function motionTest(ms=4000){
  const out={permission:'not needed',events:0,hz:0,maxAccel:0,rotation:false,orientation:false};
  try{
    /* both asks start inside the tap, or iPad refuses */
    const asks=[window.DeviceMotionEvent,window.DeviceOrientationEvent].filter(E=>E&&typeof E.requestPermission==='function').map(E=>E.requestPermission());
    if(asks.length) out.permission=(await Promise.all(asks))[0];
  }catch(err){ out.permission='error: '+(err&&err.message||err); }
  if(!window.DeviceMotionEvent){ out.note='DeviceMotionEvent not in this browser'; return out; }
  const tilt=$('#ickTilt'), dot=tilt.querySelector('i'); tilt.hidden=false;
  let t0=0, tl=0;
  const onM=e=>{ out.events++; if(!t0) t0=performance.now(); tl=performance.now();
    const g=e.accelerationIncludingGravity||{}, a=e.acceleration||{};
    out.maxAccel=Math.max(out.maxAccel,Math.hypot(a.x||0,a.y||0,a.z||0));
    if(e.rotationRate&&(e.rotationRate.alpha!=null)) out.rotation=true;
    const gx=g.x||0, gy=g.y||0, ang=(screen.orientation&&screen.orientation.angle)||0;
    /* screen-relative tilt */
    const [sx,sy]=ang===90?[-gy,-gx]:ang===270||ang===-90?[gy,gx]:ang===180?[-gx,gy]:[gx,-gy];
    dot.style.transform=`translate(${H.clamp(sx*9,-120,120)}px,${H.clamp(sy*3.5,-24,24)}px)`;
    if(S.naviOn&&N.state==='free'){ N.vx+=sx*14; N.vy+=sy*14; } };
  const onO=e=>{ if(e.beta!=null) out.orientation=true; };
  addEventListener('devicemotion',onM); addEventListener('deviceorientation',onO);
  if(S.naviOn&&N.awake&&N.state!=='held'){ N.state='free'; H.say('Tilt the iPad. I\'ll roll.',2200,null,0); }
  await new Promise(r=>setTimeout(r,ms));
  removeEventListener('devicemotion',onM); removeEventListener('deviceorientation',onO); tilt.hidden=true;
  out.hz=out.events>1&&tl>t0?Math.round((out.events-1)/((tl-t0)/1000)):0;
  out.maxAccel=+out.maxAccel.toFixed(2);
  if(!out.events) out.note=out.permission==='denied'?(window.top!==window?'The Claude app blocks motion for artifacts. Tilt needs the real app.':'Motion was turned down. Settings › Safari can reset it.'):'No motion events: blocked by the page frame or no sensor.';
  return out;
}

function sounds(){ try{ const A=window.AudioContext||window.webkitAudioContext; if(!A) return 'none'; const c=new A(); const st=c.state; c.close(); return st; }catch{ return 'error'; } }
function webgl(){ try{ const c=document.createElement('canvas'), g=c.getContext('webgl2')||c.getContext('webgl'); if(!g) return 'none';
  const d=g.getExtension('WEBGL_debug_renderer_info'); return (c.getContext('webgl2')?'WebGL2':'WebGL')+(d?' · '+g.getParameter(d.UNMASKED_RENDERER_WEBGL):''); }catch{ return 'error'; } }
function storageOk(){ try{ localStorage.setItem('gs2-ick','1'); localStorage.removeItem('gs2-ick'); return true; }catch{ return false; } }

async function run(){
  const b=$('#ickRun'); b.disabled=true; $('#ickCopy').hidden=true; $('#ickList').innerHTML='';
  const ua=navigator.userAgent, iPad=/iPad/.test(ua)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
  const scr=window.PipScreen?.get?.();
  const mm=q=>matchMedia(q).matches;
  status('1 of 3 · Motion. Tilt the iPad…');
  const motion=await motionTest();
  status('2 of 3 · Speed. Hold still for 3 seconds…');
  const speed=await H.measure(3000), cost=H.cost();
  status('3 of 3 · Saving…');
  const R={
    at:new Date().toISOString(), v:1,
    device:{iPad, ua, platform:navigator.platform, touchPoints:navigator.maxTouchPoints, lang:navigator.language, tz:Intl.DateTimeFormat().resolvedOptions().timeZone,
      standalone:!!navigator.standalone||mm('(display-mode: standalone)'), inFrame:window.top!==window.self},
    screen:{w:innerWidth,h:innerHeight,screenW:screen.width,screenH:screen.height,dpr:devicePixelRatio,orientation:screen.orientation?.type||(innerWidth>innerHeight?'landscape':'portrait'),
      sizeClass:scr?.cls||null, safe:scr?.safe||null, dark:mm('(prefers-color-scheme: dark)'), reduceMotion:mm('(prefers-reduced-motion: reduce)'), moreContrast:mm('(prefers-contrast: more)')},
    input:{coarse:mm('(pointer: coarse)'), fine:mm('(any-pointer: fine)'), hover:mm('(any-hover: hover)'), seen:[...seen.types], pencilPressure:+seen.pressure.toFixed(2), pencilTilt:seen.tilt, pencilHover:seen.hover, coalesced:seen.coalesced},
    motion,
    features:{glass:CSS.supports('backdrop-filter','blur(1px)')||CSS.supports('-webkit-backdrop-filter','blur(1px)'), mask:CSS.supports('mask-image','none')||CSS.supports('-webkit-mask-image','none'),
      webgl:webgl(), audio:sounds(), vibrate:'vibrate' in navigator, share:!!navigator.share, clipboard:!!navigator.clipboard, storage:storageOk(), indexedDB:!!window.indexedDB,
      offscreenCanvas:!!window.OffscreenCanvas, visualViewport:!!window.visualViewport, online:navigator.onLine},
    speed:{fps:speed.fps, msPerFrame:+speed.ms.toFixed(2), worstMs:+speed.worst.toFixed(1), elements:cost.elements, heapMB:cost.heapMB&&+cost.heapMB.toFixed(1)},
    sandbox:{plugins:H.plugins.map(p=>p.id+':'+p.status), errors:(document.documentElement.dataset.errors||'').slice(0,600), pip:S.naviOn?(N.awake?'awake':'asleep'):'off', look:S.era, material:S.material, use:window.PipUsage?.()||null}
  };
  const db=await H.db(); let saved='only on this device (no database here)';
  if(db){ try{ const ref=await db.collection('checks').add(R); saved='to the sandbox database ✓'; R.id=ref.id; }catch(err){ saved='not saved to the database ('+(err&&err.code||err)+')'; } }
  R.saved=saved; H.store.set('ick-last',R);
  show(R); b.disabled=false; status('Report saved '+saved+'.');
  const bad=rows(R).filter(r=>r[0]==='❌').length;
  if(S.naviOn&&N.awake) H.say(bad?`Done. ${bad} thing${bad>1?'s':''} to look at.`:'All good. This iPad is in fine shape.',2600,null,0);
  emote(bad?'🩹':'💪',{pri:3});
}

function rows(R){
  const ok=(c,y='✅',n='❌')=>c?y:n, m=R.motion||{};
  return [
    ['🖥️',`${R.device.iPad?'iPad':'Not an iPad'} · ${R.screen.w}×${R.screen.h} at ${R.screen.dpr}×`,`${R.screen.orientation}${R.screen.sizeClass?' · '+R.screen.sizeClass:''}${R.device.inFrame?' · inside the Claude frame':''}`],
    [ok(R.input.seen.includes('pen'),'✅','➖'),'Apple Pencil',R.input.seen.includes('pen')?`pressure up to ${R.input.pencilPressure} · tilt ${R.input.pencilTilt?'yes':'no'} · hover ${R.input.pencilHover?'yes':'no'}`:'Not seen yet. Draw a line with it, then run again.'],
    [ok(m.events>0),'Motion sensors',m.events?`${m.hz} Hz · rotation ${m.rotation?'yes':'no'} · tilt ${m.orientation?'yes':'no'}`:(m.note||'none')],
    [ok(R.features.glass),'Glass (backdrop blur)',R.features.glass?'Supported':'Not supported: glass falls back to frost'],
    [ok(R.speed.fps>=50,'✅','⚠️'),`Speed ${R.speed.fps} fps`,`${R.speed.msPerFrame} ms a frame · worst ${R.speed.worstMs} ms · ${R.speed.elements} elements`],
    [ok(R.features.audio!=='none'&&R.features.audio!=='error'),'Sound',R.features.audio],
    [ok(R.features.storage),'Storage on this device',R.features.storage?'Works':'Blocked: settings won\'t stick'],
    [ok(!R.sandbox.errors),'Sandbox errors',R.sandbox.errors||'None'],
    [/✓/.test(R.saved||'')?'✅':'⚠️','Report',R.saved||'']
  ];
}
function show(R){
  if(!R){ $('#ickList').innerHTML=''; return; }
  $('#ickList').innerHTML=rows(R).map(([i,t,s])=>`<div class="ick-row"><span>${i}</span><span>${esc(t)}<small>${esc(s)}</small></span></div>`).join('')
    +`<p class="ick-st">From ${new Date(R.at).toLocaleString('en-GB',{day:'numeric',month:'short',hour:'2-digit',minute:'2-digit'})}</p>`;
  $('#ickCopy').hidden=false;
}
const esc=s=>String(s).replace(/[<>&"]/g,c=>({'<':'&lt;','>':'&gt;','&':'&amp;','"':'&quot;'}[c]));
$('#ickRun').addEventListener('click',()=>run().catch(err=>{ status('Check failed: '+(err&&err.message||err)); $('#ickRun').disabled=false; }));
$('#ickCopy').addEventListener('click',async()=>{ try{ await navigator.clipboard.writeText(JSON.stringify(H.store.get('ick-last',{}),null,1)); status('Copied.'); }catch{ status('Copy is blocked here.'); } });
window.PipCheck={run};
})();
