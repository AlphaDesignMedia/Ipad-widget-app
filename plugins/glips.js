/* =====================================================================
  🫧 GLIPS · super plugin v1   (Dream shelf)
  Loaded by the sandbox loader (see PLUGINS in index.html).
  Where: 🫧 in the plugin bar. Card tabs: Story · Family · Personality · Morph · Settings.
  - STORY: Pip's names through the eras (fits the time machine's lore: Ada Pane, 1887).
  - FAMILY: Clip (the paperclip body Pip left behind in 1997) and Pib (the bootleg).
  - PERSONALITY: curious and helpful from the start. Trust, curiosity and helpfulness drift
    slowly with how you treat them (small steps, capped per day). Pronoun: they / he / she.
  - MEND: Pip seals cracked panels, brings smashed panels back, fixes a cracked clock before
    it shatters. Less helpful Pips ask first (tap to say yes). Clip helps in the 404 game,
    never with more than half the pieces.
  - MORPH: Pip becomes a glass silhouette of what they're helping with (plaster, panel, clock,
    magnifier, phone, drop, heart); Clip bends their wire into the same shapes.
  - EMOJI STYLES: glass, sticker, bubble, pixel, outline, neon, tooltip, or random each time.
  Skeuomorphism rules for morphs (the guidelines; also shown in the Morph tab):
    1 Silhouette first   2 One material at a time   3 Keep the eyes   4 Show, then go back
    5 Honest shapes      6 Real motion (overshoot, settle)   7 One light, top-left
    8 Calm mode: with Simpler motion on, fade instead of bend
  Sandbox notes (Claude, 29 Oct): smashed panels stay smashed unless "Bring smashed panels back" is on
  (smashing to close is a favourite); cracks are sealed only after 4 quiet seconds, so a second hit can
  still smash; ✋ Stop interrupts a repair or a look.
  Switch it off in the Plugins panel, or remove it from PLUGINS.
  ===================================================================== */
