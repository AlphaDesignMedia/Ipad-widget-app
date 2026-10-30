/* =====================================================================
   9. Physics
   ===================================================================== */
function colliders(){
  const out=[];
  if(rail.offsetParent) out.push({rc:rel(rail),kind:'rail'});
  openEls().forEach(p=>out.push({rc:rel(p),kind:'panel',el:p}));
  out.push({rc:cardRect(),kind:'card'});
  if(!tmEl.hidden) out.push({rc:rel(tmEl),kind:'rail'});
  return out;
}
function hit(speed,nx,ny,kind,t){
  const g=grounded();
  N.squash=Math.min(g?.16:.32, speed/(g?4200:2600));
  if(speed>1150){ N.dizzyUntil=t+1300; N.pat=Math.max(0,N.pat-.06); N.hard=N.hard.filter(x=>t-x<12000); N.hard.push(t); if(N.hard.length>=2) N.tiredUntil=t+30000;
    if(N.hard.length>=3){ N.hard=[]; say('Three is plenty. I\'ll sit for a bit.',2200,null,1); setTimeout(()=>{ if(N.state==='free'){ if(g) goPerch(); else restOnRail(); } },900); } }
  if(!g){
    if(kind==='rail'&&!simpler()){rail.classList.remove('bump'); void rail.offsetWidth; rail.classList.add('bump');}
    if(kind==='card'){C.vx-=nx*Math.min(speed,1600)*.18; C.vy-=ny*Math.min(speed,1600)*.18;}
  }
}
function collide(rc,kind,el,t){
  const cx=clamp(N.x,rc.left,rc.right), cy=clamp(N.y,rc.top,rc.bottom);
  let dx=N.x-cx, dy=N.y-cy, d=Math.hypot(dx,dy), nx, ny, pen;
  if(d>=N.r) return;
  if(d>.001){nx=dx/d; ny=dy/d; pen=N.r-d;}
  else { const l=N.x-rc.left, r=rc.right-N.x, tp=N.y-rc.top, b=rc.bottom-N.y, m=Math.min(l,r,tp,b);
    if(m===l){nx=-1;ny=0;pen=l+N.r} else if(m===r){nx=1;ny=0;pen=r+N.r} else if(m===tp){nx=0;ny=-1;pen=tp+N.r} else {nx=0;ny=1;pen=b+N.r} }
  N.x+=nx*pen; N.y+=ny*pen;
  if(el&&pv[el.id]){N.vx+=pv[el.id].x*.08; N.vy+=pv[el.id].y*.08;}
  const vn=N.vx*nx+N.vy*ny;
  if(vn<0){ const e=grounded()?.55:.78; N.vx-=(1+e)*vn*nx; N.vy-=(1+e)*vn*ny; N.vx*=.97; N.vy*=.97; if(-vn>120) hit(-vn,nx,ny,kind,t); }
}
function restOnRail(){ const r=rel(rail), e=rail.dataset.edge;
  if(e==='left'||e==='right') travel(r.left+r.width/2, r.top-N.r+2, 220,'free');
  else if(e==='top') travel(r.left+r.width*(.2+Math.random()*.6), r.bottom+N.r+2, 220,'free');
  else travel(r.left+r.width*(.2+Math.random()*.6), r.top-N.r+2, 220,'free');
}
function wander(t){
  N.nextWander=t+(5000+Math.random()*5000)/persona().bounce;
  const roll=Math.random(), W=stage.clientWidth, H=stage.clientHeight, open=openEls();
  if(roll<.35) restOnRail();
  else if(roll<.6&&open.length){ const r=rel(pick(open)); travel(r.left+r.width*(.3+Math.random()*.4), r.top+r.height*(.25+Math.random()*.5), 140,'free'); }
  else travel(clamp(W*(.2+Math.random()*.6),N.r+20,W-N.r-20), clamp(H*(.25+Math.random()*.6),110,H-N.r-20), 160,'free');
}

