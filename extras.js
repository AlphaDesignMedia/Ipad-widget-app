/* =====================================================================
   7b. Time machine: one docked dial, two tracks.
   Build: travel to a stage and the sandbox works as it did then; each
          feature from a stage has its own on/off pill.
   Story: the Pane & Sons Visitor Experience. Entirely made up. Each year
          dresses them in that era's body, and it stays on while you play.
   ===================================================================== */
const STAGES=[
  {n:1,name:'SHELL',title:'Shell',pip:'Stage one. This is where I moved in: panels that open panels, and I learned to bounce.',text:'Panels that open panels, Grounded and Dream, flicking and sulking carried over from the Navi sandbox.'},
  {n:2,name:'PERSONALITY',title:'Personality',pip:'Stage two. I got feelings. Poke me too much and I sulk. Tea fixes it.',text:'Patience you can see, the care spot, petting, the Pencil, and tips that come from noticing what you do.'},
  {n:3,name:'TIME MACHINE',title:'Time machine',pip:'Stage three. The time machine. And my whole made-up history. Don\'t ask about 1997.',text:'This dial. Travel between stages, switch single features off, and the Story track.'},
  {n:4,name:'ERA WORLDS',title:'Era worlds',pip:'Stage four. Whole worlds for every era. I got a robot body. And a paperclip one, sadly.',text:'Each year in the Story track restyles the whole sandbox, ported from V1\'s eras. Plus the V1 bodies, clock faces and a real Glacio LCD.'},
  {n:5,name:'CRASH',title:'Crash',pip:'Stage five. The clock got fragile. Break it and I\'ll slingshot the time back together.',text:'The clock is glass. Fling it hard into an edge and it cracks; twice and it shatters into a 404. Pull Pip back and let go to collect the time. Open panels are the walls.'},
  {n:6,name:'CHECK-IN',title:'Earning their keep',pip:'Stage six. I started asking how to be more useful. I\'d like to stay, you see.',text:'Pip asks a small question now and then, a little worried about being worth keeping. Answers change how Pip behaves and become notes for the developer. The dial folds into a pill.'},
  {n:7,name:'LIQUID',title:'Liquid glass',pip:'Stage seven. Proper liquid glass. And in Dream, a little joke about reading it.',text:'Today\'s glass gets clearer, with a specular rim and a highlight that follows your finger. In Dream, Liquid Max lovingly mocks it: barely-there glass, rainbow edges, jelly panels and a Legibility slider from Beta 1 to Beta 6.'},
  {n:8,name:'HOLD THE GLASS',title:'Hold the glass',pip:'Stage eight. Hold the glass and you can see right through it. Try finding me.',text:'Press and hold a panel and the frost clears under your finger. Segments get a draggable glass droplet, switches and sliders turn into lenses while held, retro looks catch the light, and Today gets a capsule refresh.'},
  {n:9,name:'FACE CODES',title:'Emoji face codes',pip:'Stage nine. Faces as four emoji. Send one to someone. I\'ll help them try it on.',text:'Your clock face as four emoji: three carry the face, colour, backdrop, font, weight and format, the fourth is a check. Copy, send, and paste anywhere to try one on, with Keep or Undo.'},
  {n:10,name:'SMASH',pip:'Stage ten. Panels fly now. Throw one hard enough and it cracks where it hits. Twice, and it smashes. I\'ll sweep up.',title:'Flick and smash',text:'Flick a panel by its title bar and it flies, bounces and slows. A hard hit cracks it where it lands, radiating from the impact; a second hit (or one huge one) smashes it into shards that spray the way it was going. Reopen it from the rail, good as new.'},
  {n:11,name:'MATERIALS',pip:'Stage eleven. Pick your material. Glass breaks. Liquid splashes. Both, if you\'re feeling chaotic.',title:'Glass or liquid',text:'Glass is rigid: flick, crack, smash, with a real glass-break sound. Liquid is literal: panels and the clock wobble smoothly and splash droplets on impact instead of breaking. Both overlaps them.'}
];
const YEARS=[
  {y:'1887',name:'THE ACCIDENT',era:'1887',title:'The Accident',
    text:'Welcome to the Pane & Sons Visitor Experience. Please keep to the timeline and do not lick the exhibits. In 1887 Ada Pane, glassblower, dropped her pocket watch into a pot of molten glass and refused to apologise. The glass set, kept perfect time, and held one bubble that would not sit still. The bubble is your guide.',
    pip:'I was a bubble. Still am, really.'},
  {y:'1983',name:'GLACIO',era:'1983',title:'Glacio',
    text:'Before computers would have the bubble, it moonlighted inside a digital wristwatch. It learned to beep on the hour and to glow when someone pressed the little button. Water resistant to thirty metres. Never tested.',
    pip:'Beep beep. Tap the clock. Go on.'},
  {y:'1987',name:'PLATINUM',era:'1987',title:'The Desk Years',
    text:'Pane & Sons (there were no sons) licensed the bubble to a beige desk computer as its clock. Two colours and one job, done beautifully, asking for nothing except to be clicked now and then.',
    pip:'Black, and also white. Heady times.'},
  {y:'1997',name:'PAPERCLIP',era:'1997',title:'The Paperclip Incident',
    text:'A temp job helping people write letters. Help was offered four hundred times a day. The bubble was let go. Company policy ever since: offer three times, then stop. It is in the contract.',
    pip:'It looks like you\'re making a clock!', after:'…sorry. Old habits.'},
  {y:'1998',name:'DIAL-UP',era:'1998',title:'Dial-Up',
    text:'The bubble spent most of 1998 inside a modem and came back with a homepage, a visitor counter and a hard hat it refuses to take off. The page is still under construction.',
    pip:'Welcome to my homepage! It\'s under construction.'},
  {y:'2001',name:'GUMDROP',era:'2001',title:'The Gumdrop Years',
    text:'Computers went translucent, and so did the bubble. Everything was jelly. A whole year in tangerine, never fully explained.',
    pip:'Ooh, jelly. Please don\'t lick the screen.'},
  {y:'2002',name:'MEADOW',era:'2002',title:'Meadow',
    text:'An office job on a very green hill under a very blue sky. Everyone was friendly. Suspiciously friendly. Ears appeared, for reasons HR could not explain.',
    pip:'Green hills, blue sky. Suspiciously friendly.'},
  {y:'2004',name:'THE SHED',era:'2004',title:'The Shed',
    text:'During a quiet patch the bubble built a robot body in a garden shed, mostly from a toaster and some ambition. Brushed metal everywhere. The scuffs are original.',
    pip:'Built it myself. Don\'t ask about the crumbs.'},
  {y:'2007',name:'HALO GLASS',era:'2007',title:'Halo Glass',
    text:'Screens learned to look like real glass again: glossy, dark, glowing green at the edges. The bubble moved straight back in. Ada would have approved.',
    pip:'Glossy glass, a green glow. I was born for this.'},
  {y:String(new Date().getFullYear()),name:'TODAY',era:'today',title:'Today',
    text:'Home. Clear glass you can pinch, fling and stack. The bubble now lives on your clock and, per Ada\'s rule, is paid in tea: nobody argues after a cuppa.',
    pip:'Ahh. Glass again. The good kind.'}
];
const tmEl=$('#tm'), ledDest=$('#ledDest'), ledPres=$('#ledPres'), ledLast=$('#ledLast'), tmChips=$('#tmChips'), tmBody=$('#tmBodyEl'), warpEl=$('#warp');
const stops=()=>S.track==='story'?YEARS:STAGES;
const curIdx=()=>S.track==='story'?Math.max(0,YEARS.findIndex(y=>y.era===S.era)):(S.stageView||LATEST)-1;
const stopCode=(tr,i)=>tr==='story'?`${YEARS[i].y} ${YEARS[i].name}`:`STAGE ${STAGES[i].n} ${STAGES[i].name}`;
function syncLookBtn(){ const b=$('#lookBtn'); if(b) b.innerHTML=`Look <b>${LOOKNAME[S.era]}</b>`; }
function renderTM(){ syncLookBtn();
  if(!F('story')&&S.track==='story'){ S.track='build'; }
  const i=curIdx(), list=stops();
  tmEl.querySelectorAll('.tm-tabs button').forEach(b=>{ b.setAttribute('aria-pressed',b.dataset.t===S.track); b.disabled=b.dataset.t==='story'&&!F('story'); });
  ledDest.textContent=stopCode(S.track,i);
  const last=S.track==='story'?S.lastStory:S.lastBuild; ledLast.textContent=last==null?'– – –':stopCode(S.track,last);
  tmChips.innerHTML=list.map((s,k)=>`<button class="tm-chip" data-i="${k}" aria-pressed="${k===i}">${S.track==='story'?s.y:'Stage '+s.n}</button>`).join('');
  $('#tmPrev').disabled=i<=0; $('#tmNext').disabled=i>=list.length-1;
  tmEl.classList.toggle('min',S.tmMin); tmEl.classList.toggle('closed',!S.tmBody);
  $('#tmMin').setAttribute('aria-label',S.tmMin?'Expand time machine':'Collapse time machine'); $('#tmMin').textContent=S.tmMin?'+':'–';
  $('#tmBodyBtn').setAttribute('aria-expanded',S.tmBody);
  if(S.track==='story'){ const y=YEARS[i];
    tmBody.innerHTML=`<div class="plaque"><div class="pl-eyebrow">Pane &amp; Sons Visitor Experience · ${y.y}</div><h3>${y.title}</h3><p>${y.text}</p><p class="pl-fine">Entirely made up. Please do not lick the exhibits.</p></div>`;
  } else { const st=STAGES[i];
    const feats=FEATURES.filter(f=>f.stage===st.n);
    tmBody.innerHTML=`<div class="plaque"><div class="pl-eyebrow">Stage ${st.n}${st.n===LATEST?' · latest':''}</div><h3>${st.title}</h3><p>${st.text}</p>
      <div class="pills">${feats.map(f=>f.core?`<span class="fp core">${f.name}</span>`:`<button class="fp${st.n===LATEST?' new':''}" data-f="${f.id}" aria-pressed="${!S.off[f.id]}">${f.name}</button>`).join('')}</div>
      <p class="pl-fine">${st.n<LATEST?'Later stages are switched off while you\'re here. ':''}Tap a feature to switch just that one off.</p>
      <button class="fp tour" data-tour>Take the grand tour</button></div>`;
  }
  const tag=$('#stageTag'); tag.innerHTML=`Glass Sandbox <b>V2</b> · ${(S.stageView||LATEST)<LATEST?`visiting stage ${S.stageView}`:`stage ${BUILD}`}`;
  requestAnimationFrame(measureDock);
}
const dockH=()=>tmEl.offsetHeight+16;
function measureDock(){ const h=tmEl.offsetHeight+16; stage.style.setProperty('--dock-h',h+'px'); }
function travelTo(track,i){
  const cur=curIdx(); if(track===S.track&&i===cur) { S.tmBody=!S.tmBody; save(); renderTM(); return; }
  if(track===S.track){ if(track==='story') S.lastStory=cur; else S.lastBuild=cur; }
  if(track==='story'){ S.era=YEARS[i].era; } else { S.stageView=i+1===LATEST?null:i+1; }
  S.track=track; S.tmBody=true; save();
  if(F('warp')&&!simpler()){ warpEl.classList.remove('go'); void warpEl.offsetWidth; warpEl.classList.add('go'); N.squash=.3; }
  applyStageView(); renderTM();
  if(track==='build'&&S.naviOn&&!TOUR.active){ if(!N.awake) wake(); const st=STAGES[i], d=F('warp')&&!simpler()?450:0;
    setTimeout(()=>{ N.hopT=now(); setMood('happy',1800); say(st.pip,4200,null,0); },d); }
  if(track==='story'&&N.awake&&S.naviOn){ const y=YEARS[i], d=F('warp')&&!simpler()?450:0;
    setTimeout(()=>{ N.hopT=now(); say(y.pip,y.after?2400:2200,null,2); },d);
    if(y.after&&F('moments')) setTimeout(()=>{ if(S.era===y.era){ setMood('meh',1600); say(y.after,1800,null,2);} },d+2700); }
}
/* Apply what the current stage and era mean for everything else. */
/* Look = the era you live in. Same state as the Story track, picked without travelling. */
const LOOKNAME={today:'Today','1887':'Pane Original','1983':'Glacio','1987':'Platinum','1997':'Bevel 97','1998':'Dial-Up','2001':'Gumdrop','2002':'Meadow','2004':'Brushed','2007':'Halo Glass'};
const PREV={
  '1887':['radial-gradient(120% 90% at 50% 0%,#fbf3df,#cfb27a)','linear-gradient(#f1e3c0,#d6bb82)','#3a2a14','var(--f-serif)','1.5px solid #9a6a26','6px'],
  '1983':['radial-gradient(#34363a,#161719)','#a8b39a','#1b2117','"Share Tech Mono",monospace','4px solid #232427','9px'],
  '1987':['repeating-conic-gradient(#8a8a8a 0 25%,#d0d0d0 0 50%) 0 0/2px 2px','#fff','#000','Silkscreen,monospace','1.5px solid #000;box-shadow:2px 2px 0 #000','0'],
  '1997':['#008080','#000','#3cff3c','"Pixelify Sans",monospace','3px solid #c0c0c0','0'],
  '1998':['radial-gradient(1px 1px at 8px 9px,#fff 50%,transparent 52%) 0 0/22px 22px,#000018','#000','#ff0','"Comic Neue",cursive','3px ridge #c0c0c0','0'],
  '2001':['linear-gradient(160deg,#3c7bd8,#1c4fa8 55%,#5fa3f0)','linear-gradient(rgba(255,180,80,.95),rgba(255,120,0,.85))','#fff','inherit','1px solid #fff','16px'],
  '2002':['radial-gradient(140% 55% at 30% 112%,#5db534 0 44%,transparent 45%),linear-gradient(#2f6fe0,#b9d6f6)','#ece9d8','#0b3e8c','"Trebuchet MS",sans-serif','2px solid #0831d9;border-top-width:7px','4px 4px 0 0'],
  '2004':['radial-gradient(120% 90% at 50% 10%,#6f757e,#3a3e45)','linear-gradient(160deg,#eef1f4,#9aa1ab)','#2a3038','inherit','0','8px'],
  '2007':['radial-gradient(70% 30% at 35% 62%,rgba(80,240,140,.6),transparent 70%),linear-gradient(165deg,#021a12,#06303a,#010810)','linear-gradient(180deg,rgba(255,255,255,.3) 0 48%,rgba(20,48,52,.7) 49%)','#fff','inherit','1px solid rgba(255,255,255,.6);box-shadow:0 0 10px rgba(70,235,130,.6)','6px']
};
function lookPreview(k){
  if(k==='today'){ const v=BD[S.bd][resolved()]; return `<span class="lt-view" style="background:${v.bg}"><span class="lt-card" style="background:color-mix(in srgb, ${accent} 70%, transparent);color:${cardInk};border:1px solid rgba(255,255,255,.6);border-radius:9px">12:34</span></span>`; }
  const [sky,card,ink,font,border,rad]=PREV[k];
  return `<span class="lt-view" style="background:${sky}"><span class="lt-card" style="background:${card};color:${ink};font-family:${font};border:${border};border-radius:${rad}">12:34</span></span>`;
}
function setLook(k){
  if(k===S.era) return;
  const i=YEARS.findIndex(y=>y.era===k); S.lastStory=YEARS.findIndex(y=>y.era===S.era); S.era=k; save();
  applyStageView(); renderTM(); refreshPanels();
  if(N.awake&&S.naviOn){ N.hopT=now(); say(YEARS[i].pip,2000,null,2); }
}
function applyStageView(){
  ERAS.forEach(e=>stage.classList.remove('era-'+e));
  if(eraOn()) stage.classList.add('era-'+S.era);
  stage.classList.toggle('worlds',F('worlds')); applyForm(); applyFace();
  stage.classList.toggle('retro-motion',retroMotion()); stage.classList.toggle('remaster',S.remaster);
  applyLiquid();
  if(!F('care')&&careNeed){ careNeed=null; careEl.classList.remove('on'); }
  if(!F('pen')&&grounded()) stopFollow(true);
  refreshPanels();
}
const ERAS=['1887','1983','1987','1997','1998','2001','2002','2004','2007'];
const ERA_FORM={'1997':'clip','2004':'robot'};
const FORMS=[['orb','Orb'],['clip','Paperclip'],['robot','Robot'],['fairy','Fairy']];
const FACES=[['glass','Today','linear-gradient(160deg,#9cc0ff,#4f7be8)'],['1887','Pane Original','linear-gradient(#f1e3c0,#d6bb82)'],['1983','Glacio','#a8b39a'],['1987','Platinum','#fff'],
  ['1997','Bevel 97','#c0c0c0'],['1998','Dial-Up','linear-gradient(90deg,#f00,#ff0,#0f0,#0ff,#00f,#f0f)'],['2001','Gumdrop','linear-gradient(#ffb450,#ff7800)'],['2002','Meadow','linear-gradient(#0997ff 0 30%,#ece9d8 30%)'],['2004','Brushed','linear-gradient(160deg,#eef1f4,#9aa1ab)'],['2007','Halo Glass','linear-gradient(#5a8a80,#0c2a2e)']];