(() => {
const H=window.PipHost;
if(!H||!H.registerPlugin){ console.warn('Glips: needs Pip Sandbox V2 stage 12 or later.'); return; }
const {N,S,stage,navi}=H;
if(!H.registerPlugin({id:'glips',name:'Glips',icon:'🫧',shelf:'dream',desc:'Pip\'s family, history and personality. Mends broken glass, morphs into silhouettes, styles emoji. Clip helps.'})) return;
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
/* GLIPS: Pip's family, history, personality, mending, morphing and emoji styles. */
const CFG=Object.assign({mend:true,unsmash:false,clip:true,morph:true,curious:true,emo:'glass',pro:'they'},H.store.get('glip-cfg',{}));
const saveCfg=()=>H.store.set('glip-cfg',CFG);
const TR=Object.assign({trust:.6,curious:.8,helpful:.85},H.store.get('glip-traits',{}));
const MET=H.store.get('glip-met',{pip:true});
const panelsEl=document.getElementById('panels'), T=(f,ms)=>setTimeout(f,ms), svgNS='http://www.w3.org/2000/svg';
const css=document.createElement('style'); css.textContent=`
.navi.glip-hide .nb{opacity:0;transition:opacity .12s}
.glip-m{position:absolute;left:0;top:0;z-index:31;width:72px;height:72px;pointer-events:none;overflow:visible;opacity:0;transition:opacity .15s}
.glip-m.on{opacity:1}
.glip-clip{position:absolute;left:0;top:0;z-index:31;width:50px;height:50px;pointer-events:none;overflow:visible;filter:drop-shadow(0 2px 3px rgba(0,0,0,.25))}
.glip-clip-say{position:absolute;left:0;top:0;z-index:47;max-width:200px;padding:6px 9px;border-radius:10px;border:1.5px solid #8b929c;background:#fff;color:#22252b;
  font:600 12.5px/1.25 var(--ui);pointer-events:none;opacity:0;transition:opacity .15s;box-shadow:0 4px 12px rgba(0,0,0,.15)}
.glip-clip-say.on{opacity:1}
.glip-tabs{display:flex;gap:2px;padding:3px;border-radius:999px;background:var(--wash)}
.glip-tabs button{flex:1;min-height:32px;border:0;border-radius:999px;background:transparent;color:var(--ink2);font:600 12.5px/1 var(--ui);cursor:pointer}
.glip-tabs button[aria-pressed="true"]{background:var(--glass-strong);color:var(--ink);box-shadow:0 1px 3px var(--shade)}
.glip-tl{display:grid;gap:8px}
.glip-tl div{display:grid;grid-template-columns:44px 1fr;gap:2px 10px}
.glip-tl b{font:700 12px/1.3 var(--ui);color:var(--accent)}
.glip-tl span{font:650 13.5px/1.3 var(--ui)}
.glip-tl small{grid-column:2;font:400 12.5px/1.35 var(--ui);color:var(--ink2)}
.glip-fam{display:grid;gap:8px}
.glip-fam>div{display:grid;grid-template-columns:36px 1fr;gap:2px 10px;align-items:start}
.glip-fam i{grid-row:span 2;width:32px;height:32px;display:grid;place-items:center;font-style:normal;font-size:20px;border-radius:10px;background:var(--wash)}
.glip-fam span{font:650 13.5px/1.3 var(--ui)}
.glip-fam small{font:400 12.5px/1.35 var(--ui);color:var(--ink2)}
.glip-bar{display:grid;grid-template-columns:76px 1fr;gap:8px;align-items:center;font:600 12px/1 var(--ui);color:var(--ink2)}
.glip-bar em{height:8px;border-radius:4px;background:var(--wash);overflow:hidden;box-shadow:inset 0 0 0 1px var(--hair)}
.glip-bar em i{display:block;height:100%;background:var(--accent);border-radius:4px}
.glip-rules{margin:0;padding-left:18px;display:grid;gap:5px;font:400 12.5px/1.35 var(--ui);color:var(--ink2)}
.glip-rules b{color:var(--ink)}
/* emoji styles (for the Spatial plugin's bubbles) */
.emo.es-sticker{background:#fff;-webkit-backdrop-filter:none;backdrop-filter:none;box-shadow:0 0 0 3px #fff,0 5px 12px rgba(0,0,0,.28);rotate:-7deg}
.emo.es-pixel{border-radius:0;background:#fff;-webkit-backdrop-filter:none;backdrop-filter:none;box-shadow:inset 0 0 0 2px #111,3px 3px 0 #111;font-size:17px}
.emo.es-pixel::after{border-radius:0}
.emo.es-outline{background:transparent;-webkit-backdrop-filter:blur(4px);backdrop-filter:blur(4px);box-shadow:inset 0 0 0 2px var(--accent)}
.emo.es-outline::after{background:var(--accent);box-shadow:none;width:6px;height:6px}
.emo.es-neon{background:#16121f;-webkit-backdrop-filter:none;backdrop-filter:none;box-shadow:0 0 0 1.5px #ff4fd8,0 0 16px rgba(255,79,216,.75)}
.emo.es-tooltip{border-radius:4px;background:#ffffe1;-webkit-backdrop-filter:none;backdrop-filter:none;box-shadow:inset 0 0 0 1px #2b2f36,2px 2px 0 rgba(0,0,0,.25)}
.emo.es-tooltip::after{border-radius:0;width:7px;height:7px}
.emo.es-bubble{border-radius:50%;min-width:38px;height:38px;background:radial-gradient(circle at 32% 28%,#fff 0 12%,rgba(255,255,255,.25) 30%,color-mix(in srgb,var(--accent) 25%,transparent) 75%);box-shadow:inset 0 0 0 1px rgba(255,255,255,.8),0 4px 14px rgba(0,0,0,.14)}`;
document.head.appendChild(css);

/* =====================================================================
   MORPH: a silhouette of what they're helping with. Shapes are outlines in a
   100×100 box, sampled to the same number of points so any shape bends into any other.
   ===================================================================== */
const SHAPES={
  orb:{d:'M50 10 A40 40 0 1 1 49.99 10 Z',name:'Pip'},
  clock:{d:'M16 28 H84 Q96 28 96 40 V60 Q96 72 84 72 H16 Q4 72 4 60 V40 Q4 28 16 28 Z',name:'Clock'},
  panel:{d:'M26 6 H74 Q88 6 88 20 V80 Q88 94 74 94 H26 Q12 94 12 80 V20 Q12 6 26 6 Z',name:'Panel'},
  plaster:{d:'M14 38 H86 A12 12 0 0 1 86 62 H14 A12 12 0 0 1 14 38 Z',rot:-.6,name:'Plaster'},
  lens:{d:'M42 14 A28 28 0 0 1 64 59 L88 82 Q91 86 87 89 Q84 92 80 88 L57 65 A28 28 0 1 1 42 14 Z',name:'Magnifier'},
  heart:{d:'M50 86 C20 64 6 46 16 28 C26 12 46 16 50 30 C54 16 74 12 84 28 C94 46 80 64 50 86 Z',name:'Heart'},
  phone:{d:'M33 5 H67 Q78 5 78 16 V84 Q78 95 67 95 H33 Q22 95 22 84 V16 Q22 5 33 5 Z',name:'Phone'},
  drop:{d:'M50 6 C62 30 80 44 80 62 A30 30 0 0 1 20 62 C20 44 38 30 50 6 Z',name:'Drop'},
  clip:{d:'M40 86 V28 A10 10 0 0 1 60 28 V76 A7 7 0 0 1 46 76 V36',open:true,name:'Clip'}
};
const NP=72, hidSvg=document.createElementNS(svgNS,'svg'), sampler=document.createElementNS(svgNS,'path'), cache={};
hidSvg.setAttribute('aria-hidden','true'); hidSvg.style.cssText='position:absolute;width:0;height:0;overflow:hidden'; hidSvg.appendChild(sampler); document.body.appendChild(hidSvg);
function pts(name){
  if(cache[name]) return cache[name]; const sh=SHAPES[name]; sampler.setAttribute('d',sh.d); const L=sampler.getTotalLength(), a=[];
  for(let i=0;i<NP;i++){ const p=sampler.getPointAtLength(L*i/(sh.open?NP-1:NP)); let x=p.x-50, y=p.y-50;
    if(sh.rot){ const c=Math.cos(sh.rot), s=Math.sin(sh.rot); [x,y]=[x*c-y*s,x*s+y*c]; } a.push([x+50,y+50]); }
  return cache[name]=a;
}
function align(from,to){   /* start the target where it best lines up with the source, so the bend is short */
  let best=0, bd=1e9;
  for(let k=0;k<NP;k+=2){ let d=0; for(let i=0;i<NP;i+=3){ const q=to[(i+k)%NP]; d+=Math.hypot(from[i][0]-q[0],from[i][1]-q[1]); } if(d<bd){ bd=d; best=k; } }
  return to.map((_,i)=>to[(i+best)%NP]);
}
const dOf=(a,closed)=>'M'+a.map(p=>p[0].toFixed(1)+' '+p[1].toFixed(1)).join('L')+(closed?'Z':'');
function morpher(path,base,closed){
  let cur=pts(base).map(p=>p.slice()), raf=0, backT=0;
  path.setAttribute('d',dOf(cur,closed));
  const go=(name,ms=420,done)=>{ cancelAnimationFrame(raf); const from=cur.map(p=>p.slice()), to=SHAPES[name].open||!closed?pts(name):align(from,pts(name)), t0=performance.now();
    if(H.simpler()){ cur=to.map(p=>p.slice()); path.setAttribute('d',dOf(cur,closed)); done&&done(); return; }
    const step=t=>{ const k=Math.min(1,(t-t0)/ms), e=1-Math.pow(1-k,3)*(1-2.2*k*(1-k));   /* ease out with a little overshoot */
      cur=from.map((p,i)=>[p[0]+(to[i][0]-p[0])*e,p[1]+(to[i][1]-p[1])*e]); path.setAttribute('d',dOf(cur,closed));
      if(k<1) raf=requestAnimationFrame(step); else done&&done(); };
    raf=requestAnimationFrame(step); };
  return { to(name,hold=1300,done){ clearTimeout(backT); go(name,420,()=>{ backT=setTimeout(()=>go(base,360,done),hold); }); }, now(name){ clearTimeout(backT); go(name); } };
}
/* Pip's glass silhouette: drawn over Pip, with Pip's eyes kept on */
const pm=document.createElementNS(svgNS,'svg'); pm.setAttribute('class','glip-m'); pm.setAttribute('viewBox','-10 -10 120 120'); pm.setAttribute('aria-hidden','true');
pm.innerHTML=`<defs><radialGradient id="glipG" cx="34%" cy="28%" r="85%"><stop offset="0" style="stop-color:#fff;stop-opacity:.95"/><stop offset=".4" style="stop-color:color-mix(in srgb,var(--accent) 30%,#fff);stop-opacity:.55"/><stop offset="1" style="stop-color:var(--accent);stop-opacity:.75"/></radialGradient></defs>
  <path fill="url(#glipG)" stroke="rgba(255,255,255,.95)" stroke-width="2.5" stroke-linejoin="round"/><ellipse cx="41" cy="47" rx="4" ry="5" fill="#1d2026"/><ellipse cx="59" cy="47" rx="4" ry="5" fill="#1d2026"/>`;
stage.appendChild(pm);
const pipM=morpher(pm.querySelector('path'),'orb',true);
let morphing=0;
function morph(name,hold=1300){
  if(!CFG.morph||!S.naviOn||morphing) return; morphing=1; pm.classList.add('on'); navi.classList.add('glip-hide');
  pipM.to(name,hold,()=>{ pm.classList.remove('on'); navi.classList.remove('glip-hide'); morphing=0; });
}
H.frame.push(()=>{ if(morphing) pm.style.transform=`translate(${N.x-36}px,${N.y-36}px)`; });

/* =====================================================================
   CLIP: the paperclip body Pip left behind in 1997. Still keen. Only turns up when there's a job.
   ===================================================================== */
let clip=null;
function makeClip(){
  if(clip) return clip; MET.clip=true; H.store.set('glip-met',MET);
  const el=document.createElementNS(svgNS,'svg'); el.setAttribute('class','glip-clip'); el.setAttribute('viewBox','0 0 100 100'); el.setAttribute('role','img'); el.setAttribute('aria-label','Clip, a paperclip helper');
  el.innerHTML=`<defs><linearGradient id="glipW" x1="0" x2="1"><stop offset="0" stop-color="#eef1f5"/><stop offset=".5" stop-color="#9aa3ae"/><stop offset="1" stop-color="#dfe3e8"/></linearGradient></defs>
    <path fill="none" stroke="url(#glipW)" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/><circle cx="45" cy="34" r="4.5" fill="#1d2026"/><circle cx="56" cy="34" r="4.5" fill="#1d2026"/>`;
  const say=document.createElement('div'); say.className='glip-clip-say'; say.setAttribute('role','status');
  stage.append(el,say);
  const c={el,say,x:stage.clientWidth+30,y:140,tx:0,ty:0,go:false,cb:null,m:morpher(el.querySelector('path'),'clip',false),sayT:0};
  c.talk=(t,ms=1800)=>{ say.textContent=t; say.classList.add('on'); clearTimeout(c.sayT); c.sayT=T(()=>say.classList.remove('on'),ms); };
  c.moveTo=(x,y,cb)=>{ c.tx=x; c.ty=y; c.go=true; c.cb=cb||null; };
  c.leave=()=>c.moveTo(stage.clientWidth+40,c.y,()=>{ el.remove(); say.remove(); clip=null; });
  return clip=c;
}
H.frame.push((dt)=>{
  if(!clip) return; const c=clip;
  if(c.go){ const dx=c.tx-c.x, dy=c.ty-c.y, d=Math.hypot(dx,dy), sp=Math.min(d,520*dt);
    if(d<2){ c.go=false; const f=c.cb; c.cb=null; f&&f(); } else { c.x+=dx/d*sp; c.y+=dy/d*sp; }
    c.el.style.rotate=H.clamp(dx/40,-14,14)+'deg'; }
  c.el.style.transform=`translate(${c.x-25}px,${c.y-25}px)`; c.say.style.transform=`translate(${c.x-10}px,${c.y-66}px)`;
});

/* =====================================================================
   PERSONALITY: curious and helpful from the start; trust, curiosity and helpfulness drift
   slowly with how you treat them. Never more than a small step a day.
   ===================================================================== */
function nudge(k,by){
  const day=new Date().toDateString(), log=H.store.get('glip-day',{day,m:{}}); if(log.day!==day){ log.day=day; log.m={}; }
  const moved=log.m[k]||0; if(Math.abs(moved+by)>.06) return;
  log.m[k]=moved+by; H.store.set('glip-day',log); TR[k]=H.clamp(TR[k]+by,.1,1); H.store.set('glip-traits',TR);
}
const on=(n,f)=>addEventListener('pip:'+n,e=>f(e.detail||{}));
on('tap',()=>nudge('trust',.004));
on('crack',()=>nudge('trust',-.008)); on('smash',()=>nudge('trust',-.012)); on('crash',()=>nudge('trust',-.01));
const PRO={they:['they','them','their'],he:['he','him','his'],she:['she','her','her']};
const pro=i=>PRO[CFG.pro][i];
function describe(){
  const name=S.name||'Pip', t=TR.trust>.7?'trusting':TR.trust<.4?'a bit careful around you':'warming up to you', c=TR.curious>.75?'very curious':TR.curious<.45?'quietly curious':'curious';
  const h=TR.helpful>.75?'always first to help':TR.helpful<.45?'helps when asked':'keen to help';
  return `${name} is ${c}, ${h}, and ${t}. ${pro(0)[0].toUpperCase()+pro(0).slice(1)} change${CFG.pro==='they'?'':'s'} slowly with how you treat ${pro(1)}.`;
}

/* =====================================================================
   MEND: cracked panels sealed, smashed panels brought back, a cracked clock fixed
   before it shatters, and Clip pitching in on the 404 game.
   ===================================================================== */
let busy=false;
const free=()=>CFG.mend&&S.naviOn&&!busy&&!H.G.on&&N.state!=='held'&&N.state!=='follow'&&!(H.isBusy&&H.isBusy());
const setBusy=v=>{ busy=v; H.busy&&H.busy('glips',v); };
addEventListener('pip:interrupt',()=>{ busy=false; });
function goFix(x,y,shape,fix,line){
  setBusy(true); if(!N.awake) H.wake();
  H.travel(H.clamp(x,N.r,stage.clientWidth-N.r),H.clamp(y,70,stage.clientHeight-N.r),360,'free',()=>{
    morph(shape,900); emote('🛠️',{pri:3});
    T(()=>{ fix(); H.beep([[988,40],[1318,60]]); if(line) H.say(line,1600,null,1); nudge('helpful',.005); setBusy(false); if(H.grounded()) T(()=>{ if(N.state==='free') H.goPerch(); },1400); },700);
  });
}
function offer(cb){   /* less helpful Pips ask first; tap them within six seconds to say yes */
  if(TR.helpful>=.55){ cb(); return; }
  H.say('Want me to fix that? Tap me.',2600,null,1); let ok=false;
  const yes=()=>{ ok=true; cb(); nudge('helpful',.01); }; addEventListener('pip:tap',yes,{once:true});
  T(()=>{ removeEventListener('pip:tap',yes); if(!ok) nudge('helpful',-.004); },6000);
}
on('crack',({el})=>T(()=>{
  if(!free()||!el?.isConnected||el.hidden) return; const c=el.querySelector('.pcrack'); if(!c) return;   /* Materials may have healed it already */
  const r=H.rel(el), o=c.querySelector('circle'), x=r.left+(+o?.getAttribute('cx')||r.width/2), y=r.top+(+o?.getAttribute('cy')||r.height/2);
  offer(()=>goFix(x,y-N.r,'plaster',()=>{ el.querySelectorAll('.pcrack').forEach(s=>s.animate?s.animate([{opacity:1},{opacity:0}],{duration:400}).onfinish=()=>s.remove():s.remove()); el._cracks=0; },H.pick(['Good as new.','Sealed.','There. You can\'t even tell.'])));
},4000));
on('smash',({el})=>{
  if(!el) return; const id=el.id.replace(/^p-/,''), x=parseFloat(el.style.left)||0, y=parseFloat(el.style.top)||0;
  T(()=>{ if(!CFG.unsmash||!free()||!el.hidden) return;
    offer(()=>goFix(x+40,y+20,'panel',()=>{ try{ H.openPanel(id,{at:{x,y}}); }catch{} },H.pick(['Put it back together.','All the pieces were there.','Fixed. Mind the edges.']))); },1500);
});
let clockSeen=0;
H.frame.push((dt,t)=>{
  if(H.G.cracks!==1||H.G.on){ clockSeen=0; return; } if(!clockSeen){ clockSeen=t; return; }
  if(t-clockSeen<2500||!free()) return; clockSeen=t+1e9;
  const c=H.cardRect(); offer(()=>goFix(c.left+c.width*.5,c.top-N.r,'clock',()=>{ H.G.cracks=0; delete H.cardIn.dataset.cracks; },'Clock\'s mended. Gently next time?'));
});
/* Clip helps on the 404 game, but never with more than half the pieces */
let helpT=0, helped=0;
on('crash',()=>{ helped=0; clearTimeout(helpT); if(CFG.clip&&CFG.mend) helpT=T(clipHelp,12000); });
on('restore',()=>{ clearTimeout(helpT); if(clip&&!clip.go) T(()=>clip?.leave(),900); });
function clipHelp(){
  if(!H.G.on) return; const left=H.G.shards.filter(s=>!s.got); if(!left.length||helped>=Math.floor(H.G.shards.length/2)) return;
  const c=makeClip(); if(!helped){ c.y=H.clamp(left[0].y,90,stage.clientHeight-60); c.talk(H.pick(['It looks like you\'re fixing a clock! Can I help?','Need a hand? I am mostly hand.']),2400); }
  const s=left.reduce((a,b)=>Math.hypot(b.x-c.x,b.y-c.y)<Math.hypot(a.x-c.x,a.y-c.y)?b:a);
  c.moveTo(s.x,s.y,()=>{ if(!H.G.on||s.got) return; s.got=true; helped++; c.m.to('clock',600);
    const cc=H.cardCentre(); s.el.classList.add('got'); s.el.style.transform=`translate(${cc.x-18}px,${cc.y-18}px) scale(.4)`; H.beep([[1200,60]]); H.emit('collect');
    if(H.G.shards.every(q=>q.got)){ T(()=>H.restore(false),550); return; }
    if(helped===1&&S.naviOn) T(()=>H.say('Clip! Long time no see.',1800,null,1),700);
    helpT=T(clipHelp,6000); });
}

/* =====================================================================
   CURIOUS: they come and have a look when something new opens.
   ===================================================================== */
let lastLook=-1e9;
new MutationObserver(ms=>{
  const el=ms.map(m=>m.target).find(e=>e.classList?.contains('panel')&&!e.hidden); if(!el) return; nudge('curious',.002);
  const t=H.now(); if(!CFG.curious||!free()||!N.awake||t-lastLook<45000||Math.random()>TR.curious-.25) return;
  if(N.state!=='perch'&&N.state!=='free') return; lastLook=t; busy=true;   /* a glance: no ✋ Stop chip for this */
  T(()=>{ if(el.hidden){ busy=false; return; } const r=H.rel(el);
    H.travel(H.clamp(r.left+30,N.r,stage.clientWidth-N.r),Math.max(80,r.top-N.r-2),300,'free',()=>{ morph('lens',1000); emote('🔍');
      if(Math.random()<.3) H.say(H.pick(['Ooh, what\'s in here?','Just having a look.','Don\'t mind me.']),1400,null,2);
      T(()=>{ busy=false; if(H.grounded()&&N.state==='free') H.goPerch(); },1800); }); },400);
}).observe(panelsEl,{subtree:true,attributes:true,attributeFilter:['hidden']});
/* small silhouettes for other moments */
on('drink',()=>T(()=>morph('drop',900),300));
on('screen',(i)=>{ if(i&&lastOrient&&i.orient!==lastOrient) T(()=>morph('phone',900),500); lastOrient=i?.orient; });
let lastOrient=null;
on('tap',()=>{ if(TR.trust>.75&&Math.random()<.08) T(()=>morph('heart',700),200); });

/* =====================================================================
   EMOJI STYLES: dress the Spatial plugin's emoji bubbles. Random picks a new style each time.
   ===================================================================== */
const EMO=['glass','sticker','bubble','pixel','outline','neon','tooltip'];
function dressEmo(){ const e=document.querySelector('.emo'); if(!e||e._glip) return; e._glip=true;
  new MutationObserver(()=>{ if(!e.classList.contains('on')||e._dressed) { if(!e.classList.contains('on')) e._dressed=false; return; } e._dressed=true;
    const st=CFG.emo==='random'?H.pick(EMO):CFG.emo; EMO.forEach(s=>e.classList.toggle('es-'+s,s===st&&s!=='glass')); }).observe(e,{attributes:true,attributeFilter:['class']}); }
dressEmo(); T(dressEmo,1000);

/* =====================================================================
   THE 🫧 CARD: Story · Family · Personality · Morph · Settings
   ===================================================================== */
const STORY=[
  ['1887','The Bubble','Ada Pane drops her pocket watch into molten glass. A bubble forms around the tick and refuses to pop. Ada calls it "the Bubble" and pays it in tea.'],
  ['1983','Beep','Moonlights inside a digital watch. Learns exactly one word.'],
  ['1987','Tick','The clock on a beige desk computer. Two colours, one job, very proud.'],
  ['1997','(with Clip)','The temp job. The Bubble wears a bent paperclip as a body to look professional. When it\'s let go, it slips out and leaves the paperclip behind. The paperclip keeps working. That\'s Clip.'],
  ['2001','Gummy','Everything went translucent. A tangerine year, never explained.'],
  ['2003','(about Pib)','Someone copies the Bubble from a blurry screenshot and gets the name wrong. That\'s Pib. Pib still thinks Pib is the original.'],
  ['2004','Toast','Builds a robot body in a shed, mostly from a toaster.'],
  ['2007','Halo','Glossy glass returns. The Bubble moves straight back in.'],
  ['2013','—','There is no exhibit for 2013. We don\'t talk about the flat years.'],
  ['Now','Pip','Liquid glass. Short name, easy to shout across a room. Named after the little dot on a watch face that marks the hour.']
];
const RULES=[
  ['Silhouette first.','Any shape must read by its outline alone, at Pip size. No detail inside it.'],
  ['One material at a time.','Pip bends glass, Clip bends wire. A shape never mixes them.'],
  ['Keep the eyes.','However far they morph, the eyes stay. That\'s how you know it\'s still them.'],
  ['Show, then go back.','A morph explains or reacts, then returns within about two seconds.'],
  ['Honest shapes.','The outline should hint at what the thing does: a plaster seals, a lens looks.'],
  ['Real motion.','Bend with a small overshoot and a settle, the way soft glass or wire would.'],
  ['One light.','Highlights sit top-left, the same light as the panels.'],
  ['Calm mode.','With Simpler motion on, shapes swap with a quick fade instead of bending.']
];
let tab=H.store.get('glip-tab','story');
const card=PB.card(`<h3>🫧 Glips</h3><div class="glip-tabs" role="group" aria-label="Glips sections">${[['story','Story'],['family','Family'],['me','Personality'],['morph','Morph'],['set','Settings']].map(([k,l])=>`<button data-tab="${k}">${l}</button>`).join('')}</div><div id="glipBody"></div>`);
const btn=PB.button('🫧','Glips',()=>{ if(PB.toggle(card,btn)) sync(); });
function sync(){
  if(card.hidden) return; card.querySelectorAll('[data-tab]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.tab===tab)));
  const pibGone=H.store.get('oops-gone',false), pibHere=!!document.querySelector('.pib')||H.plugins.some(m=>m.id==='oops');
  const B=card.querySelector('#glipBody');
  if(tab==='story') B.innerHTML=`<p>Glips: what Pane &amp; Sons called glass that came out a bit alive. ${S.name||'Pip'} has had a few names.</p><div class="glip-tl">${STORY.map(([y,n,s])=>`<div><b>${y}</b><span>${n}</span><small>${s}</small></div>`).join('')}</div>`;
  if(tab==='family') B.innerHTML=`<div class="glip-fam">
    <div><i>🫧</i><span>${S.name||'Pip'}</span><small>The original Bubble. Curious, wants to help, paid in tea.</small></div>
    <div><i>📎</i><span>Clip ${MET.clip?'':'<small>(not met yet)</small>'}</span><small>The paperclip body Pip left behind in 1997. Still offers help, now only three times. Turns up when there's a job.</small></div>
    <div><i>🫠</i><span>Pib</span><small>${pibGone?'Deleted. Somehow still mentioned here.':pibHere?'The bootleg. Thinks they\'re the original. Lives in the accidental plugin.':'Not installed. Lucky.'}</small></div></div>
    <div class="pr"><button class="pc" id="glipClip">Call Clip</button></div>`;
  if(tab==='me') B.innerHTML=`<p>${describe()}</p>
    ${[['curious','Curious'],['helpful','Helpful'],['trust','Trust']].map(([k,l])=>`<div class="glip-bar">${l}<em><i style="width:${Math.round(TR[k]*100)}%"></i></em></div>`).join('')}
    <p>Gentle taps build trust; cracks and smashes knock it a little. Accepting help makes them keener. Curiosity grows as you open things. Never more than a small step a day.</p>
    <div class="pr">${['they','he','she'].map(p=>`<button class="pc" data-pro="${p}">${p}</button>`).join('')}</div>
    <div class="pr"><button class="pc" id="glipReset">Back to how they started</button></div>`;
  if(tab==='morph') B.innerHTML=`<p>Skeuomorphism, the Glip way: become a silhouette of the thing you're helping with.</p>
    <div class="pr">${Object.keys(SHAPES).filter(k=>k!=='orb'&&k!=='clip').map(k=>`<button class="pc" data-shape="${k}">${SHAPES[k].name}</button>`).join('')}</div>
    <ol class="glip-rules">${RULES.map(([a,b])=>`<li><b>${a}</b> ${b}</li>`).join('')}</ol>`;
  if(tab==='set') B.innerHTML=`${[['mend','Mend broken glass'],['unsmash','Bring smashed panels back'],['clip','Clip helps in the 404 game'],['curious','Comes to look at new panels'],['morph','Morph into silhouettes']].map(([k,l])=>`<label class="sw2" style="display:flex;justify-content:space-between;gap:10px;font:500 13.5px/1.3 var(--ui)">${l}<input type="checkbox" class="switch" data-c="${k}"></label>`).join('')}
    <div style="font:700 11px/1 var(--ui);letter-spacing:.06em;text-transform:uppercase;color:var(--ink3)">Emoji style</div>
    <div class="pr">${EMO.concat('random').map(s=>`<button class="pc" data-emo="${s}">${s[0].toUpperCase()+s.slice(1)}</button>`).join('')}</div>
    <p>${document.querySelector('.emo')?'Styles the emoji bubbles from Spatial awareness.':'Emoji bubbles come from the Spatial awareness plugin, which is off or missing.'}</p>`;
  B.querySelectorAll('[data-c]').forEach(c=>{ c.checked=!!CFG[c.dataset.c]; });
  B.querySelectorAll('[data-emo]').forEach(b=>b.classList.toggle('on',b.dataset.emo===CFG.emo));
  B.querySelectorAll('[data-pro]').forEach(b=>b.classList.toggle('on',b.dataset.pro===CFG.pro));
}
card.addEventListener('click',e=>{
  const tb=e.target.closest('[data-tab]'); if(tb){ tab=tb.dataset.tab; H.store.set('glip-tab',tab); sync(); return; }
  const sh=e.target.closest('[data-shape]'); if(sh){ if(!N.awake) H.wake(); morph(sh.dataset.shape,1200); if(clip) clip.m.to(sh.dataset.shape,1200); return; }
  const em=e.target.closest('[data-emo]'); if(em){ CFG.emo=em.dataset.emo; saveCfg(); sync(); emote(H.pick(['✨','🫧','👋','😊']),{pri:5}); return; }
  const pr=e.target.closest('[data-pro]'); if(pr){ CFG.pro=pr.dataset.pro; saveCfg(); sync(); return; }
  if(e.target.closest('#glipReset')){ Object.assign(TR,{trust:.6,curious:.8,helpful:.85}); H.store.set('glip-traits',TR); H.store.del('glip-day'); sync(); return; }
  if(e.target.closest('#glipClip')){ const c=makeClip(); c.x=stage.clientWidth+30; c.y=H.clamp(N.y,100,stage.clientHeight-80);
    c.moveTo(H.clamp(N.x+50,30,stage.clientWidth-30),c.y,()=>{ c.talk(H.pick(['It looks like you\'re reading about me!','Hello! Offering help: one of three.','Need a hand? I am mostly hand.']),2200); c.m.to('heart',900);
      if(S.naviOn&&N.awake) T(()=>H.say('Hi Clip.',1200,null,1),1400); T(()=>c.leave(),3600); }); sync(); }
});
card.addEventListener('change',e=>{ const c=e.target.closest('[data-c]'); if(!c) return; CFG[c.dataset.c]=c.checked; saveCfg(); });
window.PipGlips={morph,traits:TR,config:CFG,makeClip,SHAPES};
})();
