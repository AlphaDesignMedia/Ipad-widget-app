/* =====================================================================
  MATERIALS · plugin v1.1   (Dream shelf)
  Loaded by the sandbox loader (see PLUGINS in index.html). Needs window.PipHost (host.js).
  Where: 🧱 in the plugin bar (default material), or long-press any panel's title (just that panel).
  Each material has its own look, impact and sound (sounds need Sounds on):
    🪟 Glass cracks · 💧 Liquid splashes · 🧊 Acrylic scuffs, never breaks · 🔩 Metal dents and rings
    📄 Paper crumples then flattens · 🍮 Jelly squishes and wobbles for ages
  Pip reacts: bounces off jelly, tiptoes on paper, rings metal, and sometimes polishes it.
  Some eras suggest a material (Bevel 97 → acrylic, The Shed → metal).
  v1.1 (Claude): the rail, plugin bar and plugin cards can wear the default material too ("Menus too").
  Uses PipHost.impact so material panels skip the glass crack entirely.
  ===================================================================== */
(() => {
const H=window.PipHost;
if(!H||!H.registerPlugin){ console.warn('Materials: needs Pip Sandbox V2 stage 12 or later.'); return; }
const {N,S,stage,navi}=H;
if(!H.registerPlugin({id:'materials',name:'Materials',icon:'🧱',shelf:'dream',desc:'Panels and menus as glass, liquid, acrylic, metal, paper or jelly, each with its own look, impact and sound.'})) return;
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

/* MATERIALS: each panel can be glass, liquid, frosted acrylic, brushed metal, paper or jelly.
   Each material has its own look, impact and sound. Pip reacts to each. Long-press a panel title to pick. */
const MATS={
  glass:{n:'Glass',i:'🪟'}, liquid:{n:'Liquid',i:'💧'}, acrylic:{n:'Frosted acrylic',i:'🧊'}, metal:{n:'Brushed metal',i:'🔩'}, paper:{n:'Paper',i:'📄'}, jelly:{n:'Jelly',i:'🍮'}
};
const ERA_SUGGEST={'1997':'acrylic','2004':'metal','1887':'paper','2001':'jelly','1987':'paper'};
const M=Object.assign({def:'',panels:{},menus:true},H.store.get('plug-materials',{}));
const save=()=>H.store.set('plug-materials',M);
/* :is() with #plugbar lifts these above Glass Lab's glass, so a chosen material always shows */
const W=':is(.panel,.rail,#plugbar,.plugcard)';
const st=document.createElement('style'); st.textContent=`
.stage ${W}[data-mat="acrylic"]{background:rgba(255,255,255,.62) !important;-webkit-backdrop-filter:blur(6px) !important;backdrop-filter:blur(6px) !important;border:0 !important;box-shadow:0 0 0 1px rgba(255,255,255,.7) inset, 0 10px 26px rgba(0,0,0,.14) !important;color:#1b1a22;--ink:#1b1a22;--ink2:#3a3946;--ink3:#5d5c6a}
.stage ${W}[data-mat="metal"]{-webkit-backdrop-filter:none !important;backdrop-filter:none !important;color:#1c2430;--ink:#1c2430;--ink2:#3a4350;--ink3:#5f6875;
  background:repeating-linear-gradient(90deg, rgba(255,255,255,.18) 0 1px, transparent 1px 3px), repeating-linear-gradient(90deg, rgba(0,0,0,.03) 0 2px, transparent 2px 5px), linear-gradient(160deg,#eef1f4,#a7aeb8) !important;
  box-shadow:inset 0 1px 0 #fff, inset 0 0 0 1px rgba(60,66,76,.35), 0 18px 40px -16px rgba(0,0,0,.5) !important;border:0 !important}
.stage ${W}[data-mat="paper"]{-webkit-backdrop-filter:none !important;backdrop-filter:none !important;color:#1c2430;--ink:#1c2430;--ink2:#3e4654;--ink3:#6a7280;border:0 !important;
  background:repeating-linear-gradient(180deg, transparent 0 23px, rgba(80,120,200,.13) 23px 24px), linear-gradient(#fbfaf4,#f3f1e8) !important;box-shadow:0 1px 0 rgba(0,0,0,.06), 0 14px 26px -16px rgba(0,0,0,.4) !important;border-radius:6px !important}
.stage .panel[data-mat="paper"]{rotate:-.4deg}
.stage ${W}[data-mat="jelly"]{border:0 !important;border-radius:36px !important;background:linear-gradient(180deg, rgba(255,255,255,.55), rgba(255,255,255,0) 40%), color-mix(in srgb, var(--accent) 38%, rgba(255,255,255,.35)) !important;
  -webkit-backdrop-filter:blur(10px) saturate(2.2) !important;backdrop-filter:blur(10px) saturate(2.2) !important;box-shadow:inset 0 -8px 18px color-mix(in srgb, var(--accent) 45%, transparent), inset 0 2px 2px rgba(255,255,255,.9), 0 14px 30px color-mix(in srgb, var(--accent) 30%, transparent) !important}
.stage ${W}[data-mat="liquid"]{border:0 !important}
.stage :is(.rail,#plugbar)[data-mat="paper"]{border-radius:8px !important}
.mat-pop{position:absolute;left:0;top:0;z-index:48;display:flex;flex-wrap:wrap;gap:6px;width:250px;padding:10px;border-radius:18px;box-sizing:border-box}
.mat-pop p{margin:0;width:100%;font:600 13px/1.2 var(--ui);color:var(--ink)}
.mat-pop button{min-height:34px;border:0;border-radius:999px;padding:0 11px;background:var(--wash);color:var(--ink);font:600 12.5px/1 var(--ui);cursor:pointer}
.mat-pop button.on{background:var(--accent);color:#fff}
.mat-mark{position:absolute;pointer-events:none;z-index:3}
.dent{width:26px;height:26px;border-radius:50%;background:radial-gradient(circle at 40% 40%, rgba(0,0,0,.22), rgba(255,255,255,.35) 60%, transparent 72%)}
.scuff{width:60px;height:6px;border-radius:3px;background:linear-gradient(90deg, transparent, rgba(255,255,255,.95), transparent);filter:blur(.5px)}`;
document.head.appendChild(st);
const matOf=p=>p.dataset.mat||'';
function setMat(p,k){ const id=p.id; if(k){ p.dataset.mat=k; M.panels[id]=k; } else { delete p.dataset.mat; delete M.panels[id]; } save(); }
/* keep newly opened panels on their saved (or default) material */
new MutationObserver(()=>H.openEls().forEach(p=>{ const k=M.panels[p.id]||M.def; if(k&&p.dataset.mat!==k) p.dataset.mat=k; else if(!k&&p.dataset.mat) delete p.dataset.mat; }))
  .observe(document.getElementById('panels'),{subtree:true,attributes:true,attributeFilter:['hidden'],childList:true});
H.openEls().forEach(p=>{ const k=M.panels[p.id]||M.def; if(k) p.dataset.mat=k; });
/* menus: the rail, the plugin bar and plugin cards follow the default material */
function applyMenus(){ const k=M.menus?M.def:''; [document.getElementById('rail'),document.getElementById('plugbar'),...document.querySelectorAll('.plugcard')].forEach(el=>{ if(!el) return; if(k) el.dataset.mat=k; else delete el.dataset.mat; }); }
window.addEventListener('pip:plugins',applyMenus); setTimeout(applyMenus,0);
/* sounds */
let ac=null; const A=()=>ac||(ac=new (window.AudioContext||window.webkitAudioContext)());
function noise(dur,f,type,vol){ const c=A(), n=Math.floor(c.sampleRate*dur), b=c.createBuffer(1,n,c.sampleRate), d=b.getChannelData(0); for(let i=0;i<n;i++) d[i]=(Math.random()*2-1)*Math.pow(1-i/n,1.6);
  const s=c.createBufferSource(), fl=c.createBiquadFilter(), g=c.createGain(); s.buffer=b; fl.type=type; fl.frequency.value=f; g.gain.value=vol; s.connect(fl).connect(g).connect(c.destination); s.start(); }
function tone(fs,dur,vol,type='sine',glide){ const c=A(), t=c.currentTime; fs.forEach(f=>{ const o=c.createOscillator(), g=c.createGain(); o.type=type; o.frequency.setValueAtTime(f,t); if(glide) o.frequency.exponentialRampToValueAtTime(f*glide,t+dur);
  g.gain.setValueAtTime(vol,t); g.gain.exponentialRampToValueAtTime(.0001,t+dur); o.connect(g).connect(c.destination); o.start(t); o.stop(t+dur+.05); }); }
const SND={ acrylic:k=>{ noise(.09,900,'lowpass',.35*k); }, metal:k=>{ tone([523,1347,2210],.9,.06*k,'sine'); }, paper:k=>{ noise(.35,2500,'bandpass',.25*k); }, jelly:k=>{ tone([180],.35,.15*k,'sine',.5); } };
const play=(m,sp)=>{ if(S.sound&&SND[m]) try{ SND[m](Math.min(1,sp/1500)); }catch{} };
function mark(p,cls,lx,ly,rot=0){ const m=document.createElement('i'); m.className='mat-mark '+cls; m.style.left=(lx-13)+'px'; m.style.top=(ly-13)+'px'; m.style.rotate=rot+'deg'; p.appendChild(m); setTimeout(()=>m.remove(),12000); }
/* impacts: each material answers the wall in its own way (glass and liquid fall through to the sandbox). */
function onImpact(p,{sp,lx,ly,nx,ny}){
  const m=matOf(p); if(!m||m==='glass'||m==='liquid') return false;
  if(sp<250) return true;
  play(m,sp); const s=H.simpler();
  if(m==='acrylic'){ mark(p,'scuff',lx,ly,Math.atan2(ny,nx)*57+90); if(!s) p.animate([{translate:'0 0'},{translate:`${-nx*4}px ${-ny*4}px`},{translate:'0 0'}],{duration:160}); emote('🧊'); }
  if(m==='metal'){ mark(p,'dent',lx,ly); if(!s) p.animate([{rotate:'0deg'},{rotate:'1.2deg'},{rotate:'-.8deg'},{rotate:'.4deg'},{rotate:'0deg'}],{duration:700}); emote('🔔'); if(sp>900) H.say('Clang! Not a scratch. Well. One dent.',1500,null,2); }
  if(m==='paper'){ if(!s) p.animate([{scale:'1 1',rotate:'-.4deg'},{scale:`${1-.14*Math.abs(nx)} ${1-.14*Math.abs(ny)}`,rotate:'2deg',offset:.3},{scale:'1.02 .98',rotate:'-1.5deg',offset:.65},{scale:'1 1',rotate:'-.4deg'}],{duration:800,easing:'ease-out'}); emote('📄'); }
  if(m==='jelly'){ if(!s) p.animate([{scale:'1 1'},{scale:`${1-.22*Math.abs(nx)+.1*Math.abs(ny)} ${1-.22*Math.abs(ny)+.1*Math.abs(nx)}`,offset:.18},{scale:`${1+.12*Math.abs(nx)} ${1+.12*Math.abs(ny)}`,offset:.4},{scale:`${1-.06*Math.abs(nx)} ${1-.06*Math.abs(ny)}`,offset:.6},{scale:'1.02 .99',offset:.8},{scale:'1 1'}],{duration:1300,easing:'ease-out'}); emote('🤸'); }
  return true;
}
H.impact.push(onImpact);
/* Pip and materials */
H.bump.push(({el,speed})=>{ const m=matOf(el); if(!m) return;
  if(m==='jelly'){ N.vy-=320; N.vx*=1.3; emote('🤸'); }
  if(m==='metal'&&speed>200){ play('metal',speed*.6); emote('🔔'); }
  if(m==='paper'){ N.vx*=.5; N.vy*=.5; emote('🦶'); }
  if(m==='acrylic'&&speed>200) play('acrylic',speed); });
let nextPolish=0;
H.frame.push((dt,t)=>{
  if(t<nextPolish||!S.naviOn||!N.awake||N.state!=='perch'||t-N.lastInteract<6000||H.bubbleOn) return; nextPolish=t+16000+Math.random()*12000;
  const metal=H.openEls().find(p=>p.dataset.mat==='metal'); if(!metal||Math.random()<.5) return;
  const r=H.rel(metal); H.travel(r.left+r.width*.5,r.top-N.r+2,180,'free',()=>{ emote('🧽'); H.say('Giving the metal a polish.',1400,null,2); setTimeout(()=>H.goPerch(),2200); });
});
/* picker: long-press a panel title, or use 🧱 for the default */
let lp=0, lpEl=null;
const pop=document.createElement('div'); pop.className='mat-pop glass'; pop.hidden=true; pop.setAttribute('role','dialog'); pop.setAttribute('aria-label','Choose a material'); stage.appendChild(pop);
pop.addEventListener('pointerdown',e=>e.stopPropagation());
function openPop(p,x,y){ pop.innerHTML=`<p>Material for ${p.getAttribute('aria-label')?.replace(' panel','')||'this panel'}</p>`+Object.entries(MATS).map(([k,v])=>`<button data-m="${k}" class="${(matOf(p)||'glass')===k?'on':''}">${v.i} ${v.n}</button>`).join('');
  pop._p=p; pop.hidden=false; pop.style.transform=`translate(${H.clamp(x-125,10,stage.clientWidth-260)}px,${H.clamp(y+14,64,stage.clientHeight-170)}px)`; emote('🧱'); }
pop.addEventListener('click',e=>{ const b=e.target.closest('[data-m]'); if(!b) return; setMat(pop._p,b.dataset.m==='glass'?'':b.dataset.m); pop.hidden=true;
  H.say({glass:'Back to glass.',liquid:'Liquid. Careful, it splashes.',acrylic:'Acrylic. Tough stuff.',metal:'Metal! I\'ll polish it.',paper:'Paper. I\'ll tiptoe.',jelly:'JELLY. I\'m going to bounce on it.'}[b.dataset.m],1600,null,2); });
stage.addEventListener('pointerdown',e=>{ if(!pop.hidden&&!e.target.closest('.mat-pop')) pop.hidden=true; const h=e.target.closest('.ph'); if(!h||e.target.closest('button')) return;
  lpEl={p:h.closest('.panel'),x:e.clientX,y:e.clientY}; clearTimeout(lp); lp=setTimeout(()=>{ if(lpEl){ const r=stage.getBoundingClientRect(); openPop(lpEl.p,lpEl.x-r.left,lpEl.y-r.top); lpEl=null; } },650); },true);
stage.addEventListener('pointermove',e=>{ if(lpEl&&Math.hypot(e.clientX-lpEl.x,e.clientY-lpEl.y)>8){ clearTimeout(lp); lpEl=null; } },true);
stage.addEventListener('pointerup',()=>{ clearTimeout(lp); lpEl=null; },true);
const card=PB.card(`<h3>🧱 Materials</h3><p>Default material for every panel. Long-press any panel's title to give it its own.</p><div class="pr" id="matDef"></div><div class="pr"><button class="pc" id="matMenus"></button></div><p id="matHint"></p><div class="pr"><button class="pc" id="matReset">Reset all panels</button></div>`);
const btn=PB.button('🧱','Materials',()=>{ if(PB.toggle(card,btn)) sync(); });
function sync(){ card.querySelector('#matDef').innerHTML=Object.entries(MATS).map(([k,v])=>`<button class="pc ${(M.def||'glass')===k?'on':''}" data-d="${k}">${v.i} ${v.n}</button>`).join('');
  const mb=card.querySelector('#matMenus'); mb.textContent=M.menus?'Menus too: on':'Menus too: off'; mb.classList.toggle('on',M.menus);
  const sug=ERA_SUGGEST[S.era]; card.querySelector('#matHint').innerHTML=sug?`This era suits <b>${MATS[sug].n}</b>. <button class="pc" data-d="${sug}">Use it</button>`:''; }
card.addEventListener('click',e=>{ const b=e.target.closest('[data-d]'); if(b){ M.def=b.dataset.d==='glass'?'':b.dataset.d; save(); H.openEls().forEach(p=>{ if(!M.panels[p.id]){ if(M.def) p.dataset.mat=M.def; else delete p.dataset.mat; } }); applyMenus(); sync(); emote(MATS[b.dataset.d].i); }
  if(e.target.id==='matMenus'){ M.menus=!M.menus; save(); applyMenus(); sync(); }
  if(e.target.id==='matReset'){ M.panels={}; M.def=''; save(); H.openEls().forEach(p=>delete p.dataset.mat); applyMenus(); sync(); H.say('Everything back to glass.',1300,null,2); } });
window.addEventListener('pip:look',({detail})=>{ const sug=ERA_SUGGEST[detail.era||S.era]; if(sug&&!M.def) setTimeout(()=>H.say(`This era would suit ${MATS[sug].n.toLowerCase()}. 🧱 has it.`,2200,null,2),2600); });
window.PipMaterials={M,setMat,MATS,applyMenus};

})();
