/* =====================================================================
  PIP REMEMBERS · plugin v1
  Loaded by the sandbox loader (see PLUGINS in index.html). Needs window.PipHost (host.js).
  Works on its own. Plays nicely with the other plugins; with Spatial installed,
  Pip also reacts with emoji bubbles.
  Where: 📓 in the plugin bar

  Pip notices what you changed since your last visit ("New backdrop? Bold.") and greets you warmly, without guilt.
  A notebook (📓) shows what Pip has kept: visits, pokes, teas, smashes, favourite look. "Forget all of this" wipes it.

  Switch it off in the Plugins panel, or remove it from PLUGINS.
  =====================================================================
*/
(() => {
const H=window.PipHost;
if(!H||!H.openPanel){ console.warn('PIP REMEMBERS: needs Pip Sandbox V2 stage 11.5 or later.'); return; }
const {N,S,stage,navi}=H;
if(H.registerPlugin&&!H.registerPlugin({id:'remembers',name:'Pip Remembers',icon:'📓',shelf:'grounded',desc:'Notices what changed since your last visit; keeps a notebook.'})) return;
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

/* What Pip keeps: a few settings and some counters. Stays on this device. Forget wipes it. */
const KEY='gs2-plug-mem', WATCH={bd:'backdrop',fav:'favourite colour',font:'font',face:'clock face',era:'look',persona:'personality',form:'body',material:'material',mode:'mode'};
const LINES={bd:v=>`New backdrop? ${v}. Bold.`,fav:()=>'You changed your colour. Suits you.',font:v=>({serif:'Serif now. Fancy.',rounded:'Rounded. Friendly choice.',system:'Back to the classic font.'})[v]||'New font!',
  face:()=>'Different clock face. I noticed.',era:v=>v==='today'?'Back home to glass, I see.':'You moved us to another era while I was away.',persona:()=>'I feel… different today. Did you change me?',
  form:()=>'New body? I keep catching my reflection.',material:v=>v==='liquid'?'Liquid now. Mind the splashes.':'Material change! Noted.',mode:v=>v==='dream'?'Dreaming today.':'Grounded today. Nice and calm.'};
const mem=Object.assign({visits:0,last:0,snap:{},taps:0,teas:0,smashes:0,looks:{},seen:[]},H.store.get('plug-mem',{}));
const save=()=>H.store.set('plug-mem',mem);
const snap=()=>Object.fromEntries(Object.keys(WATCH).map(k=>[k,S[k]]));
mem.visits++; const gap=Date.now()-(mem.last||Date.now()), changed=Object.keys(WATCH).filter(k=>mem.snap&&k in mem.snap&&mem.snap[k]!==S[k]);
mem.last=Date.now(); save();
let greeted=false;
function greet(){
  if(greeted||!S.naviOn||!N.awake) return; greeted=true;
  const lines=[];
  if(mem.visits>1){ lines.push(gap<10*60e3?'Back already? Lovely.':gap>3*864e5?'Oh, hello again! I kept your clock warm.':'Welcome back.'); }
  changed.slice(0,2).forEach(k=>lines.push(LINES[k](S[k])));
  lines.forEach((l,i)=>setTimeout(()=>H.say(l,2400,null,1),400+i*2700));
  if(changed.length) emote('🧐',{pri:2});
}
setTimeout(()=>{ if(N.awake) greet(); },3500);
window.addEventListener('pip:tap',()=>{ mem.taps++; if(!greeted) setTimeout(greet,1600); });
window.addEventListener('pip:drink',({detail})=>{ if(detail.kind==='tea') mem.teas++; });
window.addEventListener('pip:smash',()=>mem.smashes++);
setInterval(()=>{ mem.snap=snap(); mem.looks[S.era]=(mem.looks[S.era]||0)+10; save(); },10000);
addEventListener('pagehide',()=>{ mem.snap=snap(); save(); });
/* the notebook */
const card=PB.card(`<h3>📓 Pip's notebook</h3><div id="memBody"></div><p>Everything here stays on this device.</p><div class="pr"><button class="pc" id="memForget">Forget all of this</button></div>`);
const btn=PB.button('📓','Pip\'s notebook',()=>{ if(PB.toggle(card,btn)) render(); });
function render(){
  const fav=Object.entries(mem.looks).sort((a,b)=>b[1]-a[1])[0];
  const rows=[['Visits',mem.visits],['Pokes',mem.taps],['Cups of tea',mem.teas],['Things smashed',mem.smashes],['Favourite look',fav?({today:'Today'}[fav[0]]||fav[0]):'–'],['Name',S.name]];
  card.querySelector('#memBody').innerHTML='<p>'+rows.map(([k,v])=>`<b>${k}:</b> ${v}`).join('<br>')+'</p>';
}
card.querySelector('#memForget').addEventListener('click',()=>{ H.store.del('plug-mem'); Object.assign(mem,{visits:1,last:Date.now(),snap:snap(),taps:0,teas:0,smashes:0,looks:{}}); save(); render(); H.say('Forgotten. Fresh notebook.',1600,null,0); emote('🫥'); });
window.PipRemembers={mem};

})();
