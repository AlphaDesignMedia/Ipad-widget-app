/* =====================================================================
  PANEL FLAP · plugin v1
  Loaded by the sandbox loader (see PLUGINS in index.html). Needs window.PipHost (host.js).
  Works alone, and works with the Spatial plugin (emoji bubbles) if present.

  When the clock shatters, Pip flies a flappy ORBIT around it.
  - The clock's gravity pulls Pip in. Tap anywhere (or Space) to flap outward.
  - Your open panels are the obstacles. The digit shards float on the orbit.
  - Collect them all and the clock rebuilds.
  - Bonking a panel or the clock never ends the game: Pip bounces, 💫, keeps going.
  Extras: double-tap reverses direction 🔄 · near misses 😬 · combo pickups 🔥
          one bonus teacup per round = 2s slow motion ☕ · personality changes
          the physics · a Flappy ⇄ Slingshot switch on the 404 face.
  Tune it in PANEL_FLAP below.
  =====================================================================
*/
(() => {
const PANEL_FLAP={
  mode:'flap',      // 'flap' or 'slingshot' (the original). Switchable on the 404 face.
  speed:165,        // px/s along the orbit
  gravity:560,      // pull toward the clock, px/s²
  flap:270,         // outward kick per tap, px/s
  tea:true          // one bonus teacup per round
};
const H=window.PipHost;
if(!H||!H.collectCheck){ console.warn('Panel Flap: needs Pip Sandbox V2 stage 11.4 or later.'); return; }
const {N,G,stage,navi}=H;
if(H.registerPlugin&&!H.registerPlugin({id:'flap',name:'Panel Flap',icon:'🐦',shelf:'dream',desc:'The crash game as a flappy orbit around the broken clock.'})) return;
const emote=(c,o)=>window.PipSpatial?.emote(c,o);

const css=document.createElement('style'); css.textContent=`
.flap-ring{position:absolute;left:0;top:0;z-index:12;border-radius:50%;pointer-events:none;border:1.5px dashed color-mix(in srgb, var(--accent) 55%, transparent);opacity:.55}
.flap-ring.inner{border-style:solid;opacity:.18}
.navi.flapping .wing{opacity:.9 !important;animation-duration:.11s !important}
.flap-puff{position:absolute;left:0;top:0;z-index:13;width:10px;height:10px;border-radius:50%;pointer-events:none;background:color-mix(in srgb, var(--accent) 35%, rgba(255,255,255,.8))}
.flap-tea{position:absolute;left:0;top:0;z-index:13;width:34px;height:34px;display:grid;place-items:center;font-size:20px;border-radius:50%;pointer-events:none;
  background:color-mix(in srgb, var(--accent) 10%, var(--glass-strong));box-shadow:inset 1px 1px 0 rgba(255,255,255,.8), 0 4px 12px rgba(0,0,0,.15);animation:teaBob 1.6s ease-in-out infinite}
@keyframes teaBob{50%{translate:0 -5px}}
.flap-switch{margin-top:6px;min-height:32px;border:0;border-radius:999px;padding:0 14px;background:rgba(255,255,255,.2);color:inherit;font:600 12.5px/1 var(--ui);cursor:pointer}
@media (prefers-reduced-motion: reduce){ .flap-tea{animation:none} }`;
document.head.appendChild(css);

const ring=document.createElement('i'); ring.className='flap-ring'; ring.hidden=true; stage.appendChild(ring);
const inner=document.createElement('i'); inner.className='flap-ring inner'; inner.hidden=true; stage.appendChild(inner);
const F={on:false,th:0,r:0,vr:0,dir:1,lastTap:-1e9,bonkUntil:0,slowUntil:0,near:new WeakMap(),combo:0,lastGet:-1e9,tea:null,teaAt:0,t0:0};

/* the switch on the 404 face */
const err=document.getElementById('err');
const sw=document.createElement('button'); sw.className='flap-switch'; err.appendChild(sw);
const label=()=>{ sw.textContent=PANEL_FLAP.mode==='flap'?'Game: Flappy ⇄':'Game: Slingshot ⇄'; };
label();
sw.addEventListener('pointerdown',e=>e.stopPropagation());
sw.addEventListener('click',()=>{ PANEL_FLAP.mode=PANEL_FLAP.mode==='flap'?'slingshot':'flap'; label();
  if(G.on){ if(PANEL_FLAP.mode==='flap') start(); else stop(true); } });

function start(){
  if(!G.on||F.on||!H.S.naviOn) return;
  const c=H.cardCentre(), cr=H.cardRect();
  G.custom=true; F.on=true; F.dir=1; F.vr=0; F.combo=0; F.t0=H.now(); F.teaAt=H.now()+6000; F.tea=null;
  F.th=Math.atan2(N.y-c.y,N.x-c.x); F.r=Math.max(Math.hypot(N.x-c.x,N.y-c.y),Math.hypot(cr.width,cr.height)/2+N.r+14);
  N.state='flap'; N.back=false; navi.classList.add('flapping'); ring.hidden=inner.hidden=false;
  const cv=document.getElementById('trail'), wipe=()=>{ const x=cv.getContext('2d'); x.setTransform(1,0,0,1,0,0); x.clearRect(0,0,cv.width,cv.height); };
  wipe(); requestAnimationFrame(wipe);   /* clear the slingshot's tether, drawn before we took over */
  setTimeout(()=>H.say('Flappy time! Tap anywhere to flap. The clock pulls me in.',3200,null,0),900);
}
function stop(toSling){
  if(!F.on) return; F.on=false; G.custom=false; navi.classList.remove('flapping'); ring.hidden=inner.hidden=true;
  F.tea?.remove(); F.tea=null; if(N.state==='flap'){ N.state='free'; N.vx=N.vy=0; }
  if(toSling&&G.on) H.say('Slingshot it is. Pull me back and let go.',2000,null,0);
}
window.addEventListener('pip:crash',()=>{ if(PANEL_FLAP.mode==='flap') setTimeout(start,60); });
window.addEventListener('pip:restore',()=>stop(false));
window.addEventListener('pip:collect',()=>{ const t=H.now(); F.combo=t-F.lastGet<2600?F.combo+1:1; F.lastGet=t; if(F.on&&F.combo>=2) setTimeout(()=>emote(F.combo>=3?'🔥🔥':'🔥',{pri:3}),250); });

/* controls: tap anywhere flaps; double-tap reverses; Space flaps */
function flap(){
  const t=H.now();
  if(t-F.lastTap<260){ F.dir*=-1; emote('🔄',{pri:2}); }
  F.lastTap=t; const k=Math.pow(H.persona().bounce,.35);
  F.vr=Math.max(F.vr,0)*.3+PANEL_FLAP.flap*k; N.squash=.25; N.hopT=t; H.beep([[740,30]]);
  if(!H.simpler()){ const p=document.createElement('i'); p.className='flap-puff'; stage.appendChild(p); const c=H.cardCentre(), a=F.th;
    const x=N.x-Math.cos(a)*10, y=N.y-Math.sin(a)*10;
    p.animate([{transform:`translate(${x-5}px,${y-5}px) scale(1)`,opacity:.8},{transform:`translate(${x-5-Math.cos(a)*24}px,${y-5-Math.sin(a)*24}px) scale(2.2)`,opacity:0}],{duration:420,easing:'ease-out'}).onfinish=()=>p.remove(); }
}
stage.addEventListener('pointerdown',e=>{
  if(!F.on) return; if(e.target.closest('#err,.tm,.topbar')) return;
  e.stopPropagation(); e.preventDefault(); flap();
},true);
window.addEventListener('keydown',e=>{ if(F.on&&e.code==='Space'){ e.preventDefault(); flap(); } });

/* the orbit */
H.frame.push((dt,t)=>{
  if(!F.on) return;
  if(!G.on){ stop(false); return; }
  const c=H.cardCentre(), cr=H.cardRect(), pers=H.persona(), slow=t<F.slowUntil?.45:1;
  const d=dt*slow, minR=24, maxR=G.L;
  ring.style.width=ring.style.height=(maxR*2)+'px'; ring.style.transform=`translate(${c.x-maxR}px,${c.y-maxR}px)`;
  const ir=Math.hypot(cr.width,cr.height)/2+6; inner.style.width=inner.style.height=(ir*2)+'px'; inner.style.transform=`translate(${c.x-ir}px,${c.y-ir}px)`;
  const prev={th:F.th,r:F.r};
  F.vr-=PANEL_FLAP.gravity*(pers.bounce<.8?.8:1)*d; F.r+=F.vr*d;
  F.th+=F.dir*PANEL_FLAP.speed*d/Math.max(F.r,60);
  if(F.r>maxR){ F.r=maxR; F.vr=-Math.abs(F.vr)*.3; }
  if(F.r<minR){ F.r=minR; F.vr=Math.abs(F.vr)*.5+120; }
  let x=c.x+Math.cos(F.th)*F.r, y=c.y+Math.sin(F.th)*F.r;
  /* bonk: panels, the clock, the screen edges */
  const W=stage.clientWidth, Hh=stage.clientHeight, obstacles=H.openEls().map(e=>({el:e,r:H.rel(e)})).concat([{el:null,r:cr}]);
  let hit=null;
  for(const o of obstacles){ const r=o.r, inside=x>r.left-N.r&&x<r.right+N.r&&y>r.top-N.r&&y<r.bottom+N.r;
    if(inside){ hit=o; break; }
    const nearMiss=x>r.left-N.r-14&&x<r.right+N.r+14&&y>r.top-N.r-14&&y<r.bottom+N.r+14;
    if(nearMiss&&o.el&&t>F.bonkUntil&&t-(F.near.get(o.el)||-1e9)>2500){ F.near.set(o.el,t); emote('😬'); } }
  if(!hit&&(x<N.r||x>W-N.r||y<64||y>Hh-N.r)) hit={el:null,r:null};
  if(hit){
    F.th=prev.th; F.r=prev.r; F.vr=-F.vr*.35; x=c.x+Math.cos(F.th)*F.r; y=c.y+Math.sin(F.th)*F.r;
    if(t>F.bonkUntil){ F.bonkUntil=t+450; N.dizzyUntil=t+700; N.squash=.3; emote('💫',{pri:2}); H.beep([[160,40]]); F.combo=0;
      if(hit.el&&!H.simpler()) hit.el.animate([{translate:'0 0'},{translate:`${Math.cos(F.th)*5}px ${Math.sin(F.th)*5}px`},{translate:'0 0'}],{duration:220});
      H.emit('flapBonk',{el:hit.el}); }
    F.dir*=hit.el===null&&hit.r===cr?1:-1;   /* bounce back the other way off panels and edges */
  }
  N.vx=-Math.sin(F.th)*F.dir*PANEL_FLAP.speed+Math.cos(F.th)*F.vr; N.vy=Math.cos(F.th)*F.dir*PANEL_FLAP.speed+Math.sin(F.th)*F.vr;
  N.x=x; N.y=y;
  H.collectCheck();
  /* bonus teacup: once a round, somewhere on the orbit */
  if(PANEL_FLAP.tea&&!F.tea&&F.teaAt&&t>F.teaAt){ F.teaAt=0; const a=Math.random()*Math.PI*2, rr=maxR*(.45+Math.random()*.4);
    const tx=H.clamp(c.x+Math.cos(a)*rr,30,W-30), ty=H.clamp(c.y+Math.sin(a)*rr,80,Hh-30);
    F.tea=document.createElement('i'); F.tea.className='flap-tea'; F.tea.textContent='☕'; F.tea.style.left=(tx-17)+'px'; F.tea.style.top=(ty-17)+'px'; F.tea._x=tx; F.tea._y=ty; stage.appendChild(F.tea); }
  if(F.tea&&Math.hypot(N.x-F.tea._x,N.y-F.tea._y)<N.r+18){ F.tea.remove(); F.tea=null; F.slowUntil=t+2200; emote('😌',{pri:3,ms:1800}); H.say('Tea break. Everything slows down.',1600,null,0); }
});
window.PanelFlap={config:PANEL_FLAP,start,stop};
})();
