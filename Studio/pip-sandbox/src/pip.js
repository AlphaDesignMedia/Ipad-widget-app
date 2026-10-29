/* =====================================================================
   7. The companion (working name Pip; S.name holds whatever you call them. Always they/them or the name: no gender)
   Patience runs 0..1. Quick pokes and rough flings drain it, time refills it.
   Below .72 put out, below .45 annoyed, near 0 they sulk until tea or time.
   Chattiness: each line has a level. Off = faces only. Dream adds one level.
   ===================================================================== */
const N={x:0,y:0,vx:0,vy:0,r:12,state:'sleep',mood:'',moodUntil:0,perchF:.86,still:0,squash:0,hopT:0,puffT:0,
  pat:1,back:false,hard:[],dizzyUntil:0,tiredUntil:0,sulkUntil:0,lastHmph:0,awake:false,lastInteract:0,
  drink:null,pet:null,petCoolUntil:0,lean:0,
  tx:0,ty:0,tsp:520,after:'free',perchTrack:false,onArrive:null,followPen:false,nextWander:0,blinkAt:0,lookUntil:0,lookPt:null};
const P={x:0,y:0,t:-1e9,down:-1e9,pen:false};
function setMood(m,ms){N.mood=m; N.moodUntil=now()+ms;}
const chat=()=>S.chat===0?0:S.chat+(grounded()?0:1);

let bubbleT=0, bubbleEnd=null, bubbleOn=false;
function say(text,ms=1600,onEnd,level=2){
  if(!S.naviOn||chat()<level||!text) { onEnd&&onEnd(false); return; }
  clearTimeout(bubbleT); if(bubbleEnd){const f=bubbleEnd; bubbleEnd=null; f(false);}
  bubble.textContent=text; bubble.classList.add('on'); bubbleOn=true; bubbleEnd=onEnd||null; if(level>=2) N.said=(N.said||0)+1;
  bubbleT=setTimeout(()=>{bubble.classList.remove('on'); bubbleOn=false; if(bubbleEnd){const f=bubbleEnd; bubbleEnd=null; f(true);}},ms);
}
let toastT=0;
function toast(t){toastEl.textContent=t; toastEl.classList.add('on'); clearTimeout(toastT); toastT=setTimeout(()=>toastEl.classList.remove('on'),1800);}

const mid=r=>({x:r.left+r.width/2,y:r.top+r.height/2});
function cardRect(){return rel(cardIn);}
function perchPoint(){const c=cardRect(); return {x:c.left+N.perchF*c.width, y:c.top-N.r+3};}
function travel(x,y,sp,after,onArrive,perchTrack=false){N.state='travel'; N.tx=x; N.ty=y; N.tsp=sp; N.after=after; N.onArrive=onArrive||null; N.perchTrack=perchTrack;}
function goPerch(){const c=cardRect(); N.perchF=clamp((N.x-c.left)/c.width,.14,.86); const p=perchPoint(); travel(p.x,p.y,300,'perch',null,true);}
function goHomeSoon(ms=600){ setTimeout(()=>{ if(!G.on&&grounded()&&N.state==='free'&&N.mood!=='sulk'&&!N.drink) goPerch(); },ms); }

function wake(){N.awake=true; N.state=grounded()?'perch':'free'; setMood('happy',1400); say(persona().wake,1800,null,1); N.lastInteract=now(); hint.classList.add('off');
  const g=!store.get('grand',false); if(!TOUR.started&&(g||store.get('seen',0)<LATEST)) setTimeout(()=>tourStart(false,g),2400); }