let coverT=0;
function update(dt,t){
  const W=stage.clientWidth, H=stage.clientHeight, g=grounded();
  if(N.mood==='sulk'&&t>N.sulkUntil) endSulk();
  if(N.mood!=='sulk'&&!N.pet) N.pat=Math.min(1,N.pat+dt*.05);
  if(N.drink){ N.vx=N.vy=0; if(t>N.drink.until) finishDrink(); }
  petTick(t);
  if(CT){ const k=Math.min(1,(t-CT.t0)/520), e=1-Math.pow(1-k,3); C.x=CT.fx+(CT.x-CT.fx)*e; C.y=CT.fy+(CT.y-CT.fy)*e; setCard(); if(k>=1){CT=null; saveLayout();} }
  if(t-coverT>400){ coverT=t; const c=cardRect(), area=c.width*c.height;
    const cov=openEls().map(rel).reduce((o,b)=>o+Math.max(0,Math.min(c.right,b.right)-Math.max(c.left,b.left))*Math.max(0,Math.min(c.bottom,b.bottom)-Math.max(c.top,b.top)),0)/area;
    if(cov>.35){ if(!OB.coverSince) OB.coverSince=t; } else OB.coverSince=0; }
  checkNotices(t); idleLife(t); checkIn(t);
  if(N.state==='sleep'||N.state==='perch'){ const p=perchPoint(); N.x=p.x; N.y=p.y; N.vx=N.vy=0; }
  else if(N.state==='travel'){
    if(N.perchTrack){const p=perchPoint(); N.tx=p.x; N.ty=p.y;}
    const dx=N.tx-N.x, dy=N.ty-N.y, d=Math.hypot(dx,dy);
    if(d<3){ N.x=N.tx; N.y=N.ty; N.vx=N.vy=0; N.state=N.after; N.still=0; const f=N.onArrive; N.onArrive=null; f&&f(); }
    else { const sp=Math.min(N.tsp,3*d+50); N.vx=dx/d*sp; N.vy=dy/d*sp; N.x+=N.vx*dt; N.y+=N.vy*dt; }
  }
  else if(N.state==='follow'){
    if(N.followPen&&t-P.t>1500) stopFollow(true);
    else if(!N.followPen&&t-P.t>9000) stopFollow();
    else {
      const tx=clamp(P.x-(g?38:30),N.r,W-N.r), ty=clamp(P.y-(g?40:34),N.r+50,H-N.r), sp=g?11:16;
      N.vx+=(tx-N.x)*sp*dt; N.vy+=(ty-N.y)*sp*dt; const k=Math.exp(-(g?8:7)*dt); N.vx*=k; N.vy*=k;
      N.x+=N.vx*dt; N.y+=N.vy*dt;
      if(g) colliders().forEach(c=>collide(c.rc,c.kind,c.el,t));
    }
  }
  else if(N.state==='free'){
    const k=Math.exp(-(g?2.2:1.1)*dt); N.vx*=k; N.vy*=k;
    N.x+=N.vx*dt; N.y+=N.vy*dt;
    const e=g?.55:.78;
    if(N.x<N.r){N.x=N.r; if(N.vx<0){if(-N.vx>120) hit(-N.vx,1,0,'wall',t); N.vx=-N.vx*e;}}
    if(N.x>W-N.r){N.x=W-N.r; if(N.vx>0){if(N.vx>120) hit(N.vx,-1,0,'wall',t); N.vx=-N.vx*e;}}
    if(N.y<N.r){N.y=N.r; if(N.vy<0){if(-N.vy>120) hit(-N.vy,0,1,'wall',t); N.vy=-N.vy*e;}}
    if(N.y>H-N.r){N.y=H-N.r; if(N.vy>0){if(N.vy>120) hit(N.vy,0,-1,'wall',t); N.vy=-N.vy*e;}}
    colliders().forEach(c=>{ if(G.on||(g&&!N.back)||c.kind!=='panel') collide(c.rc,c.kind,c.el,t); });
    const sp=Math.hypot(N.vx,N.vy);
    N.still = sp<24 ? N.still+dt : 0;
    if(g && !S.carry.roam && !G.on && N.still>.6 && N.mood!=='sulk'){ const c=cardRect(); if(N.x>c.left-24&&N.x<c.right+24&&N.y<c.top+6&&N.y>c.top-150) goPerch(); }
    if((!g||S.carry.roam) && !G.on && N.still>1 && N.awake && N.mood!=='sulk' && t>N.nextWander && t-N.lastInteract>3500) wander(t);
  }
  cardFling(dt); panelFling(dt);
  if(G.on&&S.naviOn&&N.state==='free'){ const c=cardCentre(), dx=N.x-c.x, dy=N.y-c.y, d=Math.hypot(dx,dy)||1;
    if(d>G.L){ N.x=c.x+dx/d*G.L; N.y=c.y+dy/d*G.L; const vn=(N.vx*dx+N.vy*dy)/d; if(vn>0){ N.vx-=1.6*vn*dx/d; N.vy-=1.6*vn*dy/d; } }
    collectCheck(); }
  /* card spring (Dream bumps) */
  C.vx+=(-170*C.jx-12*C.vx)*dt; C.vy+=(-170*C.jy-12*C.vy)*dt; C.jx+=C.vx*dt; C.jy+=C.vy*dt;
  if(Math.abs(C.jx)+Math.abs(C.jy)+Math.abs(C.vx)+Math.abs(C.vy)>.05) setCard(); else if(C.jx||C.jy){C.jx=C.jy=C.vx=C.vy=0; setCard();}
}

