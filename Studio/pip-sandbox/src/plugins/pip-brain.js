/* =====================================================================
  PIP'S BRAIN · plugin v1   (Grounded shelf)
  Loaded by the sandbox loader (see PLUGINS in index.html). Where: 🧠 in the plugin bar.
  Pip keeps a brain in the sandbox's own database, so nothing is lost between visits or
  between the Mac and the iPad. Claude reads and writes the same brain between sessions.
    brains/<who>/parts/profile   what Pip knows about you (facts), written by you or Claude
    brains/<who>/parts/notes     "Remember this": your notes, newest first
    brains/<who>/parts/lessons   lessons Pip can teach (Claude writes these)
    brains/<who>/parts/progress  which lessons you've done (the page writes this)
    brains/<who>/parts/log       what happened: Claude's session notes, checks, sketches
  Pip brings one thing up when you arrive: something new from Claude, a lesson, or an old note.
  Other plugins: window.PipBrain.note(text), .log(text), .tipFor(panelId), .lessons().
  Works offline too (kept on this device until the database is back).
  Switch it off in the Plugins panel, or remove it from PLUGINS.
  ===================================================================== */
(() => {
const H=window.PipHost;
if(!H||!H.registerPlugin){ console.warn('Pip Brain: needs PipHost (host.js).'); return; }
const {N,S,stage}=H;
if(!H.registerPlugin({id:'pip-brain',name:'Pip\'s Brain',icon:'🧠',shelf:'grounded',desc:'Pip remembers you between visits and devices, and teaches you lessons Claude writes.'})) return;
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
const WHO='aaron', PARTS=['profile','notes','lessons','progress','log'];
const B=Object.assign({profile:{about:[]},notes:{items:[]},lessons:{items:[]},progress:{done:{}},log:{items:[]}},H.store.get('brain-cache',{}));
const cache=()=>H.store.set('brain-cache',B);
let db=null, live=false;
const ref=k=>db.doc(`brains/${WHO}/parts/${k}`);
const listeners=new Set(); const changed=()=>{ cache(); listeners.forEach(f=>{ try{ f(); }catch(e){ console.warn(e); } }); render(); };

/* one write at a time per part; the latest wins */
const Q={};
async function put(k){ B[k].at=new Date().toISOString(); cache(); if(!db) return;
  if(Q[k]){ Q[k].again=true; return; } Q[k]={};
  try{ do{ Q[k].again=false; await ref(k).set(JSON.parse(JSON.stringify(B[k]))); }while(Q[k].again); }
  catch(err){ console.warn('Brain save failed',k,err); toastSt('Saved on this device only ('+(err&&err.code||'offline')+').'); }
  finally{ delete Q[k]; } }

H.db().then(d=>{ if(!d) return; db=d; live=true;
  PARTS.forEach(k=>ref(k).onSnapshot(s=>{ if(s.metadata.hasPendingWrites) return;
      if(s.exists){ B[k]=JSON.parse(JSON.stringify(s.data())); changed(); }
      else if(B[k].at) put(k);            /* first run: push what this device already had */
    },err=>console.warn('Brain listen',k,err)));
  render(); });

/* ---- what other plugins and Pip use ---- */
const LOG_MAX=200, NOTE_MAX=300;
function note(text,from='you'){ text=String(text||'').trim().slice(0,500); if(!text) return;
  B.notes.items=[{at:new Date().toISOString(),from,text},...(B.notes.items||[])].slice(0,NOTE_MAX); put('notes'); changed(); }
function log(text,from='pip'){ B.log.items=[{at:new Date().toISOString(),from,text:String(text).slice(0,300)},...(B.log.items||[])].slice(0,LOG_MAX); put('log'); changed(); }
const lessons=()=>(B.lessons.items||[]).map(l=>({...l,done:!!(B.progress.done||{})[l.id]}));
function tipFor(panelId){ const l=lessons().filter(l=>l.panel===panelId); const todo=l.find(x=>!x.done)||l[0];
  const tips=(B.profile.tips||{})[panelId]; if(tips&&tips.length&&(!todo||Math.random()<.5)) return {text:H.pick(tips)};
  return todo?{text:`It looks like you're in ${panelId}. Want the "${todo.title}" lesson?`,lesson:todo}:null; }

/* ---- teaching: a lesson is a list of {say, open?, spot?}; Pip walks you through it ---- */
function teach(id){
  const L=lessons().find(l=>l.id===id); if(!L) return false;
  const steps=(L.steps||[]).map(s=>({say:s.say,act:()=>{ try{ if(s.open) H.openPanel(s.open); if(s.spot!==undefined) setTimeout(()=>window.PipGuide?.spot(s.spot),140); if(s.emoji) emote(s.emoji,{pri:3}); }catch(e){ console.warn(e); } }}));
  steps.push({say:L.outro||'That\'s the lesson. I\'ve ticked it off in my brain.',act:()=>{ window.PipGuide?.spot(null); }});
  if(H.isBusy&&H.isBusy()) H.interrupt(true);   /* a lesson you asked for beats whatever Pip was doing */
  const ok=H.tour(steps,`Lesson: ${L.title}. Tap me to start.`);
  if(!ok){ toastSt(H.chat()<1?'Turn Chattiness up in Pip\'s panel and I can teach.':'Pip is busy: tap ✋ Stop, then try again.'); return false; }
  const end=e=>{ removeEventListener('pip:tourEnd',end); if(e.detail&&e.detail.ignored) return;
    B.progress.done=Object.assign({},B.progress.done,{[id]:new Date().toISOString()}); put('progress'); log(`Finished the lesson "${L.title}".`); changed(); emote('🎓',{pri:3}); };
  addEventListener('pip:tourEnd',end); return true;
}

/* ---- Pip brings one thing up when you arrive ---- */
const lastSeen=H.store.get('brain-seen',0); H.store.set('brain-seen',Date.now());
let greeted=false;
function greet(){
  if(greeted||!S.naviOn||!N.awake||H.chat()<1||H.touring()||H.isBusy()) return; greeted=true;
  const fresh=(B.log.items||[]).find(x=>x.from==='claude'&&Date.parse(x.at)>lastSeen);
  const todo=lessons().find(l=>!l.done), notes=B.notes.items||[];
  let line=null;
  if(fresh) line=`While you were away, Claude wrote in my brain: "${fresh.text.slice(0,90)}${fresh.text.length>90?'…':''}"`;
  else if(todo&&Math.random()<.6) line=`I've got a lesson ready: ${todo.title}. Tap 🧠 when you fancy it.`;
  else if(notes.length) line=`You told me once: "${H.pick(notes.slice(0,12)).text.slice(0,90)}"`;
  if(line){ H.say(line,5200,null,1); emote('🧠',{pri:2}); }
}
let gT=0; H.frame.push((dt,t)=>{ if(greeted) return; if(!gT) gT=t; if(t-gT>9000&&N.awake) greet(); });

/* ---- the 🧠 card ---- */
const css=document.createElement('style'); css.textContent=`
.brain-tabs{display:flex;gap:4px;flex-wrap:wrap}
.brain-list{display:grid;gap:6px;max-height:300px;overflow:auto}
.brain-it{display:grid;grid-template-columns:1fr auto;gap:8px;align-items:start;padding:8px 10px;border-radius:12px;background:var(--wash);font:500 13.5px/1.35 var(--ui)}
.brain-it small{display:block;color:var(--ink3);font-weight:400;font-size:11.5px;margin-top:2px}
.brain-it button{border:0;background:transparent;color:var(--ink3);font:600 13px var(--ui);cursor:pointer;min-width:30px;min-height:30px}
.brain-it.done{opacity:.6}
.brain-add{display:flex;gap:6px}.brain-add input{flex:1;min-width:0}
.brain-st{font:500 12px/1.3 var(--ui);color:var(--ink3)}`;
document.head.appendChild(css);
const card=PB.card(`<h3>🧠 Pip's brain</h3>
  <div class="brain-tabs" role="tablist"><button class="pc" data-tab="notes">Notes</button><button class="pc" data-tab="lessons">Lessons</button><button class="pc" data-tab="about">Pip knows</button><button class="pc" data-tab="log">Log</button></div>
  <div id="brBody"></div><p class="brain-st" id="brSt"></p>`);
const btn=PB.button('🧠','Pip\'s brain',()=>{ if(PB.toggle(card,btn)) render(); });
let tab=H.store.get('brain-tab','notes'), stT=0;
function toastSt(t){ const el=card.querySelector('#brSt'); el.textContent=t; clearTimeout(stT); stT=setTimeout(()=>render(),4000); }
const esc=s=>String(s??'').replace(/[<>&"]/g,c=>({'<':'&lt;','>':'&gt;','&':'&amp;','"':'&quot;'}[c]));
const when=iso=>{ const d=new Date(iso); return isNaN(d)?'':d.toLocaleDateString('en-GB',{day:'numeric',month:'short'})+' '+d.toLocaleTimeString('en-GB',{hour:'2-digit',minute:'2-digit'}); };
const WHO_IC={you:'🙂',claude:'✳️',pip:'🧚'};
function render(){
  if(card.hidden) return;
  card.querySelectorAll('[data-tab]').forEach(b=>{ b.classList.toggle('on',b.dataset.tab===tab); b.setAttribute('aria-selected',b.dataset.tab===tab); });
  const body=card.querySelector('#brBody'); let h='';
  if(tab==='notes'){
    h=`<div class="brain-add"><input class="pin" id="brIn" placeholder="Tell Pip to remember…" maxlength="500" autocomplete="off"><button class="pc on" id="brAdd">Keep</button></div>
      <div class="brain-list">${(B.notes.items||[]).map((n,i)=>`<div class="brain-it"><span>${WHO_IC[n.from]||''} ${esc(n.text)}<small>${when(n.at)}</small></span><button data-del="${i}" aria-label="Forget this note">✕</button></div>`).join('')||'<p>No notes yet. Ideas, things to try, things to ask Claude: Pip keeps them.</p>'}</div>`;
  } else if(tab==='lessons'){
    const L=lessons();
    h=`<div class="brain-list">${L.map(l=>`<div class="brain-it${l.done?' done':''}"><span>${l.done?'✅':'📘'} ${esc(l.title)}<small>${esc(l.what||'')}${l.steps?` · ${l.steps.length} steps`:''}</small></span><button data-teach="${esc(l.id)}">${l.done?'Again':'Teach me'}</button></div>`).join('')||'<p>No lessons yet. Ask Claude for one ("teach me how the glass works") and it appears here.</p>'}</div>`;
  } else if(tab==='about'){
    const m=window.PipRemembers?.mem;
    h=`<div class="brain-list">${(B.profile.about||[]).map(a=>`<div class="brain-it"><span>${esc(a)}</span></div>`).join('')}
      ${m?`<div class="brain-it"><span>On this device: ${m.visits} visits, ${m.taps} pokes, ${m.teas} teas, ${m.smashes} smashes.</span></div>`:''}</div>
      ${(B.profile.about||[]).length?'':'<p>Nothing yet. Claude fills this in from what it learns about you.</p>'}`;
  } else {
    h=`<div class="brain-list">${(B.log.items||[]).slice(0,60).map(x=>`<div class="brain-it"><span>${WHO_IC[x.from]||''} ${esc(x.text)}<small>${when(x.at)}</small></span></div>`).join('')||'<p>Empty for now.</p>'}</div>`;
  }
  body.innerHTML=h;
  card.querySelector('#brSt').textContent=live?'Synced: the Mac and the iPad share this brain. Claude can read it.':'On this device only (no database here).';
}
card.addEventListener('click',e=>{
  const t=e.target.closest('[data-tab]'); if(t){ tab=t.dataset.tab; H.store.set('brain-tab',tab); render(); return; }
  if(e.target.closest('#brAdd')){ const i=card.querySelector('#brIn'); if(i.value.trim()){ note(i.value); i.value=''; H.say(H.pick(['Got it. In the brain.','Noted!','I\'ll hold on to that.']),1500,null,1); emote('📝'); } return; }
  const d=e.target.closest('[data-del]'); if(d){ B.notes.items.splice(+d.dataset.del,1); put('notes'); changed(); return; }
  const l=e.target.closest('[data-teach]'); if(l){ PB.toggle(card,btn); teach(l.dataset.teach); }
});
card.addEventListener('keydown',e=>{ if(e.key==='Enter'&&e.target.id==='brIn') card.querySelector('#brAdd').click(); });

/* ---- a tour of tonight's new things (offered once) ---- */
const spot=s=>window.PipGuide?.spot(s);
const barBtn=label=>()=>document.querySelector(`#plugbar button[aria-label="${label}"]`);
const STEPS=[
  {act:()=>{ spot('#navi'); emote('👋',{pri:3}); }, say:'The full tour! I\'m Pip. Tap me to wake me, drag to flick, hold me for my menu.'},
  {act:()=>spot('.topbar .seg'), say:'Grounded keeps me calm and close to the clock. Dream lets me roam, glow and hide behind glass.'},
  {act:()=>spot('#rail'), say:'The rail holds the panels: me, Clock, Look, Colour, Accessibility, Plugins, Developer. Hold it and drag it to any edge.'},
  {act:()=>{ spot('#card'); emote('🕐',{pri:3}); }, say:'The clock. Drag it, pinch it, double-tap for the next font, hold it to edit.'},
  {act:()=>spot('#tm'), say:'The time machine. Travel through my eras and the build story.'},
  {act:()=>{ spot('#plugbar'); emote('🧩',{pri:3}); }, say:'This bar is every plugin with a button. Let me show you the main ones.'},
  {act:()=>spot(barBtn('Pip\'s brain')), say:'🧠 My brain: your notes, lessons and what I know about you. Saved in the sandbox\'s database, so Mac and iPad share it, and Claude reads it.'},
  {act:()=>spot(barBtn('Sketch')), say:'✏️ Sketch: draw with your Pencil. I watch and react. 📸 saves a picture, with me in the corner.'},
  {act:()=>spot(barBtn('Clip on')), say:'📎 Clip On: drop me on a panel\'s top edge and I hang on. Be Clippy turns me into the paperclip.'},
  {act:()=>spot(barBtn('iPad Check')), say:'🩺 iPad Check tests sensors, Pencil and speed, and saves a report for Claude.'},
  {act:()=>spot(barBtn('Screen')), say:'📐 Screen, 📱 Layout and 🧲 Panels: device previews, bigger controls, snapping panels to edges.'},
  {act:()=>spot(barBtn('Glass Lab')), say:'🔬 Glass Lab and 🧱 Materials: every dial of the glass, and panels made of metal, paper or jelly.'},
  {act:()=>spot(barBtn('Dashboard')), say:'📊 Your progress dashboard, right here. Plus 📓 notebook, 🌙 night shift, 💌 postcards, 📷 Pip Cam, 🎯 focus timer and ⚡ Eager Pip.'},
  {act:()=>{ H.openPanel('plugins'); setTimeout(()=>spot(()=>document.getElementById('plList')),150); }, say:'Plugins panel: switch anything off, move it between shelves, and watch what it costs.'},
  {act:()=>{ spot(barBtn('Pib')); emote('🫠',{pri:3}); }, say:'And… that one. A stowaway. It has a 🗑. Use it, or don\'t. I\'m not your boss.'},
  {act:()=>{ spot(null); setTimeout(()=>H.goHome(),2400); emote('🎓',{pri:3}); }, say:'That\'s everything, and it\'s all running. Find this tour again under Pip\'s tours. Lessons live in 🧠.'}
];
const start=()=>H.tour(STEPS,'Everything\'s built and running. Want the full tour? Tap me.');
H.tours.push({id:'everything',name:'The whole sandbox',start});
let offered=H.store.get('tour-everything',false), oT=0;
H.frame.push((dt,t)=>{ if(offered) return; if(!oT) oT=t; if(t-oT<14000||!N.awake||H.touring()||H.isBusy()||H.G.on||H.chat()<1) return;
  if(start()){ offered=true; H.store.set('tour-everything',true); } });

window.PipBrain={note,log,tipFor,lessons,teach,data:B,onChange:f=>listeners.add(f),live:()=>live};
})();