/* Liquid glass: Today only. Grounded keeps it tasteful; Liquid Max (Dream) lovingly overdoes it. */
const isLiquid=()=>F('material')&&(S.material==='liquid'||S.material==='both');
const canBreak=()=>!F('material')||S.material!=='liquid';
const LEGIB={1:'Beta 1',2:'Beta 2',3:'Beta 3',4:'Beta 4',5:'Beta 5',6:'Beta 6'};
const liquidOn=()=>F('liquid')&&!(eraOn()&&F('worlds'));
const liquidMax=()=>liquidOn()&&F('liquidmax')&&S.liquidMax&&(!grounded()||S.carry.liquid);
function applyLiquid(){
  stage.classList.toggle('liquid',liquidOn()); stage.classList.toggle('lmax',liquidMax()); stage.classList.toggle('carry-glow',S.carry.glow); stage.classList.toggle('liquidmat',isLiquid());
  stage.classList.toggle('lctl',liquidOn()&&F('liquidctl')); stage.classList.toggle('refresh',liquidOn()&&F('refresh'));
  stage.classList.toggle('eralight',F('eralight')&&S.remaster&&eraOn()&&F('worlds'));
  const k=(S.legib-1)/5;   /* Beta 1 → Beta 6: almost nothing → properly frosted */
  stage.style.setProperty('--lm',(.03+.42*k).toFixed(3)); stage.style.setProperty('--lb',(1+15*k).toFixed(1)+'px');
}
function retroMotion(){ return S.eraMotion&&eraOn()&&['1887','1983','1987','1997','1998'].includes(S.era); }
function eraOn(){ return F('eras')&&S.era!=='today'; }
function applyForm(){ const f=(eraOn()&&ERA_FORM[S.era])||(F('forms')?S.form:'orb'); FORMS.forEach(([k])=>navi.classList.toggle('form-'+k,k===f&&k!=='orb')); }
function applyFace(){ const show=F('faces')&&!(eraOn()&&F('worlds'))&&S.face!=='glass'; FACES.forEach(([k])=>card.classList.toggle('face-'+k,show&&k===S.face)); tick(); }
tmEl.addEventListener('pointerdown',e=>e.stopPropagation());
$('#lookBtn').addEventListener('click',()=>togglePanel('look'));
tmEl.addEventListener('click',e=>{
  const b=e.target.closest('button'); if(!b) return;
  if(b.dataset.t){ if(b.dataset.t!==S.track){ S.track=b.dataset.t; S.tmBody=true; save(); renderTM(); } return; }
  if(b.dataset.i!=null){ travelTo(S.track,+b.dataset.i); return; }
  if(b.dataset.tour!=null){ if(!N.awake) wake(); TOUR.started=true; TOUR.active=false; tourStart(true,true); return; }
  if(b.dataset.f){ const id=b.dataset.f; if(S.off[id]) delete S.off[id]; else S.off[id]=true; save(); applyStageView(); renderTM(); return; }
  if(b.id==='tmPrev') travelTo(S.track,curIdx()-1);
  else if(b.id==='tmNext') travelTo(S.track,curIdx()+1);
  else if(b.id==='tmMin_'){}
  else if(b.id==='tmMin'){ S.tmMin=!S.tmMin; save(); renderTM(); }
  else if(b.id==='tmBodyBtn'){ S.tmBody=!S.tmBody; save(); renderTM(); }
});
function presentTime(d){ document.getElementById('ledPres').textContent=`${d.toLocaleDateString('en-GB',{month:'short'}).toUpperCase()} ${String(d.getDate()).padStart(2,'0')} ${d.getFullYear()} ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`; }

