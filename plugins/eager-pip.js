/* =====================================================================
  EAGER PIP · plugin v1   (Dream shelf)
  Loaded by the sandbox loader (see PLUGINS in index.html). Needs window.PipHost (host.js).
  Where: ⚡ in the plugin bar switches it on and off live.

  Pip at maximum enthusiasm. Wants to help with EVERYTHING:
  - tidies your panels into a neat column… and gets distracted halfway (🐿️)
  - opens panels "for you", checks every panel ("boop boop boop")
  - tries a new look on you, with Keep / Undo (it puts it back if you ignore it)
  - hyperfocuses on polishing the clock, then: "Done! Sorry, what?"
  - makes tea (for itself), follows you everywhere
  - after a burst of jobs: burns out into a nap, then "I'M BACK. What did I miss?"
  Tap Pip for the eager menu: "YES? What do you need? I can do anything!"
  Every change is cosmetic and undoable. Tune it in CFG below.
  =====================================================================
*/
(() => {
const H=window.PipHost;
if(!H||!H.registerPlugin){ console.warn('Eager Pip: needs Pip Sandbox V2 stage 12 or later.'); return; }
const {N,S,stage,navi}=H;
if(!H.registerPlugin({id:'eager',name:'Eager Pip',icon:'⚡',shelf:'dream',desc:'Maximum enthusiasm: helps with everything, gets distracted, naps, bounces back.'})) return;
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

/* EAGER PIP: maximum enthusiasm. Wants to help with everything, starts things, gets distracted (🐿️),
   hyperfocuses, burns out into a nap, bounces back. Every change it makes is cosmetic and undoable. */
const CFG={every:[5200,9000], distract:.3, burnout:6};
const st=document.createElement('style'); st.textContent=`
.eager-menu{position:absolute;left:0;top:0;z-index:46;display:flex;flex-wrap:wrap;gap:6px;width:min(260px,calc(100% - 20px));padding:10px;border-radius:20px;box-sizing:border-box}
.eager-menu button{min-height:34px;border:0;border-radius:999px;padding:0 12px;background:var(--accent);color:#fff;font:600 13px/1 var(--ui);cursor:pointer}
.eager-menu button.ghost{background:var(--wash);color:var(--ink2)}
.eager-menu p{margin:0 0 2px;width:100%;font:600 14px/1.3 var(--ui);color:var(--ink)}
.navi.eager .nb{animation:eagerJit .18s steps(2) infinite}
@keyframes eagerJit{0%{translate:0 0}50%{translate:.6px -.6px}}
.eager-spark{position:absolute;left:0;top:0;z-index:31;pointer-events:none;font-size:14px}
@media (prefers-reduced-motion: reduce){ .navi.eager .nb{animation:none} }`; document.head.appendChild(st);
let on=H.store.get('plug-eager-on',true), energy=0, busy=false, next=0, napUntil=0;
const btn=PB.button('⚡','Eager Pip (tap to switch on or off)',()=>{ on=!on; H.store.set('plug-eager-on',on); paint(); H.say(on?'OH! Are we doing things? I LOVE doing things.':'Okay. Calm me. Calm, calm.',1800,null,0); emote(on?'⚡':'😌',{pri:3}); });
function paint(){ btn.setAttribute('aria-pressed',String(on)); navi.classList.toggle('eager',on&&S.naviOn&&N.awake&&H.now()>napUntil); }
paint();
const say=(t,ms=1500)=>H.say(t,ms,null,0);
const go=(x,y,sp,cb)=>Object.assign(N,{state:'travel',tx:H.clamp(x,N.r,stage.clientWidth-N.r),ty:H.clamp(y,70,stage.clientHeight-N.r),tsp:sp,after:'free',perchTrack:false,onArrive:cb||null});
const ready=()=>on&&S.naviOn&&N.awake&&!busy&&!H.G.on&&N.mood!=='sulk'&&!N.pet&&!N.drink&&N.state!=='held'&&N.state!=='follow'&&H.now()>napUntil&&!H.bubbleOn;
const distracted=()=>Math.random()<CFG.distract;
function squirrel(){ emote('🐿️',{pri:3}); say(H.pick(['So I was going to— ooh, what\'s that?','Wait. Was I doing something?','Hang on. Shiny.','I\'ll finish that later. Probably.'])); }
function done(){ busy=false; energy++; if(energy>=CFG.burnout) burnout(); else { next=H.now()+H.clamp(CFG.every[0]+Math.random()*(CFG.every[1]-CFG.every[0]),2000,20000); } }
function burnout(){ energy=0; emote('😵‍💫',{pri:3}); say('I did SO many things. I need… a tiny… nap.',2000);
  setTimeout(()=>{ H.goPerch(); napUntil=H.now()+14000; setTimeout(()=>{ if(N.state==='perch'){ N.state='sleep'; N.awake=false; } paint(); },1600);
    setTimeout(()=>{ if(!on) return; H.wake(); N.squash=-.25; N.hopT=H.now(); emote('⚡',{pri:3}); say('I\'M BACK. What did I miss?'); paint(); },15000); },1200); }
/* ---- things Eager Pip does "for you" ---- */
const ACTS={
  tidy(){ const ps=H.openEls().filter(e=>!e.classList.contains('child')); if(ps.length<2){ ACTS.open(); return; }
    say('Your panels are messy. I\'ll tidy! Watch this.'); emote('🧹');
    let i=0; const W=stage.clientWidth;
    const step=()=>{ if(i>=ps.length){ say('Tidy! You\'re welcome!'); emote('✨'); done(); return; }
      if(i>=1&&distracted()){ squirrel(); done(); return; }
      const p=ps[i], r=H.rel(p), x=W-r.width-16, y=76+ps.slice(0,i).reduce((a,q)=>a+H.rel(q).height+12,0);
      go(r.left+r.width/2,r.top+8,700,()=>{ p.style.transition='left .45s cubic-bezier(.3,1.3,.5,1), top .45s cubic-bezier(.3,1.3,.5,1)'; const ty=Math.min(y,stage.clientHeight-r.height-80); if(H.pos) H.pos(p,x,ty); else { p.style.left=x+'px'; p.style.top=ty+'px'; }
        setTimeout(()=>{ p.style.transition=''; },500); i++; setTimeout(step,420); }); };
    step(); },
  open(){ const id=H.pick(['clock','colour','look','pip','access']); H.openPanel(id); say(H.pick(['I opened this for you! You were going to need it. Probably.','Look! A panel! For you!','Here, I got this out for you.'])); emote('🎁'); done(); },
  look(){ const was=S.era, k=H.pick(['1983','1987','1997','1998','2001','2002','2004','2007'].filter(x=>x!==was)); H.setLook(k);
    menu('Ooh, try THIS look! Keep it?',[['Keep it!',()=>{ say('YES. Great taste. Mine, specifically.'); emote('🤩'); }],['Undo',()=>{ H.setLook(was); say('Fair. Back it goes.'); }]],6000,()=>{ if(S.era===k){ H.setLook(was); say('I put it back. Just in case.'); } });
    done(); },
  polish(){ const r=H.cardRect(); say('Hold on. The clock has a smudge. HOLD ON.'); emote('🧽',{pri:3});
    const pts=[[r.left,r.top-6],[r.right,r.top-6],[r.right+6,r.bottom],[r.left-6,r.bottom],[r.left,r.top-6]]; let i=0;
    const lap=()=>{ if(i>=pts.length){ spark(r); say('Done! Sorry, what? Were you talking?',1800); done(); return; } const [x,y]=pts[i++]; go(x,y,900,()=>{ spark({left:x-10,top:y-10,width:20,height:20}); lap(); }); };
    lap(); },
  tea(){ emote('☕',{pri:3}); say(H.pick(['I made tea! Well. For me. It\'s for me.','Tea break! I\'m SO calm now. Look how calm.'])); N.pat=1; energy=Math.max(0,energy-1); N.squash=.3; N.hopT=H.now(); done(); },
  tour(){ const ps=H.openEls(); if(!ps.length){ ACTS.open(); return; } say('Boop boop boop! Checking everything!'); emote('👀'); let i=0;
    const hop=()=>{ if(i>=ps.length||(i>=2&&distracted())){ if(i<ps.length) squirrel(); else say('All checked. All good. All great!'); done(); return; } const r=H.rel(ps[i++]); go(r.left+r.width*(.2+Math.random()*.6),r.top-N.r,1100,()=>{ N.hopT=H.now(); setTimeout(hop,140); }); };
    hop(); },
  follow(){ say('I\'ll come with you! Everywhere! Lead on!'); emote('👆'); N.state='follow'; N.followPen=false; done(); }
};
function spark(r){ if(H.simpler()) return; for(let k=0;k<6;k++){ const s=document.createElement('i'); s.className='eager-spark'; s.textContent='✨'; stage.appendChild(s);
  const x=r.left+Math.random()*r.width, y=r.top+Math.random()*r.height; s.animate([{transform:`translate(${x}px,${y}px) scale(.4)`,opacity:1},{transform:`translate(${x}px,${y-30}px) scale(1.2)`,opacity:0}],{duration:700+Math.random()*400}).onfinish=()=>s.remove(); } }
function act(name){ if(busy) return; busy=true; N.back=false; (ACTS[name]||ACTS[H.pick(Object.keys(ACTS))])(); }
/* ---- tap Pip: the eager menu ---- */
const menuEl=document.createElement('div'); menuEl.className='eager-menu glass'; menuEl.hidden=true; menuEl.setAttribute('role','dialog'); menuEl.setAttribute('aria-label','Eager Pip menu'); stage.appendChild(menuEl);
menuEl.addEventListener('pointerdown',e=>e.stopPropagation());
let menuT=0;
function menu(q,items,ms,onTimeout){
  clearTimeout(menuT); menuEl.innerHTML=`<p>${q}</p>`; items.forEach(([l,f],i)=>{ const b=document.createElement('button'); b.textContent=l; if(i===items.length-1&&items.length>2) b.className='ghost';
    b.addEventListener('click',()=>{ clearTimeout(menuT); menuEl.hidden=true; f(); }); menuEl.appendChild(b); });
  menuEl.hidden=false; menuT=setTimeout(()=>{ menuEl.hidden=true; onTimeout&&onTimeout(); },ms||7000);
}
window.addEventListener('pip:tap',()=>{ if(!on||busy||!N.awake||N.mood==='sulk'||H.now()<napUntil||!menuEl.hidden) return;
  setTimeout(()=>{ emote('🙋',{pri:3}); menu('YES? What do you need? I can do anything!',[
    ['🧹 Tidy',()=>act('tidy')],['🧽 Polish clock',()=>act('polish')],['🎨 New look',()=>act('look')],['👀 Check panels',()=>act('tour')],['☕ Tea',()=>act('tea')],
    ['😌 Calm down',()=>{ on=false; H.store.set('plug-eager-on',false); paint(); say('Calming. Very calm. Tap ⚡ when you need me.'); }]],8000); },350); });
/* ---- the eager loop ---- */
H.frame.push((dt,t)=>{
  paint();
  if(!menuEl.hidden){ const w=menuEl.offsetWidth,h=menuEl.offsetHeight; menuEl.style.transform=`translate(${H.clamp(N.x-w/2,10,stage.clientWidth-w-10)}px,${Math.max(64,N.y-N.r-h-14)}px)`; }
  if(!ready()) return;
  if(!next){ next=t+3000; return; }
  if(t<next||t-N.lastInteract<2500) return;
  act(H.pick(['tidy','open','look','polish','tea','tour','tour','polish','follow']));
});
window.PipEager={act,set:v=>{ on=v; paint(); }};

})();
