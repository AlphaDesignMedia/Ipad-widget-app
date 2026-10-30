/* =====================================================================
   10. Plugin host
   window.PipHost: a small, stable door into the sandbox for plugins.
   Plugins push to H.frame (dt,t) and H.bump ({el,speed,nx,ny}) and listen
   for window "pip:<name>" events. A plugin that throws is switched off
   on its own; the sandbox keeps running.
   ===================================================================== */
const PH={frame:[],bump:[]};
/* cost meter: each hook is tagged with the plugin that added it, then timed.
   Rolling 1-second averages and the worst single frame. Browser estimates only. */
const PM={cur:{},acc:{},max:{},core:0,coreMax:0,n:0,t0:0,last:null};
const phOwner=()=>{ const src=document.currentScript?.src||''; const p=(window.PipPlugins||[]).find(p=>src.endsWith(p.file)); return p?p.id:'other'; };
[PH.frame,PH.bump].forEach(l=>{ l.push=function(...fs){ const id=phOwner(); fs.forEach(f=>{ f._pid=f._pid||id; }); return Array.prototype.push.apply(this,fs); }; });
function phFail(id,err){ const p=(window.PipPlugins||[]).find(p=>p.id===id); if(p){ p.status='failed'; p.error=String(err&&err.message||err); window.dispatchEvent(new Event('pip:plugins')); } }
function phRun(list,...a){ for(let i=list.length-1;i>=0;i--){ const f=list[i], t0=performance.now();
  try{ f(...a); }catch(err){ console.error('Pip plugin hook failed and was removed:',err); list.splice(i,1); phFail(f._pid,err); }
  PM.cur[f._pid]=(PM.cur[f._pid]||0)+performance.now()-t0; } }
function phEmit(n,detail){ window.dispatchEvent(new CustomEvent('pip:'+n,{detail})); }
const phWrap=(f,after)=>function(...a){ const r=f.apply(this,a); try{ after(a,r); }catch(err){ console.error(err); } return r; };

/* bumps: collide knows the panel, hit knows the speed */
let phEl=null;
const phCollide=collide; collide=function(rc,kind,el,t){ phEl=kind==='panel'?el:null; try{ return phCollide(rc,kind,el,t); } finally{ phEl=null; } };
hit=phWrap(hit,([speed,nx,ny,kind])=>{ if(kind==='panel'&&phEl) phRun(PH.bump,{el:phEl,speed,nx,ny}); });

/* every frame, after the sandbox has drawn */
let phGot=0, phHeld=false, phLast=0;
const phFrame=frame; frame=function(t){
  const c0=performance.now(); phFrame(t); const core=performance.now()-c0;
  const dt=phLast?Math.min(.033,(t-phLast)/1000):1/60; phLast=t;
  try{
    const got=G.shards.filter(s=>s.got).length; if(got>phGot) phEmit('collect',{n:got}); phGot=got;
    const held=!!(hold&&hold.found); if(held&&!phHeld) phEmit('found',{}); phHeld=held;
  }catch(err){ console.error(err); }
  phRun(PH.frame,dt,t);
  if(SM.size){ let all=core; for(const k in PM.cur) all+=PM.cur[k]; SM.forEach(m=>{ m.n++; m.ms+=all; m.worst=Math.max(m.worst,all); }); }
  PM.core+=core; PM.coreMax=Math.max(PM.coreMax,core); PM.n++;
  for(const k in PM.cur){ PM.acc[k]=(PM.acc[k]||0)+PM.cur[k]; PM.max[k]=Math.max(PM.max[k]||0,PM.cur[k]); } PM.cur={};
  if(t-PM.t0>=1000){ const n=PM.n||1, plug={}, worst={};
    for(const k in PM.acc){ plug[k]=PM.acc[k]/n; worst[k]=PM.max[k]; }
    PM.last={fps:FPS.v,core:PM.core/n,coreWorst:PM.coreMax,plug,worst};
    Object.assign(PM,{acc:{},max:{},core:0,coreMax:0,n:0,t0:t}); }
};
/* A/B sampling: average work per frame (sandbox + plugins) over a window */
const SM=new Set();
function phMeasure(ms=3000){ return new Promise(res=>{ const m={n:0,ms:0,worst:0,t0:performance.now()}; SM.add(m);
  setTimeout(()=>{ SM.delete(m); const secs=(performance.now()-m.t0)/1000; res({ms:m.n?m.ms/m.n:0,worst:m.worst,fps:Math.round(m.n/secs),frames:m.n}); },ms); }); }