/* =====================================================================
   10. Render
   ===================================================================== */
const trail=[]; let dpr=1;
function sizeCanvas(){dpr=Math.min(2,window.devicePixelRatio||1); canvas.width=stage.clientWidth*dpr; canvas.height=stage.clientHeight*dpr; canvas.style.width=stage.clientWidth+'px'; canvas.style.height=stage.clientHeight+'px';}
/* Only touch a panel's glow when it visibly changes: style writes on blurred glass are expensive. */
function setGlow(p,x,y,a){ const g=p._g||(p._g={x:-1e4,y:-1e4,a:-1});
  if(a<.01&&g.a<.01) return; if(Math.abs(g.a-a)<.02&&Math.abs(g.x-x)<1.5&&Math.abs(g.y-y)<1.5) return;
  g.x=x; g.y=y; g.a=a; p.style.setProperty('--lx',x.toFixed(0)+'px'); p.style.setProperty('--ly',y.toFixed(0)+'px'); p.style.setProperty('--la',a.toFixed(2)); }
let specT=0, specP=0, lastTx=0,lastTy=0,lastLabel='',liveT=0;
function render(dt,t){
  const g=grounded(), sp=Math.hypot(N.vx,N.vy), calm=simpler()||retroMotion();
  navi.style.setProperty('--nd',(N.r*2)+'px');
  let bob=0; if(!calm&&(N.state==='free'||N.state==='perch'||N.state==='sleep')&&sp<40) bob=Math.sin(t/(N.state==='sleep'?900:520/persona().bounce))*(N.state==='sleep'?1:2.2*persona().bounce);
  let hop=0; const hp=(t-N.hopT)/380; if(hp<1&&(N.state==='perch'||N.state==='free')) hop=-Math.sin(hp*Math.PI)*(calm?4:10*persona().bounce);
  const shake=(!calm&&N.pat<.45&&N.mood!=='sulk'&&t-N.hopT<380)?Math.sin(t/22)*2.2:0;
  navi.style.transform=`translate(${N.x-N.r+shake}px,${N.y-N.r+bob+hop}px)`;
  let s=0; if(!calm){ s=Math.min(g?.12:.3, sp/(g?3800:2200))+N.squash; } N.squash*=Math.exp(-9*dt);
  const a=Math.atan2(N.vy,N.vx);
  const tilt=N.mood==='sulk'?(N.x<stage.clientWidth/2?-12:12):0;
  const puff=(t-N.puffT<320&&!calm)?1+.14*Math.sin((t-N.puffT)/320*Math.PI):1;
  nb.style.transform=`rotate(${tilt+N.lean}deg) rotate(${a}rad) scale(${(1+s)*puff},${(1-s*.8)*puff}) rotate(${-a}rad)`;
  /* eyes */
  let lp=null; if(t<N.lookUntil&&N.lookPt) lp=N.lookPt; else if(t-P.t<2500) lp=P; else lp={x:N.x+N.vx*.3,y:N.y+N.vy*.3+1};
  const dx=lp.x-N.x, dy=lp.y-N.y, d=Math.hypot(dx,dy)||1, m=Math.min(1,d/90)*N.r*.24;
  let ex=dx/d*m, ey=dy/d*m; if(N.mood==='sulk'){ex=(N.x<stage.clientWidth/2?-1:1)*N.r*.26; ey=N.r*.08;}
  navi.style.setProperty('--ex',ex.toFixed(2)+'px'); navi.style.setProperty('--ey',ey.toFixed(2)+'px');
  /* mood classes */
  if(t>N.blinkAt){N.blinkAt=t+2600+Math.random()*3200; navi.classList.add('blink'); setTimeout(()=>navi.classList.remove('blink'),130);}
  let mood=''; if(t<N.dizzyUntil) mood='dizzy'; else if(N.state==='sleep') mood='sleep'; else if(N.state==='held') mood='held';
  else if(N.mood==='sulk') mood='sulk'; else if(N.drink||N.pet&&N.pet.chance===0) mood='happy'; else if(N.pat<.45) mood='annoyed';
  else if(N.mood&&t<N.moodUntil) mood=N.mood; else if(N.pat<.72) mood='meh';
  /* depth: Dream floats behind glass unless you're handling them; Grounded only hides or peeks */
  if(!g) N.back=!(TOUR.active||ASK.open||N.state==='held'||N.state==='follow'||N.state==='perch'||N.state==='sleep'||N.pet||N.drink);
  else if(N.state==='held'||N.state==='perch'||N.state==='follow'||N.state==='sleep') N.back=false;
  navi.classList.toggle('back',N.back);
  { const gh=$('#ghost'), behind=N.back&&S.naviOn&&openEls().some(p=>{const r=rel(p); return N.x>r.left+4&&N.x<r.right-4&&N.y>r.top+4&&N.y<r.bottom-4;});
    gh.classList.toggle('on',behind); if(behind){ gh.style.setProperty("--nd",(N.r*2.4)+"px"); gh.style.transform=`translate(${N.x-N.r*1.2}px,${N.y-N.r*1.2}px)`; } }
  /* care spot: one thing at a time */
  const need=needNow(t);
  if(need!==careNeed){ careNeed=need; careEl.classList.toggle('on',!!need); careEl.tabIndex=need?0:-1; careEl.setAttribute('aria-hidden',need?'false':'true');
    if(need){ careItem.innerHTML=CARE[need].svg; careEl.setAttribute('aria-label',`Give ${S.name} ${CARE[need].say}. Tap, or drag it to ${S.name}.`); } }
  if(careNeed||careEl.classList.contains('on')){ const cc=careCentre(); careEl.style.transform=`translate(${cc.x-22}px,${cc.y-22}px)`; }
  if(N.drink) sipEl.style.transform=`translate(${N.x+N.r*.15}px,${N.y+N.r*.25}px)`;
  ['dizzy','sleep','held','sulk','happy','meh','annoyed'].forEach(c=>navi.classList.toggle(c,c===mood));
  const label=N.state==='sleep'?`${S.name}, asleep on the clock. Press to wake.`:`${S.name}${mood?', '+({meh:'a bit put out',sulk:'sulking',held:'being held'}[mood]||mood):''}. Drag to flick. Hold to have ${S.name} follow you.`;
  if(label!==lastLabel){lastLabel=label; navi.setAttribute('aria-label',label);}
  if(!askEl.hidden){ const aw=askEl.offsetWidth, ah=askEl.offsetHeight, W=stage.clientWidth;
    const ax=clamp(N.x-aw/2,10,W-aw-10); let ay=N.y-N.r-ah-14; if(ay<64) ay=N.y+N.r+16;
    if(!askEl._p||Math.hypot(ax-askEl._p[0],ay-askEl._p[1])>14){ askEl._p=[ax,ay]; askEl.style.transform=`translate(${ax}px,${ay}px)`; } }
  else askEl._p=null;
  /* bubble */
  if(bubbleOn){ const bw=bubble.offsetWidth, bh=bubble.offsetHeight, W=stage.clientWidth;
    const bx=clamp(N.x-bw/2,10,W-bw-10); let by=N.y-N.r-bh-12+bob+hop; if(by<70) by=N.y+N.r+14;
    bubble.style.transform=`translate(${bx}px,${by}px)`; }
  /* Dream extras: light pool and glass glow */
  if(g&&S.carry.glow&&S.naviOn) pool.style.transform=`translate(${N.x-210}px,${N.y-210}px)`;
  if(!g&&S.naviOn){
    pool.style.transform=`translate(${N.x-210}px,${N.y-210}px)`;
    openEls().forEach(p=>{ const r=rel(p);
      const cx=clamp(N.x,r.left,r.right), cy=clamp(N.y,r.top,r.bottom), dd=Math.hypot(N.x-cx,N.y-cy);
      setGlow(p,N.x-r.left,N.y-r.top,dd===0?1:clamp(1-dd/230,0,1)); });
  } else if(g&&S.naviOn){ /* Grounded: the glass only glows where they're hiding */
    openEls().forEach(p=>{ const r=rel(p), inside=N.back&&N.x>r.left&&N.x<r.right&&N.y>r.top&&N.y<r.bottom;
      setGlow(p,N.x-r.left,N.y-r.top,inside?.85:0); });
  } else if(!S.naviOn) openEls().forEach(p=>p.style.setProperty('--la',0));
  /* trail */
  if(!g&&!calm&&S.naviOn){
    if(Math.hypot(N.x-lastTx,N.y-lastTy)>2.5){ trail.push({x:N.x,y:N.y,l:1,k:0}); lastTx=N.x; lastTy=N.y;
      if(sp>260&&Math.random()<.35) trail.push({x:N.x+(Math.random()-.5)*N.r,y:N.y+(Math.random()-.5)*N.r,l:1,k:1,vx:(Math.random()-.5)*40,vy:(Math.random()-.5)*40-20,s:2+Math.random()*2.5}); }
    ctx.setTransform(dpr,0,0,dpr,0,0); ctx.clearRect(0,0,canvas.width,canvas.height);
    for(let i=trail.length-1;i>=0;i--){ const p=trail[i]; p.l-=dt*(p.k?1.4:2.4); if(p.l<=0){trail.splice(i,1); continue;}
      ctx.globalAlpha=(p.k?.9:.28)*p.l; ctx.fillStyle=p.k?'#ffffff':accent;
      if(p.k){ p.x+=p.vx*dt; p.y+=p.vy*dt; const r=p.s*p.l; ctx.beginPath(); ctx.moveTo(p.x,p.y-r*1.6); ctx.lineTo(p.x+r*.4,p.y-r*.4); ctx.lineTo(p.x+r*1.6,p.y); ctx.lineTo(p.x+r*.4,p.y+r*.4); ctx.lineTo(p.x,p.y+r*1.6); ctx.lineTo(p.x-r*.4,p.y+r*.4); ctx.lineTo(p.x-r*1.6,p.y); ctx.lineTo(p.x-r*.4,p.y-r*.4); ctx.closePath(); ctx.fill(); }
      else { ctx.beginPath(); ctx.arc(p.x,p.y,N.r*.75*p.l,0,Math.PI*2); ctx.fill(); } }
    ctx.globalAlpha=1;
  }
  drawGame(g,calm);
  if((stage.classList.contains('liquid')||stage.classList.contains('eralight'))&&t-specT>50&&P.t!==specP){ specT=t; specP=P.t;
    [...openEls(),rail,cardIn].forEach(el=>{ const r=rel(el), near=P.x>r.left-140&&P.x<r.right+140&&P.y>r.top-140&&P.y<r.bottom+140;
      if(near||el._sp){ el._sp=near; el.style.setProperty('--sx',(near?P.x-r.left:-500)+'px'); el.style.setProperty('--sy',(near?P.y-r.top:-500)+'px'); } }); }
  /* live panels */
  if(t-liveT>250){ liveT=t; zOrder.forEach(id=>PANELS[id].tick?.(PS[id].el)); }
}

