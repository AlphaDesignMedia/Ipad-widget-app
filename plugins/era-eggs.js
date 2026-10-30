/* =====================================================================
  ERA EASTER EGGS · plugin v1
  Loaded by the sandbox loader (see PLUGINS in index.html). Needs window.PipHost (host.js).
  Works on its own. Plays nicely with the other plugins; with Spatial installed,
  Pip also reacts with emoji bubbles.
  Where: (no button: find them)

  One hidden joke per era:
  1997 Bevel 97: poke Pip 4 times fast → a blue screen; tap to reboot Pip.
  1998 Dial-Up: tap the date 5 times → the visitor counter explodes.
  1983 Glacio: tap the clock 3 times fast → every segment lights up, with a tune.
  1987 Platinum: double-tap the top-left tag → a happy little box says hello.
  2007 Halo Glass: hold the clock for a second → an aurora sweeps across the glass.

  Switch it off in the Plugins panel, or remove it from PLUGINS.
  =====================================================================
*/
(() => {
const H=window.PipHost;
if(!H||!H.openPanel){ console.warn('ERA EASTER EGGS: needs Pip Sandbox V2 stage 11.5 or later.'); return; }
const {N,S,stage,navi}=H;
if(H.registerPlugin&&!H.registerPlugin({id:'eggs',name:'Era Easter Eggs',icon:'🥚',shelf:'dream',desc:'One hidden joke per era.'})) return;
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

/* One hidden joke per era. Tap fast. */
const st=document.createElement('style'); st.textContent=`
.bsod{position:absolute;inset:0;z-index:60;background:#0000aa;color:#fff;font:16px/1.6 "Pixelify Sans",ui-monospace,monospace;display:grid;place-items:center;padding:24px;text-align:center;cursor:pointer}
.bsod b{background:#aaa;color:#0000aa;padding:0 8px}
.visitors{position:absolute;left:0;top:0;z-index:50;pointer-events:none;font:700 18px "Comic Neue","Comic Sans MS",cursive;color:#ff0;text-shadow:0 0 6px #f0f}
.egg-allon .lcd .s{opacity:1 !important}
.happybox{position:absolute;z-index:50;pointer-events:none;font-size:46px;background:#fff;border:3px solid #000;box-shadow:5px 5px 0 #000;padding:8px 14px;image-rendering:pixelated}
.aurora{position:absolute;inset:0;z-index:33;pointer-events:none;background:linear-gradient(110deg,transparent 30%,rgba(120,255,170,.35) 45%,rgba(60,200,255,.3) 55%,transparent 70%);background-size:300% 100%;animation:aur 2.4s ease-in-out forwards}
@keyframes aur{from{background-position:120% 0;opacity:0}20%{opacity:1}to{background-position:-60% 0;opacity:0}}`; document.head.appendChild(st);
const taps={}; const quick=(k,n,ms=900)=>{ const t=H.now(); taps[k]=(taps[k]||[]).filter(x=>t-x<ms); taps[k].push(t); if(taps[k].length>=n){ taps[k]=[]; return true; } return false; };
const era=()=>S.era;
/* 1997: poke Pip 4 times fast → blue screen, Pip reboots */
window.addEventListener('pip:tap',()=>{ if(era()!=='1997'||!quick('97',4)) return;
  const b=document.createElement('div'); b.className='bsod'; b.innerHTML=`<div><b> PIP </b><p>A fatal exception 0E has occurred at 0028:C0FFEE97.<br>The current companion will be rebooted.</p><p>Press any key or tap to continue _</p></div>`;
  stage.appendChild(b); H.beep([[200,300]]); const go=()=>{ b.remove(); removeEventListener('keydown',go); N.squash=.3; N.hopT=H.now(); H.say('…sorry. Old habits.',1800,null,0); emote('😅',{pri:3}); };
  b.addEventListener('click',go); addEventListener('keydown',go,{once:true}); });
/* 1998: tap the date 5 times → the visitor counter explodes */
stage.addEventListener('pointerdown',e=>{ if(era()!=='1998'||!e.target.closest('#date')||!quick('98',5,1500)) return;
  const r=H.rel(document.getElementById('date'));
  for(let i=0;i<24;i++){ const v=document.createElement('span'); v.className='visitors'; v.textContent=String(417+i*41667).padStart(7,'0'); stage.appendChild(v);
    const a=Math.random()*Math.PI*2, d=120+Math.random()*260; v.animate([{transform:`translate(${r.left+r.width/2}px,${r.top}px) scale(.5)`,opacity:1},{transform:`translate(${r.left+r.width/2+Math.cos(a)*d}px,${r.top+Math.sin(a)*d}px) scale(1.4)`,opacity:0}],{duration:1400+Math.random()*600}).onfinish=()=>v.remove(); }
  H.say('YOU ARE VISITOR 1,000,000!!! Click here to claim your prize!',2600,null,0); emote('🎉',{pri:3}); },true);
/* 1983: tap the clock 3 times fast → every segment lights, and a little tune */
stage.addEventListener('pointerdown',e=>{ if(era()!=='1983'&&S.face!=='1983') return; if(!e.target.closest('#cardIn')||!quick('83',3,800)) return;
  H.card.classList.add('egg-allon'); H.beep([[1047,90],[1319,90],[1568,90],[2093,200]]); setTimeout(()=>H.card.classList.remove('egg-allon'),1500); emote('🎵',{pri:2}); },true);
/* 1987: tap the top-left tag twice → a happy little box says hello */
stage.addEventListener('pointerdown',e=>{ if(era()!=='1987'||!e.target.closest('#stageTag')||!quick('87',2,600)) return;
  const b=document.createElement('div'); b.className='happybox'; b.textContent='☺'; const r=H.cardRect(); b.style.left=(r.left+r.width/2-40)+'px'; b.style.top=(r.top-90)+'px'; stage.appendChild(b);
  H.beep([[523,140],[659,140],[784,260]]); setTimeout(()=>b.remove(),1800); H.say('Welcome to Pane & Sons.',1800,null,0); },true);
/* 2007: hold the clock for a second → an aurora sweeps across the glass */
let holdT=0;
stage.addEventListener('pointerdown',e=>{ if(era()!=='2007'||!e.target.closest('#cardIn')) return; clearTimeout(holdT); holdT=setTimeout(()=>{ const a=document.createElement('i'); a.className='aurora'; stage.appendChild(a); setTimeout(()=>a.remove(),2500); emote('🌌',{pri:2}); },900); },true);
stage.addEventListener('pointerup',()=>clearTimeout(holdT),true);

})();
