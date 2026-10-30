/* =====================================================================
  FOCUS BUBBLE · plugin v1
  Loaded by the sandbox loader (see PLUGINS in index.html). Needs window.PipHost (host.js).
  Works on its own. Plays nicely with the other plugins; with Spatial installed,
  Pip also reacts with emoji bubbles.
  Where: 🫧 in the plugin bar

  Pick 5, 15 or 25 minutes. A ring fills around the clock, Pip curls up asleep and stays quiet
  (chattiness and tips pause). When it is done: a stretch, a little tune, "Done!". Stop early any time.

  Switch it off in the Plugins panel, or remove it from PLUGINS.
  =====================================================================
*/
(() => {
const H=window.PipHost;
if(!H||!H.openPanel){ console.warn('FOCUS BUBBLE: needs Pip Sandbox V2 stage 11.5 or later.'); return; }
const {N,S,stage,navi}=H;
if(H.registerPlugin&&!H.registerPlugin({id:'focus',name:'Focus Bubble',icon:'🫧',shelf:'grounded',desc:'A focus timer; Pip naps quietly until it is done.'})) return;
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

/* A focus timer. Pip curls up on the clock and stays quiet until it's done. */
const st=document.createElement('style'); st.textContent=`.focusring{position:absolute;left:0;top:0;z-index:11;pointer-events:none;overflow:visible}
.focusring circle{fill:none;stroke:var(--accent);stroke-width:4;stroke-linecap:round;transition:stroke-dashoffset 1s linear}
.focusring .bg{stroke:color-mix(in srgb, var(--accent) 20%, transparent)}`; document.head.appendChild(st);
const card=PB.card(`<h3>🫧 Focus</h3><p>Pip will curl up on the clock and stay quiet until time's up.</p><div class="pr" id="fcMins"><button class="pc" data-m="5">5 min</button><button class="pc" data-m="15">15 min</button><button class="pc" data-m="25">25 min</button></div><div class="pr"><button class="pc" id="fcStop" hidden>Stop early</button></div><p id="fcLeft"></p>`);
const btn=PB.button('🫧','Focus timer',()=>PB.toggle(card,btn));
const svg=document.createElementNS('http://www.w3.org/2000/svg','svg'); svg.setAttribute('class','focusring'); svg.setAttribute('aria-hidden','true'); svg.innerHTML='<circle class="bg"/><circle class="fg"/>'; svg.style.display='none'; stage.appendChild(svg);
let F=null;
card.querySelector('#fcMins').addEventListener('click',e=>{ const b=e.target.closest('[data-m]'); if(b) start(+b.dataset.m); });
card.querySelector('#fcStop').addEventListener('click',()=>end(true));
function start(min){
  F={end:Date.now()+min*60e3,len:min*60e3,chat:S.chat,tips:S.tips}; S.chat=0; S.tips=false;
  if(S.naviOn){ N.awake=true; N.state='perch'; N.back=false; setTimeout(()=>{ if(F){ N.state='sleep'; N.awake=false; } },1500); }
  emote('🫧',{pri:3}); svg.style.display=''; card.querySelector('#fcStop').hidden=false; PB.toggle(card,btn);
}
function end(early){
  if(!F) return; S.chat=F.chat; S.tips=F.tips; F=null; svg.style.display='none'; card.querySelector('#fcStop').hidden=true; card.querySelector('#fcLeft').textContent='';
  if(S.naviOn){ H.wake(); N.squash=-.2; N.hopT=H.now(); emote(early?'👍':'🎉',{pri:3}); H.say(early?'Stopped. Still counts.':'Done! That was a good stretch of focus.',2400,null,0); }
  if(!early) H.beep([[784,120],[0,60],[988,120],[0,60],[1175,200]]);
}
H.frame.push(()=>{
  if(!F) return; const left=F.end-Date.now(); if(left<=0){ end(false); return; }
  const r=H.cardRect(), R=Math.hypot(r.width,r.height)/2+14, C=2*Math.PI*R;
  svg.setAttribute('width',R*2+8); svg.setAttribute('height',R*2+8); svg.style.transform=`translate(${r.left+r.width/2-R-4}px,${r.top+r.height/2-R-4}px)`;
  svg.querySelectorAll('circle').forEach(c=>{ c.setAttribute('cx',R+4); c.setAttribute('cy',R+4); c.setAttribute('r',R); });
  const fg=svg.querySelector('.fg'); fg.setAttribute('stroke-dasharray',C); fg.setAttribute('stroke-dashoffset',(C*(1-left/F.len)).toFixed(1)); fg.setAttribute('transform',`rotate(-90 ${R+4} ${R+4})`);
  const m=Math.floor(left/60e3), s=Math.floor(left/1000)%60; card.querySelector('#fcLeft').textContent=`${m}:${String(s).padStart(2,'0')} left`;
});
window.PipFocus={start,end};

})();
