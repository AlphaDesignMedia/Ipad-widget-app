/* =====================================================================
  SKETCH · plugin v1   (Dream shelf)
  Loaded by the sandbox loader (see PLUGINS in index.html). Where: ✏️ in the plugin bar.
  - A drawing page over the sandbox, made for Apple Pencil: pressure, tilt-free smooth ink,
    every in-between point (coalesced events), and palm rejection once the Pencil is seen.
  - Pen, marker, highlighter, eraser; colours; size; undo; clear; paper or see-through glass.
  - Pip watches your pen, reacts to what you draw (circles, scribbles, drawing on Pip…).
  - 📋 Whiteboard (paper or see-through) or 🖋️ Ink layer: the Pencil draws over everything while
    your fingers keep using the app (needs ✍️ Pencil-only, which switches on when it sees a Pencil).
  - Pages (‹ 1 / 3 ›, + for a new one). Synced between the Mac and the iPad via the sandbox database.
  - 📸 saves a PNG (Pip sneaks into the corner). The last few stay as thumbnails on this device.
  Ink shapes come from perfect-freehand (free, MIT, loaded from esm.sh). Offline it falls back
  to plain round lines.
  Switch it off in the Plugins panel, or remove it from PLUGINS.
  ===================================================================== */
(() => {
const H=window.PipHost;
if(!H||!H.registerPlugin){ console.warn('Sketch: needs PipHost (host.js).'); return; }
const {N,S,stage,navi}=H;
if(!H.registerPlugin({id:'sketch',name:'Sketch',icon:'✏️',shelf:'dream',desc:'Draw with Apple Pencil; Pip watches, reacts and photobombs your snapshots.'})) return;
/*PB*/
let PF=null; import('https://esm.sh/perfect-freehand@1.2.2').then(m=>{ PF=m.getStroke||m.default; }).catch(()=>{});

const css=document.createElement('style'); css.textContent=`
.sk{position:absolute;inset:0;z-index:28;touch-action:none;-webkit-user-select:none;user-select:none}
.sk[hidden]{display:none}
.sk.paper{background:color-mix(in srgb,var(--paper,#fbfaf6) 94%,transparent) radial-gradient(circle,rgba(0,0,0,.09) 1px,transparent 1.4px) 0 0/22px 22px}
.sk.see{background:color-mix(in srgb,var(--paper,#fbfaf6) 18%,transparent);-webkit-backdrop-filter:blur(2px);backdrop-filter:blur(2px)}
.sk canvas{position:absolute;inset:0;width:100%;height:100%}
.sk-bar{position:absolute;left:50%;top:calc(62px + env(safe-area-inset-top,0px));translate:-50% 0;z-index:41;display:flex;gap:4px;align-items:center;padding:5px;border-radius:22px;max-width:calc(100% - 24px);overflow-x:auto}
.sk-bar[hidden]{display:none}
.sk-bar button{flex:none;min-width:40px;height:40px;border:0;border-radius:16px;background:transparent;font:600 18px/1 var(--ui);color:var(--ink);cursor:pointer}
.sk-bar button[aria-pressed="true"]{background:var(--glass-strong)}
.sk-bar .sw{width:26px;min-width:26px;height:26px;border-radius:50%;margin:0 2px;box-shadow:inset 0 0 0 2px rgba(255,255,255,.7),0 0 0 1px rgba(0,0,0,.15)}
.sk-bar .sw[aria-pressed="true"]{outline:2.5px solid var(--accent);outline-offset:2px}
.sk-bar input[type=range]{width:90px;flex:none}
.sk-bar i.sep{width:1px;height:26px;background:var(--hair);flex:none}
.sk-shots{position:absolute;right:12px;bottom:calc(14px + env(safe-area-inset-bottom,0px));z-index:41;display:flex;gap:6px}
.sk-shots img{width:64px;height:48px;object-fit:cover;border-radius:8px;box-shadow:0 2px 8px rgba(0,0,0,.25);cursor:pointer;background:#fff}
.sk-flash{position:absolute;inset:0;z-index:60;background:#fff;pointer-events:none;animation:skF .5s ease-out forwards}
@keyframes skF{from{opacity:.9}to{opacity:0}}
.sk-hover{position:absolute;z-index:29;width:8px;height:8px;margin:-4px;border-radius:50%;pointer-events:none;border:1.5px solid var(--ink3);opacity:0;transition:opacity .15s}
.stage.sketching .navi{pointer-events:none}
.sk.ink{background:transparent;-webkit-backdrop-filter:none;backdrop-filter:none;pointer-events:none}
.sk.ink.grab{pointer-events:auto}
.sk-bar .pg{flex:none;min-width:44px;text-align:center;font:600 13px var(--ui);color:var(--ink2)}
@media (prefers-reduced-motion: reduce){ .sk-flash{animation-duration:.01s} }`;
document.head.appendChild(css);

const CFG=Object.assign({tool:'pen',color:'#1d2026',size:6,paper:true,pencilOnly:false,ink:false,page:0},H.store.get('sk-cfg',{}));
const saveCfg=()=>H.store.set('sk-cfg',CFG);
const COLORS=['#1d2026','#e5484d','#f5a524','#30a46c','#0091ff','#8e4ec6','#ffffff'];
const TOOLS={pen:{ic:'✒️',k:1,a:1,label:'Pen'},marker:{ic:'🖍️',k:2.6,a:.9,label:'Marker'},hl:{ic:'🖌️',k:5,a:.35,label:'Highlighter'},eraser:{ic:'🧽',k:4,a:1,label:'Eraser'}};

const wrap=document.createElement('div'); wrap.className='sk'; wrap.hidden=true; wrap.setAttribute('aria-label','Drawing page');
const base=document.createElement('canvas'), live=document.createElement('canvas'); wrap.append(base,live);
const hover=document.createElement('i'); hover.className='sk-hover'; wrap.append(hover);
const bar=document.createElement('div'); bar.className='sk-bar glass'; bar.hidden=true; bar.setAttribute('role','toolbar'); bar.setAttribute('aria-label','Drawing tools');
const shots=document.createElement('div'); shots.className='sk-shots'; shots.hidden=true;
stage.append(wrap,bar,shots);
[wrap,bar,shots].forEach(el=>el.addEventListener('pointerdown',e=>e.stopPropagation()));
const bx=base.getContext('2d'), lx=live.getContext('2d');

/* pages: each one a list of strokes. Kept on this device and, when the database is here, synced (Mac ⇄ iPad). */
let pages=H.store.get('sk-pages',null); if(!pages){ pages=[H.store.get('sk-strokes',[])]; }
let pagesAt=H.store.get('sk-pagesAt',pages.map(()=>0));
CFG.page=Math.min(CFG.page||0,pages.length-1);
let strokes=pages[CFG.page], cur=null, dpr=1, W=0, Hh=0;
function size(){ dpr=Math.min(2,devicePixelRatio||1); W=stage.clientWidth; Hh=stage.clientHeight;
  for(const c of [base,live]){ c.width=Math.round(W*dpr); c.height=Math.round(Hh*dpr); c.getContext('2d').setTransform(dpr,0,0,dpr,0,0); } redraw(); }
function outline(st){
  const pts=st.p, o={size:st.w,thinning:st.pen?.62:.5,smoothing:.55,streamline:.42,simulatePressure:!st.pen,last:!!st.done,start:{taper:st.pen?6:0},end:{taper:st.pen?10:0}};
  return PF?PF(pts,o):null;
}
function paint(ctx,st){
  ctx.save(); ctx.globalAlpha=st.a; ctx.globalCompositeOperation=st.tool==='eraser'?'destination-out':st.tool==='hl'?'multiply':'source-over';
  ctx.fillStyle=ctx.strokeStyle=st.c;
  const o=st.p.length>1?outline(st):null;
  if(o&&o.length){ ctx.beginPath(); ctx.moveTo(o[0][0],o[0][1]); for(let i=1;i<o.length-1;i++){ const a=o[i],b=o[i+1]; ctx.quadraticCurveTo(a[0],a[1],(a[0]+b[0])/2,(a[1]+b[1])/2); } ctx.closePath(); ctx.fill(); }
  else { ctx.lineCap=ctx.lineJoin='round'; const p=st.p;
    if(p.length===1){ ctx.beginPath(); ctx.arc(p[0][0],p[0][1],st.w*(p[0][2]||.5)*.6,0,7); ctx.fill(); }
    for(let i=1;i<p.length;i++){ ctx.lineWidth=Math.max(1,st.w*(st.pen?(p[i][2]||.5)*1.4:1)); ctx.beginPath(); ctx.moveTo(p[i-1][0],p[i-1][1]); ctx.lineTo(p[i][0],p[i][1]); ctx.stroke(); } }
  ctx.restore();
}
function redraw(){ bx.clearRect(0,0,W,Hh); strokes.forEach(s=>paint(bx,s)); }
let syncT=0;
const keep=()=>{ pages[CFG.page]=strokes; pagesAt[CFG.page]=Date.now();
  try{ H.store.set('sk-pages',pages); H.store.set('sk-pagesAt',pagesAt); }catch{ /* full: keep the newest strokes */ strokes.splice(0,strokes.length-300); }
  clearTimeout(syncT); const i=CFG.page; syncT=setTimeout(()=>push(i),1500); };
async function push(i){ const db=await H.db(); if(!db) return; const body={strokes:pages[i],at:pagesAt[i]};
  if(JSON.stringify(body).length>240000){ console.warn('Sketch page too big to sync'); return; }
  try{ await db.doc('boards/page-'+i).set(body); }catch(err){ console.warn('Sketch sync',err); } }
async function pull(){ const db=await H.db(); if(!db) return; try{ const q=await db.collection('boards').get(); let changed=false;
  q.docs.forEach(d=>{ const i=+d.id.replace('page-',''), v=d.data(); if(!(i>=0)||!v||!Array.isArray(v.strokes)) return;
    if((v.at||0)>(pagesAt[i]||0)){ pages[i]=JSON.parse(JSON.stringify(v.strokes)); pagesAt[i]=v.at; changed=true; } });
  for(let i=0;i<pages.length;i++) if(!pages[i]) pages[i]=[];
  if(changed){ strokes=pages[CFG.page]; try{ H.store.set('sk-pages',pages); H.store.set('sk-pagesAt',pagesAt); }catch{} redraw(); sync(); } }catch(err){ console.warn('Sketch pull',err); } }
function goPage(i){ pages[CFG.page]=strokes; if(i>=pages.length){ pages.push([]); pagesAt.push(Date.now()); }
  CFG.page=H.clamp(i,0,pages.length-1); strokes=pages[CFG.page]; saveCfg(); redraw(); sync(); }

/* ---- drawing ---- */
let penSeen=false;
const P=e=>{ const r=wrap.getBoundingClientRect(); return [+(e.clientX-r.left).toFixed(1),+(e.clientY-r.top).toFixed(1),e.pointerType==='pen'?Math.max(.05,e.pressure):.5]; };
function startStroke(e){
  if(e.pointerType==='pen'&&!penSeen){ penSeen=true; if(!CFG.pencilOnly){ CFG.pencilOnly=true; saveCfg(); sync(); H.say('Pencil! I\'ll ignore your palm now.',1800,null,1); } }
  if(CFG.pencilOnly&&e.pointerType==='touch') return;
  if(cur) return; e.preventDefault(); try{ wrap.setPointerCapture(e.pointerId); }catch{}
  const t=TOOLS[CFG.tool]; cur={id:e.pointerId,tool:CFG.tool,c:CFG.tool==='eraser'?'#000':CFG.color,a:t.a,w:CFG.size*t.k,pen:e.pointerType==='pen',p:[P(e)],t0:H.now()};
  look(cur.p[0]);
}
function moveStroke(e){
  if(e.pointerType==='pen'&&!cur){ const p=P(e); hover.style.left=p[0]+'px'; hover.style.top=p[1]+'px'; hover.style.opacity=e.buttons?0:1; look(p); }
  if(!cur||e.pointerId!==cur.id) return;
  const evs=e.getCoalescedEvents?e.getCoalescedEvents():[e]; (evs.length?evs:[e]).forEach(ev=>cur.p.push(P(ev)));
  if(!draw.q){ draw.q=requestAnimationFrame(draw); }
  look(cur.p[cur.p.length-1]);
}
wrap.addEventListener('pointerdown',startStroke); wrap.addEventListener('pointermove',moveStroke);
wrap.addEventListener('pointerleave',()=>{ hover.style.opacity=0; });
function draw(){ draw.q=0; if(!cur) return; lx.clearRect(0,0,W,Hh); if(cur.tool==='eraser'){ redraw(); paint(bx,cur); } else paint(lx,cur); }
const end=e=>{ if(!cur||e.pointerId!==cur.id) return; cur.done=true; const st=cur; cur=null; lx.clearRect(0,0,W,Hh);
  strokes.push(st); if(st.tool==='eraser') redraw(); else paint(bx,st); keep(); react(st); };
wrap.addEventListener('pointerup',end); wrap.addEventListener('pointercancel',end);
/* Ink layer: the Pencil draws anywhere, fingers keep using the app underneath */
const inkOn=()=>isOpen&&CFG.ink&&CFG.pencilOnly;
const ui=e=>e.target.closest&&e.target.closest('.sk-bar,.sk-shots,#plugbar,.plugcard,.pip-stop');
addEventListener('pointerdown',e=>{ if(!inkOn()||e.pointerType!=='pen'||ui(e)) return; e.preventDefault(); e.stopPropagation(); startStroke(e); },true);
addEventListener('pointermove',e=>{ if(!inkOn()||e.pointerType!=='pen') return; if(cur){ e.preventDefault(); e.stopPropagation(); } moveStroke(e); },true);
addEventListener('pointerup',e=>{ if(inkOn()&&cur&&e.pointerId===cur.id){ e.stopPropagation(); end(e); } },true);
addEventListener('pointercancel',e=>{ if(inkOn()&&cur&&e.pointerId===cur.id) end(e); },true);

/* ---- Pip watches and reacts ---- */
function look(p){ if(!S.naviOn||!N.awake) return; N.lookPt={x:p[0],y:p[1]}; N.lookUntil=H.now()+700; }
let lastReact=0, count=0;
function react(st){
  count++; const t=H.now(); if(!S.naviOn||!N.awake||H.chat()<1) return;
  const p=st.p, xs=p.map(q=>q[0]), ys=p.map(q=>q[1]), w=Math.max(...xs)-Math.min(...xs), h=Math.max(...ys)-Math.min(...ys), diag=Math.hypot(w,h);
  let len=0; for(let i=1;i<p.length;i++) len+=Math.hypot(p[i][0]-p[i-1][0],p[i][1]-p[i-1][1]);
  const closed=diag>60&&Math.hypot(p[0][0]-p[p.length-1][0],p[0][1]-p[p.length-1][1])<diag*.18&&len>diag*2.2;
  const onPip=p.some(q=>Math.hypot(q[0]-N.x,q[1]-N.y)<N.r+4);
  const dur=(t-st.t0)/1000;
  let say=null, em=null;
  if(onPip){ em='😳'; say=H.pick(['Hey! That\'s me.','Are you drawing on me?','That tickles.']); N.squash=.35; N.hopT=t; }
  else if(t-lastReact<6000||Math.random()>.4) return;
  else if(st.tool==='eraser') { em='🧽'; say=H.pick(['Gone. Never happened.','Erase with confidence.']); }
  else if(closed) { em='⭕'; say=H.pick(['A circle! Pretty round.','Ooh, a loop.','Is that the sun? Or me?']); }
  else if(len>1400&&dur<2) { em='💨'; say=H.pick(['Speedy!','Whoosh.']); }
  else if(len>2600) { em='😵‍💫'; say=H.pick(['So many lines.','I\'m dizzy just watching.']); }
  else if(diag<10) { em='•'; say='A dot. Minimalist.'; }
  else if(count%10===0) { em='🎨'; say=`${count} strokes. It's really coming along.`; }
  else { em=H.pick(['👀','✨','🤔','😄']); say=H.pick(['Is it a cat?','I like where this is going.','Hmm. Modern.','Keep going!','Can I be in it?']); }
  lastReact=t; if(em) emote(em,{pri:2}); if(say) H.say(say,1800,null,2);
}

/* ---- snapshot: paper + ink + Pip in the corner ---- */
const SHOTS_MAX=6; let thumbs=H.store.get('sk-thumbs',[]);
function pipStamp(ctx,x,y,r){
  ctx.save(); const g=ctx.createRadialGradient(x-r*.3,y-r*.35,r*.1,x,y,r); g.addColorStop(0,'#fff'); g.addColorStop(1,getComputedStyle(stage).getPropertyValue('--accent').trim()||'#7aa7ff');
  ctx.fillStyle=g; ctx.beginPath(); ctx.arc(x,y,r,0,7); ctx.fill();
  ctx.fillStyle='#1a1d22'; [[-.32,-.05],[.32,-.05]].forEach(([dx,dy])=>{ ctx.beginPath(); ctx.ellipse(x+dx*r,y+dy*r,r*.11,r*.17,0,0,7); ctx.fill(); });
  ctx.strokeStyle='#1a1d22'; ctx.lineWidth=Math.max(1.5,r*.07); ctx.lineCap='round'; ctx.beginPath(); ctx.arc(x,y+r*.12,r*.28,.2*Math.PI,.8*Math.PI); ctx.stroke(); ctx.restore();
}
async function snap(){
  const c=document.createElement('canvas'); c.width=base.width; c.height=base.height; const x=c.getContext('2d');
  x.fillStyle=CFG.paper?'#fbfaf6':'#ffffff'; x.fillRect(0,0,c.width,c.height); x.drawImage(base,0,0);
  x.setTransform(dpr,0,0,dpr,0,0);
  if(S.naviOn) pipStamp(x,W-46,Hh-46,26);
  x.fillStyle='rgba(0,0,0,.35)'; x.font='600 12px -apple-system,system-ui,sans-serif'; x.fillText(`${S.name||'Pip'} Sandbox · ${new Date().toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'})}`,16,Hh-16);
  const fl=document.createElement('i'); fl.className='sk-flash'; stage.append(fl); setTimeout(()=>fl.remove(),600);
  H.beep([[1800,8],[600,30]]); if(S.naviOn&&N.awake){ H.say(H.pick(['Say cheese!','Got it.','Framing that one.']),1400,null,1); emote('📸',{pri:3}); }
  const blob=await new Promise(r=>c.toBlob(r,'image/png')); if(!blob) return;
  /* a small thumbnail stays on this device */
  const tc=document.createElement('canvas'); tc.width=320; tc.height=Math.round(320*c.height/c.width); tc.getContext('2d').drawImage(c,0,0,tc.width,tc.height);
  thumbs=[tc.toDataURL('image/jpeg',.7),...thumbs].slice(0,SHOTS_MAX); try{ H.store.set('sk-thumbs',thumbs); }catch{ thumbs=thumbs.slice(0,2); H.store.set('sk-thumbs',thumbs); }
  showThumbs(); window.PipBrain?.log?.(`You drew something (${strokes.length} strokes) and took a snapshot.`);
  await saveBlob(blob,`pip-sketch-${new Date().toISOString().slice(0,16).replace(/[:T]/g,'-')}.png`);
}
async function saveBlob(blob,name){
  try{ const dl=await H.downloads(); if(dl){ await dl.save({filename:name,data:blob}); return; } }catch(err){ console.warn('downloads',err); if(err&&/declin|cancel|reject/i.test(err.code||err.message||'')) return; }
  try{ const f=new File([blob],name,{type:'image/png'}); if(navigator.canShare&&navigator.canShare({files:[f]})){ await navigator.share({files:[f],title:'Pip sketch'}); return; } }catch(err){ if(err&&err.name==='AbortError') return; }
  const a=document.createElement('a'); a.href=URL.createObjectURL(blob); a.download=name; document.body.append(a); a.click(); a.remove(); setTimeout(()=>URL.revokeObjectURL(a.href),4000);
}
function showThumbs(){ shots.innerHTML=thumbs.map((u,i)=>`<img src="${u}" alt="Snapshot ${i+1}" data-i="${i}">`).join(''); }
shots.addEventListener('click',e=>{ const im=e.target.closest('img'); if(!im) return; fetch(im.src).then(r=>r.blob()).then(b=>saveBlob(b,'pip-sketch-thumb.jpg')); });

/* ---- toolbar ---- */
function sync(){
  bar.innerHTML=Object.entries(TOOLS).map(([k,t])=>`<button data-tool="${k}" aria-label="${t.label}" aria-pressed="${CFG.tool===k}">${t.ic}</button>`).join('')+'<i class="sep"></i>'
    +COLORS.map(c=>`<button class="sw" data-col="${c}" style="background:${c}" aria-label="Colour ${c}" aria-pressed="${CFG.color===c}"></button>`).join('')+'<i class="sep"></i>'
    +`<input type="range" min="2" max="24" step="1" value="${CFG.size}" aria-label="Size" data-size>`
    +`<button data-a="undo" aria-label="Undo">↶</button><button data-a="clear" aria-label="Clear page">🗑</button>`
    +`<button data-a="ink" aria-label="${CFG.ink?'Ink layer: Pencil draws, fingers use the app':'Whiteboard'}" aria-pressed="${CFG.ink}">${CFG.ink?'🖋️':'📋'}</button>`
    +(CFG.ink?'':`<button data-a="paper" aria-label="Paper or see-through" aria-pressed="${!CFG.paper}">${CFG.paper?'📄':'🪟'}</button>`)
    +`<i class="sep"></i><button data-a="prev" aria-label="Previous page">‹</button><span class="pg">${CFG.page+1} / ${pages.length}</span><button data-a="next" aria-label="${CFG.page===pages.length-1?'New page':'Next page'}">${CFG.page===pages.length-1?'+':'›'}</button>`
    +`<button data-a="pencil" aria-label="Pencil only (ignore fingers)" aria-pressed="${CFG.pencilOnly}">✍️</button>`
    +`<button data-a="snap" aria-label="Snapshot">📸</button><button data-a="close" aria-label="Close drawing">✕</button>`;
  wrap.classList.toggle('ink',CFG.ink); wrap.classList.toggle('grab',CFG.ink&&!CFG.pencilOnly); wrap.classList.toggle('paper',!CFG.ink&&CFG.paper); wrap.classList.toggle('see',!CFG.ink&&!CFG.paper);
  stage.classList.toggle('sketching',isOpen&&!(CFG.ink&&CFG.pencilOnly));
}
bar.addEventListener('click',e=>{
  const t=e.target.closest('[data-tool]'), c=e.target.closest('[data-col]'), a=e.target.closest('[data-a]')?.dataset.a;
  if(t){ CFG.tool=t.dataset.tool; if(CFG.tool==='eraser'&&S.naviOn&&N.awake&&Math.random()<.3) H.say('Careful with that.',1200,null,2); }
  if(c){ CFG.color=c.dataset.col; if(CFG.tool==='eraser') CFG.tool='pen'; }
  if(a==='undo'){ strokes.pop(); redraw(); keep(); }
  if(a==='clear'){ if(strokes.length){ strokes=[]; redraw(); keep(); if(S.naviOn&&N.awake) H.say('Fresh page.',1200,null,1); } }
  if(a==='paper') CFG.paper=!CFG.paper;
  if(a==='ink'){ CFG.ink=!CFG.ink; if(CFG.ink&&!CFG.pencilOnly&&penSeen) CFG.pencilOnly=true;
    if(S.naviOn&&N.awake) H.say(CFG.ink?(CFG.pencilOnly?'Ink layer. Pencil draws anywhere; fingers still work the app.':'Ink layer. Turn on ✍️ Pencil-only to use the app with your fingers too.'):'Whiteboard.',2600,null,0); }
  if(a==='prev'&&CFG.page>0){ goPage(CFG.page-1); return; }
  if(a==='next'){ goPage(CFG.page+1); if(S.naviOn&&N.awake&&CFG.page===pages.length-1&&!strokes.length) H.say('New page.',1000,null,2); return; }
  if(a==='pencil') CFG.pencilOnly=!CFG.pencilOnly;
  if(a==='snap'){ snap().catch(err=>console.warn(err)); return; }
  if(a==='close'){ open(false); return; }
  saveCfg(); sync();
});
bar.addEventListener('input',e=>{ if(e.target.matches('[data-size]')){ CFG.size=+e.target.value; saveCfg(); } });

/* ---- open / close ---- */
let isOpen=false;
function open(on){
  isOpen=on; wrap.hidden=bar.hidden=!on; shots.hidden=!on||!thumbs.length; stage.classList.toggle('sketching',on&&!(CFG.ink&&CFG.pencilOnly)); btn.setAttribute('aria-pressed',String(on));
  if(on){ sync(); size(); showThumbs(); pull();
    if(S.naviOn&&!CFG.ink){ if(!N.awake) H.wake(); window.PipClip?.release?.(false); N.state='free';
      H.travel(stage.clientWidth-60,stage.clientHeight-120,360,'free'); setTimeout(()=>H.say(strokes.length?'Back to your drawing!':'A blank page! I\'ll watch from here.',1800,null,1),400); }
  } else if(S.naviOn&&N.awake){ H.goHome(); }
}
const btn=PB.button('✏️','Sketch',()=>open(!isOpen));
addEventListener('resize',()=>{ if(isOpen) size(); });
addEventListener('keydown',e=>{ if(!isOpen) return; if((e.metaKey||e.ctrlKey)&&e.key==='z'){ e.preventDefault(); strokes.pop(); redraw(); keep(); } if(e.key==='Escape') open(false); });
window.PipSketch={open,snap,goPage,get strokes(){ return strokes; },get pages(){ return pages; },config:CFG};
})();