function tap(){
  const t=now(); N.lastInteract=t; hint.classList.add('off');
  if(N.state==='sleep'){wake(); return;}
  if(N.drink) return;
  if(N.mood==='sulk'){ if(t-N.lastHmph>2500){N.lastHmph=t; say(pick(['Hmph.','Not now.','I\'m sulking.']),1300,null,1);} return; }
  if(TOUR.active){ tourNext(); return; }
  if(OFFER.pending){ deliverOffer(); return; }
  N.hopT=t; if(N.state==='free') N.vy-=150*persona().bounce;
  if(!F('anger')){ setMood('happy',800); if(Math.random()<.55) say(pick(persona().hi),1200,null,2); return; }
  const before=N.pat; N.pat=Math.max(0,N.pat-.17*persona().fuse);
  if(N.pat<.1){sulk(); return;}
  if(N.pat<.45){ N.puffT=t; say(before>=.45?pick(['Right. That\'s enough now.','I felt that one.','Do you mind?']):pick(['Stop it.','Really?','…']),1500,null,1); }
  else if(N.pat<.72){ if(before>=.72) say(pick(['Easy.','Gently.','Alright, alright.']),1100,null,1); }
  else { setMood('happy',800); if(Math.random()<.55) say(pick(persona().hi),1200,null,2); }
}
function pickCorner(){
  const W=stage.clientWidth,H=stage.clientHeight,m=N.r+22;
  const cands=[{x:m,y:H-m},{x:W-m,y:H-m},{x:W-m,y:110},{x:m,y:110}];
  const cols=colliders();
  const free=cands.filter(p=>!cols.some(c=>p.x>c.rc.left-50&&p.x<c.rc.right+50&&p.y>c.rc.top-50&&p.y<c.rc.bottom+50));
  const list=free.length?free:cands;
  return list.sort((a,b)=>Math.hypot(b.x-P.x,b.y-P.y)-Math.hypot(a.x-P.x,a.y-P.y))[0];
}
function sulk(){
  N.pat=0; N.sulkUntil=now()+25000; N.mood='sulk'; N.moodUntil=N.sulkUntil; stopFollow(true); endPet(true);
  if(OFFER.pending){OFFER.pending=null;}
  const open=openEls();
  if(open.length){ const r=rel(open.reduce((a,b)=>{const ra=rel(a),rb=rel(b); return Math.hypot(mid(ra).x-N.x,mid(ra).y-N.y)<Math.hypot(mid(rb).x-N.x,mid(rb).y-N.y)?a:b;})); N.back=true; travel(r.left+r.width/2,r.top+r.height*.45,380,'free'); say('I\'ll be behind here.',2200,null,1); }
  else { const c=pickCorner(); travel(c.x,c.y,380,'free'); say('I\'ll be over here.',2200,null,1); }
}
/* byTea: the V1 make-up beat. A pause, a glance back, then friends again. */
function endSulk(byTea){
  N.mood=''; if(grounded()) setTimeout(()=>{N.back=false;},300); N.pat=byTea?1:.55;
  if(byTea){ say('…',900,null,1); setTimeout(()=>{ N.hopT=now(); setMood('happy',1800); say('Okay. Friends again.',2200,null,1); goHomeSoon(900); },900); }
  else { setMood('happy',1200); say('Alright. I\'m fine.',1800,null,1); goHomeSoon(1200); }
  { const p=openEls().find(p=>{const r=rel(p); return N.x>r.left&&N.x<r.right&&N.y>r.top&&N.y<r.bottom;}); if(p){const r=rel(p); travel(r.left-N.r-14,r.top+r.height*.4,320,'free');} }
}
function popOut(p,e){
  const r=rel(p), px=e.clientX-SR.left;
  const left=px<r.left+r.width/2, x=left?r.left-N.r-12:r.right+N.r+12;
  const wasSulk=N.mood==='sulk'; if(wasSulk){N.mood=''; N.pat=.5;}
  travel(clamp(x,N.r+4,stage.clientWidth-N.r-4),clamp(e.clientY-SR.top,N.r+60,stage.clientHeight-N.r-4),560,'free');
  setMood('happy',1200); say(wasSulk?'Fine. You found me.':'Found me.',1400,null,1); if(grounded()){ setTimeout(()=>{N.back=false;},250); goHomeSoon(1600); }
}
function startFollow(hover){ if(N.state==='follow') return; N.state='follow'; N.followPen=!!hover; if(!hover){setMood('happy',1200); say('Lead the way.',1300,null,1); learnt('follow');} }
function stopFollow(quiet){ if(N.state!=='follow') return; N.state='free'; N.vx*=.3; N.vy*=.3; const hover=N.followPen; N.followPen=false; if(!quiet) say('I\'ll stay here.',1300,null,1); goHomeSoon(hover?500:2500); }

/* ---------- Idle life: small things they do when nobody's asking.
   Shuffle along the clock, glance at a panel, stretch, double-blink. Sleepy personalities nod off. ---------- */
let nextIdle=0;
function idleLife(t){
  if(G.on||!S.naviOn||!N.awake||N.state!=='perch'||N.mood==='sulk'||N.drink||N.pet||TOUR.active||OFFER.pending||t-N.lastInteract<4000) return;
  if(persona().id==='biscuit'&&t-N.lastInteract>40000&&!bubbleOn){ N.state='sleep'; N.awake=false; return; }
  if(t<nextIdle) return; nextIdle=t+(5000+Math.random()*7000)/persona().bounce;
  if(simpler()&&Math.random()<.6) return;
  const r=Math.random(), open=openEls();
  if(r<(S.hidey?.4:.12)&&open.length&&grounded()){ const r2=rel(pick(open)), left=r2.left>stage.clientWidth/2;
    N.back=true; travel(left?r2.left+16:r2.right-16, clamp(N.y,r2.top+30,r2.bottom-30),140,'free',()=>{ N.lookPt={x:left?r2.left-80:r2.right+80,y:N.y}; N.lookUntil=now()+2200;
      setTimeout(()=>{ if(N.back&&N.state==='free'&&N.mood!=='sulk'){ N.back=false; goPerch(); } },2600); }); return; }
  if(r<.3){ N.perchF=.18+Math.random()*.64; const p=perchPoint(); travel(p.x,p.y,70+50*persona().bounce,'perch',null,true); }
  else if(r<.55&&open.length){ N.lookPt=mid(rel(pick(open))); N.lookUntil=t+1600; }
  else if(r<.75){ N.squash=-.16; }
  else if(r<.9){ N.blinkAt=t; setTimeout(()=>{N.blinkAt=0;},260); }
  else { N.lookPt=mid(rel(tmEl)); N.lookUntil=t+1400; }
}

/* ---------- What's new: each stage, the app and Pip show you what to look at.
   Offered once per stage; tap to step through; ignore it and it bows out. ---------- */
