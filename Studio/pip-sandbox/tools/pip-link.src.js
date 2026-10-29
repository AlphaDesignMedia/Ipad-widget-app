/* =====================================================================
  PIP LINK · plugin v1   (Dream shelf)
  Loaded by the sandbox loader (see PLUGINS in index.html). Where: 📡 in the plugin bar.
  - Open the sandbox on two devices (Mac and iPad): they link by themselves. No setup.
  - Tap an emoji: it flies off this screen and Pip catches it on the other one.
  - Moods, built in: pick how you feel; your other device's Pip knows, and your brain keeps a mood log.
  - Pair code: three emojis (🐸🌙🍩) make a private link, for a friend's device later.
  The sandbox links through the internet (the page's live "room"). Truly offline, device to device,
  is an app job (Apple's Multipeer); this is how it would feel.
  Switch it off in the Plugins panel, or remove it from PLUGINS.
  ===================================================================== */
(() => {
const H=window.PipHost;
if(!H||!H.registerPlugin){ console.warn('Pip Link: needs PipHost (host.js).'); return; }
const {N,S,stage}=H;
if(!H.registerPlugin({id:'pip-link',name:'Pip Link',icon:'📡',shelf:'dream',desc:'Send emojis and moods between your devices; Pip catches them.'})) return;
/*PB*/
const css=document.createElement('style'); css.textContent=`
.lk-row{display:flex;gap:4px;flex-wrap:wrap}
.lk-row button{width:42px;height:42px;border:0;border-radius:14px;background:var(--wash);font-size:21px;line-height:1;cursor:pointer;transition:scale .12s}
.lk-row button:active{scale:.88}
.lk-row button[aria-pressed="true"]{background:var(--accent);box-shadow:0 0 0 2px var(--accent)}
.lk-peers{font:600 13.5px/1.45 var(--ui)} .lk-peers small{display:block;font-weight:400;color:var(--ink3)}
.lk-lbl{font:700 11px/1 var(--ui);letter-spacing:.06em;text-transform:uppercase;color:var(--ink3)}
.lk-fly{position:absolute;left:0;top:0;z-index:44;font-size:34px;line-height:1;pointer-events:none;filter:drop-shadow(0 4px 8px rgba(0,0,0,.25))}
#plugbar button.lk-has::after{content:"";position:absolute;margin:-24px 0 0 22px;width:8px;height:8px;border-radius:50%;background:#3ec98a}`;
document.head.appendChild(css);

const EMOJI=['👋','❤️','😂','🎉','☕','👀','🙌','🌙'];
const MOODS=[['😊','good'],['🥳','buzzing'],['🎯','focused'],['😐','meh'],['😴','tired'],['😤','stressed'],['🤒','unwell']];
const ua=navigator.userAgent, iPad=/iPad/.test(ua)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
const DEV=iPad?'iPad':/iPhone/.test(ua)?'iPhone':/Mac/.test(ua)?'Mac':/Android/.test(ua)?'Android':'Computer';
const ME=H.store.get('lk-id',null)||(()=>{ const id=Math.random().toString(36).slice(2,10); H.store.set('lk-id',id); return id; })();
let mood=H.store.get('lk-mood',null), code=H.store.get('lk-code',null);
let lobby=null, room=null, peers=[], off=[];
const SYMS=['🐸','🌙','🍩','🦊','🌵','🎈','🍋','🐙','🪐','🍄','🐢','⚡','🌈','🎲','🐝','🧊'];
const roomName=()=>code?'pair-'+[...code].map(c=>c.codePointAt(0).toString(36)).join('-'):'home';

async function connect(){
  const c=window.claude; if(!c||!c.use) return render();
  lobby=lobby||await Promise.resolve(c.use('room')).catch(()=>null); if(!lobby) return render();
  off.forEach(f=>{ try{ f(); }catch{} }); off=[]; if(room&&room!==lobby&&room.leave) room.leave().catch(()=>{}); peers=[];
  try{ room=lobby.join?await lobby.join(roomName()):lobby; }catch(err){ console.warn('Pip Link join',err); room=lobby; }
  const u1=room.on('beam',msg=>{ if(msg&&!msg.sameTab) receive(msg.data); },err=>console.warn('Pip Link',err));
  const u2=room.onPeers(ch=>{ const before=peers;
    peers=(ch.peers||[]).filter(p=>!p.sameTab&&p.presence&&p.presence.id&&p.presence.id!==ME).map(p=>({state:p.presence}));
    moodChanges(before); render(); },err=>console.warn('Pip Link',err));
  [u1,u2].forEach(u=>typeof u==='function'&&off.push(u));
  announce(); render();
}
const announce=()=>{ if(room) room.presence({id:ME,dev:DEV,mood:mood||null,at:Date.now()}).catch(e=>console.warn(e)); };
setTimeout(()=>connect().catch(e=>console.warn(e)),1200);   /* after the page settles */

/* someone's mood changed: Pip mentions it, once */
function moodChanges(before){
  peers.forEach(p=>{ const was=before.find(b=>b.state&&b.state.id===p.state.id);
    if(!was){ if(S.naviOn&&N.awake) H.say(`Linked with your ${p.state.dev}.`,1800,null,1); return; }
    if(p.state.mood&&p.state.mood!==was.state.mood&&S.naviOn&&N.awake){ const m=MOODS.find(x=>x[0]===p.state.mood);
      H.say(`Your ${p.state.dev} says: feeling ${m?m[1]:''} ${p.state.mood}`,2400,null,1); window.PipSpatial?.emote(p.state.mood,{pri:3}); } });
}

/* sending and catching */
function fly(emoji,fromX,fromY,toX,toY,cb){
  const el=document.createElement('span'); el.className='lk-fly'; el.textContent=emoji; stage.append(el);
  if(H.simpler()){ el.remove(); cb&&cb(); return; }
  const mx=(fromX+toX)/2, my=Math.min(fromY,toY)-120;
  el.animate([{transform:`translate(${fromX}px,${fromY}px) scale(.6)`},{transform:`translate(${mx}px,${my}px) scale(1.3)`,offset:.5},{transform:`translate(${toX}px,${toY}px) scale(.8)`}],
    {duration:900,easing:'cubic-bezier(.3,.1,.4,1)'}).onfinish=()=>{ el.remove(); cb&&cb(); };
}
function send(emoji){
  if(!room||!peers.length){ H.say('Nobody to send to yet. Open the sandbox on your other device.',2400,null,0); return; }
  room.emit('beam',{emoji,dev:DEV,id:ME,at:Date.now()}).catch(e=>{ console.warn(e); H.say('That one didn\'t send. Try again?',1600,null,0); });
  const b=card.getBoundingClientRect(), r=stage.getBoundingClientRect();
  fly(emoji,b.left-r.left+b.width/2,b.top-r.top,stage.clientWidth+40,-40);
  H.beep([[660,30],[990,40]]);
}
let lastCatch=0;
function receive(d){
  if(!d||typeof d.emoji!=='string'||d.id===ME) return;
  const emoji=[...d.emoji].slice(0,4).join(''), dev=String(d.dev||'other device').slice(0,20);
  btn.classList.add('lk-has'); setTimeout(()=>btn.classList.remove('lk-has'),4000);
  const x0=Math.random()<.5?-40:stage.clientWidth+40, tx=S.naviOn?N.x:stage.clientWidth/2, ty=S.naviOn?N.y-N.r:120;
  fly(emoji,x0,60,tx,ty,()=>{ H.beep([[1200,20],[1500,30]]);
    if(S.naviOn){ if(!N.awake) H.wake(); N.hopT=H.now(); N.squash=.3; window.PipSpatial?.emote(emoji,{pri:3});
      if(H.now()-lastCatch>4000) H.say(`From your ${dev}: ${emoji}`,1800,null,1); }
    lastCatch=H.now(); });
}

/* the 📡 card */
const card=PB.card(`<h3>📡 Pip Link</h3><div class="lk-peers" id="lkPeers"></div>
  <div class="lk-lbl">Send</div><div class="lk-row" id="lkSend">${EMOJI.map(e=>`<button data-e="${e}" aria-label="Send ${e}">${e}</button>`).join('')}</div>
  <div class="lk-lbl">How are you?</div><div class="lk-row" id="lkMood">${MOODS.map(([e,w])=>`<button data-m="${e}" aria-label="Mood: ${w}">${e}</button>`).join('')}</div>
  <div class="lk-lbl">Link</div><div class="pr"><button class="pc" id="lkHome">All my devices</button><button class="pc" id="lkNew">New pair code</button><button class="pc" id="lkEnter">Enter a code</button></div>
  <div class="lk-row" id="lkPad" hidden>${SYMS.map(e=>`<button data-k="${e}">${e}</button>`).join('')}</div>
  <p id="lkNote">Works through the internet in the sandbox. Truly offline, device to device, is a job for the real app.</p>`);
const btn=PB.button('📡','Pip Link',()=>{ if(PB.toggle(card,btn)){ render(); if(!room) connect().catch(e=>console.warn(e)); } });
let typing='';
function render(){
  if(card.hidden) return; const el=card.querySelector('#lkPeers');
  const link=code?`Pair code ${code}`:'All your devices';
  el.innerHTML=!lobby?'Link isn\'t available here.<small>It needs the live sandbox page (not the exported file).</small>'
    :peers.length?peers.map(p=>`${esc(p.state.dev)} ${esc(p.state.mood||'')} <small>${link}</small>`).join('')
    :`Waiting for another device…<small>${link}. Open the sandbox on your ${DEV==='iPad'?'Mac':'iPad'}.</small>`;
  card.querySelectorAll('[data-m]').forEach(b=>b.setAttribute('aria-pressed',b.dataset.m===mood));
  card.querySelector('#lkHome').classList.toggle('on',!code);
  card.querySelector('#lkNew').textContent=code?`Code ${code}`:'New pair code';
}
const esc=s=>String(s??'').replace(/[<>&"]/g,c=>({'<':'&lt;','>':'&gt;','&':'&amp;','"':'&quot;'}[c]));
let moodLogT=H.store.get('lk-moodLog',0);
card.addEventListener('click',e=>{
  const s=e.target.closest('[data-e]'); if(s){ send(s.dataset.e); return; }
  const m=e.target.closest('[data-m]'); if(m){ mood=mood===m.dataset.m?null:m.dataset.m; H.store.set('lk-mood',mood); announce(); render();
    if(mood&&S.naviOn){ if(!N.awake) H.wake(); const w=MOODS.find(x=>x[0]===mood)[1];
      H.say({good:'Good! Me too.',buzzing:'Ooh, buzzing! Let\'s make something.',focused:'Focused. I\'ll keep quiet.',meh:'Meh days are allowed.',tired:'Tired. Gentle mode, then.',stressed:'Stressed? One thing at a time.',unwell:'Oh no. Tea, and go easy.'}[w],2200,null,0);
      window.PipSpatial?.emote(mood,{pri:3});
      if(Date.now()-moodLogT>10*60e3){ moodLogT=Date.now(); H.store.set('lk-moodLog',moodLogT); window.PipBrain?.log?.(`Mood: ${mood} ${w} (on the ${DEV}).`,'you'); } }
    return; }
  if(e.target.closest('#lkHome')){ code=null; H.store.set('lk-code',null); connect().catch(e=>console.warn(e)); return; }
  if(e.target.closest('#lkNew')){ if(code){ navigator.clipboard?.writeText(code).catch(()=>{}); H.say(`Your code is ${code}. Enter it on the other device.`,3000,null,0); return; }
    code=Array.from({length:3},()=>H.pick(SYMS)).join(''); H.store.set('lk-code',code); connect().catch(e=>console.warn(e)); H.say(`Pair code: ${code}. Enter it on the other device.`,3200,null,0); return; }
  if(e.target.closest('#lkEnter')){ typing=''; card.querySelector('#lkPad').hidden=false; card.querySelector('#lkNote').textContent='Tap the three emojis.'; return; }
  const k=e.target.closest('[data-k]'); if(k){ typing+=k.dataset.k; card.querySelector('#lkNote').textContent='Code: '+typing;
    if([...typing].length>=3){ code=typing; H.store.set('lk-code',code); card.querySelector('#lkPad').hidden=true; card.querySelector('#lkNote').textContent='Paired on '+code+'.'; connect().catch(e=>console.warn(e)); } }
});
/* stay announced: a fresh presence every few minutes, and when you come back to the tab */
setInterval(()=>{ if(room&&!document.hidden) announce(); },180000);
document.addEventListener('visibilitychange',()=>{ if(!document.hidden&&room) announce(); });
window.PipLink={send,connect,get peers(){ return peers; },get mood(){ return mood; }};
})();
