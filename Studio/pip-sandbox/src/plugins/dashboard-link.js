/* =====================================================================
  DASHBOARD LINK · plugin v1
  Loaded by the sandbox loader (see PLUGINS in index.html). Needs window.PipHost (host.js).
  Where: 📊 in the plugin bar

  Your Glass Clock Progress dashboard inside the sandbox, so Pip comes along.
  - A snapshot Claude refreshes when updating the dashboard (data/dashboard.json).
  - The live headline from the file that feeds the Glass Dashboard iPad widget, if reachable.
  - "Pip, show me": a guided tour. Also under Plugins → Pip's tours.
  Read-only: nothing here changes the real dashboard.
  ===================================================================== */
(() => {
const H=window.PipHost;
if(!H||!H.tour){ console.warn('Dashboard Link: needs PipHost with tours (host.js).'); return; }
const {N,S,stage,navi}=H;
if(H.registerPlugin&&!H.registerPlugin({id:'dashboard',name:'Dashboard Link',icon:'📊',shelf:'trial',desc:'Your progress dashboard inside the sandbox, with Pip as guide.'})) return;
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

/* Your progress dashboard, inside the sandbox. A snapshot Claude refreshes (data/dashboard.json),
   plus the live headline file that feeds the Glass Dashboard iPad widget, if this page can reach it. */
const CFG={snapshot:'data/dashboard.json', live:'https://gist.githubusercontent.com/AlphaDesignMedia/1f2abb87c59f63844a9f7523f37da9f4/raw/status.json', liveTimeoutMs:5000};
const st=document.createElement('style'); st.textContent=`
.plugcard.dash{width:min(420px,calc(100% - 32px))}
.dash .d-sec{display:grid;gap:6px;padding:10px 12px;border-radius:14px;background:var(--wash)}
.dash .d-lbl{font:600 11px/1 var(--ui);letter-spacing:.07em;text-transform:uppercase;color:var(--ink3);display:flex;gap:8px;align-items:center}
.dash .d-chip{font:600 10.5px/1 var(--ui);letter-spacing:.04em;padding:3px 7px;border-radius:999px;background:var(--hair);color:var(--ink2);text-transform:none}
.dash .d-chip.live{background:color-mix(in srgb,var(--accent) 22%,transparent);color:var(--accent)}
.dash .d-row{font:500 13.5px/1.35 var(--ui);color:var(--ink)}
.dash .d-row small{display:block;font-weight:400;color:var(--ink2)}
.dash .d-nums{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;text-align:center}
.dash .d-nums b{display:block;font:700 20px/1.1 var(--ui);color:var(--ink)}
.dash .d-nums span{font:500 11px/1.2 var(--ui);color:var(--ink2)}
.dash .d-bar{height:8px;border-radius:4px;background:var(--hair);overflow:hidden}
.dash .d-bar i{display:block;height:100%;border-radius:4px;background:var(--accent)}
.dash a.pc{display:inline-flex;align-items:center;text-decoration:none}`; document.head.appendChild(st);

const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const when=iso=>{ const d=new Date(iso); if(isNaN(d)) return esc(iso); return d.toLocaleString('en-GB',{weekday:'short',day:'numeric',month:'short',hour:'numeric',minute:'2-digit'}); };
const ago=iso=>{ const h=(Date.now()-new Date(iso))/36e5; return h<1?'just now':h<48?Math.round(h)+' h ago':Math.round(h/24)+' days ago'; };
let D=null, L=null, liveState='checking';

const card=PB.card(`<h3>📊 Glass Clock Progress</h3><div id="dashBody"><p>Loading…</p></div>`); card.classList.add('dash');
const btn=PB.button('📊','Dashboard',()=>{ if(PB.toggle(card,btn)){ render(); greet(); } });

async function load(){
  try{ const r=await fetch(CFG.snapshot,{cache:'no-store'}); if(r.ok) D=await r.json(); }catch{}
  try{ const c=new AbortController(), t=setTimeout(()=>c.abort(),CFG.liveTimeoutMs);
    const r=await fetch(CFG.live+'?t='+Date.now(),{signal:c.signal,cache:'no-store'}); clearTimeout(t);
    if(r.ok){ L=await r.json(); liveState='live'; } else liveState='blocked'; }catch{ liveState='blocked'; }
  if(!card.hidden) render();
}
function render(){
  const b=card.querySelector('#dashBody');
  if(!D&&!L){ b.innerHTML='<p>No dashboard data yet. Ask Claude to sync it.</p>'; return; }
  const s=D?.status||{}, nu=D?.needsYou||[], parts=[];
  if(L) parts.push(`<div class="d-sec" id="dLive"><div class="d-lbl">Live headline <span class="d-chip live">widget file · ${ago(L.updatedAt)}</span></div>
    <div class="d-nums"><div><b>${+L.needYou||0}</b><span>Need you</span></div><div><b>${+L.toTry||0}</b><span>To try</span></div><div><b>${+L.upNext||0}</b><span>Up next</span></div><div><b>${+L.done||0}</b><span>Done</span></div></div>
    <div class="d-row">${esc(L.latestUpdate)}<small>iPad: ${esc(L.ipadBuild)}</small></div></div>`);
  if(D){
    parts.push(`<div class="d-sec" id="dStatus"><div class="d-lbl">Latest <span class="d-chip">snapshot · ${ago(D.syncedAt)}</span></div><div class="d-row">${esc(s.headline)}</div>
      <div class="d-row">📱 ${esc(s.ipadBuild)}<small>${esc(s.ipadNote)}</small></div></div>`);
    parts.push(`<div class="d-sec" id="dNeeds"><div class="d-lbl">Needs you · ${nu.length}</div>${nu.map(n=>`<div class="d-row">${esc(n.q)}<small>Suggested: ${esc(n.suggested)}</small></div>`).join('')||'<div class="d-row">Nothing waiting.</div>'}</div>`);
    if(D.upNext?.length) parts.push(`<div class="d-sec"><div class="d-lbl">Up next</div>${D.upNext.map(i=>`<div class="d-row">${esc(i.title)}<small>${esc(i.area)}</small></div>`).join('')}</div>`);
    if(D.builds?.length) parts.push(`<div class="d-sec" id="dBuilds"><div class="d-lbl">Recent iPad builds</div>${D.builds.slice(0,3).map(x=>`<div class="d-row">${esc(x.title)}<small>${when(x.at)} · ${esc(x.changes?.[0]||'')}</small></div>`).join('')}</div>`);
    if(D.usage?.windows) parts.push(`<div class="d-sec" id="dUsage"><div class="d-lbl">Claude usage <span class="d-chip">reading from ${when(D.usage.at)}, may be out of date</span></div>${D.usage.windows.map(w=>`<div class="d-row">${esc(w.label)} · ${+w.percentUsed||0}%<div class="d-bar"><i style="width:${Math.min(100,+w.percentUsed||0)}%"></i></div></div>`).join('')}</div>`);
    if(D.reminders?.length) parts.push(`<div class="d-sec"><div class="d-lbl">Reminders</div>${D.reminders.map(r=>`<div class="d-row">⏰ ${esc(r.title)}<small>${when(r.due)}</small></div>`).join('')}</div>`);
  }
  parts.push(`<div class="pr">${D?.url?`<a class="pc" href="${esc(D.url)}" target="_blank" rel="noopener">Open the full dashboard</a>`:''}<button class="pc" id="dashTour">Pip, show me</button></div>
    <p>${liveState==='live'?'The live headline comes from the file that feeds your iPad widget.':liveState==='blocked'?'The live headline couldn’t be reached from here, so this is the snapshot only.':'Checking for the live headline…'} The rest is a copy Claude refreshes when updating your dashboard.</p>`);
  b.innerHTML=parts.join('');
  b.querySelector('#dashTour').addEventListener('click',()=>{ if(!tour()) H.say('I’m busy, or set to quiet. Try again in a moment.',1800,null,0); });
}
/* Pip comes along: a line when you open it, and a tour */
let greeted=0;
function greet(){ if(!S.naviOn||H.now()-greeted<60000||H.touring()) return; greeted=H.now(); const n=D?.needsYou?.length||L?.needYou||0;
  setTimeout(()=>{ emote('📊',{pri:2}); H.say(n?`Your dashboard! ${n} thing${n>1?'s':''} waiting for you.`:'Your dashboard. All quiet.',2200,null,1); },300); }
const spot=sel=>()=>{ if(card.hidden) PB.toggle(card,btn), render(); window.PipGuide?.spot(sel); };
function tour(){
  if(!D&&!L) return false; const n=D?.needsYou?.length||0;
  return H.tour([
    {act:spot('#dashBody'), say:'This is your progress dashboard, carried into the sandbox. I came along too.'},
    ...(L?[{act:spot('#dLive'), say:'These numbers come live from the file that feeds your iPad widget.'}]:[]),
    {act:spot('#dStatus'), say:'The latest headline and what’s on your iPad right now.'},
    {act:spot('#dNeeds'), say:n?`${n} decisions want you. Each one has my suggested answer underneath.`:'Nothing needs you. Lovely.'},
    {act:spot('#dBuilds'), say:'Recent iPad builds, newest first.'},
    {act:spot('#dUsage'), say:'Claude usage. Check the date: it’s only as fresh as the last dashboard update.'},
    {act:()=>window.PipGuide?.spot(null), say:'Open the full dashboard any time with the button at the bottom.'}
  ],'Want me to walk you through your dashboard? Tap me.');
}
H.tours.push({id:'dashboard',name:'Your dashboard',start:()=>{ if(card.hidden){ PB.toggle(card,btn); render(); } return tour(); }});
load();
window.PipDashboard={reload:load,get data(){return {snapshot:D,live:L,liveState};}};

})();
