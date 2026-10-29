/* =====================================================================
  NIGHT SHIFT · plugin v1
  Loaded by the sandbox loader (see PLUGINS in index.html). Needs window.PipHost (host.js).
  Works on its own. Plays nicely with the other plugins; with Spatial installed,
  Pip also reacts with emoji bubbles.
  Where: 🌙/☀️ in the plugin bar (tap to preview)

  After 9pm the glass dims and warms, Pip nods off after a quiet half-minute, and Glacio lights
  itself. At 6am: a stretch and "Morning!". Tap 🌙/☀️ to preview either without waiting.

  Switch it off in the Plugins panel, or remove it from PLUGINS.
  =====================================================================
*/
(() => {
const H=window.PipHost;
if(!H||!H.openPanel){ console.warn('NIGHT SHIFT: needs Pip Sandbox V2 stage 11.5 or later.'); return; }
const {N,S,stage,navi}=H;
if(H.registerPlugin&&!H.registerPlugin({id:'night',name:'Night Shift',icon:'🌙',shelf:'grounded',desc:'Warm, dim glass after dark; sleepy Pip; morning stretch.'})) return;
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

/* After dark the glass dims and warms, Pip gets sleepy, Glacio lights itself. Morning: stretch, coffee. */
const CFG={nightFrom:21, nightTo:6};
const st=document.createElement('style'); st.textContent=`
.nightveil{position:absolute;inset:0;z-index:34;pointer-events:none;opacity:0;transition:opacity 2.5s;background:radial-gradient(120% 90% at 50% 10%, rgba(255,170,90,.10), rgba(20,10,40,.28));mix-blend-mode:multiply}
.is-night .nightveil{opacity:1}
.is-night .halo{opacity:.25 !important}`; document.head.appendChild(st);
const veil=document.createElement('i'); veil.className='nightveil'; stage.appendChild(veil);
let forced=null, lastNight=null;
const isNight=()=>{ if(forced!==null) return forced; const h=new Date().getHours(); return h>=CFG.nightFrom||h<CFG.nightTo; };
const btn=PB.button('🌙','Night shift (tap to preview day or night)',()=>{ forced=!isNight(); apply(true); });
function apply(user){
  const n=isNight(); stage.classList.toggle('is-night',n); btn.textContent=n?'🌙':'☀️';
  if(n&&(S.era==='1983'||S.face==='1983')) H.cardIn.classList.add('lit'); else if(lastNight&&!n) H.cardIn.classList.remove('lit');
  if(lastNight!==null&&n!==lastNight&&S.naviOn){
    if(n){ emote('🥱',{pri:2}); H.say(user?'Lights down. I might nap.':'Getting late. I might nap.',1800,null,1); }
    else { N.squash=-.2; N.hopT=H.now(); emote('☕',{pri:3}); H.say('Morning! *stretch*',1800,null,1); }
  }
  lastNight=n;
}
apply(false); setInterval(()=>apply(false),60000);
/* sleepier at night: nod off after a quiet half-minute on the clock */
H.frame.push((dt,t)=>{ if(isNight()&&S.naviOn&&N.awake&&N.state==='perch'&&t-N.lastInteract>30000&&!H.bubbleOn&&N.mood!=='sulk'){ N.state='sleep'; N.awake=false; emote('💤',{pri:2}); } });
window.PipNight={set:v=>{forced=v; apply(true);}};

})();
