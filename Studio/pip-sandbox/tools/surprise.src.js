/* =====================================================================
  SURPRISE ME · plugin v1   (Dream shelf)
  Loaded by the sandbox loader (see PLUGINS in index.html). Where: 🎁 in the plugin bar.
  One button, a shuffled deck of six bits. No repeats until you've seen them all:
    🧐 The design review   Pip critiques your actual settings, like a creative director.
    🎈 Gravity off         Everything floats away. Then it doesn't.
    📎 It looks like…      A 1997 help bubble that will not take no for an answer.
    🕰️ Pip tells the time  Badly, in six formats.
    💃 Conga               Your panels follow Pip round the screen, on the beat.
    ⭐ Reviews from 2027    What people say about Glass Clock, from the future.
  When the deck runs out, Pip writes a note in his brain asking Claude for more.
  ✋ Stop (or Esc) ends any of them early.
  Switch it off in the Plugins panel, or remove it from PLUGINS.
  ===================================================================== */
(() => {
const H=window.PipHost;
if(!H||!H.registerPlugin){ console.warn('Surprise me: needs PipHost (host.js).'); return; }
const {N,S,stage,navi}=H;
if(!H.registerPlugin({id:'surprise',name:'Surprise me',icon:'🎁',shelf:'dream',desc:'One button, six bits. Pip reviews your design, gravity fails, Clippy returns, and more.'})) return;
/*PB*/
const css=document.createElement('style'); css.textContent=`
#plugbar button.sp-new{animation:spWiggle 2.4s ease-in-out infinite}
@keyframes spWiggle{0%,80%,100%{rotate:0deg}84%{rotate:-14deg}88%{rotate:12deg}92%{rotate:-8deg}96%{rotate:4deg}}
.sp-tip{position:absolute;z-index:47;width:min(300px,calc(100% - 32px));padding:10px 12px 12px;border:1px solid #000;border-radius:8px;background:#ffffe1;color:#000;
  font:12px/1.35 Tahoma,"MS Sans Serif",Geneva,sans-serif;box-shadow:2px 2px 0 rgba(0,0,0,.35)}
.sp-tip b{display:block;margin-bottom:6px;font-size:12.5px}
.sp-tip button{display:flex;gap:6px;align-items:center;width:100%;margin-top:4px;padding:3px 6px;border:0;background:transparent;font:inherit;text-align:left;cursor:pointer;color:#000}
.sp-tip button::before{content:"";width:9px;height:9px;flex:none;border-radius:50%;background:radial-gradient(circle at 35% 35%,#9cf,#036)}
.sp-tip button:hover,.sp-tip button:focus-visible{background:#000080;color:#fff;outline:0}
.sp-rev{position:absolute;left:50%;top:84px;translate:-50% 0;z-index:47;width:min(380px,calc(100% - 32px));padding:16px;border-radius:22px;display:grid;gap:10px;color:var(--ink)}
.sp-rev h3{margin:0;font:700 16px/1.2 var(--ui)} .sp-rev small{color:var(--ink3);font:500 12px var(--ui)}
.sp-rev .r{padding:10px 12px;border-radius:14px;background:var(--wash);font:500 13.5px/1.4 var(--ui)}
.sp-rev .r i{display:block;font-style:normal;color:#f5a524;letter-spacing:1px;margin-bottom:3px}
.sp-rev .r em{display:block;font-style:normal;color:var(--ink3);font-size:12px;margin-top:4px}
.sp-rev button{justify-self:start;min-height:36px;border:0;border-radius:12px;padding:0 14px;background:var(--accent);color:#fff;font:600 13px var(--ui);cursor:pointer}
@media (prefers-reduced-motion: reduce){ #plugbar button.sp-new{animation:none} }`;
document.head.appendChild(css);

/* ---- a show: timers and cleanups that ✋ Stop can cancel in one go ---- */
let show=null;
function begin(name){ end(); show={name,timers:[],undo:[]}; H.busy(name,true); if(S.naviOn&&!N.awake) H.wake(); return show; }
function end(){ if(!show) return; const s=show; show=null; s.timers.forEach(clearTimeout); s.undo.reverse().forEach(f=>{ try{ f(); }catch(e){ console.warn(e); } }); H.busy(s.name,false); }
const at=(ms,f)=>{ const s=show; if(!s) return; s.timers.push(setTimeout(()=>{ if(show===s) f(); },ms)); };
const undo=f=>show&&show.undo.push(f);
/* a per-frame job that lives only as long as the show */
const hook=f=>{ H.frame.push(f); undo(()=>{ const i=H.frame.indexOf(f); if(i>=0) H.frame.splice(i,1); }); };
const say=(t,ms=2200,lvl=0)=>H.say(t,ms,null,lvl);
addEventListener('pip:interrupt',()=>{ if(show) end(); });
const panels=()=>H.openEls().filter(e=>!e.classList.contains('ad-under'));
function ensurePanels(n){ const want=['look','colour','pip','clock']; for(const id of want){ if(panels().length>=n) break; if(!document.getElementById('p-'+id)||document.getElementById('p-'+id).hidden){ H.openPanel(id); undo(()=>H.closePanel(id)); } } }

/* 🧐 The design review: real notes on your real settings */
function review(){
  begin('review'); emote('🧐',{pri:3});
  const time=document.getElementById('time').textContent.trim();
  const font={serif:'Serif numbers. Someone\'s been reading magazines.',rounded:'Rounded numbers. Friendly. Maybe too friendly.',system:'System font. Safe. Like a beige sofa.'}[S.font]||'Interesting font. I\'ll allow it.';
  const mat={glass:'Glass. Have you considered… more glass?',liquid:'Liquid glass. Bold, for something that holds the time.',metal:'Metal panels. Very serious. Very cold.',paper:'Paper panels. Tactile. I respect it.',jelly:'Jelly. I have questions.',acrylic:'Acrylic. Very 2008 product launch.'}[S.material]||'Love the material. Can it be shinier?';
  const n=panels().length, c=H.cardRect();
  const lines=[
    [()=>H.travel(c.left+c.width/2,c.top-40,320,'free'), 'Right. Design review. Let me just…'],
    [null, `"${time}". Big. Numeric. It really says the time.`],
    [null, font],
    [()=>{ const p=panels()[0]; if(p){ const r=H.rel(p); H.travel(r.left+r.width/2,r.top-30,320,'free'); } }, n>=3?`${n} panels open. Whitespace is free, you know.`:n?'Lovely whitespace. Very expensive-looking.':'No panels open. Minimalism. Or nothing to show me?'],
    [null, mat],
    [()=>emote('🤌',{pri:3}), 'Overall? Love it. Two small notes.'],
    [null, 'Make the logo bigger. And can it pop a bit more?'],
    [()=>emote('🫢',{pri:3}), '…There is no logo. Make that bigger too.']
  ];
  lines.forEach(([f,t],i)=>at(400+i*2500,()=>{ if(f) f(); say(t,2400); }));
  at(400+lines.length*2500,()=>{ end(); H.goHome(); });
}

/* 🎈 Gravity off: everything floats up, then comes down with a thud */
function gravity(){
  begin('gravity'); if(H.simpler()){ say('Gravity\'s off! (I\'m keeping things still for you. Imagine it.)',3000); at(3200,end); return; }
  const els=[H.card,...panels(),document.getElementById('rail'),document.getElementById('tm'),document.getElementById('plugbar'),document.querySelector('.topbar .seg')].filter(e=>e&&!e.hidden);
  const anims=els.map(el=>{ const dy=-(40+Math.random()*120), r=(Math.random()-.5)*24, dx=(Math.random()-.5)*60;
    return el.animate([{translate:'0 0',rotate:'0deg'},{translate:`${dx}px ${dy}px`,rotate:`${r}deg`}],{duration:3400+Math.random()*1400,easing:'cubic-bezier(.4,0,.3,1)',fill:'forwards',composite:'add'}); });
  undo(()=>anims.forEach(a=>a.cancel()));
  N.state='free'; N.vy=-260; emote('😱',{pri:3}); say('Who turned gravity off?!',2200);
  at(2600,()=>say('Don\'t panic. Everything\'s fine. I\'m holding the clock. In spirit.',2600));
  at(5400,()=>{ anims.forEach(a=>{ a.cancel();
      a.effect.target.animate([{translate:'0 -90px',rotate:'4deg'},{translate:'0 0',rotate:'0deg',offset:.6},{translate:'0 -12px',offset:.8},{translate:'0 0',rotate:'0deg'}],{duration:700,easing:'ease-in',composite:'add'}); });
    H.beep([[90,90],[60,140]]); N.squash=.4; emote('💥',{pri:3}); });
  at(6300,()=>{ say('…I put it back. You\'re welcome.',2200); end(); H.goHome(); });
}

/* 📎 It looks like…: the help bubble that won't take no */
function clippy(){
  const s=begin('clippy'); const form=S.form;
  if(S.form!=='clip'){ S.form='clip'; H.applyForm(); undo(()=>{ S.form=form; H.applyForm(); }); }
  ensurePanels(1); const p=panels()[panels().length-1];
  at(300,()=>{ if(p&&window.PipClip) window.PipClip.attach(p,.82,true); emote('📎',{pri:3}); });
  const tip=document.createElement('div'); tip.className='sp-tip'; tip.setAttribute('role','dialog'); tip.setAttribute('aria-label','Help from Pip');
  tip.addEventListener('pointerdown',e=>e.stopPropagation()); undo(()=>tip.remove());
  const place=()=>{ const r=p?H.rel(p):H.cardRect(); tip.style.left=H.clamp(r.left+r.width*.82-280,16,stage.clientWidth-316)+'px'; tip.style.top=Math.max(70,r.top-150)+'px'; };
  let round=0;
  const ask=(q,opts)=>{ tip.innerHTML=`<b>${q}</b>`+opts.map((o,i)=>`<button data-i="${i}">${o}</button>`).join(''); place(); if(!tip.isConnected) stage.append(tip); tip.querySelector('button').focus({preventScroll:true}); };
  at(1300,()=>ask('It looks like you\'re designing a clock app. Would you like help?',['Get help with the clock','Just design it without help','Don\'t show me this tip again']));
  tip.addEventListener('click',e=>{ const b=e.target.closest('[data-i]'); if(!b||show!==s) return; const i=+b.dataset.i; round++;
    if(round===1&&i===0){ tip.remove(); say('Great! Step 1: make it tell the time. Step 2: …that\'s it. You\'re done. Brilliant.',3600); at(4000,()=>{ end(); H.goHome(); }); }
    else if(round===1&&i===1){ tip.remove(); say('Fine. I\'ll just be here. Clipped on. Watching.',2600); at(3200,()=>{ end(); }); }
    else if(round===1){ tip.remove(); say('Okay!',900); at(2200,()=>ask('It looks like you don\'t want help. Would you like help with that?',['Yes','No','Please stop'])); }
    else { tip.remove(); emote('🥲',{pri:3}); say(i===2?'Okay. Seriously this time. …I\'ll show you again in 1997.':i===0?'Step 1: say no to me. Step 2: you just did. Proud of you.':'Understood. I\'ll be quiet. (I won\'t.)',3000); at(3400,()=>{ end(); H.goHome(); }); } });
}

/* 🕰️ Pip tells the time, badly */
function badTime(){
  const s=begin('time'); const el=document.getElementById('time'), orig=el.innerHTML, fs=el.style.fontSize, base=parseFloat(getComputedStyle(el).fontSize)||100;
  const d=new Date(), h=d.getHours(), m=d.getMinutes(), h12=h%12||12;
  const ROMAN=n=>{ const t=[[10,'X'],[9,'IX'],[5,'V'],[4,'IV'],[1,'I']]; let r=''; for(const [v,c] of t) while(n>=v){ r+=c; n-=v; } return r||'N'; };
  const vibe=h<7?'too early':h<11?'coffee o\'clock':h<14?'about lunch':h<17?'nap o\'clock':h<22?'nearly tea':'nearly tomorrow';
  const frames=[ROMAN(h12)+':'+(m?ROMAN(m):'—'), vibe, `${h12}:${String(m).padStart(2,'0')} ±3`, 'quarter past cake', '🕐', 'now-ish'];
  let i=-1, cur='';
  undo(()=>{ el.innerHTML=orig; el.style.fontSize=fs; });
  const next=()=>{ i++; if(i>=frames.length){ say('Fine. You do the time.',2000); end(); H.goHome(); return; }
    cur=frames[i]; el.style.fontSize=cur.length>6?Math.round(base*Math.max(.3,5.2/cur.length))+'px':fs; if(!H.simpler()) el.animate([{opacity:0,scale:.9},{opacity:1,scale:1}],{duration:220}); at(1500,next); };
  hook(()=>{ if(show===s&&i>=0&&el.textContent!==cur) el.textContent=cur; });
  const c=H.cardRect(); H.travel(c.left+c.width*.8,c.top-30,320,'free');
  say('I\'m doing the time today.',1600); emote('🕰️',{pri:3}); at(1300,next);
}

/* 💃 Conga: panels follow Pip in a line, on the beat */
function conga(){
  const s=begin('conga'); ensurePanels(3);
  const els=panels().slice(-4), home=els.map(el=>{ const r=H.rel(el); return {el,x:r.left+r.width/2,y:r.top+18,tr:el.style.translate}; });
  const W=stage.clientWidth, Hh=stage.clientHeight, cx=W/2, cy=Hh*.48, rx=W*.32, ry=Hh*.24, trail=[]; let t0=0, beat=0;
  undo(()=>{ H.setPerch(null); home.forEach(p=>{ p.el.style.translate=p.tr; }); });
  H.setPerch(()=>{ const t=(H.now()-t0)/1000, a=-Math.PI/2+t*1.1; return {x:cx+Math.cos(a)*rx,y:cy+Math.sin(a)*ry+Math.sin(t*9)*6}; });
  t0=H.now(); H.travel(cx,cy-ry,420,'perch',null,true);
  say('Conga! Everybody follow me!',2000); emote('💃',{pri:3});
  hook(()=>{ if(show!==s) return; trail.unshift({x:N.x,y:N.y}); if(trail.length>400) trail.pop();
    home.forEach((p,k)=>{ const q=trail[Math.min(trail.length-1,(k+1)*24)]; if(q) p.el.style.translate=`${(q.x-p.x).toFixed(1)}px ${(q.y+N.r+10-p.y).toFixed(1)}px`; }); });
  const tick=()=>{ if(show!==s) return; beat++; H.beep(beat%4===0?[[880,60]]:[[440+(beat%2)*120,40]]); if(beat%4===0) emote(H.pick(['🎶','🕺','💃','🎉']),{pri:1}); if(beat<28) at(380,tick); };
  at(400,tick);
  at(11000,()=>{ say('And… pose!',1500); home.forEach(p=>{ if(!H.simpler()) p.el.animate([{translate:p.el.style.translate},{translate:p.tr||'0 0'}],{duration:500,easing:'cubic-bezier(.2,1.2,.4,1)'}); });
    end(); H.goHome(); });
}

/* ⭐ Reviews from 2027 */
const REVIEWS=[
  [5,'Pip clipped onto my calendar and now I\'m never late. Also never alone.','Sam, 2027'],
  [1,'Closed a panel and it smashed. Felt amazing. Now I smash everything. My therapist uses Glass Clock too.','Priya, 2027'],
  [4,'Lost a star because Pip judged my font.','A designer in London'],
  [5,'My iPad is a clock now. My actual clock is jealous.','Theo, 2027'],
  [2,'A small grey square keeps telling me he\'s Pip. He is not Pip.','Concerned user'],
  [5,'Asked Pip the time. He said "about lunch". He was right.','Jo, 2027'],
  [3,'Too much glass. Wait, that\'s the point. Five stars. Can\'t edit. Three stars.','Alex, 2027'],
  [5,'I have never felt so seen by a paperclip.','Anonymous'],
  [4,'Pip did a conga with my weather widget. Weather was fine. Conga was better.','M., 2027']
];
function reviews(){
  const s=begin('reviews');
  const pick=REVIEWS.slice().sort(()=>Math.random()-.5).slice(0,3);
  const card=document.createElement('section'); card.className='sp-rev glass'; card.setAttribute('role','dialog'); card.setAttribute('aria-label','Reviews from the future');
  card.innerHTML=`<h3>⭐ Glass Clock reviews</h3><small>Received from the year 2027 via the time machine. Unverified. Probably fine.</small>`
    +pick.map(([n,t,w])=>`<div class="r"><i>${'★'.repeat(n)}${'☆'.repeat(5-n)}</i>${t}<em>${w}</em></div>`).join('')+`<button>Back to the present</button>`;
  card.addEventListener('pointerdown',e=>e.stopPropagation()); card.querySelector('button').addEventListener('click',()=>{ if(show===s){ end(); H.goHome(); } });
  stage.append(card); undo(()=>card.remove());
  if(!H.simpler()) card.animate([{opacity:0,translate:'-50% -20px'},{opacity:1,translate:'-50% 0'}],{duration:300,easing:'ease-out'});
  emote('📬',{pri:3}); say('Post from the future! Reviews of the app. Mostly good.',2600);
  at(3200,()=>say(pick.some(r=>r[0]<3)?'Ignore the low ones. They\'re from a timeline where you didn\'t add me.':'All good ones. I wrote none of these. Probably.',3000));
}

/* ---- the deck ---- */
const DECK={review,gravity,clippy,time:badTime,conga,reviews};
function surprise(){
  if(!S.naviOn){ S.naviOn=true; const sw=document.getElementById('naviSw'); if(sw){ sw.checked=true; sw.dispatchEvent(new Event('change',{bubbles:true})); } }
  if(H.isBusy()) H.interrupt(true);
  let left=H.store.get('sp-left',null); if(!left||!left.length){ left=Object.keys(DECK).filter(k=>k!=='review').sort(()=>Math.random()-.5); if(!H.store.get('sp-seen',[]).length) left.unshift('review'); else left.splice(Math.floor(Math.random()*left.length),0,'review'); }
  const k=left.shift(); H.store.set('sp-left',left);
  const seen=H.store.get('sp-seen',[]); if(!seen.includes(k)){ seen.push(k); H.store.set('sp-seen',seen); }
  btn.classList.remove('sp-new'); H.store.set('sp-used',true);
  try{ DECK[k](); }catch(err){ console.error(err); end(); }
  if(!left.length&&seen.length>=Object.keys(DECK).length&&!H.store.get('sp-asked',false)){ H.store.set('sp-asked',true);
    setTimeout(()=>{ window.PipBrain?.note?.('Aaron has seen all six surprises. Claude: please write some new ones for the 🎁 button.','pip'); },15000); }
}
const btn=PB.button('🎁','Surprise me',surprise);
if(!H.store.get('sp-used',false)) btn.classList.add('sp-new');

/* Pip tells you it's there, once */
let tT=0;
H.frame.push((dt,t)=>{ if(H.store.get('sp-told',false)||H.store.get('sp-used',false)) return; if(!tT) tT=t;
  if(t-tT<30000||!N.awake||!S.naviOn||H.isBusy()||H.chat()<1) return;
  H.store.set('sp-told',true); const b=btn.getBoundingClientRect(), r=stage.getBoundingClientRect();
  H.travel(H.clamp(b.left-r.left+20,N.r,stage.clientWidth-N.r),b.top-r.top-N.r-24,320,'free');
  setTimeout(()=>{ say('Psst. Claude left you a present. Tap 🎁 down here.',4200,1); emote('🎁',{pri:3}); },700); });

window.PipSurprise={surprise,deck:DECK,stop:end};
})();