/* =====================================================================
   7c. Crash → 404 → slingshot. Fling the clock hard into an edge and it
   cracks; twice and it shatters. Pip, tethered to the empty frame, gets
   pulled back and let go to collect the digit shards. Open panels are the walls.
   ===================================================================== */
const G={on:false,cracks:0,shards:[],t0:0,L:300,lastHit:0};
const shardsEl=$('#shards'), errEl=$('#err');
const cardCentre=()=>mid(cardRect());
function crack(){
  if(!F('fragile')||G.on) return; const t=now(); if(t-G.lastHit<350) return; G.lastHit=t;
  G.cracks++; cardIn.dataset.cracks=Math.min(2,G.cracks);
  if(!simpler()&&cardIn.animate) cardIn.animate([{translate:'0 0'},{translate:'-5px 2px'},{translate:'4px -2px'},{translate:'0 0'}],{duration:220});
  if(S.sound&&F('shatter')) shatterSound(G.cracks>=2?2600:900); else beep([[220,70]]);
  if(G.cracks>=2) setTimeout(crash,200);
  else if(N.awake&&S.naviOn){ N.lookPt=cardCentre(); N.lookUntil=t+1500; say(pick(['Careful! That\'s glass.','Ooh. That cracked.','Easy with the clock.']),1400,null,1); }
}
function crash(){
  if(G.on||!F('game')) return;
  const d=new Date(), h=S.h24?String(d.getHours()).padStart(2,'0'):String(d.getHours()%12||12), digits=h+String(d.getMinutes()).padStart(2,'0');
  G.on=true; G.t0=now(); G.cracks=2; cardIn.dataset.cracks=2; exitEdit(); C.tvx=C.tvy=0;
  card.classList.add('broken'); errEl.hidden=false;
  if(!simpler()&&cardIn.animate) cardIn.animate([{scale:1.06},{scale:.96},{scale:1}],{duration:320});
  const c=cardCentre(), W=stage.clientWidth, H=stage.clientHeight-dockH();
  G.L=Math.max(170,Math.min(W,H)*.46);
  const blocks=openEls().map(rel).concat([rel(rail),cardRect()]);
  shardsEl.innerHTML='';
  G.shards=[...digits].map(ch=>{ let x,y,k=0;
    do{ const a=Math.random()*Math.PI*2, r=G.L*(.5+Math.random()*.42); x=c.x+Math.cos(a)*r; y=c.y+Math.sin(a)*r; k++; }
    while(k<80&&(x<26||x>W-26||y<84||y>H-14||blocks.some(b=>x>b.left-24&&x<b.right+24&&y>b.top-24&&y<b.bottom+24)));
    const el=document.createElement('span'); el.className='shard'; el.textContent=ch; el.setAttribute('aria-hidden','true');
    el.style.transform=`translate(${c.x-18}px,${c.y-18}px)`; shardsEl.appendChild(el);
    requestAnimationFrame(()=>requestAnimationFrame(()=>{ el.style.transform=`translate(${x-18}px,${y-18}px) rotate(${Math.round((Math.random()-.5)*50)}deg)`; }));
    return {x,y,el,got:false}; });
  if(S.naviOn){ N.awake=true; hint.classList.add('off'); N.mood=''; N.pat=1; N.drink=null; sipEl.hidden=true; endPet(true); stopFollow(true);
    N.back=false; N.state='free'; N.x=c.x; N.y=cardRect().top-N.r-6; N.vx=0; N.vy=-80; if(TOUR.active&&!TOUR.grand) tourEnd(false); if(OFFER.pending) OFFER.pending=null;
    if(!TOUR.active) setTimeout(()=>say('404! The time\'s gone everywhere. Pull me back and let go.',3400,null,0),550); }
}
function collectCheck(){
  G.shards.forEach(s=>{ if(s.got||Math.hypot(N.x-s.x,N.y-s.y)>N.r+18) return;
    s.got=true; const c=cardCentre(), n=G.shards.filter(q=>q.got).length, left=G.shards.length-n;
    s.el.classList.add('got'); s.el.style.transform=`translate(${c.x-18}px,${c.y-18}px) scale(.4)`; N.hopT=now(); beep([[1046+n*180,70]]);
    if(left) say(left===1?'One more!':pick(['Got one!','Nice shot.','Another!']),900,null,2); else setTimeout(()=>restore(false),550); });
}
function restore(skipped){
  if(!G.on) return; const secs=Math.round((now()-G.t0)/1000);
  G.on=false; G.cracks=0; delete cardIn.dataset.cracks; card.classList.remove('broken'); errEl.hidden=true; shardsEl.innerHTML='';
  ctx.setTransform(1,0,0,1,0,0); ctx.clearRect(0,0,canvas.width,canvas.height); tick();
  if(!simpler()&&cardIn.animate) cardIn.animate([{scale:.86,filter:'brightness(1.7)'},{scale:1,filter:'brightness(1)'}],{duration:520,easing:'cubic-bezier(.2,1.4,.4,1)'});
  beep([[1318,80],[1568,80],[2093,140]]);
  if(S.naviOn&&!TOUR.active){ setMood('happy',2200); say(skipped?'Fixed. No harm done.':`Good as new. ${secs} seconds.`,2400,null,0); goHomeSoon(1500); }
}
$('#errSkip').addEventListener('pointerdown',e=>e.stopPropagation());
$('#errSkip').addEventListener('click',()=>restore(true));
/* the clock can be flung; hitting an edge hard enough cracks it */
function cardFling(dt){
  if(!C.tvx&&!C.tvy) return;
  const W=stage.clientWidth, H=stage.clientHeight-dockH(), c=cardRect(), hw=c.width/2, hh=c.height/2, k=Math.exp(-2.2*dt);
  C.x+=C.tvx*dt; C.y+=C.tvy*dt; C.tvx*=k; C.tvy*=k;
  const edge=(sp,nx,ny)=>{ if(sp>300&&isLiquid()){ const r=cardRect(); splash(cardIn,nx>0?0:nx<0?r.width:r.width/2,ny>0?0:ny<0?r.height:r.height/2,sp,nx,ny); }
    if(sp>1000&&canBreak()) crack(); else if(sp>300&&!simpler()&&!isLiquid()) beep([[120,30]]); };
  if(C.x<hw+6){C.x=hw+6; if(C.tvx<0){edge(-C.tvx,1,0); C.tvx=-C.tvx*.45;}}
  if(C.x>W-hw-6){C.x=W-hw-6; if(C.tvx>0){edge(C.tvx,-1,0); C.tvx=-C.tvx*.45;}}
  if(C.y<hh+70){C.y=hh+70; if(C.tvy<0){edge(-C.tvy,0,1); C.tvy=-C.tvy*.45;}}
  if(C.y>H-hh-6){C.y=H-hh-6; if(C.tvy>0){edge(C.tvy,0,-1); C.tvy=-C.tvy*.45;}}
  if(Math.hypot(C.tvx,C.tvy)<20){ C.tvx=C.tvy=0; saveLayout(); }
  setCard();
}
function drawGame(g,calm){
  if(!G.on) return;
  if(g||calm||!S.naviOn){ ctx.setTransform(dpr,0,0,dpr,0,0); ctx.clearRect(0,0,stage.clientWidth,stage.clientHeight); }
  const c=cardCentre(), d=Math.hypot(N.x-c.x,N.y-c.y);
  ctx.strokeStyle=accent; ctx.lineWidth=1.5;
  ctx.globalAlpha=.14; ctx.beginPath(); ctx.arc(c.x,c.y,G.L,0,Math.PI*2); ctx.stroke();
  if(S.naviOn){ ctx.globalAlpha=.6; ctx.setLineDash([4,5]); ctx.beginPath(); ctx.moveTo(c.x,c.y);
    ctx.quadraticCurveTo((c.x+N.x)/2,(c.y+N.y)/2+Math.max(0,G.L-d)*.22,N.x,N.y); ctx.stroke(); ctx.setLineDash([]); }
  if(grab&&grab.sling){ const o=grab.sling;
    ctx.globalAlpha=.95; ctx.strokeStyle='#ffffff'; ctx.lineWidth=3; ctx.beginPath(); ctx.moveTo(o.x-10,o.y); ctx.lineTo(N.x,N.y); ctx.lineTo(o.x+10,o.y); ctx.stroke();
    ctx.globalAlpha=.55; ctx.lineWidth=2; ctx.setLineDash([2,7]); ctx.beginPath(); ctx.moveTo(o.x,o.y); ctx.lineTo(o.x+(o.x-N.x)*1.8,o.y+(o.y-N.y)*1.8); ctx.stroke(); ctx.setLineDash([]); }
  ctx.globalAlpha=1;
}

