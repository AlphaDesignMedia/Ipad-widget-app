/* =====================================================================
  GLASS HARP · plugin v1
  Loaded by the sandbox loader (see PLUGINS in index.html). Needs window.PipHost (host.js).
  Works on its own. Plays nicely with the other plugins; with Spatial installed,
  Pip also reacts with emoji bubbles.
  Where: (no button)

  Every panel is a glass bell pitched by its size (big = low, small = high, pentatonic so it
  always sounds nice). Pip bumping it, you tapping it, it cracking or opening: each rings a note.
  Needs Sounds on (Accessibility); Pip tells you once if they are off.

  Switch it off in the Plugins panel, or remove it from PLUGINS.
  =====================================================================
*/
(() => {
const H=window.PipHost;
if(!H||!H.openPanel){ console.warn('GLASS HARP: needs Pip Sandbox V2 stage 11.5 or later.'); return; }
const {N,S,stage,navi}=H;
if(H.registerPlugin&&!H.registerPlugin({id:'harp',name:'Glass Harp',icon:'🎵',shelf:'dream',desc:'Panels ring like glass bells, pitched by size.'})) return;
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

/* Every panel is a glass bell. Pip bumping it, you tapping it, or it opening rings a note pitched by its size. */
const SCALE=[0,2,4,7,9,12,14,16,19,21];   // major pentatonic, two octaves
let ctx=null, hinted=false;
function bell(area,vel=.6){
  if(!S.sound){ if(!hinted){ hinted=true; H.say('Turn Sounds on in Accessibility and the glass will sing.',2400,null,1); } return; }
  try{ ctx=ctx||new (window.AudioContext||window.webkitAudioContext)(); const t=ctx.currentTime;
    const idx=Math.max(0,Math.min(SCALE.length-1,Math.round(9-Math.log2(area/12000)*2.4))), f=440*Math.pow(2,(SCALE[idx]-9)/12)*2;
    [[1,.16],[2.76,.05],[5.4,.02]].forEach(([m,g])=>{ const o=ctx.createOscillator(), a=ctx.createGain(); o.type='sine'; o.frequency.value=f*m;
      a.gain.setValueAtTime(0,t); a.gain.linearRampToValueAtTime(g*vel,t+.006); a.gain.exponentialRampToValueAtTime(.0001,t+1.6/m+.2); o.connect(a).connect(ctx.destination); o.start(t); o.stop(t+2); }); }catch{}
}
const area=el=>{ const r=H.rel(el); return r.width*r.height; };
H.bump.push(({el,speed})=>{ if(speed>60) bell(area(el),Math.min(1,speed/900)); });
window.addEventListener('pip:crack',({detail})=>bell(area(detail.el),1));
window.addEventListener('pip:splash',({detail})=>bell(area(detail.el),.7));
stage.addEventListener('pointerdown',e=>{ const p=e.target.closest('.panel'); if(p&&!e.target.closest('button,input,label,.drill,.mseg,.sw')) bell(area(p),.35); },true);
const seen=new WeakSet();
new MutationObserver(ms=>ms.forEach(m=>{ const p=m.target; if(p.classList?.contains('panel')&&!p.hidden&&!seen.has(p)){ seen.add(p); setTimeout(()=>seen.delete(p),400); bell(area(p),.3); } }))
  .observe(document.getElementById('panels'),{subtree:true,attributes:true,attributeFilter:['hidden']});
window.PipHarp={bell};

})();
