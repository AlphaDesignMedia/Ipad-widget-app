/* =====================================================================
  CLIP ON · plugin v1   (Dream shelf)
  Loaded by the sandbox loader (see PLUGINS in index.html). Where: 📎 in the plugin bar.
  - Drop Pip on the top edge of a panel and he clips on. Drag the panel: he rides along and swings.
  - As the paperclip, his lower half tucks behind the glass and he peeks over the edge.
  - Clippy mode: now and then he hops onto the panel you're using and offers a tip
    (from Pip's Brain if it's on). "It looks like you're…"
  - Grab him to take him off. Closing the panel sends him home.
  Switch it off in the Plugins panel, or remove it from PLUGINS.
  ===================================================================== */
(() => {
const H=window.PipHost;
if(!H||!H.setPerch){ console.warn('Clip On: needs PipHost with setPerch (host.js).'); return; }
const {N,S,stage,navi}=H;
if(!H.registerPlugin({id:'clip-on',name:'Clip On',icon:'📎',shelf:'dream',desc:'Pip clips onto panel edges, swings when you drag them, and offers Clippy tips.'})) return;
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
const CFG=Object.assign({on:true,clippy:true,everyS:75},H.store.get('clip-cfg',{}));
const saveCfg=()=>H.store.set('clip-cfg',CFG);
const css=document.createElement('style'); css.textContent=`
.navi.clipped .fm.clip{rotate:var(--clip-swing,0deg);transform-origin:50% 30%}
.navi.form-clip.clipped .fm.clip svg{-webkit-mask-image:linear-gradient(#000 0 31%,rgba(0,0,0,.42) 36%);mask-image:linear-gradient(#000 0 31%,rgba(0,0,0,.42) 36%)}
.navi.clipped:not(.form-clip) .nb{rotate:var(--clip-swing,0deg);transform-origin:50% 100%}
.panel.clip-host{box-shadow:0 0 0 1px color-mix(in srgb,var(--accent) 35%,transparent),var(--shadow, 0 10px 30px rgba(0,0,0,.18))}
@media (prefers-reduced-motion: reduce){ .navi.clipped .fm.clip,.navi.clipped .nb{rotate:0deg} }`;
document.head.appendChild(css);

let clip=null;                 /* {el, f}: which panel, how far along its top edge */
let swing=0, sv=0, lastX=null;
const isClip=()=>navi.classList.contains('form-clip');
function anchor(){
  if(!clip) return null;
  const el=clip.el; if(!el.isConnected||el.hidden){ release(true); return null; }
  const r=H.rel(el);
  return {x:r.left+clip.f*r.width, y:isClip()?r.top+N.r*.15:r.top-N.r+4};
}
function attach(el,f,fly){
  clip={el,f:H.clamp(f,.12,.88)}; el.classList.add('clip-host'); navi.classList.add('clipped');
  H.setPerch(anchor); lastX=null;
  const p=anchor(); if(!p) return;
  const done=()=>{ H.beep([[1500,10],[900,22]]); N.hopT=H.now(); };
  if(fly) H.travel(p.x,p.y,360,'perch',done,true); else { N.state='perch'; N.vx=N.vy=0; done(); }
}
function release(home){
  if(!clip) return; clip.el.classList.remove('clip-host'); clip=null; navi.classList.remove('clipped'); navi.style.removeProperty('--clip-swing');
  H.setPerch(null); if(home&&S.naviOn&&N.state==='perch'){ N.state='free'; H.goHome(); }
}
addEventListener('pip:perchHome',()=>{ if(clip){ clip.el.classList.remove('clip-host'); clip=null; navi.classList.remove('clipped'); } });

/* which panel top edge is Pip near? */
function edgeNear(x,y,pad=40){
  const els=H.openEls().slice().reverse();          /* front first */
  for(const el of els){ if(el.classList.contains('ad-under')) continue; const r=H.rel(el);
    if(x>r.left+10&&x<r.right-10&&Math.abs(y-r.top)<pad) return {el,f:(x-r.left)/r.width}; }
  return null;
}

let still=0, lastVisit=H.now(), lastTip=0;
H.frame.push((dt,t)=>{
  if(!CFG.on||!S.naviOn){ if(clip) release(false); return; }
  /* taken off: you grabbed him, or something else moved him */
  if(clip&&!['perch','travel','sleep'].includes(N.state)) release(false);
  /* clip on when he settles near a top edge */
  if(!clip&&N.state==='free'&&N.awake){
    const sp=Math.hypot(N.vx,N.vy); still=sp<70?still+dt:0;
    if(still>.12){ const e=edgeNear(N.x,N.y); if(e){ attach(e.el,e.f,false); if(H.chat()>1&&Math.random()<.5) H.say(H.pick(['Click. I\'m on.','Clipped!','Ooh, good view from here.']),1300,null,2); } }
  }
  /* swing: follow the panel's sideways motion with a little spring */
  if(clip){ const p=anchor(); if(p){
      if(lastX!=null){ const v=(p.x-lastX)/Math.max(dt,1/120); sv+=(-v*.035-swing)*18*dt; }
      lastX=p.x; sv*=Math.exp(-3.2*dt); swing=H.clamp(swing+sv*dt*8,-32,32);
      if(Math.abs(swing)<.05&&Math.abs(sv)<.05) swing=0;
      navi.style.setProperty('--clip-swing',swing.toFixed(2)+'deg'); } }
  /* Clippy: now and then, visit the panel you're using and offer a tip */
  if(CFG.clippy&&!clip&&N.awake&&N.state==='perch'&&!H.touring()&&!(H.isBusy&&H.isBusy())&&!H.G.on&&H.chat()>=1&&t-lastVisit>CFG.everyS*1000&&t-(N.lastInteract||0)>8000){
    lastVisit=t; const els=H.openEls().filter(e=>!e.classList.contains('ad-under')); const el=els[els.length-1];
    if(el){ attach(el,.78,true); const id=el.id.replace(/^p-/,'');
      setTimeout(()=>{ if(!clip||clip.el!==el) return; lastTip=H.now();
        const tip=window.PipBrain?.tipFor?.(id);
        H.say(tip?tip.text:H.pick([`It looks like you're in ${id}. Need a hand?`,'It looks like you\'re designing something. Want me to watch?','Just hanging around. Literally.']),4200,null,1);
        if(tip&&tip.lesson) pending=tip.lesson.id;
        emote('📎',{pri:2}); },900); }
  }
});
/* tap Pip while he's offering a lesson: start it */
let pending=null;
addEventListener('pip:tap',()=>{ if(pending&&clip&&H.now()-lastTip<6000){ const id=pending; pending=null; release(false); window.PipBrain?.teach?.(id); } });

/* the 📎 card */
const card=PB.card(`<h3>📎 Clip on</h3>
  <p>Drop ${S.name||'Pip'} on the top edge of a panel and they clip on. Drag the panel and they swing. Grab them to take them off.</p>
  <div class="pr"><button class="pc" id="clBe">Be Clippy</button><button class="pc" id="clNow">Clip onto a panel</button></div>
  <label class="sw2" style="display:flex;justify-content:space-between;gap:10px;font:500 13.5px/1.3 var(--ui)">Clip onto panel edges<input type="checkbox" class="switch" data-c="on"></label>
  <label class="sw2" style="display:flex;justify-content:space-between;gap:10px;font:500 13.5px/1.3 var(--ui)">Clippy visits with tips<input type="checkbox" class="switch" data-c="clippy"></label>`);
const btn=PB.button('📎','Clip on',()=>{ if(PB.toggle(card,btn)) sync(); });
function sync(){ card.querySelectorAll('[data-c]').forEach(c=>{ c.checked=!!CFG[c.dataset.c]; }); card.querySelector('#clBe').classList.toggle('on',S.form==='clip'); }
card.addEventListener('change',e=>{ const c=e.target.closest('[data-c]'); if(!c) return; CFG[c.dataset.c]=c.checked; saveCfg(); if(!CFG.on) release(true); });
card.addEventListener('click',e=>{
  if(e.target.closest('#clBe')){ S.form=S.form==='clip'?'orb':'clip'; H.savePrefs(); H.applyForm(); H.refreshPanels(); sync();
    if(S.naviOn){ if(!N.awake) H.wake(); H.say(S.form==='clip'?'It looks like you want a paperclip.':'Back to round.',1800,null,0); } }
  if(e.target.closest('#clNow')){ const els=H.openEls(); let el=els[els.length-1];
    if(!el){ H.openPanel('pip'); el=document.getElementById('p-pip'); }
    if(S.naviOn){ if(!N.awake) H.wake(); PB.toggle(card,btn); setTimeout(()=>attach(el,.7,true),300); } }
});
window.PipClip={attach,release,config:CFG,get:()=>clip};
})();
