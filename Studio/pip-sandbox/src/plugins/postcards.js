/* =====================================================================
  PIP POSTCARDS · plugin v1
  Loaded by the sandbox loader (see PLUGINS in index.html). Needs window.PipHost (host.js).
  Works on its own. Plays nicely with the other plugins; with Spatial installed,
  Pip also reacts with emoji bubbles.
  Where: ✉️ in the plugin bar

  Pip as a postcard: ✉️ + four emoji + name. Send it; your friend pastes it anywhere and your Pip
  visits theirs as a guest, orbiting and chatting, then heads home after a while (tap the guest to wave goodbye).
  Fully offline: copy and paste is the only channel.

  Switch it off in the Plugins panel, or remove it from PLUGINS.
  =====================================================================
*/
(() => {
const H=window.PipHost;
if(!H||!H.openPanel){ console.warn('PIP POSTCARDS: needs Pip Sandbox V2 stage 11.5 or later.'); return; }
const {N,S,stage,navi}=H;
if(H.registerPlugin&&!H.registerPlugin({id:'postcards',name:'Postcards',icon:'✉️',shelf:'trial',desc:'Send your Pip to visit a friend as emoji. Offline.'})) return;
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

/* Pip's state as four emoji + a name. Paste one and that Pip visits yours as a guest. */
const EMO=Array.from('🍎🍊🍋🍇🍓🍒🍑🥝🍍🥥🥑🍆🥕🌽🍄🥐🍩🍪🎂🍭🍯🧁🍵🐝🐞🦋🐌🐙🐳🐬🐠🦊🐼🐨🐯🦁🐸🐵🦉🐧🦄🐢🌵🌲🌴🌻🌷🌹🍀🌈🌙🌟🔥🌊🎈🎁🎨🎲🎸🎺🚀🛸💎🔮');
const PERS=['pip','tock','lumen','glint','biscuit','bevel'], FORMS=['orb','clip','robot','fairy'], MOODS=['happy','calm','sleepy','grumpy'],
  COLS=['#4f7be8','#e0655a','#e6a03a','#2fae86','#22a5b5','#b452c0','#d0567e','#6c7282','#4f7be8'];
const myMood=()=>N.mood==='sulk'||N.pat<.45?'grumpy':N.state==='sleep'?'sleepy':N.pat<.8?'calm':'happy';
function encode(){
  const ci=Math.max(0,COLS.indexOf(S.fav||'')); let n=((PERS.indexOf(S.persona)*4+FORMS.indexOf(S.form))*4+MOODS.indexOf(myMood()))*9+ci;
  const d=[Math.floor(n/4096)%64,Math.floor(n/64)%64,n%64], c=(d[0]+d[1]*5+d[2]*11+23)%64;
  return '✉️ '+d.map(x=>EMO[x]).join('')+EMO[c]+' · '+S.name;
}
function decode(str){
  if(!str.includes('✉️')) return null;
  const e=Array.from(str).filter(ch=>EMO.includes(ch)); if(e.length<4) return null;
  const d=e.slice(0,3).map(ch=>EMO.indexOf(ch)); if((d[0]+d[1]*5+d[2]*11+23)%64!==EMO.indexOf(e[3])) return null;
  let n=d[0]*4096+d[1]*64+d[2]; const col=n%9; n=Math.floor(n/9); const mood=MOODS[n%4]; n=Math.floor(n/4); const form=FORMS[n%4]; n=Math.floor(n/4); const pers=PERS[n];
  if(!pers) return null; const name=(str.split('·')[1]||'').trim().slice(0,16)||'A friend';
  return {pers,form,mood,col:COLS[col],name};
}
const card=PB.card(`<h3>✉️ Postcards</h3><p>Send your Pip to visit a friend. Copy this, send it, and they paste it anywhere.</p>
  <div id="pcCode" style="font-size:24px;letter-spacing:.06em;user-select:text;-webkit-user-select:text"></div>
  <div class="pr"><button class="pc" id="pcCopy">Copy postcard</button></div>
  <input class="pin" id="pcIn" placeholder="Paste a postcard here" aria-label="Paste a postcard">`);
const btn=PB.button('✉️','Postcards',()=>{ if(PB.toggle(card,btn)) card.querySelector('#pcCode').textContent=encode(); });
card.querySelector('#pcCopy').addEventListener('click',async()=>{ const c=encode(); try{ await navigator.clipboard.writeText(c); H.say('Postcard copied. I\'ll pack a bag.',1600,null,0); }catch{ H.say('Copy was blocked. Select the emoji instead.',1800,null,0); } });
card.querySelector('#pcIn').addEventListener('input',e=>{ const g=decode(e.target.value); if(g){ e.target.value=''; visit(g); PB.toggle(card,btn); } });
window.addEventListener('paste',e=>{ const t=(e.clipboardData||window.clipboardData)?.getData('text')||''; const g=decode(t); if(g){ e.preventDefault(); e.stopImmediatePropagation(); visit(g); } },true);
/* the guest */
const st=document.createElement('style'); st.textContent=`.guest{position:absolute;left:0;top:0;z-index:31;width:24px;height:24px;border-radius:50%;cursor:pointer;border:1px solid rgba(255,255,255,.75);padding:0;
  box-shadow:inset 0 -2px 4px rgba(0,0,0,.16), 0 2px 7px rgba(0,0,0,.2)}
.guest.clip{border-radius:30% 30% 50% 50%}.guest.robot{border-radius:24%}.guest.fairy{border-radius:52% 48% 50% 50%/58% 58% 42% 42%}
.guest i{position:absolute;top:40%;width:3px;height:5px;border-radius:2px;background:#1d1830}.guest i:first-child{left:32%}.guest i:last-child{right:32%}
.guest.sleepy i{height:1.5px}.guest.grumpy i:first-child{rotate:18deg}.guest.grumpy i:last-child{rotate:-18deg}
.guest .tag{position:absolute;top:28px;left:50%;translate:-50% 0;font:600 11px/1 var(--ui);color:var(--ink2);white-space:nowrap}`; document.head.appendChild(st);
let G2=null;
function visit(g){
  if(G2) leave(true);
  const el=document.createElement('button'); el.className=`guest ${g.form} ${g.mood}`; el.setAttribute('aria-label',`${g.name}, visiting. Tap to say goodbye.`);
  el.style.background=`radial-gradient(circle at 34% 28%, rgba(255,255,255,.95) 0 11%, color-mix(in srgb, ${g.col} 40%, white) 58%, color-mix(in srgb, ${g.col} 85%, black))`;
  el.innerHTML='<i></i><i></i><span class="tag"></span>'; el.querySelector('.tag').textContent=g.name; stage.appendChild(el);
  G2={el,g,x:-30,y:140,t0:H.now(),ang:0};
  el.addEventListener('pointerdown',e=>e.stopPropagation()); el.addEventListener('click',()=>leave(false));
  if(!N.awake) H.wake(); emote('😮',{pri:3});
  const hi={happy:'Oh! A visitor!',calm:'Someone\'s here. Hello.',sleepy:'A sleepy visitor. Same.',grumpy:'Uh oh. They look grumpy.'}[g.mood];
  H.say(`${hi} It's ${g.name}.`,2600,null,0);
  setTimeout(()=>{ if(G2) H.say(H.pick(['They like your clock.','We\'re comparing bodies.',`${g.name} says hi.`,'Tea for two?']),2200,null,1); },6000);
}
function leave(quiet){
  if(!G2) return; const {el,g}=G2; G2=null; el.animate([{opacity:1},{opacity:0,translate:'0 -40px'}],{duration:500}).onfinish=()=>el.remove();
  if(!quiet){ emote('👋',{pri:3}); H.say(`${g.name} went home. Send them a postcard back?`,2400,null,0); }
}
H.frame.push((dt,t)=>{
  if(!G2) return; const age=(t-G2.t0)/1000; G2.ang+=dt*1.2;
  const tx=N.x+Math.cos(G2.ang)*46, ty=N.y-20+Math.sin(G2.ang*1.3)*18;
  G2.x+=(tx-G2.x)*Math.min(1,dt*2.2); G2.y+=(ty-G2.y)*Math.min(1,dt*2.2);
  G2.el.style.transform=`translate(${G2.x-12}px,${G2.y-12}px)`;
  if(age>75) leave(false);
});
window.PipPostcards={encode,decode,visit};

})();