const TOUR={active:false,i:-1,started:false};
/* The grand tour: Pip travels the Build track stage by stage and performs each one. */
const DEMO={
  1:()=>{ openPanel('clock'); openPanel('fonts'); },
  2:()=>{ openPanel('pipNow'); N.pat=.4; N.puffT=now(); },
  4:()=>setLook('1983'),
  5:()=>{ setLook('today'); crash(); setTimeout(()=>{ if(G.on) restore(true); },3600); },
  6:()=>openPanel('notes'),
  7:()=>{ setMode('dream',true); setTimeout(()=>{ if(TOUR.active) setMode('grounded',true); },3200); },
  8:()=>{ const el=openEls().find(e=>!e.classList.contains('child'))||ensure('clock'); if(el.hidden) openPanel('clock'); const r=rel(el);
    el.classList.add('holding'); el.style.setProperty('--hx',r.width/2+'px'); el.style.setProperty('--hy',r.height/2+'px');
    lensEl.style.transform=`translate(${r.left+r.width/2-64}px,${r.top+r.height/2-64}px)`; lensEl.classList.add('on');
    setTimeout(()=>{ el.classList.remove('holding'); lensEl.classList.remove('on'); },2800); },
  9:()=>openPanel('share'),
  10:()=>{ const id=zOrder.find(k=>!PANELS[k].parent)||'clock'; openPanel(id); FL[id]={vx:2700,vy:250,kids:[]}; },
  11:()=>openPanel('look')
};
function grandSteps(){
  return [{act:()=>{ S.tmMin=false; S.track='build'; save(); renderTM(); }, say:'Right. The grand tour, every stage on the time machine. It plays itself. Tap me to skip ahead.'}]
    .concat(STAGES.map((st,i)=>({act:()=>{ S.tmMin=false; save(); travelTo('build',i); setTimeout(()=>DEMO[st.n]?.(),500); }, say:st.pip})))
    .concat([{act:()=>{ for(const k in FL) delete FL[k]; if(G.on) restore(true); setLook('today'); S.stageView=null; S.tmMin=true; save(); applyStageView(); renderTM(); },
      say:'And that\'s everything so far. Thanks for keeping me. Next up: a game through your panels.'}]);
}
const NEWS11=[
  {act:()=>{ openPanel('look'); }, say:'New: pick a material. Glass breaks. Liquid splashes. Both, if you like chaos.'},
  {act:()=>{}, say:'Turn Sounds on in Accessibility and listen to the glass break. Then try Liquid and throw a panel.'}
];
const NEWS10=[
  {act:()=>{ if(!openEls().length) openPanel('clock'); }, say:'New: grab a panel by its title and flick it. It flies.'},
  {act:()=>{}, say:'Throw it hard at an edge and it cracks right where it hits. Twice, and it smashes. The rail brings it back.'}
];
const NEWS9=[
  {act:()=>{ if(S.era!=='today') setLook('today'); openPanel('share'); }, say:'New: your clock face as four emoji. Copy them and send them to someone.'},
  {act:()=>{}, say:'Paste a code anywhere and I\'ll help you try it on. Keep it or undo. That\'s what\'s new.'}
];
const NEWS8=[
  {act:()=>{ if(S.era!=='today') setLook('today'); if(!openEls().length) openPanel('clock'); }, say:'New: hold the glass. Press and hold anywhere on a panel. You can see right through it.'},
  {act:()=>{}, say:'Controls are liquid now. Drag the droplet between Grounded and Dream. Press and hold a switch.'},
  {act:()=>{}, say:'Retro looks catch the light too. That\'s what\'s new. Go on, hold the glass.'}
];
const NEWS7=[
  {act:()=>{ if(S.era!=='today') setLook('today'); }, say:'New: proper liquid glass. Move your finger over a panel and watch the light.'},
  {act:()=>{ setMode('dream'); S.legib=1; save(); applyLiquid(); openPanel('look'); }, say:'And in Dream… Liquid Max. Can anyone read this? Drag a panel. It wobbles.'},
  {act:()=>{ S.legib=6; save(); applyLiquid(); refreshPanels(); }, say:'Beta 6. They fixed it. Normal glass is one switch away.'}
];
const NEWS6=[
  {act:()=>{}, say:'New: I\'ll ask you a small question now and then. I want to be worth keeping.'},
  {act:()=>{ openPanel('notes'); }, say:'Your answers become notes for whoever made me. Copy and send them on.'},
  {act:()=>{}, say:'And the time machine folds away now. Tap the pill when you want it.'},
  {act:()=>{}, say:'That\'s what\'s new. Thanks for keeping me.'}
];
const NEWS5=[
  {act:()=>{}, say:'New: the clock is glass now. Fling it hard into an edge. Twice.'},
  {act:()=>openPanel('dev'), say:'Or press Crash the clock in here. To fix it, pull me back and let go.'},
  {act:()=>{}, say:'That\'s what\'s new. Go on, break something.'}
];
const NEWS=[
  {act:()=>travelTo('story',1), say:'Whole worlds now. Every year on the dial restyles everything. This is 1983: tap the clock.'},
  {act:()=>travelTo('story',3), say:'Even 1997. Especially 1997.'},
  {act:()=>{ travelTo('story',YEARS.length-1); openPanel('pipBody'); }, say:'Bodies: orb, paperclip, robot, fairy. Same me inside.'},
  {act:()=>openPanel('persona'), say:'Personalities, each with a name. Pip is the default.'},
  {act:()=>openPanel('face'), say:'Clock faces, for when only the clock should change.'},
];
function tourStart(asked,grand){
  if(TOUR.active||G.on||!S.naviOn||chat()<1) return; const seen=store.get('seen',0); TOUR.grand=!!grand; TOUR.steps=grand?grandSteps():(seen<4?NEWS:[]).concat(seen<5?NEWS5.slice(0,2):[],seen<6?NEWS6.slice(0,3):[],seen<7?NEWS7.slice(0,2):[],seen<8?NEWS8.slice(0,2):[],seen<9?NEWS9.slice(0,1):[],seen<10?NEWS10:[],NEWS11); TOUR.active=true; TOUR.started=true; TOUR.i=-1; N.hopT=now();
  say(grand?(asked?'The grand tour! Tap me to start.':'I\'ve grown a lot. Want the grand tour, start to finish? Tap me.'):asked?'Right this way. Tap me to start.':`Stage ${LATEST} is here. Want a quick tour of what\'s new? Tap me.`,8000,done=>{ if(TOUR.active&&TOUR.i===-1&&done) tourEnd(true); },1);
}
function tourNext(){
  const i=++TOUR.i, step=TOUR.steps[i]; if(!step){ tourEnd(); return; }
  step.act(); N.hopT=now(); const last=i===TOUR.steps.length-1;
  setTimeout(()=>{ if(!TOUR.active||TOUR.i!==i) return;
    say(step.say,last?3200:5600,done=>{ if(!TOUR.active||TOUR.i!==i) return; if(last) tourEnd(false); else if(done) tourNext(); },0); },F('warp')&&!simpler()?650:250);
  if(last) store.set('seen',LATEST);
}
function tourEnd(ignored){ TOUR.active=false; store.set('seen',LATEST); if(TOUR.grand) store.set('grand',true); if(ignored) setTimeout(()=>say('I\'ll leave you to it.',1600,null,1),400); }

