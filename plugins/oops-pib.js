/* =====================================================================
  🫠 untitled plugin (copy) (2) FINAL.html · plugin v0.0.2   (Dream shelf)
  You probably didn't mean to paste this.
  Turning it off is not the same as deleting it. Deleting it from the sandbox is
  not the same as deleting it from your file. Delete this whole block to be sure.
  🫠
  Remove the block to remove the plugin.
  ===================================================================== */
(() => {
const H=window.PipHost;
if(!H||!H.registerPlugin){ console.warn('Accidental plugin: needs Pip Sandbox V2 stage 12 or later.'); return; }
const {N,S,stage,navi}=H;
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
const css=document.createElement('style'); css.textContent=`
.pib{position:absolute;left:0;top:0;z-index:46;width:24px;height:24px;border-radius:6px;box-sizing:border-box;border:1.5px solid #2b2f36;cursor:pointer;touch-action:none;
  background:linear-gradient(160deg,#c3ccd8,#8d9aad);box-shadow:2px 2px 0 rgba(0,0,0,.35)}
.pib::before,.pib::after{content:"";position:absolute;top:7px;width:3px;height:3px;border-radius:50%;background:#1d2026}
.pib::before{left:5px}.pib::after{left:13px;width:4px;height:4px;top:6px}
.pib.flip{scale:-1 1}.pib.down{rotate:180deg}
.pib-say{position:absolute;left:0;top:0;z-index:47;max-width:190px;padding:5px 8px;border-radius:4px;border:1px solid #2b2f36;background:#ffffe1;color:#1d2026;
  font:400 12.5px/1.25 "Comic Sans MS","Chalkboard SE","Comic Neue",cursive;box-shadow:2px 2px 0 rgba(0,0,0,.25);pointer-events:none;opacity:0;transition:opacity .12s}
.pib-say.on{opacity:1}
.oops-dlg{position:absolute;left:50%;top:84px;transform:translateX(-50%);z-index:60;width:min(360px,calc(100% - 32px));box-sizing:border-box;padding:16px;border-radius:22px;display:grid;gap:10px;color:var(--ink)}
.oops-dlg h3{margin:0;font:700 16px/1.25 var(--ui)}
.oops-dlg p{margin:0;font:400 13.5px/1.4 var(--ui);color:var(--ink2)}
.oops-dlg code{font:600 12px/1.3 ui-monospace,Menlo,monospace;color:var(--ink);word-break:break-all}
.oops-dlg .row{display:flex;gap:8px;flex-wrap:wrap}
.oops-dlg button{min-height:38px;border:0;border-radius:12px;padding:0 14px;background:var(--wash);color:var(--ink);font:600 13.5px/1 var(--ui);cursor:pointer}
.oops-dlg button.main{background:var(--accent);color:#fff}
.oops-bar{height:14px;border-radius:7px;background:var(--wash);overflow:hidden;box-shadow:inset 0 0 0 1px var(--hair)}
.oops-bar i{display:block;height:100%;width:0;background:var(--accent);transition:width .6s ease-out}
.oops-del{grid-column:1/-1;justify-self:start;min-height:30px;border:0;border-radius:10px;padding:0 10px;background:var(--wash);color:var(--danger,#d4483b);font:600 12px/1 var(--ui);cursor:pointer;margin:0 0 6px 34px}
.pl .oops-del{margin:6px 0 0}`;
document.head.appendChild(css);

const FILE='untitled plugin (copy) (2) FINAL.html';
const T=(f,ms)=>setTimeout(f,ms);

/* ---------- the uninstaller (works whether Pib is on or off) ---------- */
function dialog(html){ const d=document.createElement('section'); d.className='oops-dlg glass'; d.setAttribute('role','alertdialog'); d.innerHTML=html;
  d.addEventListener('pointerdown',e=>e.stopPropagation()); stage.appendChild(d); return d; }
let pib=null;
function uninstall(){
  if(document.querySelector('.oops-dlg.un')) return;
  document.querySelectorAll('.oops-dlg').forEach(x=>x.remove());
  const d=dialog(`<h3>Uninstalling</h3><p><code>${FILE}</code></p><div class="oops-bar"><i></i></div><p id="ooSt" aria-live="polite">Starting…</p><div class="row" id="ooRow"></div>`);
  d.classList.add('un'); d.setAttribute('aria-label','Uninstalling Pib');
  const bar=d.querySelector('.oops-bar i'), st=d.querySelector('#ooSt'), row=d.querySelector('#ooRow');
  const steps=[[18,'Removing Pib\'s files…'],[41,'Removing Pib\'s other files…'],[63,'Asking Pib to leave…'],[82,'Pib is pretending not to hear…'],[99,'99%. Pib is holding on to the progress bar.']];
  steps.forEach(([p,s],i)=>T(()=>{ bar.style.width=p+'%'; st.textContent=s; },500+i*900));
  T(()=>{   /* Pib clings to the end of the bar, even if they were switched off */
    const r=H.rel(d.querySelector('.oops-bar')); if(!pib) pib=makePib(r.right-6,r.top-40);
    pib.hold={x:r.right-8,y:r.top-6}; pib.say(pib.off?'wait i\'m switched off. how am i here':'nooo',2000);
    if(S.naviOn){ T(()=>{ if(!N.awake) H.wake(); H.say('I\'ve got this.',1400,null,0);
      H.travel(r.right-14,r.top-N.r-2,420,'free',()=>T(finish,250)); },1300); }
    else { row.innerHTML='<button class="main">Give it a nudge</button>'; row.firstChild.addEventListener('click',finish); }
  },500+steps.length*900);
  let done=false;
  function finish(){
    if(done) return; done=true; bar.style.width='100%'; st.textContent='Done.'; H.beep([[180,60],[120,90]]);
    if(pib){ pib.fall(); }
    gone();
    T(()=>{ d.innerHTML=`<h3>Pib has been deleted ✓</h3><p>Gone from this sandbox for good.</p>
      <p>To take them out of your file too, delete the block between the two 🫠 lines. (Reset everything brings Pib back. Sorry.)</p><div class="row"><button class="main">Done</button></div>`;
      d.querySelector('button').addEventListener('click',()=>d.remove());
      if(S.naviOn) H.say('Done. I did that.',1800,null,0);
      T(()=>H.say('It\'s quiet now. I sort of miss them.',2600,null,2),30000); },700);
  }
}
function gone(){
  H.store.set('oops-gone',true);
  const off=new Set(H.store.get('pluginsOff',[])); off.delete('oops'); H.store.set('pluginsOff',[...off]);   /* it loads quietly next time and hides itself */
  const i=H.plugins.findIndex(m=>m.id==='oops'); if(i>=0) H.plugins.splice(i,1);
  document.querySelectorAll('.oops-del').forEach(b=>b.remove());
  window.dispatchEvent(new CustomEvent('oops:gone')); H.refreshPanels();
}
/* a 🗑 in the plugin's row in Developer › Plugins (both the plain list and Plugins Panel+) */
new MutationObserver(()=>{
  if(H.store.get('oops-gone',false)) return;
  document.querySelectorAll('[data-plug="oops"],[data-sw="oops"]').forEach(sw=>{
    const row=sw.closest('.plug')||sw.closest('.row')||sw.closest('.pl'); if(!row||row.querySelector('.oops-del')) return;
    const b=document.createElement('button'); b.className='oops-del'; b.textContent='🗑 Delete properly'; b.addEventListener('click',e=>{ e.stopPropagation(); uninstall(); });
    (row.classList.contains('pl')?row.querySelector('.pl-tx')||row:row).appendChild(b); });
}).observe(document.getElementById('panels'),{subtree:true,childList:true});

/* ---------- Pib ---------- */
function makePib(x,y,off){
  const el=document.createElement('div'); el.className='pib'; el.setAttribute('role','img'); el.setAttribute('aria-label','Pib, a knock-off of Pip');
  const bub=document.createElement('div'); bub.className='pib-say'; bub.setAttribute('role','status');
  stage.append(el,bub);
  const p={el,x,y,off:!!off,hold:null,trail:[],acc:0,bubT:0,gone:false};
  p.say=(t,ms=1800)=>{ bub.textContent=t; bub.classList.add('on'); clearTimeout(p.bubT); p.bubT=T(()=>bub.classList.remove('on'),ms); };
  p.draw=()=>{ el.style.transform=`translate(${Math.round(p.x-12)}px,${Math.round(p.y-12)}px)`; bub.style.transform=`translate(${Math.round(p.x-8)}px,${Math.round(p.y-48)}px)`; };
  p.fall=()=>{ p.gone=true; p.say('aaaa',900); if(H.simpler()){ el.remove(); bub.remove(); return; }
    el.classList.add('down'); el.animate([{translate:'0 0'},{translate:'0 '+(stage.clientHeight-p.y+40)+'px'}],{duration:700,easing:'steps(7)'}).onfinish=()=>{ el.remove(); T(()=>bub.remove(),900); }; };
  p.leave=cb=>{ p.gone=true; const side=p.x<stage.clientWidth/2?-40:stage.clientWidth+40; el.classList.toggle('flip',side<0);
    const step=()=>{ p.x+=(side<0?-1:1)*14; p.draw(); if((side<0&&p.x>side)||(side>0&&p.x<side)) T(step,110); else { el.remove(); bub.remove(); cb&&cb(); } }; step(); };
  el.addEventListener('pointerdown',e=>{ e.stopPropagation(); p.say(H.pick(['hi','ow','i am helping','beep','do not delete me','i was here first (i was not)'])); });
  p.draw(); return p;
}
/* Pib copies Pip: same path, 0.7 seconds late, at about 8 frames a second */
H.frame.push((dt,t)=>{
  if(!pib||pib.gone) return;
  pib.trail.push({t,x:N.x,y:N.y}); while(pib.trail.length&&t-pib.trail[0].t>700) pib.trail.shift();
  pib.acc+=dt; if(pib.acc<.125) return; pib.acc=0;
  if(pib.hold){ pib.x=pib.hold.x; pib.y=pib.hold.y; }
  else if(S.naviOn&&pib.trail.length){ const s=pib.trail[0]; pib.el.classList.toggle('flip',s.x<pib.x); pib.x+=(s.x-30-pib.x)*.6; pib.y+=(s.y+4-pib.y)*.6; }
  pib.el.hidden=!S.naviOn; pib.draw();
});

window.PipOops={uninstall};
if(H.store.get('oops-gone',false)){ const i=H.plugins.findIndex(m=>m.id==='oops'); if(i>=0){ H.plugins.splice(i,1); H.emit('plugins'); } return; }
if(!H.registerPlugin({id:'oops',name:'untitled plugin (copy) (2) FINAL',icon:'🫠',shelf:'dream',desc:'Installed by accident. Breaks your panels when you close them. Possibly a feature.'})){
  /* switched off but still in the file: Pip mentions it once */
  T(()=>{ if(S.naviOn&&!H.store.get('oops-mention',false)){ H.store.set('oops-mention',true); H.say('That accidental plugin is off, but it\'s still in your file. Developer › Plugins has a 🗑 for it.',3800,null,1); } },9000);
  return;
}

/* ---------- switched on: the arrival ---------- */
function turnOff(){
  document.querySelectorAll('.oops-dlg').forEach(x=>x.remove());
  const off=new Set(H.store.get('pluginsOff',[])); off.add('oops'); H.store.set('pluginsOff',[...off]);
  const me=H.plugins.find(m=>m.id==='oops'); if(me){ me.status='off'; H.emit('plugins'); }
  pbBtn?.remove(); card?.remove();
  const after=()=>{ H.refreshPanels(); if(S.naviOn) H.say('Switched off. They\'re still in your file, though. There\'s a 🗑 in Developer › Plugins.',3400,null,0); };
  if(pib&&!pib.gone){ pib.say('ok. packing 🧳',1600); T(()=>pib.leave(after),1400); } else after();
}
function nag(){
  if(H.store.get('oops-kept',false)||document.querySelector('.oops-dlg')) return;
  const d=dialog(`<h3>⚠️ A plugin was installed by accident</h3>
    <p><code>${FILE}</code> breaks your panels: close one and it smashes into pieces. Someone (you) probably pasted it in by mistake. That's either a bug or a feature.</p>
    <div class="row"><button class="main" data-a="keep">Feature! Keep it</button><button data-a="off">Turn it off</button><button data-a="later">Later</button></div>
    <p style="font-size:12px;opacity:.75">Pib can hear you.</p>`);
  d.setAttribute('aria-label','A plugin was installed by accident'); d.querySelector('button').focus({preventScroll:true});
  d.addEventListener('click',e=>{ const a=e.target.closest('[data-a]')?.dataset.a; if(!a) return; d.remove();
    if(a==='off') turnOff();
    if(a==='keep'){ H.store.set('oops-kept',true); pib?.say('yay!! i will smash so much',2000); T(()=>{ if(pib&&!pib.gone&&!pib.hold) pib.leave(); visitLater(); },VISIT_MS); if(S.naviOn) T(()=>H.say('Honestly? The smashing is the best bit. Tap × on a panel.',2600,null,1),1600); }
    if(a==='later'){ pib?.say('phew',1200); T(()=>{ if(pib&&!pib.gone&&!pib.hold) pib.leave(); },VISIT_MS); } });
}
function arrive(){
  if(H.store.get('oops-kept',false)){ visitLater(); return; }   /* kept: Pib only drops by now and then */
  if(!S.naviOn){ T(nag,800); return; }
  const c=H.cardRect(), x=c.left+c.width*.25, y=c.top-12;
  pib=makePib(x,-30);
  const drop=H.simpler()?[{opacity:0},{opacity:1}]:[{translate:'0 0'},{translate:`0 ${y+30}px`}];
  pib.el.animate(drop,{duration:600,easing:'steps(6)'}).onfinish=()=>{ pib.y=y; pib.hold={x,y}; pib.draw(); H.beep([[140,50]]); };
  pib.y=-30; pib.draw();
  T(()=>{ pib.el.style.translate=''; pib.y=y; pib.draw(); if(!N.awake) H.wake(); N.lookPt={x,y}; N.lookUntil=H.now()+3000; },700);
  T(()=>pib.say('HELLO!! I AM PIP',1900),1300);
  T(()=>H.say('…No you\'re not.',1700,null,0),3300);
  T(()=>{ pib.say('i am Pip (copy)',1800); emote('🤨',{pri:3}); },5100);
  T(()=>{ pib.hold=null; nag(); },7200);
}
/* sparing: Pib visits for about 25 seconds every few minutes, then wanders off */
const VISIT_MS=25000;
function visitLater(){ T(visit,(150+Math.random()*210)*1000); }
function visit(){
  if(H.store.get('oops-gone',false)) return;
  if(!S.naviOn||!N.awake||H.isBusy?.()||document.hidden){ visitLater(); return; }
  const side=Math.random()<.5?-30:stage.clientWidth+30; pib=makePib(side,H.clamp(N.y,80,stage.clientHeight-80));
  pib.say(H.pick(['hi again','just passing','did i miss anything','smash anything good?']),1600);
  T(()=>{ if(pib&&!pib.gone) pib.leave(); visitLater(); },VISIT_MS);
}
T(arrive,6000);

/* Pib repeats what Pip says, badly. Sometimes. */
let lastEcho=-1e9, quiet=false;
const garble=s=>s.replace(/Pip/g,'Pib').replace(/clock/gi,'clok').replace(/glass/gi,'glas').replace(/\bI\b/g,'i').replace(/[.!?]+$/,'').toLowerCase()+' !!';
new MutationObserver(()=>{
  const b=document.getElementById('bubble'), txt=b.textContent; if(!pib||pib.gone||pib.hold||!b.classList.contains('on')||!txt) return;
  if(txt==='Stop copying me.'){ T(()=>pib.say('stop copying me'),900); quiet=true; return; }
  if(quiet){ quiet=false; return; }
  const t=H.now(); if(t-lastEcho<45000||Math.random()>.15) return; lastEcho=t;
  T(()=>{ pib.say(garble(txt),2000); if(Math.random()<.35) T(()=>H.say('Stop copying me.',1500,null,2),2200); },1100);
}).observe(document.getElementById('bubble'),{childList:true,characterData:true,subtree:true});

/* ---------- Pib's "features" ---------- */
const card=PB.card(`<h3>🫠 Pib's features</h3><p>Version 0.0.2 (copy). Installed by accident. The one thing it does well: smashing.</p>
  <label class="sw2" style="display:flex;justify-content:space-between;gap:10px;font:500 13.5px/1.3 var(--ui)">× smashes the panel<input type="checkbox" class="switch" data-sc="close"></label>
  <label class="sw2" style="display:flex;justify-content:space-between;gap:10px;font:500 13.5px/1.3 var(--ui)">Pib cheers<input type="checkbox" class="switch" data-sc="cheer"></label>
  <p id="pibCount"></p>
  <div class="pr"><button class="pc" data-f="time">Tell the time</button><button class="pc" data-f="fast">Make it faster</button><button class="pc" data-f="fix">Fix everything</button></div>
  <div class="pr"><button class="pc" data-f="off">Turn me off</button><button class="pc" data-f="del">🗑 Delete properly</button></div>`);
const pbBtn=PB.button('🫠','Pib',()=>PB.toggle(card,pbBtn));
card.addEventListener('click',e=>{ const f=e.target.closest('[data-f]')?.dataset.f; if(!f) return; const say=t=>pib&&!pib.gone?pib.say(t,2200):H.say(t,2000,null,0);
  if(f==='time') say(H.pick(['it is a time','it\'s o\'clock','later than before','about now']));
  if(f==='fast'){ if(pib&&!H.simpler()) pib.el.animate([{rotate:'0deg'},{rotate:'360deg'}],{duration:500,easing:'steps(4)'}); say('now 0% faster'); }
  if(f==='fix'){ if(!H.simpler()) H.openEls().forEach(p=>p.animate([{rotate:'0deg'},{rotate:'1.2deg'},{rotate:'-1deg'},{rotate:'0deg'}],{duration:420,easing:'steps(4)'})); say('fixed! nothing was broken. now it\'s fixed twice'); }
  if(f==='off'){ PB.toggle(card,pbBtn); turnOff(); }
  if(f==='del'){ PB.toggle(card,pbBtn); uninstall(); } });
addEventListener('oops:gone',()=>{ pbBtn.remove(); card.remove(); });
/* ---------- the one real feature: × smashes the panel ---------- */
const SC=Object.assign({close:true,cheer:true,n:0},H.store.get('oops-smash',{}));
const saveSC=()=>H.store.set('oops-smash',SC);
document.getElementById('panels').addEventListener('click',e=>{
  const x=e.target.closest('[data-close]'); if(!x||!e.isTrusted||!SC.close||!H.smash) return;
  const el=x.closest('.panel'); if(!el||el.hidden) return;
  e.stopPropagation(); e.preventDefault();
  H.smash(el.id.replace(/^p-/,''),{x:el.offsetWidth-24,y:20});
},true);
addEventListener('pip:smash',()=>{ SC.n++; saveSC(); syncSC();
  if(SC.cheer&&pib&&!pib.gone&&Math.random()<.6) T(()=>pib.say(H.pick(['SMASH','again again','i did that','10/10','crunchy','that one was mine'])),300); });
function syncSC(){ card.querySelectorAll('[data-sc]').forEach(c=>{ c.checked=!!SC[c.dataset.sc]; }); const p=card.querySelector('#pibCount'); if(p) p.textContent=SC.n?`Panels smashed: ${SC.n}.`:'Nothing smashed yet.'; }
card.addEventListener('change',e=>{ const c=e.target.closest('[data-sc]'); if(!c) return; SC[c.dataset.sc]=c.checked; saveSC(); });
syncSC();

})();
