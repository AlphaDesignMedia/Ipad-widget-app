/* =====================================================================
  WEATHER WINDOW · plugin v1
  Loaded by the sandbox loader (see PLUGINS in index.html). Needs window.PipHost (host.js).
  Works on its own. Plays nicely with the other plugins; with Spatial installed,
  Pip also reacts with emoji bubbles.
  Where: (no button)

  Panels you leave alone slowly fog up. Draw in the fog with your finger or Pencil;
  Pip answers by tracing a heart, circle or star in the mist. Off under Simpler effects.

  Switch it off in the Plugins panel, or remove it from PLUGINS.
  =====================================================================
*/
(() => {
const H=window.PipHost;
if(!H||!H.openPanel){ console.warn('WEATHER WINDOW: needs Pip Sandbox V2 stage 11.5 or later.'); return; }
const {N,S,stage,navi}=H;
if(H.registerPlugin&&!H.registerPlugin({id:'weather',name:'Weather Window',icon:'🌫️',shelf:'dream',desc:'Idle panels fog up; draw in the mist and Pip draws back.'})) return;
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

/* Panels fog up when left alone. Draw in the fog; Pip doodles back. */
const CFG={fogAfter:15000, fogMax:.62, regrow:.018};
const st=document.createElement('style'); st.textContent=`.fogc{position:absolute;inset:0;width:100%;height:100%;z-index:2;pointer-events:none;border-radius:inherit}`; document.head.appendChild(st);
const fog=new Map();   // panel → {cv,ctx,level,touched,w,h}
function ensure(p){ let f=fog.get(p); const w=p.offsetWidth,h=p.offsetHeight; if(!f){ const cv=document.createElement('canvas'); cv.className='fogc'; p.appendChild(cv); f={cv,ctx:cv.getContext('2d'),level:0,touched:H.now(),w:0,h:0}; fog.set(p,f); }
  if(f.w!==w||f.h!==h){ f.w=w; f.h=h; f.cv.width=w; f.cv.height=h; paint(f,1); } return f; }
function paint(f,amt){ const c=f.ctx; c.globalCompositeOperation='source-over'; c.fillStyle=`rgba(225,232,240,${(amt*.06).toFixed(3)})`; c.fillRect(0,0,f.w,f.h); }
H.frame.push((dt,t)=>{
  if(H.simpler()) return;
  H.openEls().forEach(p=>{ const f=ensure(p);
    if(t-f.touched>CFG.fogAfter&&f.level<CFG.fogMax){ f.level=Math.min(CFG.fogMax,f.level+CFG.regrow*dt*10); paint(f,CFG.regrow*10*dt*4); if(f.level>.3&&!f.told){ f.told=true; if(Math.random()<.5) H.say('It\'s getting misty. Draw something?',2000,null,2); } }
    f.cv.style.opacity=Math.min(1,f.level/CFG.fogMax).toFixed(2); });
});
let drawing=null;
function wipe(f,x,y,px,py,r=11){ const c=f.ctx; c.globalCompositeOperation='destination-out'; c.lineCap='round'; c.lineWidth=r*2; c.beginPath(); c.moveTo(px,py); c.lineTo(x,y); c.stroke(); }
stage.addEventListener('pointerdown',e=>{
  const p=e.target.closest('.panel'); if(!p||e.target.closest('button,input,label,.drill,.ph,.sw,.mseg,.look-tile,.pers')) return;
  const f=fog.get(p); if(!f) return; f.touched=H.now(); if(f.level<.25) return;
  e.stopPropagation(); const r=p.getBoundingClientRect(); drawing={p,f,px:e.clientX-r.left,py:e.clientY-r.top,len:0}; p.setPointerCapture(e.pointerId);
},true);
stage.addEventListener('pointermove',e=>{ if(!drawing) return; const r=drawing.p.getBoundingClientRect(), x=e.clientX-r.left, y=e.clientY-r.top;
  wipe(drawing.f,x,y,drawing.px,drawing.py); drawing.len+=Math.hypot(x-drawing.px,y-drawing.py); drawing.px=x; drawing.py=y; },true);
stage.addEventListener('pointerup',()=>{ if(!drawing) return; const d=drawing; drawing=null; d.f.touched=H.now(); if(d.len>120) setTimeout(()=>doodle(d.p,d.f),700); },true);
/* Pip answers with a little heart, a smiley or a star, traced in the fog */
const SHAPES=[t=>[16*Math.pow(Math.sin(t),3),-(13*Math.cos(t)-5*Math.cos(2*t)-2*Math.cos(3*t)-Math.cos(4*t))],t=>[Math.cos(t)*16,Math.sin(t)*16],t=>{const k=Math.floor(t/(Math.PI*2)*10),r=k%2?7:17,a=k/10*Math.PI*2;return[Math.cos(a-Math.PI/2)*r,Math.sin(a-Math.PI/2)*r];}];
function doodle(p,f){
  if(!S.naviOn||!N.awake||f.level<.2) return; const r=H.rel(p), cx=20+Math.random()*(r.width-40), cy=60+Math.random()*(r.height-90), sh=H.pick(SHAPES);
  N.lookPt={x:r.left+cx,y:r.top+cy}; N.lookUntil=H.now()+2500; emote('✍️'); H.say(H.pick(['My turn.','I can draw too.','Look!']),1300,null,2);
  let i=0, prev=null; const steps=40, iv=setInterval(()=>{ const [dx,dy]=sh(i/steps*Math.PI*2), x=cx+dx, y=cy+dy; if(prev) wipe(f,x,y,prev[0],prev[1],4); prev=[x,y]; if(++i>steps){ clearInterval(iv); emote(H.pick(['😊','💕','⭐'])); } },35);
}
window.PipWeather={fog};

})();