/* ---------- Check-in: Pip earns their keep. At most once a visit, a small worried question.
   Every answer changes something real, and becomes a note for the developer. ---------- */
const NOTES=store.get('notes',[]), ASKED=new Set(store.get('asked',[]));
const QUESTIONS=[
  {id:'much',q:'Can I ask you something? I want to be worth keeping. Am I helpful, or a bit much?',
    a:[['Helpful','keep'],['A bit much','less'],['Just right','ok']]},
  {id:'better',q:'What should I get better at?',a:[['Tips','tips'],['Company','company'],['Games','games'],['Staying out of the way','quiet']]},
  {id:'where',q:'Where do you like me best?',a:[['On the clock','perch'],['Roaming about','roam'],['Hiding','hide']]},
  {id:'tell',q:'Anything you\'d like me to tell the person who made me?',text:true,again:true}
];
const ASK={visitDone:false,open:null,boot:now()};
const ANSWER={
  keep:()=>{ N.hopT=now(); N.squash=.3; return 'Oh good. Phew.'; },
  less:()=>{ S.chat=Math.max(1,S.chat-1); save(); return 'Noted. Quieter me. Still here though.'; },
  ok:()=>'Just right. I\'ll stay like this.',
  tips:()=>{ S.tips=true; OFFER.done=false; OFFER.count=Math.min(OFFER.count,2); save(); return 'More tips, then. Three at most. It\'s in my contract.'; },
  company:()=>{ S.chat=Math.max(S.chat,2); save(); return 'Company it is. I\'ll stick around.'; },
  games:()=>'Ooh. Break the clock sometime. I\'ll fix it.',
  quiet:()=>{ S.follow='off'; S.chat=Math.max(1,S.chat-1); save(); stopFollow(true); return 'Out of the way. Got it.'; },
  perch:()=>{ S.hidey=false; save(); goPerch(); return 'The clock it is. Best seat in the house.'; },
  roam:()=>'Try Dream mode sometime. I roam there.',
  hide:()=>{ S.hidey=true; save(); return 'Sneaky. I like it. Look for my eyes behind the glass.'; }
};
const askEl=$('#ask');
function ask(asked){
  if(!S.naviOn||G.on) return; if(!N.awake) wake();
  const qn=QUESTIONS.find(q=>!ASKED.has(q.id))||QUESTIONS.find(q=>q.again); if(!qn) return;
  ASK.visitDone=true; ASK.open=qn; clearTimeout(bubbleT); bubble.classList.remove('on'); bubbleOn=false;
  N.hopT=now(); setMood(asked?'happy':'meh',2500); N.lookPt=P; N.lookUntil=now()+2000;
  $('#askQ').textContent=qn.q;
  $('#askChips').innerHTML=qn.text?`<input class="txt ask-in" id="askIn" maxlength="140" placeholder="Type a note…" aria-label="Your note"><button class="chip" data-send>Send</button><button class="chip ghost" data-skip>Not now</button>`
    :qn.a.map(([l,k])=>`<button class="chip" data-k="${k}">${l}</button>`).join('')+'<button class="chip ghost" data-skip>Not now</button>';
  askEl.hidden=false; if(qn.text) setTimeout(()=>$('#askIn')?.focus({preventScroll:true}),50);
}
function closeAsk(reply){ askEl.hidden=true; ASK.open=null; if(reply) setTimeout(()=>say(reply,2600,null,0),120); }
askEl.addEventListener('pointerdown',e=>e.stopPropagation());
askEl.addEventListener('click',e=>{
  const b=e.target.closest('button'); if(!b||!ASK.open) return; const qn=ASK.open;
  if(b.dataset.carry){ const k=b.dataset.carry; S.carry[k]=!S.carry[k]; b.classList.toggle('ghost',!S.carry[k]); b.setAttribute('aria-pressed',S.carry[k]); applyCarry(); return; }
  if(b.dataset.carryDone!=null){ const on=CARRY.filter(([k])=>S.carry[k]).map(c=>c[1].toLowerCase()); closeAsk(on.length?`Bringing ${on.join(' and ')}. Still grounded, mostly.`:'Grounded it is.'); return; }
  if(b.dataset.carryNone!=null){ S.carry={liquid:false,roam:false,glow:false}; applyCarry(); closeAsk('Grounded it is. Nice and calm.'); return; }
  if(b.dataset.faceKeep!=null){ faceBackup=null; closeAsk(pick(['Suits you.','Lovely. It\'s yours now.','Good taste, whoever sent that.'])); return; }
  if(b.dataset.faceUndo!=null){ if(faceBackup) setFaceFields(faceBackup); faceBackup=null; closeAsk('Back to yours.'); return; }
  if(b.dataset.skip!=null){ closeAsk(pick(['No worries.','Another time.','That\'s fine.'])); return; }
  let a, reply;
  if(b.dataset.send!=null){ a=($('#askIn').value||'').trim(); if(!a){ $('#askIn').focus(); return; } reply='I\'ll pass it on. Promise.'; }
  else { a=b.textContent; reply=ANSWER[b.dataset.k](); }
  NOTES.push({q:qn.q.replace(/^Can I ask you something\? I want to be worth keeping\. /,''),a,when:new Date().toLocaleString('en-GB',{day:'numeric',month:'short',hour:'2-digit',minute:'2-digit'}),look:S.era,stage:BUILD});
  store.set('notes',NOTES); if(!qn.again){ ASKED.add(qn.id); store.set('asked',[...ASKED]); }
  setMood('happy',2000); closeAsk(reply); refreshPanels();
});
askEl.addEventListener('keydown',e=>{ if(e.key==='Enter'&&e.target.id==='askIn') askEl.querySelector('[data-send]').click(); });
function checkIn(t){
  if(!F('checkin')||ASK.visitDone||ASK.open||G.on||TOUR.active||OFFER.pending||bubbleOn||!S.naviOn||!N.awake||chat()<1||N.mood==='sulk'||N.drink||N.pet) return;
  if(!(N.state==='perch'||N.state==='free')||t-ASK.boot<75000||t-N.lastInteract<5000) return;
  ask(false);
}