function phCost(){ const m=performance.memory;
  return {...(PM.last||{fps:FPS.v,core:0,coreWorst:0,plug:{},worst:{}}), heapMB:m?m.usedJSHeapSize/1048576:null, elements:document.getElementsByTagName('*').length}; }

/* things you do */
tap=phWrap(tap,()=>phEmit('tap',{pat:N.pat}));
crack=phWrap(crack,()=>phEmit('crack',{cracks:G.cracks,el:cardIn}));
crash=phWrap(crash,()=>phEmit('crash',{}));
restore=phWrap(restore,([skipped])=>phEmit('restore',{skipped:!!skipped}));
smashPanel=phWrap(smashPanel,([id,el])=>phEmit('smash',{id,el}));
splash=phWrap(splash,([el])=>phEmit('splash',{el}));
popOut=phWrap(popOut,()=>phEmit('found',{}));
setLook=phWrap(setLook,([k])=>phEmit('look',{look:k,era:S.era}));
setFaceFields=phWrap(setFaceFields,()=>phEmit('face',{}));
give=phWrap(give,([kind])=>phEmit('drink',{kind}));

/* tours: plugins can give Pip a guided tour. Chattiness 0 keeps Pip quiet, so no tour.
   A plugin tour never marks the stage tour as seen. */
const PT=[];
const phTourEnd=tourEnd; tourEnd=function(ignored){ if(!TOUR.custom) return phTourEnd(ignored);
  TOUR.active=false; TOUR.custom=false; phEmit('tourEnd',{ignored:!!ignored}); if(ignored) setTimeout(()=>say('Another time, then.',1600,null,1),400); };
function phTour(steps,intro){ if(TOUR.active||G.on||!S.naviOn||chat()<1) return false; if(!N.awake) wake();
  Object.assign(TOUR,{steps,grand:false,active:true,started:true,custom:true,i:-1}); N.hopT=now();
  say(intro||'Tap me to start.',8000,done=>{ if(TOUR.active&&TOUR.i===-1&&done) tourEnd(true); },1); return true; }

/* registerPlugin: a plugin says who it is and which shelf it starts on.
   Shelves: dream → trial → grounded → core. Returns false if the plugin is switched off. */
function phRegister(m={}){ const src=document.currentScript?.src||''; const p=(window.PipPlugins||[]).find(p=>src.endsWith(p.file));
  if(p){ if(m.icon) p.icon=m.icon; if(m.shelf) p.shelfDefault=m.shelf; if(m.desc&&!p.what) p.what=m.desc; phEmit('plugins'); }
  return !p||p.status!=='off'; }

/* perch: a plugin can give Pip somewhere else to sit (a panel edge, say). Return {x,y} or null for the clock. */
let phPerchFn=null; const phPerchPoint=perchPoint; perchPoint=function(){ const p=phPerchFn&&phPerchFn(); return p||phPerchPoint(); };
const phGoPerch=goPerch; goPerch=function(){ if(phPerchFn){ phPerchFn=null; phEmit('perchHome',{}); } return phGoPerch(); };
/* the sandbox's own database and downloads (null offline, or in the exported file) */
const phUse=n=>{ const c=window.claude; return c&&c.use?Promise.resolve(c.use(n)).catch(()=>null):Promise.resolve(null); };
let phDbP=null, phDlP=null;

/* interrupt: Pip can be busy (a tour, a lesson, a question, a long flight, a plugin's show), and you can always stop him.
   ✋ Stop Pip appears in one fixed spot, under the top bar, while he's busy (never over the clock); Esc does the same. Plugins mark their shows with
   PipHost.busy(name,true/false) and listen for "pip:interrupt" to stop them. */