let last=now();
const FPS={n:0,t0:0,v:0};
function frame(t){ const dt=Math.min(.033,(t-last)/1000); last=t; FPS.n++; if(t-FPS.t0>1000){ FPS.v=Math.round(FPS.n*1000/(t-FPS.t0)); FPS.n=0; FPS.t0=t; } RC.clear(); SR=stage.getBoundingClientRect();
  if(S.naviOn) update(dt,t); render(dt,t); requestAnimationFrame(frame); }

/* =====================================================================
   11. Layout + boot
   ===================================================================== */
function layout(first){
  SR=stage.getBoundingClientRect(); sizeCanvas();
  const W=stage.clientWidth, H=stage.clientHeight, wide=W>=760;
  const tb=document.querySelector('.topbar').getBoundingClientRect();
  stage.style.setProperty('--rail-top',(tb.bottom-SR.top+12)+'px');
  if(first){
    const saved=first==='restore'?store.get('layout',null):null;
    if(saved){
      if(saved.rail) rail.dataset.edge=saved.rail;
      (saved.panels||[]).forEach(p=>{ if(PANELS[p.id]) openPanel(p.id,{at:{x:p.x,y:p.y,dock:p.dock},quiet:true}); });
      if(saved.card){C.x=clamp(saved.card.x,40,W-40); C.y=clamp(saved.card.y,90,H-40); C.s=clamp(saved.card.s||1,.6,1.7);}
      else centreCard();
    } else {
      rail.dataset.edge='left'; C.s=1;
      if(wide) openPanel('clock',{quiet:true});
      centreCard();
    }
    setCard();
  } else {
    C.x=clamp(C.x,40,W-40); C.y=clamp(C.y,90,H-40); setCard();
    openEls().forEach(clampPanel);
    N.x=clamp(N.x,N.r,W-N.r); N.y=clamp(N.y,N.r,H-N.r);
  }
}
function centreCard(){
  const W=stage.clientWidth, H=stage.clientHeight, rr=rel(rail);
  const left=rail.dataset.edge==='left'?rr.right:0, tops=openEls().filter(e=>!e.classList.contains('child'));
  const right=W>=760&&tops.length?Math.min(...tops.map(e=>parseFloat(e.style.left))):W;
  C.x=Math.round((left+right)/2); C.y=Math.round(Math.max(170,(H-dockH())*.52));
}
addEventListener('resize',()=>layout(false));

if(store.get('prefs',{}).tmMin==null&&stage.clientWidth<520) S.tmMin=true;   // phones start with the dial folded
applyNames(); applyTheme(); applyClock(); applyEffects(); nameChanged(); renderTM(); applyStageView(); presentTime(new Date());
new ResizeObserver(measureDock).observe(tmEl);
setMode(S.mode,true); setNavi(S.naviOn,true);
requestAnimationFrame(()=>{
  layout('restore');
  const p=perchPoint(); N.x=p.x; N.y=p.y; N.lastInteract=now();
  if(!grounded()){ N.awake=true; N.state='free'; N.y-=40; if(store.get('seen',0)<LATEST) setTimeout(()=>tourStart(false),2500); }
  if(!S.naviOn) hint.classList.add('off');
  requestAnimationFrame(frame);
});
