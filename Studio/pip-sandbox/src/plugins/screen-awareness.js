/* =====================================================================
  SCREEN AWARENESS · plugin v1   (Trial shelf)
  Loaded by the sandbox loader (see PLUGINS in index.html). Where: 📐 in the plugin bar.
  - Pip reacts to rotating and resizing, notices pencil/mouse, hops above the keyboard,
    keeps out of the notch, and moves off your panels when idle.
  - 📐 card: size class, orientation, input, safe areas; Guides overlay (breakpoints at 600 / 1100,
    biggest free space); Preview as Phone, Split ⅓ / ½, iPad, Laptop, with a drag-to-resize corner.
  - Exposes window.PipScreen for other plugins.
  Remove the block to remove the plugin.
  ===================================================================== */
(() => {
const H=window.PipHost;
if(!H||!H.registerPlugin){ console.warn('Screen Awareness: needs Pip Sandbox V2 stage 12 or later.'); return; }
const {N,S,stage,navi}=H;
if(!H.registerPlugin({id:'screen',name:'Screen Awareness',icon:'📐',shelf:'trial',desc:'Pip knows the screen: size, rotation, pencil or mouse, keyboard, notch, free space. Plus a screen inspector with device previews.'})) return;
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
/* ---- shared screen reader (created once, reused by Screen Awareness and Adaptive Layout) ---- */
const SC=window.PipScreenCore||(window.PipScreenCore=(()=>{
  const st=window.PipHost.stage, fns=[];
  const probe=document.createElement('i'); probe.setAttribute('aria-hidden','true');
  probe.style.cssText='position:fixed;left:0;top:0;width:0;height:0;visibility:hidden;pointer-events:none;padding:env(safe-area-inset-top,0px) env(safe-area-inset-right,0px) env(safe-area-inset-bottom,0px) env(safe-area-inset-left,0px)';
  document.body.appendChild(probe);
  let input=matchMedia('(pointer:coarse)').matches?'touch':'mouse', info=null, t=0;
  function read(){
    const W=st.clientWidth, Hh=st.clientHeight, cs=getComputedStyle(probe), vv=window.visualViewport;
    const cls=W<600?'compact':W<1100?'regular':'wide', orient=W>=Hh?'landscape':'portrait';
    const typing=!!document.activeElement?.matches?.('input:not([type=checkbox]):not([type=range]),textarea,[contenteditable]');
    return {W,H:Hh,cls,short:Hh<500,orient,input,dpr:window.devicePixelRatio||1,
      kb:!!(vv&&typing&&innerHeight-vv.height>140), kbTop:vv?vv.height+vv.offsetTop:Hh,
      safe:{t:parseFloat(cs.paddingTop)||0,r:parseFloat(cs.paddingRight)||0,b:parseFloat(cs.paddingBottom)||0,l:parseFloat(cs.paddingLeft)||0},
      device:input==='mouse'?'Desktop':Math.min(W,Hh)<500?'Phone-sized':'Tablet-sized',
      preview:document.body.classList.contains('scr-preview')};
  }
  function apply(){
    const prev=info; info=read();
    st.classList.remove('scr-compact','scr-regular','scr-wide'); st.classList.add('scr-'+info.cls);
    st.classList.toggle('scr-short',info.short); st.classList.toggle('scr-portrait',info.orient==='portrait');
    st.style.setProperty('--sw',info.W+'px'); st.style.setProperty('--sh',info.H+'px');
    if(!prev||prev.W!==info.W||prev.H!==info.H||prev.input!==info.input||prev.kb!==info.kb) fns.forEach(f=>{ try{ f(info,prev); }catch(e){ console.warn(e); } });
  }
  const soon=()=>{ clearTimeout(t); t=setTimeout(apply,90); };
  addEventListener('resize',soon); window.visualViewport?.addEventListener('resize',soon); new ResizeObserver(soon).observe(st);
  addEventListener('focusin',soon); addEventListener('focusout',soon);
  addEventListener('pointerdown',e=>{ const k=e.pointerType==='pen'?'pen':e.pointerType==='touch'?'touch':'mouse'; if(k!==input){ input=k; apply(); } },true);
  apply();
  return {get:()=>info, on(f){ fns.push(f); }, refresh:apply};
})());
/* SCREEN AWARENESS: Pip knows the screen they live on, and you get a screen inspector. */
const CFG=Object.assign({react:true,rest:true,keyboard:true},H.store.get('scr-cfg',{}));
const saveCfg=()=>H.store.set('scr-cfg',CFG);
const css=document.createElement('style'); css.textContent=`
body.scr-preview{display:grid;place-items:center;background:#121317 repeating-linear-gradient(45deg,transparent 0 12px,rgba(255,255,255,.035) 12px 24px)}
body.scr-preview .stage{border-radius:30px;box-shadow:0 0 0 1px rgba(255,255,255,.22),0 0 0 9px #26272d,0 0 0 10px rgba(255,255,255,.12),0 40px 90px rgba(0,0,0,.6)}
.scr-tag{position:fixed;left:50%;top:8px;transform:translateX(-50%);z-index:99;display:flex;gap:8px;align-items:center;padding:5px 6px 5px 12px;border-radius:999px;background:#26272d;color:#eceef3;font:600 12px/1 system-ui,sans-serif;box-shadow:0 6px 20px rgba(0,0,0,.4)}
.scr-tag button{border:0;border-radius:999px;min-height:26px;padding:0 10px;background:#3a3d46;color:#fff;font:600 12px/1 system-ui,sans-serif;cursor:pointer}
.scr-grip{position:fixed;z-index:99;width:26px;height:26px;border-radius:9px;background:#3a3d46;color:#fff;display:grid;place-items:center;font:700 13px/1 system-ui;cursor:nwse-resize;touch-action:none;box-shadow:0 4px 12px rgba(0,0,0,.4)}
.scr-guides{position:absolute;inset:0;z-index:45;pointer-events:none}
.scr-guides .bp{position:absolute;top:0;bottom:0;border-left:1.5px dashed color-mix(in srgb,var(--accent) 70%,transparent)}
.scr-guides .bp b{position:absolute;top:70px;left:5px;font:600 11px/1 var(--ui);color:var(--accent);white-space:nowrap}
.scr-guides .free{position:absolute;border-radius:16px;border:2px dashed #3ec98a;background:rgba(62,201,138,.08)}
.scr-guides .free b{position:absolute;left:10px;top:8px;font:600 11px/1 var(--ui);color:#2a9c69}
.scr-guides .safe{position:absolute;background:rgba(255,91,58,.18)}
.scr-guides .kb{position:absolute;left:0;right:0;bottom:0;background:rgba(80,120,255,.14);border-top:2px dashed #5b7cff}
.plugcard .scr-now{font:600 13.5px/1.45 var(--ui);color:var(--ink)}
.plugcard .scr-now small{display:block;font-weight:400;color:var(--ink2)}
.plugcard .lbl2{font:700 11px/1 var(--ui);letter-spacing:.06em;text-transform:uppercase;color:var(--ink3);margin-top:2px}
.plugcard label.sw2{display:flex;align-items:center;justify-content:space-between;gap:10px;font:500 13.5px/1.3 var(--ui)}`;
document.head.appendChild(css);

/* ---------- free space: where nothing is covering the stage ---------- */
function blockers(pad){
  const els=[...H.openEls(),document.getElementById('rail'),document.querySelector('.topbar .tb-left'),document.querySelector('.topbar .seg'),document.querySelector('.topbar .pill'),
    document.getElementById('tm'),document.getElementById('plugbar'),...document.querySelectorAll('.plugcard:not([hidden])')].filter(e=>e&&!e.hidden&&e.getClientRects().length);
  return els.map(e=>H.rel(e)).concat([H.cardRect()]).map(r=>({l:r.left-pad,t:r.top-pad,r:r.right+pad,b:r.bottom+pad}));
}
function grid(pad){
  const c=24, W=stage.clientWidth, Hh=stage.clientHeight, cols=Math.floor(W/c), rows=Math.floor(Hh/c), bs=blockers(pad), g=[];
  for(let j=0;j<rows;j++){ const row=[]; for(let i=0;i<cols;i++){ const x=i*c+c/2, y=j*c+c/2; row.push(!bs.some(b=>x>b.l&&x<b.r&&y>b.t&&y<b.b)); } g.push(row); }
  return {g,c,cols,rows};
}
function largestFree(){
  const {g,c,cols,rows}=grid(8), h=new Array(cols).fill(0); let best={a:0};
  for(let j=0;j<rows;j++){
    for(let i=0;i<cols;i++) h[i]=g[j][i]?h[i]+1:0;
    const st=[];
    for(let i=0;i<=cols;i++){ const hi=i<cols?h[i]:0; let s=i;
      while(st.length&&st[st.length-1][1]>=hi){ const [si,sh]=st.pop(), a=sh*(i-si); if(a>best.a) best={a,l:si*c,t:(j-sh+1)*c,w:(i-si)*c,h:sh*c}; s=si; }
      st.push([s,hi]); }
  }
  return best.a?{left:best.l,top:best.t,width:best.w,height:best.h}:null;
}
function nearestFree(x,y){
  const {g,c,cols,rows}=grid(N.r+10); let best=null, bd=1e9;
  for(let j=3;j<rows-1;j++) for(let i=1;i<cols-1;i++) if(g[j][i]){ const px=i*c+c/2, py=j*c+c/2, d=Math.hypot(px-x,py-y); if(d<bd){ bd=d; best={x:px,y:py}; } }
  return best;
}

/* ---------- Pip notices the screen changing ---------- */
const once=new Set(); let lastLine=-1e9;
const line=(text,lvl=2)=>{ if(!CFG.react||!S.naviOn||!N.awake||H.G.on||N.state==='held'||H.now()-lastLine<15000) return; lastLine=H.now(); H.say(text,2400,null,lvl); };
SC.on((info,prev)=>{
  H.emit('screen',info);
  if(!prev) return;
  const t=H.now();
  if(prev.orient!==info.orient&&S.naviOn){
    N.dizzyUntil=t+900; N.squash=.3; N.hopT=t; emote('🔄',{pri:3});
    line(info.orient==='portrait'?H.pick(['Tall mode. Whoa.','Sideways! Give me a second.','Everything just tipped over.']):H.pick(['Wide again. Much better.','Landscape. Room to fly.']));
  } else if(prev.cls!==info.cls){
    emote(info.cls==='compact'?'🤏':info.cls==='wide'?'🙌':'👌');
    line(info.cls==='compact'?'Cosy in here. I\'ll keep out of the way.':info.cls==='wide'?'Ooh. Room to stretch.':'Just right.');
  }
  if(prev.input!==info.input&&!once.has(info.input)){ once.add(info.input);
    if(info.input==='pen') line('Pencil out. I\'ll stay clear of your hand.');
    else if(info.input==='mouse'&&prev.input!=='mouse') line('A mouse! Haven\'t seen one of those in ages.'); }
  /* the keyboard came up: hop above it */
  if(CFG.keyboard&&info.kb&&!prev.kb&&S.naviOn&&N.y>info.kbTop-50&&N.state!=='held'){
    H.travel(H.clamp(N.x,N.r,info.W-N.r),Math.max(90,info.kbTop-70),380,N.state==='perch'?'free':N.state==='sleep'?'free':'free');
    emote('⌨️'); if(!once.has('kb')){ once.add('kb'); line('Keyboard\'s up. Moving.'); }
  }
  if(info.preview&&!prev.preview&&!once.has('pv')){ once.add('pv'); line(`Pretending to be ${/Phone/.test(info.device)||info.cls==='compact'?'a phone':'a different screen'}. Convincing?`); }
});

/* ---------- Pip doesn't loiter on top of your stuff, or under the notch ---------- */
let lastRest=-1e9, restCheck=0;
H.frame.push((dt,t)=>{
  const info=SC.get(); if(!S.naviOn||!info) return;
  if(N.state==='free'&&info.safe.t>0&&N.y<info.safe.t+N.r){ N.y=info.safe.t+N.r; N.vy=Math.abs(N.vy)*.4; }
  if(!CFG.rest||t-restCheck<500) return; restCheck=t;
  if(!N.awake||N.state!=='free'||N.back||H.G.on||!H.grounded()||t-lastRest<8000||Math.hypot(N.vx,N.vy)>30||t-(N.lastInteract||0)<4000) return;
  const on=[...H.openEls(),document.getElementById('rail'),document.getElementById('tm')].filter(e=>e&&!e.hidden).some(e=>{ const r=H.rel(e); return N.x>r.left-4&&N.x<r.right+4&&N.y>r.top-4&&N.y<r.bottom+4; });
  if(!on) return; const p=nearestFree(N.x,N.y); if(!p) return;
  lastRest=t; H.travel(p.x,p.y,160,'free'); if(Math.random()<.4) emote('🙂',{pri:0});
});

/* ---------- guides overlay: breakpoints, safe areas, keyboard, the biggest free space ---------- */
const guides=document.createElement('div'); guides.className='scr-guides'; guides.hidden=true; guides.setAttribute('aria-hidden','true'); stage.appendChild(guides);
function drawGuides(){
  if(guides.hidden) return; const i=SC.get(), f=largestFree();
  guides.innerHTML=[[600,'600 · Compact | Regular'],[1100,'1100 · Regular | Wide']].filter(([x])=>x<i.W).map(([x,l])=>`<i class="bp" style="left:${x}px"><b>${l}</b></i>`).join('')
    +(i.safe.t?`<i class="safe" style="left:0;right:0;top:0;height:${i.safe.t}px"></i>`:'')+(i.safe.b?`<i class="safe" style="left:0;right:0;bottom:0;height:${i.safe.b}px"></i>`:'')
    +(i.kb?`<i class="kb" style="top:${i.kbTop}px"></i>`:'')
    +(f?`<i class="free" style="left:${f.left}px;top:${f.top}px;width:${f.width}px;height:${f.height}px"><b>Free space · ${f.width}×${f.height}</b></i>`:'');
}
let gT=0; H.frame.push((dt,t)=>{ if(!guides.hidden&&t-gT>400){ gT=t; drawGuides(); } });

/* ---------- device preview: squeeze the sandbox into another screen's shape ---------- */
const DEVICES=[['Phone',390,844],['Phone ↔',844,390],['Split ⅓',320,820],['Split ½',590,820],['iPad',820,1180],['iPad ↔',1180,820],['Laptop',1440,900]];
let pv=null;
const tag=document.createElement('div'); tag.className='scr-tag'; tag.hidden=true; document.body.appendChild(tag);
const grip=document.createElement('button'); grip.className='scr-grip'; grip.hidden=true; grip.textContent='⤡'; grip.setAttribute('aria-label','Resize preview'); document.body.appendChild(grip);
function fit(){
  if(!pv){ document.body.classList.remove('scr-preview'); stage.style.width=stage.style.height=''; tag.hidden=grip.hidden=true; }
  else {
    const w=Math.round(Math.min(pv.w,innerWidth-24)), h=Math.round(Math.min(pv.h,innerHeight-60));
    document.body.classList.add('scr-preview'); stage.style.width=w+'px'; stage.style.height=h+'px'; tag.hidden=grip.hidden=false;
    tag.innerHTML=`<span>${pv.name} · ${w}×${h}${w<pv.w||h<pv.h?` <span style="opacity:.6">(cropped from ${pv.w}×${pv.h})</span>`:''}</span><button data-x>Exit preview</button>`;
    requestAnimationFrame(()=>{ const r=stage.getBoundingClientRect(); grip.style.left=(r.right-14)+'px'; grip.style.top=(r.bottom-14)+'px'; });
  }
  dispatchEvent(new Event('resize')); SC.refresh(); sync();
}
const setPreview=p=>{ pv=p; fit(); };
tag.addEventListener('click',e=>{ if(e.target.closest('[data-x]')) setPreview(null); });
addEventListener('resize',e=>{ if(e.isTrusted&&pv) fit(); });
let gd=null;
grip.addEventListener('pointerdown',e=>{ e.preventDefault(); grip.setPointerCapture(e.pointerId); gd={x:e.clientX,y:e.clientY,w:stage.clientWidth,h:stage.clientHeight}; });
grip.addEventListener('pointermove',e=>{ if(!gd) return;
  pv={name:'Custom',w:Math.round(H.clamp(gd.w+(e.clientX-gd.x)*2,280,innerWidth-24)),h:Math.round(H.clamp(gd.h+(e.clientY-gd.y)*2,300,innerHeight-60))};
  if(!gd.raf) gd.raf=requestAnimationFrame(()=>{ if(gd) gd.raf=0; fit(); }); });
const gup=()=>{ gd=null; }; grip.addEventListener('pointerup',gup); grip.addEventListener('pointercancel',gup);

/* ---------- the 📐 card ---------- */
const card=PB.card(`<h3>📐 Screen</h3><div class="scr-now" id="scrNow"></div>
  <div class="lbl2">See</div><div class="pr"><button class="pc" id="scrGuides">Guides</button></div>
  <div class="lbl2">Preview as</div><div class="pr" id="scrDev"><button class="pc" data-d="-1">Your screen</button>${DEVICES.map((d,i)=>`<button class="pc" data-d="${i}">${d[0]}</button>`).join('')}<button class="pc" id="scrRot" aria-label="Rotate preview">⟳ Rotate</button></div>
  <p>Drag the ⤡ corner to resize freely, like a window on iPad. Previews use the stage size, so plugins that read the stage (like Adaptive Layout) react exactly as on the device.</p>
  <div class="lbl2">Pip</div>
  <label class="sw2">Reacts to rotating and resizing<input type="checkbox" class="switch" data-c="react"></label>
  <label class="sw2">Moves off panels when idle<input type="checkbox" class="switch" data-c="rest"></label>
  <label class="sw2">Hops above the keyboard<input type="checkbox" class="switch" data-c="keyboard"></label>`);
const btn=PB.button('📐','Screen',()=>{ if(PB.toggle(card,btn)) sync(); });
function sync(){
  const i=SC.get(); if(!i||card.hidden&&!pv) return;
  const s=i.safe, safe=s.t||s.r||s.b||s.l?`safe area ${s.t}/${s.r}/${s.b}/${s.l}`:'no safe-area insets';
  card.querySelector('#scrNow').innerHTML=`${i.device} · ${{compact:'Compact',regular:'Regular',wide:'Wide'}[i.cls]}${i.short?' · Short':''} · ${i.orient==='portrait'?'Portrait':'Landscape'}<small>${i.W}×${i.H} · ${i.input} · ${i.dpr}× · ${safe}${i.kb?' · keyboard up':''}</small>`;
  card.querySelectorAll('[data-d]').forEach(b=>b.classList.toggle('on',+b.dataset.d===-1?!pv:!!pv&&DEVICES[+b.dataset.d][0]===pv.name));
  card.querySelector('#scrGuides').classList.toggle('on',!guides.hidden);
  card.querySelectorAll('[data-c]').forEach(c=>{ c.checked=!!CFG[c.dataset.c]; });
}
card.addEventListener('click',e=>{
  const d=e.target.closest('[data-d]');
  if(d){ const k=+d.dataset.d; setPreview(k<0?null:{name:DEVICES[k][0],w:DEVICES[k][1],h:DEVICES[k][2]}); return; }
  if(e.target.closest('#scrRot')&&pv){ const m=DEVICES.find(x=>x[1]===pv.h&&x[2]===pv.w); setPreview({name:m?m[0]:pv.name,w:pv.h,h:pv.w}); return; }
  if(e.target.closest('#scrGuides')){ guides.hidden=!guides.hidden; drawGuides(); sync(); }
});
card.addEventListener('change',e=>{ const c=e.target.closest('[data-c]'); if(c){ CFG[c.dataset.c]=c.checked; saveCfg(); } });
SC.on(()=>{ sync(); drawGuides(); });
window.PipScreen={get:SC.get,on:SC.on,largestFree,nearestFree,preview:setPreview,config:CFG};
})();
