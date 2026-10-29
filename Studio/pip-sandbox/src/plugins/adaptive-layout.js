/* =====================================================================
  ADAPTIVE LAYOUT · plugin v1   (Grounded shelf)
  Loaded by the sandbox loader (see PLUGINS in index.html). Where: 📱 in the plugin bar.
  Size classes by stage width: Compact < 600 · Regular < 1100 · Wide. Short = under 500 tall.
  - Size: Auto (bigger on touch tablets) or 90–150%. Panels, rail, time machine, plugin cards.
  - Phones: panels become sheets above the time machine, one at a time; child panels stack on top.
  - Plugin tray: the plugin bar folds behind 🧩 when it would crowd the time machine.
  - Rotate or resize: panels keep their place relative to the nearest edges.
  - The clock sizes from the stage instead of the browser window (so previews are true).
  Remove the block to remove the plugin.
  ===================================================================== */
(() => {
const H=window.PipHost;
if(!H||!H.registerPlugin){ console.warn('Adaptive Layout: needs Pip Sandbox V2 stage 12 or later.'); return; }
const {N,S,stage,navi}=H;
if(!H.registerPlugin({id:'adaptive',name:'Adaptive Layout',icon:'📱',shelf:'grounded',desc:'Fits phones, tablets and desktops: Size control, sheets on phones, plugin tray, panels keep their place on rotate, clock sized by the stage.'})) return;
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
/* ---- shared screen reader (created once, reused by Screen Awareness and Adaptive Layout) ---- */
const SC=window.PipScreenCore||(window.PipScreenCore=(()=>{
  const st=window.PipHost.stage, fns=[];
  const probe=document.createElement('i'); probe.setAttribute('aria-hidden','true');
  probe.style.cssText='position:fixed;left:0;top:0;width:0;height:0;visibility:hidden;pointer-events:none;padding:env(safe-area-inset-top,0px) env(safe-area-inset-right,0px) env(safe-area-inset-bottom,0px) env(safe-area-inset-left,0px)';
  document.body.appendChild(probe);
  let input=matchMedia('(pointer:coarse)').matches?'touch':'mouse', info=null, t=0;
  function read(){
    const W=st.clientWidth, Hh=st.clientHeight, cs=getComputedStyle(probe), vv=window.visualViewport;
    const cls=W<600?'compact':W<1100?'regular':'wide', orient=W>=Hh?'landscape':'portrait';
    const typing=!!document.activeElement?.matches?.('input:not([type=checkbox]):not([type=range]),textarea,[contenteditable]');
    return {W,H:Hh,cls,short:Hh<500,orient,input,dpr:window.devicePixelRatio||1,
      kb:!!(vv&&typing&&innerHeight-vv.height>140), kbTop:vv?vv.height+vv.offsetTop:Hh,
      safe:{t:parseFloat(cs.paddingTop)||0,r:parseFloat(cs.paddingRight)||0,b:parseFloat(cs.paddingBottom)||0,l:parseFloat(cs.paddingLeft)||0},
      device:input==='mouse'?'Desktop':Math.min(W,Hh)<500?'Phone-sized':'Tablet-sized',
      preview:document.body.classList.contains('scr-preview')};
  }
  function apply(){
    const prev=info; info=read();
    st.classList.remove('scr-compact','scr-regular','scr-wide'); st.classList.add('scr-'+info.cls);
    st.classList.toggle('scr-short',info.short); st.classList.toggle('scr-portrait',info.orient==='portrait');
    st.style.setProperty('--sw',info.W+'px'); st.style.setProperty('--sh',info.H+'px');
    if(!prev||prev.W!==info.W||prev.H!==info.H||prev.input!==info.input||prev.kb!==info.kb) fns.forEach(f=>{ try{ f(info,prev); }catch(e){ console.warn(e); } });
  }
  const soon=()=>{ clearTimeout(t); t=setTimeout(apply,90); };
  addEventListener('resize',soon); window.visualViewport?.addEventListener('resize',soon); new ResizeObserver(soon).observe(st);
  addEventListener('focusin',soon); addEventListener('focusout',soon);
  addEventListener('pointerdown',e=>{ const k=e.pointerType==='pen'?'pen':e.pointerType==='touch'?'touch':'mouse'; if(k!==input){ input=k; apply(); } },true);
  apply();
  return {get:()=>info, on(f){ fns.push(f); }, refresh:apply};
})());
/* ADAPTIVE LAYOUT: the sandbox fits phones, tablets and desktops. Sizes go by the stage, not the browser. */
const CFG=Object.assign({size:'auto',sheets:true,tray:true,keep:true,fit:true},H.store.get('ad-cfg',{}));
const saveCfg=()=>H.store.set('ad-cfg',CFG);
const rail=document.getElementById('rail'), tm=document.getElementById('tm'), panelsEl=document.getElementById('panels');
const css=document.createElement('style'); css.textContent=`
:where(.stage.ad-fit) .card-in{width:min(340px, calc(var(--sw,100vw) * .7))}
:where(.stage.ad-fit) .time{font-size:min(125px, calc(var(--sw,100vw) * .259), calc(var(--sh,100vh) * .26))}
:where(.stage.ad-fit) .date{font-size:min(17.7px, calc(var(--sw,100vw) * .0364))}
.stage.scr-compact .topbar .seg{order:-1;flex-basis:100%;justify-content:center;margin-inline:auto;max-width:max-content}
.stage.scr-compact .topbar .tag:not(.look-btn){display:none}
.stage.scr-compact .tm-brand{display:none}
/* size: bigger controls without touching positions */
.stage.ad-k .panel{width:min(calc(272px * var(--ui-k)), calc(100% - 92px))}
.stage.ad-k .panel>.ph,.stage.ad-k .panel>.pb,.stage.ad-k .rail>*,.stage.ad-k .topbar>*,.stage.ad-k #tm>*,.stage.ad-k #plugbar>*,.stage.ad-k .plugcard>*,.stage.ad-k #bubble,.stage.ad-k #ask{zoom:var(--ui-k)}
.stage.ad-k #tm{width:min(calc(600px * var(--ui-k)), calc(100% - 32px))}
.stage.ad-k .plugcard{width:min(calc(310px * var(--ui-k)), calc(100% - 32px))}
/* phones: panels become sheets */
.stage.ad-sheet .panel{width:var(--sheet-w,calc(100% - 16px)) !important;height:auto !important;max-height:var(--sheet-max,70%) !important;transition:opacity .2s, box-shadow .2s, scale .25s}
.stage.ad-sheet .panel>.pb{min-height:0}
.stage.ad-sheet .panel.ad-under{opacity:0;pointer-events:none}
/* plugin tray */
#plugbar .ad-tog{font-size:20px}
#plugbar.ad-tray{flex-wrap:wrap-reverse;max-width:min(calc(100% - 32px), 290px)}
#plugbar.ad-tray:not(.open)>button:not(.ad-tog){display:none}
#plugbar.ad-tray.open>button:not(.ad-tog){width:64px;height:60px;display:grid;place-items:center;align-content:center;gap:4px;font-size:22px;border-radius:16px}
#plugbar.ad-tray.open>button:not(.ad-tog)::after{content:attr(data-l);font:600 10px/1.1 var(--ui);color:var(--ink2);max-width:58px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
#plugbar.ad-tray .ad-tog.has::after{content:"";position:absolute;margin:-22px 0 0 22px;width:8px;height:8px;border-radius:50%;background:var(--accent)}
.stage.ad-lift #plugbar{bottom:calc(var(--dock-h,0px) + 4px + env(safe-area-inset-bottom,0px))}
.stage.ad-lift .plugcard{bottom:calc(var(--dock-h,0px) + 60px + env(safe-area-inset-bottom,0px));max-height:calc(100% - var(--dock-h,0px) - 150px)}
.stage.ad-lift.ad-trayopen .plugcard{display:none}`;
document.head.appendChild(css);

const info=()=>SC.get();
const sizeK=()=>{ if(CFG.size!=='auto') return CFG.size/100; const i=info(); return i.input==='mouse'?1:i.cls==='wide'?1.15:i.cls==='regular'?1.1:1; };
const sheetMode=()=>{ const i=info(); return !!(CFG.sheets&&i&&(i.cls==='compact'||(i.short&&i.input!=='mouse'))); };
const floorY=()=>stage.clientHeight-(tm&&!tm.hidden?tm.offsetHeight+16:0);

/* ---------- sheets: one panel at a time, docked above the time machine; children stack on top ---------- */
let wasSheet=false;
function placeSheets(){
  const on=sheetMode(); stage.classList.toggle('ad-sheet',on);
  if(!on){ if(wasSheet) restack(); wasSheet=false; H.openEls().forEach(e=>e.classList.remove('ad-under')); return; }
  wasSheet=true;
  const i=info(), rr=H.rel(rail), edge=rail.dataset.edge; let l=8, r=i.W-8, bottom=floorY()-8;
  if(edge==='left') l=rr.right+8; if(edge==='right') r=rr.left-8; if(edge==='bottom') bottom=Math.min(bottom,rr.top-8);
  if(i.cls!=='compact'){ const w=Math.min(380,Math.round((r-l)*.5)); l=r-w; }       /* short landscape: a side sheet */
  const top=H.rel(document.querySelector('.topbar')).bottom+8;
  stage.style.setProperty('--sheet-w',(r-l)+'px'); stage.style.setProperty('--sheet-max',Math.max(160,bottom-top)+'px');
  const els=H.openEls();
  els.forEach((el,k)=>{ el.classList.toggle('ad-under',k<els.length-1); el.style.left=l+'px'; el.style.top=Math.max(top,bottom-el.offsetHeight)+'px'; });
}
function restack(){   /* leaving sheet mode: line top-level panels up on the right again */
  const W=stage.clientWidth; let y=76;
  H.openEls().filter(e=>!e.classList.contains('child')).forEach(el=>{ el.style.left=Math.max(8,W-el.offsetWidth-16)+'px'; el.style.top=y+'px'; y+=Math.min(el.offsetHeight,240)+12; });
}
let lastTop=null;
const mo=new MutationObserver(ms=>{
  if(!sheetMode()) return;
  const shown=ms.filter(m=>m.type==='attributes'&&!m.target.hidden&&m.target.classList.contains('panel')&&!m.target.classList.contains('child')).map(m=>m.target);
  shown.forEach(el=>{ lastTop=el; H.openEls().filter(o=>o!==el&&!o.classList.contains('child')).forEach(o=>o.querySelector('[data-close]')?.click()); });
  ms.forEach(m=>m.addedNodes?.forEach(n=>n.classList?.contains('panel')&&ro.observe(n)));
  requestAnimationFrame(placeSheets);
});
const ro=new ResizeObserver(()=>{ if(sheetMode()) requestAnimationFrame(placeSheets); });
mo.observe(panelsEl,{subtree:false,childList:true,attributes:true,attributeFilter:['hidden']});
[...panelsEl.querySelectorAll('.panel')].forEach(p=>ro.observe(p));

/* ---------- keep panels where you put them when the screen rotates or resizes ---------- */
let snap={W:stage.clientWidth,H:stage.clientHeight,list:[]}, snapT=0;
H.frame.push((dt,t)=>{
  if(t-snapT<300) return; snapT=t;
  if(stage.clientWidth!==snap.W||stage.clientHeight!==snap.H) return;    /* a resize is pending: keep the old picture */
  snap.list=H.openEls().map(el=>({el,l:parseFloat(el.style.left)||0,t:parseFloat(el.style.top)||0,w:el.offsetWidth,h:el.offsetHeight}));
});
function keepPlace(){
  const W=stage.clientWidth, Hh=stage.clientHeight, fl=floorY();
  if(CFG.keep&&!sheetMode()&&!wasSheet&&snap.list.length&&(W!==snap.W||Hh!==snap.H))
    snap.list.forEach(p=>{ if(p.el.hidden) return;
      const l=p.l+p.w/2>snap.W/2?W-(snap.W-p.l):p.l, t=p.t+p.h/2>snap.H/2?Hh-(snap.H-p.t):p.t;
      p.el.style.left=H.clamp(l,8,Math.max(8,W-p.el.offsetWidth-8))+'px'; p.el.style.top=H.clamp(t,64,Math.max(64,fl-p.el.offsetHeight-8))+'px'; });
  snap={W,H:Hh,list:[]};
}

/* ---------- plugin tray: the plugin bar folds behind 🧩 when it would crowd the screen ---------- */
let tog=null;
function trayCheck(){
  const bar=document.getElementById('plugbar'); if(!bar) return;
  if(!tog){ tog=document.createElement('button'); tog.className='ad-tog'; tog.textContent='🧩'; tog.title='Plugins'; tog.setAttribute('aria-label','Plugins'); tog.setAttribute('aria-expanded','false');
    bar.prepend(tog);
    tog.addEventListener('click',e=>{ e.stopPropagation(); const o=!bar.classList.contains('open'); bar.classList.toggle('open',o); tog.setAttribute('aria-expanded',String(o)); stage.classList.toggle('ad-trayopen',o);
      if(o) bar.querySelectorAll('button:not(.ad-tog)').forEach(b=>b.dataset.l=b.getAttribute('aria-label')||''); });
    bar.addEventListener('click',e=>{ const b=e.target.closest('button'); if(!b||b===tog||!bar.classList.contains('open')) return;
      setTimeout(()=>{ bar.classList.remove('open'); stage.classList.remove('ad-trayopen'); tog.setAttribute('aria-expanded','false'); tog.classList.toggle('has',!!bar.querySelector('button[aria-pressed="true"]:not(.ad-tog)')); },0); }); }
  const i=info(), n=bar.querySelectorAll('button:not(.ad-tog)').length, tmW=tm&&!tm.hidden?tm.offsetWidth:0, avail=(i.W-tmW)/2-24, k=sizeK();
  const tray=CFG.tray&&n>1&&(i.cls==='compact'||(n*42+8)*k>avail);
  bar.classList.toggle('ad-tray',tray); tog.hidden=!tray;
  if(!tray){ bar.classList.remove('open'); stage.classList.remove('ad-trayopen'); }
  else tog.classList.toggle('has',!!bar.querySelector('button[aria-pressed="true"]:not(.ad-tog)'));
  stage.classList.toggle('ad-lift',(tray?48*k:(n*42+8)*k)>avail);
}
setInterval(trayCheck,1000);

/* ---------- apply everything ---------- */
function apply(){
  const k=sizeK(); stage.style.setProperty('--ui-k',k); stage.classList.toggle('ad-k',k!==1); stage.classList.toggle('ad-fit',CFG.fit);
  keepPlace(); placeSheets(); trayCheck(); sync();
}
stage.classList.add('ad-on');
SC.on(()=>apply());
requestAnimationFrame(apply);

/* ---------- the 📱 card ---------- */
const card=PB.card(`<h3>📱 Layout</h3><p id="adNow"></p>
  <div class="lbl2" style="font:700 11px/1 var(--ui);letter-spacing:.06em;text-transform:uppercase;color:var(--ink3)">Size</div>
  <div class="pr" id="adSize"><button class="pc" data-s="auto">Auto</button>${[90,100,115,130,150].map(v=>`<button class="pc" data-s="${v}">${v}%</button>`).join('')}</div>
  <p>Panels, rail, time machine and plugin cards get bigger; their places stay put. Pinch the clock to size it.</p>
  <label class="sw2" style="display:flex;justify-content:space-between;gap:10px;font:500 13.5px/1.3 var(--ui)">Panels become sheets on phones<input type="checkbox" class="switch" data-c="sheets"></label>
  <label class="sw2" style="display:flex;justify-content:space-between;gap:10px;font:500 13.5px/1.3 var(--ui)">Fold plugins into 🧩 when crowded<input type="checkbox" class="switch" data-c="tray"></label>
  <label class="sw2" style="display:flex;justify-content:space-between;gap:10px;font:500 13.5px/1.3 var(--ui)">Keep panels in place on rotate<input type="checkbox" class="switch" data-c="keep"></label>
  <label class="sw2" style="display:flex;justify-content:space-between;gap:10px;font:500 13.5px/1.3 var(--ui)">Clock fits the window<input type="checkbox" class="switch" data-c="fit"></label>`);
const btn=PB.button('📱','Layout',()=>{ if(PB.toggle(card,btn)) sync(); });
function sync(){
  if(card.hidden) return; const i=info(), k=Math.round(sizeK()*100);
  card.querySelector('#adNow').textContent=`${{compact:'Compact',regular:'Regular',wide:'Wide'}[i.cls]} screen, ${i.W}×${i.H}. ${sheetMode()?'Panels are sheets.':'Panels float.'} Size ${k}%${CFG.size==='auto'?' (auto)':''}.`;
  card.querySelectorAll('[data-s]').forEach(b=>b.classList.toggle('on',String(CFG.size)===b.dataset.s));
  card.querySelector('[data-s="auto"]').textContent=`Auto${CFG.size==='auto'?` · ${k}%`:''}`;
  card.querySelectorAll('[data-c]').forEach(c=>{ c.checked=!!CFG[c.dataset.c]; });
}
card.addEventListener('click',e=>{ const b=e.target.closest('[data-s]'); if(!b) return; CFG.size=b.dataset.s==='auto'?'auto':+b.dataset.s; saveCfg(); apply();
  requestAnimationFrame(()=>{ dispatchEvent(new Event('resize')); H.refreshPanels(); }); });
card.addEventListener('change',e=>{ const c=e.target.closest('[data-c]'); if(!c) return; CFG[c.dataset.c]=c.checked; saveCfg(); apply(); });
window.PipAdaptive={config:CFG,apply,sheetMode,sizeK};
})();