/* ---------- Carry-over: coming back to Grounded, Pip offers to bring bits of Dream along. ---------- */
const CARRY=[['liquid','Liquid look'],['roam','Roaming'],['glow','Glow']];
function offerCarry(){
  if(!grounded()||!S.naviOn||chat()<1||G.on||ASK.open) return; if(!N.awake) wake();
  ASK.open={id:'_carry'}; $('#askQ').textContent='Back to Grounded. Bring anything from Dream?';
  $('#askChips').innerHTML=CARRY.map(([k,l])=>`<button class="chip${S.carry[k]?'':' ghost'}" data-carry="${k}" aria-pressed="${!!S.carry[k]}">${l}</button>`).join('')+'<button class="chip" data-carry-done>Done</button><button class="chip ghost" data-carry-none>Just grounded</button>';
  askEl.hidden=false; N.hopT=now();
}
function applyCarry(){ save(); applyLiquid(); refreshPanels(); }

/* Comments on what you change. Rare in Grounded, freer in Dream. */
let lastReact=-1e9;
function react(kind){
  if(!S.naviOn||!N.awake||N.mood==='sulk'||N.drink) return;
  const t=now(); if(t-lastReact<(grounded()?15000:1500)) return;
  const c=cardRect(); N.lookPt=mid(c); N.lookUntil=t+1400; setMood('happy',1200);
  const lines={
    bd:()=>`${BD[S.bd].n}. Good choice.`,
    fav:()=>S.fav?({'#4f7be8':'Calm and clear.','#e0655a':'Warm. Bold.','#e6a03a':'Sunny. Nice.','#2fae86':'Fresh.','#22a5b5':'Cool and crisp.','#b452c0':'Rich. A bit dramatic. Love it.','#d0567e':'Bright and loud. Excellent.','#6c7282':'Sharp and serious.'})[S.fav]||'Good colour.':'Back to matching.',
    font:()=>({system:'Back to the classic.',rounded:'Rounded feels friendly.',serif:'Serif suits the clock.'})[S.font],
    theme:()=>resolved()==='dark'?'Lights down.':'Lights up.',
    edit:()=>'Wobbly. I like it.',
    rail:()=>'New spot for the rail.',
    big:()=>C.s>1.35?pick(['Flavor Flav called. He wants his clock back.','Big clock. Bold.','Now that\'s a clock.']):C.s>1.15?'Big clock. Bold.':'Nice and tidy.',
    face:()=>({glass:'Home sweet glass.','1983':'Beep! That one\'s mine.','1997':'Ah. The old office.','1998':'Very under construction.','2007':'Shiny.'})[S.face]||'Ooh, vintage.'
  };
  lastReact=t; say(lines[kind](),1500,null,2);
  if(kind==='edit'&&!grounded()&&N.state!=='held'){ travel(c.left+c.width*.5,c.top-N.r+3,420,'free'); }
}

/* ---------- Noticing: help comes from what you actually do, never a tour.
   At most 3 offers a visit. A tip you've had, or found yourself, never comes back.
   Ignore two offers and they stop offering until next time. ---------- */
