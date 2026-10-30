/* =====================================================================
  STACK ATTACK · plugin v1
  Loaded by the sandbox loader (see PLUGINS in index.html). Needs window.PipHost (host.js).
  Works on its own. Plays nicely with the other plugins; with Spatial installed,
  Pip also reacts with emoji bubbles.
  Where: (no button)

  Drag a panel by its title and drop it on top of another: it stacks with a clunk.
  Make a tower of two or more and Pip climbs up and plants a 🚩 that rides along with the panel.

  Switch it off in the Plugins panel, or remove it from PLUGINS.
  =====================================================================
*/
(() => {
const H=window.PipHost;
if(!H||!H.openPanel){ console.warn('STACK ATTACK: needs Pip Sandbox V2 stage 11.5 or later.'); return; }
const {N,S,stage,navi}=H;
if(H.registerPlugin&&!H.registerPlugin({id:'stack',name:'Stack Attack',icon:'🧱',shelf:'dream',desc:'Drop panels onto each other; Pip climbs and plants a flag.'})) return;
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

/* Drop a panel onto another and it stacks with a clunk. Two or more: Pip climbs up and plants a flag. */
const st=document.createElement('style'); st.textContent=`.pipflag{position:absolute;left:0;top:0;z-index:32;font-size:22px;pointer-events:none;transform-origin:20% 100%}`; document.head.appendChild(st);
let dragP=null, flag=null;
stage.addEventListener('pointerdown',e=>{ const h=e.target.closest('.ph'); if(h&&!e.target.closest('button')) dragP={p:h.closest('.panel'),x:e.clientX,y:e.clientY}; },true);
stage.addEventListener('pointerup',e=>{
  if(!dragP) return; const {p,x,y}=dragP; dragP=null; if(Math.hypot(e.clientX-x,e.clientY-y)<20) return;
  const l0=p.style.left, t0=p.style.top;
  setTimeout(()=>{ if(p.hidden||p.style.left!==l0||p.style.top!==t0) return; tryStack(p); },120);   // skip panels still flying
},true);
function tryStack(p){
  const r=H.rel(p);
  const base=H.openEls().filter(o=>o!==p).map(o=>({o,r:H.rel(o)})).find(({r:b})=>r.left<b.right-40&&r.right>b.left+40&&r.bottom>b.top-30&&r.bottom<b.top+Math.min(140,b.height*.6));
  if(!base) return;
  const b=base.r, x=Math.max(8,b.left+(b.width-r.width)/2), y=b.top-r.height+10;
  if(y<64) return;
  if(H.pos) H.pos(p,x,y); else { p.style.left=x+'px'; p.style.top=y+'px'; }   // H.pos also refreshes the cached panel rect
  if(!H.simpler()) p.animate([{translate:'0 -14px'},{translate:'0 3px',offset:.6},{translate:'0 0'}],{duration:260,easing:'ease-in'});
  base.o.animate([{scale:'1'},{scale:'1 .97',offset:.4},{scale:'1'}],{duration:240});
  H.beep([[98,60],[82,90]]); emote('🧱',{pri:2});
  if(stackOf(p).length>=2) setTimeout(()=>climb(p),500);
}
function stackOf(top){ const out=[top]; let cur=top;
  for(let k=0;k<6;k++){ const r=H.rel(cur), under=H.openEls().find(o=>!out.includes(o)&&Math.abs(H.rel(o).top-(r.bottom-10))<6); if(!under) break; out.push(under); cur=under; } return out; }
function climb(top){
  if(!S.naviOn) return; if(!N.awake) H.wake(); const r=H.rel(top), x=r.left+r.width*.7, y=r.top-N.r+3;
  N.back=false; emote('🧗',{pri:3}); H.say(H.pick(['A tower! I\'m going up.','Summit attempt.','Up we go.']),1600,null,1);
  Object.assign(N,{state:'travel',tx:x,ty:y,tsp:260,after:'free',perchTrack:false,onArrive:()=>{
    N.state='free'; N.vx=N.vy=0; flag?.el.remove(); const el=document.createElement('span'); el.className='pipflag'; el.textContent='🚩'; stage.appendChild(el); flag={el,p:top,dx:r.width*.7+10};
    if(!H.simpler()) el.animate([{rotate:'-40deg',scale:'.3'},{rotate:'6deg',scale:'1.1',offset:.6},{rotate:'0deg',scale:'1'}],{duration:500,easing:'ease-out'});
    emote('🎉',{pri:3}); H.say('Planted it. Best view in the house.',1800,null,1); }});
}
H.frame.push(()=>{ if(!flag) return; if(flag.p.hidden){ flag.el.remove(); flag=null; return; } const r=H.rel(flag.p); flag.el.style.transform=`translate(${r.left+flag.dx}px,${r.top-30}px)`; });

})();