/* =====================================================================
   8. Top bar + effects
   ===================================================================== */
const naviSw=$('#naviSw');
function applyEffects(){ stage.classList.toggle('simpler',simpler()); stage.classList.toggle('clear',S.clear); stage.classList.toggle('outlines',S.outlines);
  if(simpler()) ctx.clearRect(0,0,canvas.width,canvas.height); refreshPanels(); }
function setMode(m,quiet){
  S.mode=m; save(); stage.classList.toggle('dream',m==='dream');
  $('#mGround').setAttribute('aria-pressed',m==='grounded'); $('#mDream').setAttribute('aria-pressed',m==='dream');
  N.r=m==='dream'?15:12;
  if(m==='dream'){ if(N.state==='sleep'||N.state==='perch'){ N.awake=true; N.state='free'; N.vy=-220; N.vx=60; N.nextWander=now()+2500; setMood('happy',1200);} hint.classList.add('off'); }
  else { stopFollow(true); openEls().forEach(p=>{ p.style.setProperty('--la',0); p._g=null; }); if(!quiet) setTimeout(offerCarry,700); }
  ctx.clearRect(0,0,canvas.width,canvas.height); trail.length=0; if(typeof applyLiquid==='function') applyLiquid();
  if(!quiet) toast(m==='grounded'?'Grounded: what the real app could ship':'Dream: what it could be if we went all in');
}
$('#mGround').addEventListener('click',()=>setMode('grounded')); liquidSeg($('#mGround').parentElement);
$('#mDream').addEventListener('click',()=>setMode('dream'));
function setNavi(on,quiet){
  S.naviOn=on; save(); naviSw.checked=on;
  if(!on){ askEl.hidden=true; if(!quiet) say(pick(['See you later.','Was it something I said?','Oh. Okay. Bye for now.']),1100,null,1); setTimeout(()=>{ if(!S.naviOn){navi.classList.add('gone'); bubble.classList.remove('on');} },quiet?0:700); navi.setAttribute('aria-hidden','true'); navi.tabIndex=-1; hint.classList.add('off'); }
  else { navi.classList.remove('gone'); navi.removeAttribute('aria-hidden'); navi.tabIndex=0; N.mood='';
    if(quiet) return;
    if(grounded()){ N.awake=true; N.perchF=.82; const p=perchPoint(); N.x=p.x; N.y=p.y; N.state='perch'; }
    else { const c=cardRect(); N.x=c.left+c.width/2; N.y=c.top-60; N.state='free'; N.awake=true; }
    setMood('happy',1200); setTimeout(()=>say(pick(['Back again. I\'ll be good.','Oh! You kept me.','Hello again.']),1500,null,1),250); }
}
naviSw.addEventListener('change',e=>setNavi(e.target.checked));