const BUSY=new Set(); let travelSince=0;
function phBusy(){ return TOUR.active||!!ASK.open||BUSY.size>0||(N.state==='travel'&&travelSince&&now()-travelSince>1200); }
function phInterrupt(quiet){
  const was=phBusy()||N.state==='travel';
  if(TOUR.active){ if(TOUR.custom){ TOUR.active=false; TOUR.custom=false; phEmit('tourEnd',{ignored:true}); } else phTourEnd(false); }
  if(ASK.open) closeAsk();
  if(N.state==='travel'){ N.state='free'; N.vx=N.vy=0; N.onArrive=null; }
  phEmit('interrupt',{}); BUSY.clear();
  clearTimeout(bubbleT); bubble.classList.remove('on'); bubbleOn=false;
  if(was&&!quiet&&S.naviOn) setTimeout(()=>say(pick(['Okay, stopping.','Sorry! Stopped.','Right. Done.']),1200,null,0),150);
  if(was&&grounded()) goHomeSoon(1200);
}
const stopBtn=document.createElement('button'); stopBtn.className='pip-stop glass'; stopBtn.hidden=true; stopBtn.textContent='✋ Stop Pip'; stopBtn.setAttribute('aria-label','Stop Pip');
stopBtn.addEventListener('pointerdown',e=>e.stopPropagation()); stopBtn.addEventListener('click',e=>{ e.stopPropagation(); phInterrupt(); });
stage.appendChild(stopBtn);
{ const st=document.createElement('style'); st.textContent=`.pip-stop{position:absolute;left:0;top:0;z-index:46;min-height:36px;padding:0 14px;border:0;border-radius:18px;font:600 13.5px/1 var(--ui);color:var(--ink);cursor:pointer;translate:-50% 0;transition:opacity .2s}
.pip-stop[hidden]{display:none}`; document.head.appendChild(st); }
addEventListener('keydown',e=>{ if(e.key==='Escape'&&phBusy()) phInterrupt(); });
let stopT=0;
PH.frame.push(function(){ if(N.state==='travel'){ if(!travelSince) travelSince=now(); } else travelSince=0;
  const b=S.naviOn&&phBusy(); if(b) stopT=stopT||now(); else stopT=0;
  const show=b&&now()-stopT>350; if(stopBtn.hidden===show) stopBtn.hidden=!show;
  if(show){ const tb=document.querySelector('.topbar'), y=tb?tb.getBoundingClientRect().bottom-stage.getBoundingClientRect().top+10:64; stopBtn.style.transform=`translate(${Math.round(stage.clientWidth/2)}px,${Math.round(y)}px)`; } });

window.PipHost={N,S,P,G,stage,navi,
  frame:PH.frame, bump:PH.bump, impact:IMPACT, shelfOf,
  now, clamp, pick, rel, mid, persona, grounded, openEls, simpler,
  say, beep, cardRect, cardCentre, emit:phEmit, cost:phCost, measure:phMeasure,
  collectCheck:()=>collectCheck(),
  tour:phTour, tours:PT, touring:()=>TOUR.active, chat, openPanel, closePanel, travel, setMood,
  goHome:()=>{ if(grounded()) goPerch(); },
  store, wake, pos, card, cardIn, setLook, goPerch, registerPlugin:phRegister,
  refreshPanels, applyForm, savePrefs:save,
  restore:s=>restore(s),
  interrupt:phInterrupt, isBusy:phBusy, busy:(name,on)=>{ on?BUSY.add(name):BUSY.delete(name); },
  smash:(id,at={})=>{ const el=document.getElementById('p-'+id); if(!el||el.hidden) return; smashPanel(id,el,at.x??el.offsetWidth/2,at.y??el.offsetHeight/2,at.sp||2400,0,-1); }, setPerch:f=>{ phPerchFn=f||null; },
  db:()=>phDbP||(phDbP=phUse('db')), downloads:()=>phDlP||(phDlP=phUse('downloads'))};
Object.defineProperty(window.PipHost,'bubbleOn',{get:()=>bubbleOn});
Object.defineProperty(window.PipHost,'plugins',{get:()=>window.PipPlugins||[]});
