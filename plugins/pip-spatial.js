/* =====================================================================
  PIP PLUGIN PACK · v1 · 13 plugins in one paste
  Paste this whole file at the very end of a copy of Pip Sandbox V2 (stage 12+).

  Inside, in load order:
    1. 🧭 Spatial awareness (Trial)
    2. 🐦 Panel Flap (Dream)
    3. 📓 Pip Remembers (Grounded)
    4. 🌫️ Weather Window (Dream)
    5. 🌗 Shadow Puppets (Grounded)
    6. 🌙 Night Shift (Grounded)
    7. ✉️ Postcards (Trial)
    8. 🧱 Stack Attack (Dream)
    9. 🎵 Glass Harp (Dream)
   10. 📷 Pip Cam (Trial)
   11. 🫧 Focus Bubble (Grounded)
   12. 🥚 Era Easter Eggs (Dream)
   13. ⚡ Eager Pip (Dream)

  Manage them in Developer › Plugins: switch any off (then Reload to apply),
  and promote or demote them between Dream → Trial → Grounded → Core.
  Each plugin below is still its own self-contained block: delete a block to
  remove that plugin for good. Tuning lives at the top of each block.
  ===================================================================== -->
<!-- =====================================================================
  PIP SPATIAL AWARENESS · plugin v1
  Loaded by the sandbox loader (see PLUGINS in index.html). Needs window.PipHost (host.js).
  (stage 11.3 or later: it needs window.PipHost and the "pip:" events).

  What it adds
  1. Bump, think, decide. When the companion bumps into a panel they stop,
     wonder (🤔), realise (💡) and choose: slip BEHIND the glass (🫣) or hop
     OVER it (😤). Personality leans the choice; your throw nudges it:
     a slow push sends them behind, a firm flick sends them over.
  2. Emoji in small glass bubbles for things you do and things they feel.
     Rate-limited, never more than one at a time.
  3. Wings while flying. They flap when moving, following you or tucked
     behind glass, and fold away when perched on the clock.

  Tuning: change PIP_SPATIAL below. Switch it off in the Plugins panel, or remove it from PLUGINS.
  =====================================================================
*/
(() => {
const PIP_SPATIAL={
  emoji:true,          // glass-bubble emoji reactions
  wings:'flying',      // 'flying' · 'always' · 'never'
  decide:true,         // bump → think → choose front or behind
  gapMs:900,           // minimum time between emoji
  thinkMs:520,         // how long they ponder after a bump
  pushSlow:520,        // bump speed below this: slips behind
  flickFirm:1150       // bump speed above this: hops over
};
const H=window.PipHost;
if(!H){ console.warn('Pip Spatial: no PipHost found. Use Pip Sandbox V2 stage 11.3 or later.'); return; }
const {N,S,stage,navi}=H;
if(H.registerPlugin&&!H.registerPlugin({id:'spatial',name:'Spatial awareness',icon:'🧭',shelf:'trial',desc:'Bump, think, choose front or behind; emoji bubbles; wings when flying.'})) return;

/* ---------- styles ---------- */
const css=document.createElement('style'); css.textContent=`
.emo{position:absolute;left:0;top:0;z-index:47;pointer-events:none;display:grid;place-items:center;min-width:34px;height:34px;padding:0 6px;box-sizing:border-box;border-radius:17px;font-size:19px;line-height:1;
  background:color-mix(in srgb, var(--accent) 10%, var(--glass-strong));-webkit-backdrop-filter:blur(12px) saturate(1.7);backdrop-filter:blur(12px) saturate(1.7);
  box-shadow:inset 1px 1px 0 rgba(255,255,255,.8), inset 0 0 0 .5px rgba(255,255,255,.4), 0 4px 14px rgba(0,0,0,.16);opacity:0;scale:.4;transition:opacity .18s, scale .32s cubic-bezier(.2,1.7,.4,1)}
.emo::after{content:"";position:absolute;left:5px;bottom:-5px;width:9px;height:9px;border-radius:50%;background:inherit;box-shadow:inherit}
.emo.on{opacity:1;scale:1}
.navi.flying .wing{opacity:.85 !important}
.navi.wings-always .wing{opacity:.85 !important}
.navi.wings-never .wing{opacity:0 !important}
.navi.thinking .nb{animation:pipTilt .5s ease-in-out}
@keyframes pipTilt{40%{rotate:-12deg}80%{rotate:6deg}}
@media (prefers-reduced-motion: reduce){ .emo{transition:opacity .15s} .navi.thinking .nb{animation:none} }`;
document.head.appendChild(css);

/* ---------- emoji bubble ---------- */
const bub=document.createElement('span'); bub.className='emo'; bub.setAttribute('aria-hidden','true'); stage.appendChild(bub);
let lastEmo=-1e9, emoT=0, emoPri=0;
function emote(ch,{pri=1,ms=1300}={}){
  if(!PIP_SPATIAL.emoji||!S.naviOn) return false;
  const t=H.now(); if(t-lastEmo<PIP_SPATIAL.gapMs&&pri<=emoPri) return false;
  lastEmo=t; emoPri=pri; bub.textContent=ch; bub.classList.add('on'); clearTimeout(emoT);
  emoT=setTimeout(()=>{ bub.classList.remove('on'); emoPri=0; },ms); return true;
}
window.PipSpatial={emote,config:PIP_SPATIAL};

/* ---------- bump → think → decide ---------- */
let pending=null; const cool=new WeakMap();
H.bump.push(({el,speed,nx,ny})=>{
  if(!PIP_SPATIAL.decide||pending||speed<70||!H.grounded()||N.mood==='sulk'||H.G.on) return;
  const t=H.now(); if(cool.has(el)&&t-cool.get(el)<3500) return; cool.set(el,t);
  const vx=N.vx, vy=N.vy;                        // where they were heading, before the bounce
  N.vx*=.15; N.vy*=.15;
  pending={el,speed,nx,ny,dir:Math.atan2(-ny||vy,-nx||vx),t};
  navi.classList.add('thinking'); emote('🤔',{pri:2,ms:PIP_SPATIAL.thinkMs});
  setTimeout(decide,PIP_SPATIAL.thinkMs);
});
function decide(){
  const p=pending; pending=null; navi.classList.remove('thinking');
  if(!p||!p.el.isConnected||p.el.hidden||N.state==='held'||N.state==='follow') return;
  const r=H.rel(p.el), bounce=H.persona().bounce;
  /* the nudge: slow push → behind, firm flick → over; otherwise personality leans it */
  let behind = p.speed<PIP_SPATIAL.pushSlow ? true : p.speed>PIP_SPATIAL.flickFirm ? false : Math.random() < (bounce>1.1?.3:bounce<.8?.75:.5);
  emote('💡',{pri:3,ms:700});
  setTimeout(()=>{
    if(behind){
      /* slip through: aim for the far side along the way they were travelling */
      const c=H.mid(r), ex=H.clamp(c.x-p.nx*(r.width/2+N.r+18),N.r,stage.clientWidth-N.r), ey=H.clamp(c.y-p.ny*(r.height/2+N.r+18),70,stage.clientHeight-N.r);
      N.back=true; Object.assign(N,{state:'travel',tx:ex,ty:ey,tsp:150,after:'free',onArrive:null,perchTrack:false});
      emote('🫣',{pri:4,ms:1100});
    } else {
      /* hop over the top edge and down the other side */
      const over=Math.min(r.top-N.r-10, N.y-60), ex=H.clamp(N.x-p.nx*(r.width+N.r*2+20)*(Math.abs(p.nx)>.5?1:0)+(Math.abs(p.nx)>.5?0:(N.x<H.mid(r).x?-1:1)*20),N.r,stage.clientWidth-N.r);
      N.back=false; N.hopT=H.now(); N.squash=-.2;
      Object.assign(N,{state:'travel',tx:H.clamp(N.x,N.r,stage.clientWidth-N.r),ty:Math.max(70,over),tsp:420,after:'free',perchTrack:false,
        onArrive:()=>{ Object.assign(N,{state:'travel',tx:ex,ty:Math.max(70,over),tsp:300,after:'free',onArrive:null}); }});
      emote('😤',{pri:4,ms:900});
    }
  },380);
}

/* ---------- per-frame: wings, emerging from glass, state-change emoji ---------- */
let prev={state:N.state,mood:'',back:N.back,awake:N.awake,dizzy:false,pet:false,sulk:false,follow:false}, outSince=0;
H.frame.push((dt,t)=>{
  const sp=Math.hypot(N.vx,N.vy), flying=N.awake&&N.state!=='perch'&&N.state!=='sleep'&&(sp>50||N.state==='follow'||N.state==='travel'||N.back);
  navi.classList.toggle('flying',PIP_SPATIAL.wings==='flying'&&flying);
  navi.classList.toggle('wings-always',PIP_SPATIAL.wings==='always');
  navi.classList.toggle('wings-never',PIP_SPATIAL.wings==='never');
  /* bubble follows, up and to the right */
  if(bub.classList.contains('on')) bub.style.transform=`translate(${N.x+N.r*.6}px,${N.y-N.r-38}px)`;
  /* coming out the other side of the glass (Grounded) */
  if(H.grounded()&&N.back&&N.state==='free'&&N.mood!=='sulk'){
    const inside=H.openEls().some(e=>{const r=H.rel(e); return N.x>r.left&&N.x<r.right&&N.y>r.top&&N.y<r.bottom;});
    if(!inside){ if(!outSince) outSince=t; else if(t-outSince>450){ N.back=false; outSince=0; emote('👋'); } } else outSince=0;
  }
  /* reactions to what they're feeling */
  const now={state:N.state,back:N.back,awake:N.awake,dizzy:t<N.dizzyUntil,pet:!!N.pet,sulk:N.mood==='sulk',follow:N.state==='follow',drink:!!N.drink,
    mood:N.pat<.45?'annoyed':N.pat<.72?'meh':'ok'};
  if(now.awake&&!prev.awake) emote('👀');
  if(now.state==='held'&&prev.state!=='held') emote('😮');
  if(now.dizzy&&!prev.dizzy) emote('💫',{pri:2});
  if(now.pet&&!prev.pet) emote('🥰',{pri:2,ms:1800});
  if(now.sulk&&!prev.sulk) emote('😒',{pri:3,ms:2000});
  if(!now.sulk&&prev.sulk) emote('😌',{pri:2});
  if(now.follow&&!prev.follow) emote(H.P.pen?'✏️':'👆');
  if(!now.sulk&&now.mood!==prev.mood){ if(now.mood==='annoyed') emote('😤',{pri:2}); else if(now.mood==='meh') emote('😐'); }
  if(now.drink&&!prev.drink) emote('😋',{pri:2});
  if(N.state==='perch'&&prev.state==='travel'&&!N.back) emote('🙂',{pri:0});
  prev=now;
});

/* ---------- reactions to what you do ---------- */
const on=(n,f)=>window.addEventListener('pip:'+n,e=>f(e.detail||{}));
on('tap',({pat})=>{ if(pat>.72&&Math.random()<.4) emote(H.pick(['😊','✨','🙂'])); });
on('crack',()=>emote('😬',{pri:2}));
on('smash',()=>emote('😱',{pri:3,ms:1500}));
on('splash',()=>emote('💦',{pri:2}));
on('crash',()=>emote('😮',{pri:3,ms:1600}));
on('collect',()=>emote('✨',{pri:2}));
on('found',()=>emote(N.mood==='sulk'?'🙈':'👋',{pri:3}));
on('look',()=>emote('🤩',{pri:2}));
on('face',()=>emote('💌',{pri:2}));
on('drink',({kind})=>emote(kind==='tea'?'☕':kind==='coffee'?'☕':'💧',{pri:3}));
})();
