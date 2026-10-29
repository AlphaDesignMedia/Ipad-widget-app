/* =====================================================================
  SHADOW PUPPETS · plugin v1
  Loaded by the sandbox loader (see PLUGINS in index.html). Needs window.PipHost (host.js).
  Works on its own. Plays nicely with the other plugins; with Spatial installed,
  Pip also reacts with emoji bubbles.
  Where: (no button)

  Pip casts a soft shadow onto the panel or clock behind them. The light comes from your
  finger: move it and the shadow swings. Higher flight = softer, further shadow. Behind glass = no shadow.

  Switch it off in the Plugins panel, or remove it from PLUGINS.
  =====================================================================
*/
(() => {
const H=window.PipHost;
if(!H||!H.openPanel){ console.warn('SHADOW PUPPETS: needs Pip Sandbox V2 stage 11.5 or later.'); return; }
const {N,S,stage,navi}=H;
if(H.registerPlugin&&!H.registerPlugin({id:'shadow',name:'Shadow Puppets',icon:'🌗',shelf:'grounded',desc:'A soft shadow under Pip, lit from your finger.'})) return;
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

/* A soft shadow of Pip falls on whatever surface is behind them. The light comes from your finger. */
const st=document.createElement('style'); st.textContent=`.pipshadow{position:absolute;left:0;top:0;z-index:29;border-radius:50%;pointer-events:none;background:radial-gradient(closest-side, rgba(10,10,30,.32), rgba(10,10,30,0));opacity:0;transition:opacity .25s}`; document.head.appendChild(st);
const sh=document.createElement('i'); sh.className='pipshadow'; stage.appendChild(sh);
let lx=-1,ly=-1;
H.frame.push(()=>{
  if(!S.naviOn||N.back){ sh.style.opacity=0; return; }
  const surfaces=H.openEls().map(e=>H.rel(e)).concat([H.cardRect()]);
  const on=surfaces.find(r=>N.x>r.left-4&&N.x<r.right+4&&N.y>r.top-N.r*2&&N.y<r.bottom+4);
  if(!on||N.back){ sh.style.opacity=0; return; }
  /* height above the glass: perched = low; flying = higher, so the shadow drifts and softens */
  const height=N.state==='perch'||N.state==='sleep'?4:N.state==='held'?26:16+Math.min(20,Math.hypot(N.vx,N.vy)/60);
  const P=H.P, fresh=H.now()-P.t<4000, ax=fresh?N.x-P.x:-60, ay=fresh?N.y-P.y:-90, d=Math.hypot(ax,ay)||1;
  const ox=ax/d*height*.9, oy=ay/d*height*.9+height*.35, size=N.r*2*(1+height/40);
  const x=Math.round(N.x+ox-size/2), y=Math.round(N.y+oy-size*.35);
  if(x!==lx||y!==ly){ lx=x; ly=y; sh.style.width=size+'px'; sh.style.height=(size*.7)+'px'; sh.style.transform=`translate(${x}px,${y}px)`; }
  sh.style.opacity=(1-height/60).toFixed(2);
});

})();