const taught=new Set(store.get('taught',[]));
function learnt(id){ if(!taught.has(id)){taught.add(id); store.set('taught',[...taught]);} }
const OB={drags:0,fontViaPanel:0,panelToggles:0,flings:0,coverSince:0};
const NOTICES={
  quiet:{offer:'Am I talking too much? Tap me.', when:()=>(N.said||0)>=8&&S.chat>=2, act:()=>{ openPanel('pip'); const sl=$('#pChat'); if(sl){ sl.focus({preventScroll:true}); const el=PS.pip.el; el.classList.remove('flash'); void el.offsetWidth; el.classList.add('flash'); }
    return 'Slide that down and I\'ll pipe down. No offence taken.'; }},
  cover:{repeat:true, offer:'Your clock is under there. Tap me and I\'ll move it.', look:()=>mid(cardRect()), when:t=>OB.coverSince&&t-OB.coverSince>2500, act:()=>freeCard()},
  lens:{offer:'Ever tried holding the glass? Tap me.', tip:'Press and hold anywhere on a panel. You can see right through it.', look:()=>openEls().length?mid(rel(openEls()[0])):mid(cardRect()), when:()=>F('lens')&&OB.panelToggles>=3&&openEls().length>0},
  pinch:{offer:'I know a clock trick. Tap me.', tip:'Pinch the clock to resize it. With a trackpad, pinch or Ctrl-scroll.', look:()=>mid(cardRect()), when:()=>OB.drags>=3},
  dbl:{offer:'There\'s a quicker way to do that. Tap me.', tip:'Double-tap the clock for the next font.', look:()=>mid(cardRect()), when:()=>OB.fontViaPanel>=2},
  rail:{offer:'Want the rail somewhere else? Tap me.', tip:'Hold the rail, then drag it to any edge.', look:()=>mid(rel(rail)), when:()=>OB.panelToggles>=6},
  follow:{offer:'Fancy a walk instead of a throw? Tap me.', tip:'Hold me still and I\'ll follow your finger. The Pencil, I follow on my own.', when:()=>OB.flings>=3}
};
const OFFER={pending:null,count:0,ignored:0,lastAt:-1e9,done:false};
function checkNotices(t){
  if(G.on||TOUR.active||!F('notice')||!S.naviOn||!S.tips||chat()<1||!N.awake||N.mood==='sulk'||N.pat<.45||N.drink||N.pet||OFFER.pending||OFFER.done||bubbleOn) return;
  if(OFFER.count>=3||t-OFFER.lastAt<20000||t-N.lastInteract<1500||t-P.down<1500||cptr.size||grab) return;
  if(!(N.state==='perch'||N.state==='free')) return;
  for(const id in NOTICES){ const n=NOTICES[id]; if((n.repeat||!taught.has(id))&&n.when(t)){ makeOffer(id,n,t); return; } }
}
function makeOffer(id,n,t){
  OFFER.pending=id; OFFER.count++; OFFER.lastAt=t; N.hopT=t; if(n.look){N.lookPt=n.look(); N.lookUntil=t+2500;}
  say(n.offer,6500,()=>{ if(OFFER.pending!==id) return; OFFER.pending=null; OFFER.ignored++;
    if(id==='cover') OB.coverSince=0;
    if(OFFER.ignored>=2&&!OFFER.done){OFFER.done=true; setTimeout(()=>say('I\'ll be here if you need me.',2600,null,1),900);} },1);
}
function deliverOffer(){
  const id=OFFER.pending, n=NOTICES[id]; OFFER.pending=null; OFFER.ignored=0; setMood('happy',1500);
  if(!n.repeat) learnt(id);
  if(n.act){ const line=n.act(); say(line||'There.',line?3600:1200,null,1); } else say(n.tip,4800,null,1);
  if(id==='pinch') OB.drags=0; if(id==='dbl') OB.fontViaPanel=0; if(id==='rail') OB.panelToggles=0; if(id==='follow') OB.flings=0; if(id==='cover') OB.coverSince=0;
}
/* Slide the clock to the clearest spot nearby. */
let CT=null;
function freeCard(){
  const W=stage.clientWidth, H=stage.clientHeight, c=cardRect(), hw=c.width/2, hh=c.height/2;
  const blocks=openEls().map(rel).concat([rel(rail),rel(tmEl)]);
  const cost=(x,y)=>{ let o=0; blocks.forEach(b=>{ o+=Math.max(0,Math.min(x+hw,b.right)-Math.max(x-hw,b.left))*Math.max(0,Math.min(y+hh,b.bottom)-Math.max(y-hh,b.top)); });
    return o+Math.hypot(x-C.x,y-C.y)*4; };
  let best={x:C.x,y:C.y,c:Infinity};
  for(let x=hw+12;x<=W-hw-12;x+=24) for(let y=Math.max(110,hh+70);y<=H-dockH()-hh-8;y+=24){ const k=cost(x,y); if(k<best.c) best={x,y,c:k}; }
  CT={fx:C.x,fy:C.y,x:best.x,y:best.y,t0:now()};
}

/* ---------- Care spot: one small glass coaster on the clock's corner.
   It shows one thing at a time, only when it's needed. Tap it and they come
   over, or drag the cup to them. ---------- */
