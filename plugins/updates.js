/* =====================================================================
  📮 UPDATES · plugin v1   (Trial shelf)
  Loaded by the sandbox loader (see PLUGINS in index.html).
  - WELCOME: when something big lands, a once-only welcome sheet shows it off (Pip celebrates).
    Add an entry to NEWS to announce the next one. "What's new" shows them all again.
  - TELL CLAUDE: leave feedback inside the sandbox (bug, idea, game, clock, Pip, other). Each note
    saves to the sandbox database ("feedback"), with what was on screen if you like. Then say
    "update" in chat: Claude reads every waiting note, works through them, and marks each one
    Done with a short reply you see here.
  Offline or outside claude.ai, notes wait on this device and send next time.
  ===================================================================== */
(() => {
const H=window.PipHost;
if(!H||!H.registerPlugin){ console.warn('Updates: needs Pip Sandbox V2 stage 12 or later.'); return; }
const {N,S}=H;
if(!H.registerPlugin({id:'updates',name:'Updates',icon:'📮',shelf:'trial',desc:'Big welcomes for new features, and a box to leave Claude feedback. Say "update" in chat and Claude works through it.'})) return;
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
const esc=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'})[c]);

/* ---------- news: newest first ---------- */
const NEWS=[
  {id:'clock-studio-1', at:'29 Oct 2026', icon:'⏱️', title:'Clock Studio is here', lead:'Your clock, any way you like it.',
   points:[['🕰️','7 faces','Digital, Flip, Roll, Analog, Segments, Dots and Words'],
           ['🎨','12 presets','From Pane 1887 to Ghost. Tap one below to try it now.'],
           ['🔤','12 fonts','Weight, width, slant and spacing, all live'],
           ['🌅','Cards and extras','Sky that changes through the day, moon phase, countdowns, a second time zone'],
           ['🎲','Surprise me','A random clock with a contrast check. Pip names it.'],
           ['🍓','Emoji codes','Share any clock as a string of fruit, animals, sea creatures or toys']],
   tryIt:['Flip \'74','Pane 1887','Night Stand','Words','Pixel Pal','Liquid'],
   go:['Open Clock Studio',()=>window.PipClockStudio?.open()],
   also:'Also new: 📮 Tell Claude. Leave feedback right here, then say “update” in chat.'}
];

/* ---------- styles ---------- */
const css=document.createElement('style'); css.textContent=`
.up-wel{position:absolute;inset:0;z-index:60;display:grid;place-items:center;padding:20px;background:rgba(8,10,20,.32);-webkit-backdrop-filter:blur(6px);backdrop-filter:blur(6px);animation:upFade .35s ease-out}
.up-sheet{position:relative;width:min(560px,100%);max-height:calc(100% - 24px);overflow:auto;box-sizing:border-box;padding:28px 26px 22px;border-radius:32px;color:var(--ink);display:grid;gap:16px;animation:upRise .6s cubic-bezier(.2,1.3,.4,1)}
.up-badge{justify-self:start;padding:5px 11px;border-radius:999px;background:var(--accent);color:#fff;font:700 11px/1 var(--ui);letter-spacing:.08em;text-transform:uppercase}
.up-hero{display:flex;gap:16px;align-items:center}
.up-hero i{font-style:normal;font-size:64px;line-height:1;animation:upBob 2.6s ease-in-out infinite;filter:drop-shadow(0 8px 14px rgba(0,0,0,.2))}
.up-hero h2{margin:0;font:800 clamp(28px,4.4vw,40px)/1.05 var(--ui);letter-spacing:-.02em}
.up-hero p{margin:6px 0 0;font:500 16px/1.35 var(--ui);color:var(--ink2)}
.up-pts{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:10px}
.up-pt{display:grid;grid-template-columns:auto 1fr;gap:2px 10px;padding:11px 12px;border-radius:16px;background:var(--wash);animation:upRise .5s cubic-bezier(.2,1.2,.4,1) backwards}
.up-pt span{grid-row:span 2;font-size:22px;line-height:1.2}
.up-pt b{font:700 14px/1.2 var(--ui)}.up-pt small{font:400 12.5px/1.35 var(--ui);color:var(--ink2)}
.up-try{display:flex;gap:6px;flex-wrap:wrap;align-items:center}
.up-try em{font:700 11px/1 var(--ui);letter-spacing:.06em;text-transform:uppercase;color:var(--ink3);font-style:normal;margin-right:4px}
.up-sheet button.pc{min-height:40px;border:0;border-radius:14px;padding:0 14px;background:var(--wash);color:var(--ink);font:600 14px/1 var(--ui);cursor:pointer}
.up-sheet button.pc.on,.up-sheet button.go{background:var(--accent);color:#fff}
.up-acts{display:flex;gap:8px;justify-content:flex-end;flex-wrap:wrap}
.up-acts .go{min-height:46px;padding:0 20px;font-size:15px;border-radius:16px}
.up-also{margin:0;font:500 13px/1.4 var(--ui);color:var(--ink2)}
.up-conf{position:absolute;top:-12px;width:9px;height:14px;border-radius:2px;pointer-events:none;z-index:61;animation:upFall linear forwards}
.up-wel.peek{place-items:end center;background:transparent;-webkit-backdrop-filter:none;backdrop-filter:none;pointer-events:none}
.up-wel.peek .up-sheet{pointer-events:auto;gap:12px;padding:18px 20px 16px;animation:none;transition:padding .3s}
.up-wel.peek .up-pts,.up-wel.peek .up-hero p,.up-wel.peek .up-badge,.up-wel.peek .up-also{display:none}
.up-wel.peek .up-hero i{font-size:34px}.up-wel.peek .up-hero h2{font-size:22px}
@keyframes upFade{from{opacity:0}}
@keyframes upRise{from{opacity:0;transform:translateY(24px) scale(.96)}}
@keyframes upBob{50%{transform:translateY(-6px) rotate(-6deg)}}
@keyframes upFall{to{transform:translate(var(--dx),calc(100vh + 40px)) rotate(var(--r));opacity:.2}}
.up-card{width:min(360px,calc(100% - 32px)) !important}
.up-tabs{display:flex;gap:2px;padding:3px;border-radius:999px;background:var(--wash)}
.up-tabs button{flex:1;min-height:32px;border:0;border-radius:999px;background:transparent;color:var(--ink2);font:600 12.5px/1 var(--ui);cursor:pointer}
.up-tabs button[aria-pressed="true"]{background:var(--glass-strong);color:var(--ink);box-shadow:0 1px 3px var(--shade)}
.up-card textarea{min-height:96px;resize:vertical;border:1px solid var(--hair);border-radius:12px;background:var(--wash);padding:10px;font:500 15px/1.4 var(--ui);color:var(--ink);box-sizing:border-box;width:100%}
.up-row{display:flex;justify-content:space-between;align-items:center;gap:10px;font:500 13.5px/1.3 var(--ui)}
.up-note{display:grid;gap:4px;padding:10px 12px;border-radius:14px;background:var(--wash);font:500 13.5px/1.4 var(--ui)}
.up-note header{display:flex;gap:8px;align-items:center;font:600 11.5px/1 var(--ui);color:var(--ink3)}
.up-note header .st{margin-left:auto;padding:3px 8px;border-radius:999px;background:var(--glass-strong);color:var(--ink2)}
.up-note header .st.done{background:#2fa36b;color:#fff}.up-note header .st.doing{background:var(--accent);color:#fff}
.up-note blockquote{margin:2px 0 0;padding-left:10px;border-left:3px solid var(--accent);color:var(--ink2);font-style:italic}
.up-note button{justify-self:end;min-height:28px;border:0;border-radius:9px;padding:0 10px;background:transparent;color:var(--ink3);font:600 12px/1 var(--ui);cursor:pointer}
@media (prefers-reduced-motion: reduce){ .up-wel,.up-sheet,.up-pt,.up-hero i{animation:none} }`;
document.head.appendChild(css);

/* ---------- welcome sheet ---------- */
let wel=null;
function closeWelcome(){ if(!wel) return; wel.remove(); wel=null; H.busy('updates-welcome',false); }
function confetti(){
  if(H.simpler()) return; const cols=['#ff5f6d','#ffc371','#5dff9a','#5aa8ff','#c58bff','#ffd36e'];
  for(let i=0;i<46;i++){ const c=document.createElement('i'); c.className='up-conf';
    c.style.cssText=`left:${Math.random()*100}%;background:${cols[i%cols.length]};--dx:${(Math.random()-.5)*160}px;--r:${(Math.random()*720-360)|0}deg;animation-duration:${1.8+Math.random()*1.6}s;animation-delay:${Math.random()*.5}s`;
    wel.appendChild(c); setTimeout(()=>c.remove(),4200); }
}
function showWelcome(n){
  closeWelcome(); markSeen(n.id);
  const presets=window.PipClockStudio?.presets||[];
  wel=document.createElement('div'); wel.className='up-wel'; wel.setAttribute('role','dialog'); wel.setAttribute('aria-modal','true'); wel.setAttribute('aria-label',n.title);
  wel.innerHTML=`<section class="up-sheet glass">
    <span class="up-badge">New · ${esc(n.at)}</span>
    <div class="up-hero"><i aria-hidden="true">${n.icon}</i><div><h2>${esc(n.title)}</h2><p>${esc(n.lead)}</p></div></div>
    <div class="up-pts">${n.points.map(([e,b,s],i)=>`<div class="up-pt" style="animation-delay:${.15+i*.07}s"><span>${e}</span><b>${esc(b)}</b><small>${esc(s)}</small></div>`).join('')}</div>
    ${n.tryIt&&presets.length?`<div class="up-try"><em>Try one</em>${n.tryIt.map(t=>presets.findIndex(p=>p[0]===t)).filter(i=>i>=0).map(i=>`<button class="pc" data-pre="${i}">${esc(presets[i][0])}</button>`).join('')}</div>`:''}
    ${n.also?`<p class="up-also">${esc(n.also)}</p>`:''}
    <div class="up-acts"><button class="pc" data-x>Later</button>${n.go?`<button class="pc go" data-go>${esc(n.go[0])}</button>`:''}</div></section>`;
  wel.addEventListener('pointerdown',e=>{ e.stopPropagation(); if(e.target===wel) closeWelcome(); });
  wel.addEventListener('click',e=>{
    const p=e.target.closest('[data-pre]'); if(p){ window.PipClockStudio?.usePreset?.(+p.dataset.pre); wel.classList.add('peek'); wel.querySelectorAll('[data-pre]').forEach(b=>b.classList.toggle('on',b===p)); return; }
    if(e.target.closest('[data-go]')){ closeWelcome(); n.go[1](); return; }
    if(e.target.closest('[data-x]')) closeWelcome(); });
  H.stage.appendChild(wel); H.busy('updates-welcome',true); confetti();
  (wel.querySelector('[data-go]')||wel.querySelector('[data-x]'))?.focus({preventScroll:true});
  if(S.naviOn){ if(!N.awake) H.wake(); H.say('New toy! '+n.title.replace(/ is here$/,'')+'.',2400,null,0); emote('🎉',{pri:3}); }
}
addEventListener('pip:interrupt',closeWelcome);
addEventListener('keydown',e=>{ if(e.key==='Escape') closeWelcome(); });
const seen=()=>H.store.get('up-seen',[]);
function markSeen(id){ const s=seen(); if(!s.includes(id)){ s.push(id); H.store.set('up-seen',s); } }
/* show the newest unseen welcome once things are calm */
let tries=0;
(function waitCalm(){ const n=NEWS.find(x=>!seen().includes(x.id)); if(!n) return;
  if((H.isBusy()||H.touring?.())&&tries++<20) return setTimeout(waitCalm,3000);
  showWelcome(n); })();

/* ---------- Tell Claude ---------- */
const TAGS=[['bug','🐞','Bug'],['idea','💡','Idea'],['game','🎮','Game'],['clock','⏱️','Clock'],['pip','🧚','Pip'],['other','✨','Other']];
const STATUS={new:['Waiting',''],seen:['Seen',''],doing:['Working on it','doing'],done:['Done ✓','done'],later:['Saved for later','']};
let notes=H.store.get('up-notes',[]), tag=H.store.get('up-tag','idea'), withCtx=H.store.get('up-ctx',true), tab='tell';
const keep=()=>H.store.set('up-notes',notes.slice(-200));
function context(){
  return {look:S.era, material:S.material, w:innerWidth, h:innerHeight,
    panels:[...document.querySelectorAll('#panels [id^="p-"]:not([hidden])')].map(p=>p.id.slice(2)),
    card:document.querySelector('.plugcard:not([hidden]) h3')?.textContent||null,
    clock:window.PipClockStudio?.get?.().on?window.PipClockStudio.get().mode:'sandbox',
    off:H.plugins.filter(p=>p.status==='off').map(p=>p.id), use:window.PipUsage?.()||null};
}
async function push(){
  const db=await H.db(); if(!db) return false; let sent=0;
  for(const n of notes.filter(n=>!n.dbId)){
    try{ const ref=await db.collection('feedback').add({text:n.text,tag:n.tag,at:n.at,status:'new',ctx:n.ctx||null,from:'aaron'}); n.dbId=ref.id; sent++; }catch(err){ console.warn('Updates: send',err); break; } }
  if(sent) keep(); return true;
}
async function pull(){
  const db=await H.db(); if(!db) return;
  try{ const q=await db.collection('feedback').get(); let changed=false;
    q.docs.forEach(d=>{ const v=d.data()||{}; let n=notes.find(x=>x.dbId===d.id);
      if(!n){ if(!v.text) return; n={id:'db-'+d.id,dbId:d.id,text:v.text,tag:v.tag||'other',at:v.at||Date.now(),status:v.status||'new'}; notes.push(n); changed=true; }
      if((v.status||'new')!==n.status||(v.reply||'')!==(n.reply||'')){ n.status=v.status||'new'; n.reply=v.reply||''; changed=true; } });
    if(changed){ notes.sort((a,b)=>a.at-b.at); keep(); sync(); } }catch(err){ console.warn('Updates: read',err); }
}
const syncAll=()=>push().then(pull);
const waiting=()=>notes.filter(n=>n.status==='new'||!n.dbId).length;
async function send(){
  const ta=card.querySelector('#upText'), text=(ta?.value||'').trim(); if(!text) return ta?.focus();
  notes.push({id:'n'+Date.now(),text:text.slice(0,4000),tag,at:Date.now(),status:'new',ctx:withCtx?context():null}); keep(); ta.value=''; H.store.set('up-draft','');
  const online=await push(); tab='notes'; sync();
  if(S.naviOn&&N.awake){ H.say(online?'Got it. Claude will see that next time you say “update”.':'Saved here. It sends when the database is back.',2600,null,0); emote(TAGS.find(t=>t[0]===tag)[1],{pri:2}); }
}
async function remove(id){
  const n=notes.find(x=>x.id===id); if(!n) return; notes=notes.filter(x=>x!==n); keep(); sync();
  if(n.dbId){ try{ const db=await H.db(); await db?.doc('feedback/'+n.dbId).delete(); }catch(err){ console.warn('Updates: remove',err); } }
}
const when=t=>{ const d=new Date(t), m=(Date.now()-t)/6e4; return m<1?'just now':m<60?Math.round(m)+' min ago':d.toLocaleString('en-GB',{weekday:'short',hour:'2-digit',minute:'2-digit'}); };

const card=PB.card(`<h3>📮 Updates</h3>
  <div class="up-tabs" role="group" aria-label="Updates sections"><button data-tab="tell">Tell Claude</button><button data-tab="notes">Your notes</button><button data-tab="news">What's new</button></div>
  <div id="upBody"></div>`);
card.classList.add('up-card');
const btn=PB.button('📮','Updates',()=>{ if(PB.toggle(card,btn)){ sync(); syncAll(); } });
function body(){
  if(tab==='tell') return `<p>What should change? Bugs, ideas, game feedback, anything. Say “update” in chat and Claude works through every waiting note.</p>
    <div class="pr">${TAGS.map(([k,e,l])=>`<button class="pc${k===tag?' on':''}" data-tag="${k}">${e} ${l}</button>`).join('')}</div>
    <textarea id="upText" placeholder="Type or dictate here…" aria-label="Your feedback">${esc(H.store.get('up-draft',''))}</textarea>
    <label class="up-row">Include what's on screen<input type="checkbox" class="switch" id="upCtx" ${withCtx?'checked':''}></label>
    <div class="pr"><button class="pc on" id="upSend">Send to Claude</button></div>
    ${waiting()?`<p>${waiting()} waiting for Claude.</p>`:''}`;
  if(tab==='notes'){ const list=[...notes].reverse();
    return list.length?`${waiting()?`<p>${waiting()} waiting. Say “update” in chat.</p>`:'<p>All caught up.</p>'}`+list.map(n=>{ const [lab,cls]=STATUS[n.status]||STATUS.new, t=TAGS.find(x=>x[0]===n.tag)||TAGS[5];
      return `<div class="up-note"><header><span>${t[1]} ${t[2]}</span><span>${when(n.at)}${n.dbId?'':' · not sent yet'}</span><span class="st ${cls}">${lab}</span></header>
        <div>${esc(n.text)}</div>${n.reply?`<blockquote>Claude: ${esc(n.reply)}</blockquote>`:''}${n.status==='new'||!n.dbId?`<button data-rm="${esc(n.id)}">Remove</button>`:''}</div>`; }).join('')
      :'<p>No notes yet. Tell Claude something.</p>'; }
  if(tab==='news') return NEWS.map((n,i)=>`<div class="up-note"><header><span>${n.icon} ${esc(n.at)}</span></header><b>${esc(n.title)}</b><div>${esc(n.lead)}</div><button data-news="${i}">Show the welcome again</button></div>`).join('');
  return '';
}
function sync(){
  if(card.hidden) return;
  card.querySelectorAll('[data-tab]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.tab===tab)));
  card.querySelector('#upBody').innerHTML=body();
}
card.addEventListener('click',e=>{
  const t=e.target.closest('[data-tab]'); if(t){ tab=t.dataset.tab; sync(); return; }
  const g=e.target.closest('[data-tag]'); if(g){ tag=g.dataset.tag; H.store.set('up-tag',tag); card.querySelectorAll('[data-tag]').forEach(b=>b.classList.toggle('on',b===g)); return; }
  if(e.target.closest('#upSend')) return send();
  const r=e.target.closest('[data-rm]'); if(r) return remove(r.dataset.rm);
  const nw=e.target.closest('[data-news]'); if(nw){ PB.toggle(card,btn); showWelcome(NEWS[+nw.dataset.news]); }
});
card.addEventListener('input',e=>{ if(e.target.id==='upText') H.store.set('up-draft',e.target.value); });
card.addEventListener('change',e=>{ if(e.target.id==='upCtx'){ withCtx=e.target.checked; H.store.set('up-ctx',withCtx); } });
card.addEventListener('keydown',e=>{ if(e.target.id==='upText'&&e.key==='Enter'&&(e.metaKey||e.ctrlKey)){ e.preventDefault(); send(); } });

setTimeout(syncAll,4000);
window.PipUpdates={news:NEWS,show:id=>{ const n=NEWS.find(x=>x.id===id)||NEWS[0]; if(n) showWelcome(n); },notes:()=>notes.slice(),sync:syncAll};
})();
