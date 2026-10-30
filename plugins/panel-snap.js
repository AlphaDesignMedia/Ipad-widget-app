/* =====================================================================
  PANEL SNAP · plugin v1   (Trial shelf)
  Loaded by the sandbox loader (see PLUGINS in index.html). Where: 🧲 in the plugin bar.
  - Drag a panel by its title to a screen edge (column) or corner (quarter), or the top (centre): it snaps.
  - Magnetic edges line panels up with the screen and each other. Fast flicks still fly.
  - Corner grip resizes, with detents at 272 / 340 / 420 / 520 and at 'fits content'. Double-tap resets.
  - Sizes are remembered per panel. Save up to three layouts and open them again.
  - Switches for everything, plus the gap between panels.
  Remove the block to remove the plugin.
  ===================================================================== */
(() => {
const H=window.PipHost;
if(!H||!H.registerPlugin){ console.warn('Panel Snap: needs Pip Sandbox V2 stage 12 or later.'); return; }
const {N,S,stage,navi}=H;
if(!H.registerPlugin({id:'snap',name:'Panel Snap',icon:'🧲',shelf:'trial',desc:'Drag panels to edges and corners to snap; magnetic edges; corner grip resizes; three saved layouts.'})) return;
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
/* PANEL SNAP: drag a panel to an edge or corner and it snaps into place; a corner grip resizes it; save layouts. */
const CFG=Object.assign({zones:true,magnet:true,grips:true,gap:12},H.store.get('snap-cfg',{}));
const saveCfg=()=>H.store.set('snap-cfg',CFG);
const sizes=H.store.get('snap-size',{});
const panelsEl=document.getElementById('panels'), rail=document.getElementById('rail'), tm=document.getElementById('tm');
const css=document.createElement('style'); css.textContent=`
.snap-ghost{position:absolute;z-index:19;border-radius:26px;pointer-events:none;border:2px solid color-mix(in srgb,var(--accent) 70%,transparent);background:color-mix(in srgb,var(--accent) 12%,transparent);
  -webkit-backdrop-filter:blur(6px);backdrop-filter:blur(6px);opacity:0;transition:opacity .15s, left .18s, top .18s, width .18s, height .18s}
.snap-ghost.on{opacity:1}
.snap-ghost b{position:absolute;left:14px;top:12px;font:600 12px/1 var(--ui);color:var(--accent)}
.panel.snap-sized{max-height:none !important}
.panel.snap-sized>.pb{flex:1 1 auto;min-height:0}
.snap-grip{position:absolute;right:3px;bottom:3px;z-index:3;width:22px;height:22px;border-radius:0 0 20px 0;cursor:nwse-resize;touch-action:none;opacity:.45;transition:opacity .2s;
  background:linear-gradient(135deg,transparent 52%,var(--ink3) 52% 58%,transparent 58% 68%,var(--ink3) 68% 74%,transparent 74%)}
.snap-grip:hover,.snap-grip.on{opacity:1}
.stage:not(.snap-grips) .snap-grip,.stage.ad-sheet .snap-grip{display:none}
.snap-flash{animation:snapFlash .35s ease-out}
@keyframes snapFlash{from{box-shadow:0 0 0 3px var(--accent)}}
.plugcard .snap-slots{display:grid;grid-template-columns:auto 1fr auto auto;gap:6px;align-items:center;font:600 13px/1 var(--ui)}
.plugcard .snap-slots small{font-weight:400;color:var(--ink3)}
@media (prefers-reduced-motion: reduce){ .snap-ghost{transition:opacity .15s} .snap-flash{animation:none} }`;
document.head.appendChild(css);
stage.classList.toggle('snap-grips',CFG.grips);

const off=()=>window.PipAdaptive?.sheetMode?.();
const idOf=el=>el.id.replace(/^p-/,'');
const bounds=()=>{ const W=stage.clientWidth, g=CFG.gap, rr=H.rel(rail), e=rail.dataset.edge;
  let l=g, r=W-g, t=64, b=stage.clientHeight-(tm&&!tm.hidden?tm.offsetHeight+16:0)-g;
  if(e==='left') l=rr.right+g; if(e==='right') r=rr.left-g; if(e==='bottom') b=Math.min(b,rr.top-g); if(e==='top') t=Math.max(t,rr.bottom+g);
  return {l,r,t,b,W,g}; };

/* ---------- zones ---------- */
function zoneAt(x,y){
  const B=bounds(), g=B.g, w=B.r-B.l, h=B.b-B.t, col=H.clamp(Math.round(w*.3),280,420), qw=(w-g)/2, qh=(h-g)/2, E=44;
  const L=x<B.l+E, R=x>B.r-E, T=y<B.t+E, D=y>B.b-E;
  if(L&&T) return {name:'Top left',l:B.l,t:B.t,w:qw,h:qh};
  if(R&&T) return {name:'Top right',l:B.l+qw+g,t:B.t,w:qw,h:qh};
  if(L&&D) return {name:'Bottom left',l:B.l,t:B.t+qh+g,w:qw,h:qh};
  if(R&&D) return {name:'Bottom right',l:B.l+qw+g,t:B.t+qh+g,w:qw,h:qh};
  if(L) return {name:'Left column',l:B.l,t:B.t,w:col,h};
  if(R) return {name:'Right column',l:B.r-col,t:B.t,w:col,h};
  if(T) { const cw=Math.min(640,Math.round(w*.6)); return {name:'Centre',l:B.l+(w-cw)/2,t:B.t,w:cw,h:Math.round(h*.8)}; }
  return null;
}
const ghost=document.createElement('div'); ghost.className='snap-ghost'; ghost.setAttribute('aria-hidden','true'); panelsEl.before(ghost);
function showGhost(z){ ghost.classList.toggle('on',!!z); if(!z) return;
  Object.assign(ghost.style,{left:z.l+'px',top:z.t+'px',width:z.w+'px',height:z.h+'px'}); ghost.innerHTML=`<b>${z.name}</b>`; }
function setSize(el,w,h,keep=true){
  const B=bounds(); w=Math.round(H.clamp(w,220,B.r-B.l)); h=Math.round(H.clamp(h,150,B.b-B.t));
  el.style.width=w+'px'; el.style.height=h+'px'; el.classList.add('snap-sized');
  if(keep){ sizes[idOf(el)]={w,h}; H.store.set('snap-size',sizes); }
}
function clearSize(el){ el.style.width=el.style.height=''; el.classList.remove('snap-sized'); delete sizes[idOf(el)]; H.store.set('snap-size',sizes); }
function place(el,x,y){ const B=bounds(); el.style.left=H.clamp(x,8,Math.max(8,B.W-el.offsetWidth-8))+'px'; el.style.top=H.clamp(y,64,Math.max(64,B.b-el.offsetHeight))+'px'; }

/* ---------- magnets: edges line up with the screen and with each other ---------- */
function magnet(el){
  const B=bounds(), r=H.rel(el), M=10, xs=[B.l,B.r-r.width], ys=[B.t,B.b-r.height];
  H.openEls().forEach(o=>{ if(o===el||o.classList.contains('ad-under')) return; const q=H.rel(o);
    xs.push(q.left,q.right+B.g,q.left-B.g-r.width,q.right-r.width); ys.push(q.top,q.bottom+B.g,q.top-B.g-r.height,q.bottom-r.height); });
  const bx=xs.reduce((a,v)=>Math.abs(v-r.left)<Math.abs(a-r.left)?v:a,1e9), by=ys.reduce((a,v)=>Math.abs(v-r.top)<Math.abs(a-r.top)?v:a,1e9);
  if(Math.abs(bx-r.left)<M) el.style.left=bx+'px'; if(Math.abs(by-r.top)<M) el.style.top=by+'px';
}

/* ---------- watch panel drags (the sandbox moves the panel; we add zones and magnets) ---------- */
let drag=null;
panelsEl.addEventListener('pointerdown',e=>{ const h=e.target.closest('.ph'); if(!h||e.target.closest('button')||off()) return;
  drag={el:h.closest('.panel'),sx:e.clientX,sy:e.clientY,lx:e.clientX,ly:e.clientY,lt:H.now(),v:0,zone:null,moved:false}; },true);
addEventListener('pointermove',e=>{ if(!drag) return; const t=H.now(), dt=Math.max(8,t-drag.lt)/1000;
  drag.v=Math.hypot(e.clientX-drag.lx,e.clientY-drag.ly)/dt; drag.lx=e.clientX; drag.ly=e.clientY; drag.lt=t;
  if(Math.hypot(e.clientX-drag.sx,e.clientY-drag.sy)>6) drag.moved=true; if(!drag.moved) return;
  const SR=stage.getBoundingClientRect(), z=CFG.zones?zoneAt(e.clientX-SR.left,e.clientY-SR.top):null;
  if(z?.name!==drag.zone?.name){ showGhost(z); if(z&&navigator.vibrate) try{navigator.vibrate(5);}catch{} } drag.zone=z;
  if(!z&&CFG.magnet) magnet(drag.el); });
const end=()=>{ if(!drag) return; const d=drag; drag=null; showGhost(null);
  if(!d.moved||!d.zone||(H.now()-d.lt<70&&d.v>500)) return;    /* a fast flick stays a flick */
  const z=d.zone, el=d.el, x0=parseFloat(el.style.left), y0=parseFloat(el.style.top);
  setSize(el,z.w,z.h); el.style.left=z.l+'px'; el.style.top=z.t+'px';
  /* docked child panels come along */
  const dx=z.l-x0, dy=z.t-y0; H.openEls().filter(o=>o!==el&&o.classList.contains('child')).forEach(o=>{ const q=H.rel(o), p=H.rel(el);
    if(Math.abs(q.top-(p.top-dy))<6) place(o,parseFloat(o.style.left)+dx,parseFloat(o.style.top)+dy); });
  if(!H.simpler()){ el.classList.remove('snap-flash'); void el.offsetWidth; el.classList.add('snap-flash'); }
  H.beep([[880,25]]);
  if(S.naviOn&&N.awake&&Math.random()<.25) emote('🧲');
};
addEventListener('pointerup',end); addEventListener('pointercancel',end);

/* ---------- resize grips ---------- */
function addGrip(el){
  if(el.querySelector('.snap-grip')) return;
  const g=document.createElement('i'); g.className='snap-grip'; g.setAttribute('aria-hidden','true'); el.appendChild(g);
  let r=null, lastTap=0;
  g.addEventListener('pointerdown',e=>{ e.stopPropagation(); e.preventDefault(); g.setPointerCapture(e.pointerId); g.classList.add('on');
    const t=H.now(); if(t-lastTap<300){ clearSize(el); r=null; return; } lastTap=t;
    r={x:e.clientX,y:e.clientY,w:el.offsetWidth,h:el.offsetHeight}; });
  g.addEventListener('pointermove',e=>{ if(!r) return; let w=r.w+e.clientX-r.x, h=r.h+e.clientY-r.y;
    for(const s of [272,340,420,520]) if(Math.abs(w-s)<12) w=s;   /* gentle detents at common widths */
    const fit=el.querySelector('.ph').offsetHeight+el.querySelector('.pb').scrollHeight; if(Math.abs(h-fit)<16) h=fit;
    setSize(el,w,h,false); });
  const up=()=>{ g.classList.remove('on'); if(!r) return; r=null; setSize(el,el.offsetWidth,el.offsetHeight); };
  g.addEventListener('pointerup',up); g.addEventListener('pointercancel',up);
}
function restoreSize(el){ const s=sizes[idOf(el)]; if(!s||off()) return; setSize(el,s.w,s.h,false); place(el,parseFloat(el.style.left)||0,parseFloat(el.style.top)||0); }
new MutationObserver(ms=>ms.forEach(m=>{
  m.addedNodes?.forEach(n=>{ if(n.classList?.contains('panel')){ addGrip(n); if(!n.hidden) restoreSize(n); } });
  if(m.type==='attributes'&&m.target.classList.contains('panel')&&!m.target.hidden) restoreSize(m.target);
})).observe(panelsEl,{childList:true,attributes:true,attributeFilter:['hidden']});
panelsEl.querySelectorAll('.panel').forEach(p=>{ addGrip(p); if(!p.hidden) restoreSize(p); });

/* ---------- layouts: save what's open, where, and how big ---------- */
const slots=H.store.get('snap-layouts',[null,null,null]);
function saveSlot(i){ slots[i]={when:new Date().toLocaleDateString('en-GB',{day:'numeric',month:'short'}),rail:rail.dataset.edge,
  panels:H.openEls().map(el=>({id:idOf(el),x:parseFloat(el.style.left)||0,y:parseFloat(el.style.top)||0,w:el.classList.contains('snap-sized')?el.offsetWidth:0,h:el.classList.contains('snap-sized')?el.offsetHeight:0}))};
  H.store.set('snap-layouts',slots); sync(); }
function loadSlot(i){ const s=slots[i]; if(!s) return;
  H.openEls().slice().reverse().forEach(el=>el.querySelector('[data-close]')?.click());
  s.panels.forEach(p=>{ try{ H.openPanel(p.id,{at:{x:p.x,y:p.y}}); }catch{ return; } const el=document.getElementById('p-'+p.id); if(!el) return;
    if(p.w) setSize(el,p.w,p.h); else clearSize(el); el.style.left=p.x+'px'; el.style.top=p.y+'px'; });
  if(S.naviOn&&N.awake) H.say(`Layout ${i+1}. Everything back where you had it.`,1800,null,2); }

/* ---------- the 🧲 card ---------- */
const card=PB.card(`<h3>🧲 Panels</h3>
  <p>Drag a panel by its title to a screen edge or corner and let go: it snaps. Drag the corner grip to resize; double-tap the grip to reset. Fast flicks still fly.</p>
  <label class="sw2" style="display:flex;justify-content:space-between;gap:10px;font:500 13.5px/1.3 var(--ui)">Snap zones at edges and corners<input type="checkbox" class="switch" data-c="zones"></label>
  <label class="sw2" style="display:flex;justify-content:space-between;gap:10px;font:500 13.5px/1.3 var(--ui)">Magnetic edges<input type="checkbox" class="switch" data-c="magnet"></label>
  <label class="sw2" style="display:flex;justify-content:space-between;gap:10px;font:500 13.5px/1.3 var(--ui)">Resize grips<input type="checkbox" class="switch" data-c="grips"></label>
  <label style="display:grid;gap:6px;font:500 13.5px/1.3 var(--ui)">Gap between panels <span id="snapGapV" style="color:var(--ink3)"></span><input type="range" min="4" max="28" step="2" id="snapGap"></label>
  <div style="font:700 11px/1 var(--ui);letter-spacing:.06em;text-transform:uppercase;color:var(--ink3)">Layouts</div>
  <div class="snap-slots" id="snapSlots"></div>
  <div class="pr"><button class="pc" id="snapReset">Reset all panel sizes</button></div>`);
const btn=PB.button('🧲','Panels',()=>{ if(PB.toggle(card,btn)) sync(); });
function sync(){
  if(card.hidden) return;
  card.querySelectorAll('[data-c]').forEach(c=>{ c.checked=!!CFG[c.dataset.c]; });
  const gp=card.querySelector('#snapGap'); gp.value=CFG.gap; card.querySelector('#snapGapV').textContent=CFG.gap+'px'; gp.style.setProperty('--pct',((CFG.gap-4)/24*100)+'%');
  card.querySelector('#snapSlots').innerHTML=slots.map((s,i)=>`<b>${i+1}</b><small>${s?`${s.panels.length} panel${s.panels.length===1?'':'s'} · ${s.when}`:'Empty'}</small>
    <button class="pc" data-save="${i}">Save</button><button class="pc" data-load="${i}" ${s?'':'disabled style="opacity:.35"'}>Open</button>`).join('');
}
card.addEventListener('click',e=>{ const s=e.target.closest('[data-save]'), l=e.target.closest('[data-load]');
  if(s) saveSlot(+s.dataset.save); if(l) loadSlot(+l.dataset.load);
  if(e.target.closest('#snapReset')){ panelsEl.querySelectorAll('.panel').forEach(clearSize); for(const k in sizes) delete sizes[k]; H.store.set('snap-size',sizes); } });
card.addEventListener('change',e=>{ const c=e.target.closest('[data-c]'); if(!c) return; CFG[c.dataset.c]=c.checked; saveCfg(); stage.classList.toggle('snap-grips',CFG.grips); });
card.addEventListener('input',e=>{ if(e.target.id==='snapGap'){ CFG.gap=+e.target.value; saveCfg(); sync(); } });
window.PipSnap={config:CFG,zoneAt,setSize,saveSlot,loadSlot};
})();