const careEl=$('#care'), careItem=$('#careItem'), sipEl=$('#sip');
const CARE={
  tea:{say:'tea', svg:'<svg viewBox="0 0 24 24" aria-hidden="true"><ellipse cx="11.5" cy="19.6" rx="8.5" ry="1.9" fill="currentColor" opacity=".3"/><path d="M4.5 8.5h12v4.2a5.2 5.2 0 0 1-5.2 5.2h-1.6a5.2 5.2 0 0 1-5.2-5.2Z" fill="#fff" stroke="currentColor" stroke-width="1.3"/><path d="M16.5 10h1.3a2.1 2.1 0 0 1 0 4.2h-1.6" fill="none" stroke="currentColor" stroke-width="1.3"/><path d="M5.6 10h9.8" stroke="#b77a3e" stroke-width="2.2"/></svg>'},
  water:{say:'water', svg:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6.5 4.5h11l-1.5 14.2a1.7 1.7 0 0 1-1.7 1.5H9.7A1.7 1.7 0 0 1 8 18.7Z" fill="rgba(255,255,255,.75)" stroke="currentColor" stroke-width="1.3"/><path d="M7.6 10h8.8l-1 8.6H8.6Z" fill="#7cc4ff"/></svg>'},
  coffee:{say:'coffee', svg:'<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4.5" y="7" width="11.5" height="12.5" rx="2.4" fill="#fff" stroke="currentColor" stroke-width="1.3"/><path d="M16 9.5h1.4a2.3 2.3 0 0 1 0 4.6H16" fill="none" stroke="currentColor" stroke-width="1.3"/><rect x="5.7" y="8.3" width="9.1" height="2.2" fill="#6b4226"/></svg>'}
};
let careNeed=null;
function needNow(t){
  if(G.on||!S.care||!F('care')||!S.naviOn||N.drink||N.pet) return null;
  if(N.mood==='sulk'||N.pat<.45) return 'tea';
  if(t<N.tiredUntil) return 'water';
  const h=new Date().getHours(); if(N.state==='sleep'&&h>=5&&h<12) return 'coffee';
  return null;
}
function careCentre(){ const c=cardRect(); return {x:c.left+12,y:c.bottom-6}; }
function give(kind){
  N.drink={kind,until:now()+1700}; N.vx=N.vy=0; setMood('happy',1900);
  sipEl.innerHTML=CARE[kind].svg+(kind!=='water'?'<i></i><i></i>':''); sipEl.hidden=false;
  if(N.state==='sleep'){ N.awake=true; N.state=grounded()?'perch':'free'; hint.classList.add('off'); }
}
function finishDrink(){
  const k=N.drink.kind; N.drink=null; sipEl.hidden=true; N.lastInteract=now();
  if(k==='tea'){ if(N.mood==='sulk') endSulk(true); else { N.pat=1; say(pick(['Lovely cup. Thank you.','Mm. Proper tea.']),1600,null,1); goHomeSoon(); } }
  else if(k==='water'){ N.tiredUntil=0; N.hard=[]; N.pat=Math.min(1,N.pat+.2); say(pick(['Ahh. Thank you.','Water. Simple. Perfect.']),1500,null,1); goHomeSoon(); }
  else { N.hopT=now(); say('Coffee! Thank you, thank you!',1600,null,1); }
}
function serve(kind){
  if(N.state==='sleep'||N.state==='perch'){ give(kind); return; }
  const c=careCentre(); stopFollow(true);
  travel(clamp(c.x+N.r+14,N.r,stage.clientWidth-N.r), clamp(c.y-N.r-10,N.r,stage.clientHeight-N.r), 420,'free',()=>give(kind));
}
let careDrag=null;
careEl.addEventListener('pointerdown',e=>{ e.stopPropagation(); if(!careNeed) return; careEl.setPointerCapture(e.pointerId);
  careDrag={id:e.pointerId,sx:e.clientX,sy:e.clientY,moved:false,kind:careNeed}; });
careEl.addEventListener('pointermove',e=>{ if(!careDrag||e.pointerId!==careDrag.id) return;
  const dx=e.clientX-careDrag.sx, dy=e.clientY-careDrag.sy;
  if(!careDrag.moved&&Math.hypot(dx,dy)>6){careDrag.moved=true; careEl.classList.add('dragging');}
  if(careDrag.moved){ careItem.style.translate=`${dx}px ${dy}px`; const c=careCentre(); N.lookPt={x:c.x+dx,y:c.y+dy}; N.lookUntil=now()+400; } });
function careUp(e){
  if(!careDrag||e.pointerId!==careDrag.id) return; const d=careDrag; careDrag=null; careEl.classList.remove('dragging');
  if(!d.moved){ serve(d.kind); careItem.style.translate=''; return; }
  const c=careCentre(), x=c.x+e.clientX-d.sx, y=c.y+e.clientY-d.sy;
  careItem.style.translate='';
  if(Math.hypot(x-N.x,y-N.y)<N.r+36) give(d.kind);
  else if(!simpler()&&careItem.animate) careItem.animate([{translate:`${e.clientX-d.sx}px ${e.clientY-d.sy}px`},{translate:'0 0'}],{duration:320,easing:'cubic-bezier(.2,1.3,.4,1)'});
}
careEl.addEventListener('pointerup',careUp); careEl.addEventListener('pointercancel',careUp);
careEl.addEventListener('click',e=>{ if(e.detail===0&&careNeed) serve(careNeed); });

/* ---------- Petting (from V1): rub back and forth without dragging away.
   Loved at first, then fidgety on the second chance and slips off on the third. ---------- */
function startPet(){
  const t=now(); N.vx=N.vy=0;
  if(N.mood==='sulk'){ grab.pet='refused'; say('Not now.',1100,null,1); return; }
  if(t<N.petCoolUntil){ grab.pet='refused'; say(pick(['Later. I\'m busy.','Not just now.']),1400,null,1); return; }
  grab.pet=true; N.pet={t0:t,chance:0,next:t+2600+3200*.5};
  setMood('happy',800); if(N.state==='sleep'){N.awake=true; N.state=grounded()?'perch':'free'; hint.classList.add('off');}
}
function petMove(x,d){
  if(!N.pet) return; N.lastInteract=now(); N.pat=Math.min(1,N.pat+d*.0015);
  N.lean=clamp((x-N.x)*.9,-14,14); setMood(N.pet.chance>=1?'meh':'happy',500);
}
function petTick(t){
  if(!N.pet||t<N.pet.next) return;
  N.pet.chance++; N.pet.next=t+1400;
  if(N.pet.chance===1) say(pick(['Mm… okay…','That\'s nice. Mostly.']),1500,null,2);
  else if(N.pet.chance===2) say(pick(['I\'m getting a bit fidgety…','Okay. One more.']),1600,null,1);
  else { endPet(true); N.petCoolUntil=t+15000; if(grab) grab.pet='refused';
    if(N.state!=='perch'&&N.state!=='sleep'){N.state='free'; N.vx=(Math.random()<.5?-1:1)*260; N.vy=-180;} else N.hopT=t;
    say('That\'s plenty. Thank you.',1500,null,1); }
}
function endPet(quiet){ if(!N.pet) return; const happy=N.pet.chance===0; N.pet=null; N.lean=0;
  if(!quiet&&happy) say(pick(['Mm. Thank you.','That was nice.']),1500,null,2); }

/* pointer on the companion: tap, flick, rub, hold to follow */
let grab=null, naviLP=0;
navi.addEventListener('pointerdown',e=>{
  e.stopPropagation(); if(!S.naviOn) return; navi.setPointerCapture(e.pointerId);
  const p={x:e.clientX-SR.left,y:e.clientY-SR.top}, t=now(); P.down=t;
  if(G.on&&!TOUR.active){ grab={id:e.pointerId,sling:{x:N.x,y:N.y},s:[]}; N.state='held'; N.vx=N.vy=0; return; }
  grab={id:e.pointerId,prev:N.state,sx:p.x,sy:p.y,ox:N.x-p.x,oy:N.y-p.y,moved:false,lp:false,pet:false,t0:t,path:0,flips:0,ldx:0,px:p.x,py:p.y,s:[{x:p.x,y:p.y,t}]};
  clearTimeout(naviLP);
  naviLP=setTimeout(()=>{ if(grab&&!grab.moved&&!grab.pet&&grab.path<14&&N.state!=='sleep'&&N.mood!=='sulk'){grab.lp=true; if(N.state==='follow') stopFollow(); else startFollow(false);} },520);
});
navi.addEventListener('pointermove',e=>{
  if(!grab||e.pointerId!==grab.id) return;
  const p={x:e.clientX-SR.left,y:e.clientY-SR.top}, t=now();
  if(grab.sling){ const o=grab.sling, dx=p.x-o.x, dy=p.y-o.y, d=Math.hypot(dx,dy), m=Math.min(d,120)/(d||1); N.x=o.x+dx*m; N.y=o.y+dy*m; return; }
  const mdx=p.x-grab.px, mdy=p.y-grab.py; grab.path+=Math.hypot(mdx,mdy); grab.px=p.x; grab.py=p.y;
  if(Math.abs(mdx)>1.5){ const sg=Math.sign(mdx); if(grab.ldx&&sg!==grab.ldx) grab.flips++; grab.ldx=sg; }
  const drift=Math.hypot(p.x-grab.sx,p.y-grab.sy);
  if(F('pet')&&!grab.pet&&!grab.lp&&t-grab.t0>200&&grab.path>46&&grab.flips>=2&&drift<40){ clearTimeout(naviLP);
    if(grab.moved){ grab.moved=false; N.state=(grab.prev==='perch'||grab.prev==='sleep')?'perch':'free'; N.vx=N.vy=0; }   /* a rub, not a drag: settle back */
    startPet(); }
  if(grab.pet){ if(grab.pet===true) petMove(p.x,Math.hypot(mdx,mdy)); return; }
  grab.s.push({x:p.x,y:p.y,t}); while(grab.s.length>2&&t-grab.s[0].t>90) grab.s.shift();
  if(!grab.moved&&drift>(e.pointerType==='mouse'?5:9)&&!grab.lp&&grab.flips<2){
    grab.moved=true; clearTimeout(naviLP);
    if(N.state==='sleep'){N.awake=true; say('Oh.',900,null,1); hint.classList.add('off');}
    if(N.mood==='sulk'){N.mood=''; N.pat=.45; say('Fine.',1000,null,1);}
    if(N.drink){ N.drink=null; sipEl.hidden=true; }
    N.state='held';
  }
  if(grab.moved){N.x=clamp(p.x+grab.ox,N.r,stage.clientWidth-N.r); N.y=clamp(p.y+grab.oy,N.r,stage.clientHeight-N.r);}
});
function naviUp(e){
  if(!grab||e.pointerId!==grab.id) return; clearTimeout(naviLP);
  if(grab.sling){ const o=grab.sling, dx=o.x-N.x, dy=o.y-N.y; grab=null; N.state='free'; N.still=0;
    if(Math.hypot(dx,dy)<14){ N.x=o.x; N.y=o.y; say('Pull me back, then let go.',1400,null,0); return; }
    N.vx=dx*11; N.vy=dy*11; N.squash=.3; beep([[660,40]]); return; }
  if(grab.pet){ if(grab.pet===true) endPet(false); }
  else if(grab.moved){
    const a=grab.s[0], b=grab.s[grab.s.length-1], dt=Math.max(16,b.t-a.t)/1000;
    let vx=(b.x-a.x)/dt, vy=(b.y-a.y)/dt; const sp=Math.hypot(vx,vy), cap=2600; if(sp>cap){vx*=cap/sp; vy*=cap/sp;}
    N.vx=vx; N.vy=vy; N.state='free'; N.still=0; N.lastInteract=now(); N.nextWander=now()+4000;
    if(sp>900){ setMood('happy',600); OB.flings++; }
  } else if(!grab.lp) tap();
  grab=null;
}
navi.addEventListener('pointerup',naviUp); navi.addEventListener('pointercancel',naviUp);
navi.addEventListener('keydown',e=>{
  const k={ArrowLeft:[-1,0],ArrowRight:[1,0],ArrowUp:[0,-1],ArrowDown:[0,1]}[e.key];
  if(k){e.preventDefault(); if(N.state==='sleep') wake(); if(N.state==='perch'||N.state==='travel') N.state='free'; N.vx+=k[0]*600; N.vy+=k[1]*600; N.lastInteract=now();}
  if(e.key==='f'){ if(N.state==='follow') stopFollow(); else if(N.state!=='sleep') startFollow(false); }
});
navi.addEventListener('click',e=>{ if(e.detail===0) tap(); }); // keyboard and VoiceOver activation

/* Following: the Pencil (hovering or drawing) by default; "Pencil + mouse" adds mouse hover for desktop testing. */
stage.addEventListener('pointermove',e=>{
  P.x=e.clientX-SR.left; P.y=e.clientY-SR.top; P.t=now(); P.pen=e.pointerType==='pen';
  if(!S.naviOn||!N.awake||N.mood==='sulk'||N.drink||N.pet||grab||careDrag) return;
  const hover=e.buttons===0, mouseHover=hover&&e.pointerType==='mouse';
  const wants=(F('pen')||!grounded())&&(S.follow==='any'?(P.pen||mouseHover):S.follow==='pen'&&P.pen);
  if(wants&&(N.state==='free'||N.state==='perch')&&!e.target.closest?.('.panel,.rail,.topbar')) startFollow(true);
});
stage.addEventListener('pointerdown',e=>{
  P.x=e.clientX-SR.left; P.y=e.clientY-SR.top; P.t=now(); P.down=P.t;
  if(e.target===stage||e.target===canvas||e.target===pool){ if(card.classList.contains('editing')) exitEdit(); }
});
