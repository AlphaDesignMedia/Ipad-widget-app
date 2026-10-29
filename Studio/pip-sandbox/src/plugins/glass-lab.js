/* =====================================================================
  GLASS LAB · plugin v1.1   (Dream shelf)
  Loaded by the sandbox loader (see PLUGINS in index.html). Needs window.PipHost (host.js).
  Where: 🔬 in the plugin bar.
  Glass tab
  - Live sliders: blur, frost, saturation, rim light, light angle, shadow, corners.
  - Presets: Frosted, Clear, Liquid, Beta 1, Solid.
  - Light from your finger, a fixed angle, or the time of day (the rim highlight follows).
  - Refraction: a real lens warp where the browser supports it (Chrome/Mac); shown as unavailable on iPad Safari.
  - Readability guard: an estimate of text contrast on your glass, with a warning.
  - Share a glass recipe as 🔬 + five emoji; paste one anywhere to apply it.
  Menus tab (added by Claude, 29 Oct 2026)
  - The rail, the plugin bar and plugin cards: size, spacing, padding, icon size, corners, separators.
  - Plugin cards move clear of the rail; inner sections can be glass, lines or the old flat wash.
  - Presets: Roomy (default), Compact, Big touch, Original.
  Glass dials affect Today's look only; era looks keep their own glass. Menu spacing applies everywhere.
  ===================================================================== */
(() => {
const H=window.PipHost;
if(!H||!H.registerPlugin){ console.warn('Glass Lab: needs Pip Sandbox V2 stage 12 or later.'); return; }
const {N,S,stage,navi}=H;
if(!H.registerPlugin({id:'glasslab',name:'Glass Lab',icon:'🔬',shelf:'dream',desc:'Every dial of the glass, live: blur, frost, rim light, shadow, corners, light source, refraction, recipes. Plus menu spacing and size.'})) return;
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

/* GLASS LAB: every dial of the glass, live. Applies to Today's look (eras keep theirs). */
const DEF={on:true,blur:16,frost:.3,sat:1.8,rim:.8,ang:225,shadow:.4,rad:28,light:'finger',refract:false};
const PRESETS={Frosted:{blur:24,frost:.55,sat:1.5,rim:.55,shadow:.5,rad:26},Clear:{blur:14,frost:.25,sat:1.9,rim:.85,shadow:.35,rad:28},
  Liquid:{blur:9,frost:.12,sat:2.2,rim:1,shadow:.3,rad:34},'Beta 1':{blur:2,frost:.03,sat:2.3,rim:1,shadow:.2,rad:34},Solid:{blur:30,frost:.85,sat:1.15,rim:.4,shadow:.55,rad:22}};
/* menus: the rail, the plugin bar and plugin cards */
const MDEF={on:true,rSize:46,rGap:4,rPad:6,rIcon:21,rRad:26,seps:true,bSize:42,bGap:4,bPad:5,bPlace:'left',cW:330,cPad:16,cGap:12,clear:true,inner:'glass'};
const MPRE={Roomy:{},Compact:{rSize:38,rGap:2,rPad:4,rIcon:18,rRad:20,bSize:34,bGap:2,bPad:3,cW:300,cPad:12,cGap:8},
  'Big touch':{rSize:56,rGap:6,rPad:8,rIcon:25,rRad:32,bSize:50,bGap:6,bPad:6,cW:370,cPad:18,cGap:14},
  Original:{rSize:44,rGap:2,rPad:4,rIcon:20,rRad:22,bSize:40,bGap:2,bPad:4,cW:310,cPad:14,cGap:10,clear:false,inner:'wash'}};
const L=Object.assign({},DEF,H.store.get('plug-glasslab',{}));
L.menu=Object.assign({},MDEF,L.menu||{});
const MM=L.menu;
const save=()=>H.store.set('plug-glasslab',L);
const st=document.createElement('style'); st.textContent=`
.stage.liquid.glasslab .glass{-webkit-backdrop-filter:var(--gl-bf) !important;backdrop-filter:var(--gl-bf) !important;
  background-color:color-mix(in srgb, var(--accent) 6%, rgba(var(--gl-tint),var(--gl-frost))) !important;
  box-shadow:inset var(--gl-rx) var(--gl-ry) 0 rgba(255,255,255,var(--gl-rim)), inset calc(var(--gl-rx) * -1) calc(var(--gl-ry) * -1) 0 rgba(255,255,255,calc(var(--gl-rim) * .35)),
    inset 0 0 0 .5px rgba(255,255,255,calc(var(--gl-rim) * .5)), 0 calc(var(--gl-sh) * 24px) calc(var(--gl-sh) * 56px) rgba(0,0,0,calc(var(--gl-sh) * .32)) !important}
.stage.liquid.glasslab .panel{border-radius:var(--gl-rad) !important}
.stage.liquid.glasslab .panel.child{border-radius:calc(var(--gl-rad) - 4px) !important}
.stage.liquid.glasslab .card-in{border-radius:calc(var(--gl-rad) + 4px) !important;box-shadow:inset var(--gl-rx) var(--gl-ry) 0 rgba(255,255,255,var(--gl-rim)), inset 0 0 0 .5px rgba(255,255,255,.4), 0 calc(var(--gl-sh) * 28px) calc(var(--gl-sh) * 60px) rgba(0,0,0,calc(var(--gl-sh) * .32)) !important}
.gl-row{display:grid;gap:4px;font:500 13.5px/1.2 var(--ui);color:var(--ink)}
.gl-row div{display:flex;justify-content:space-between}.gl-row output{color:var(--ink3);font-variant-numeric:tabular-nums}
.gl-row input{width:100%;accent-color:var(--accent);margin:0}
.gl-tab{display:grid;gap:10px}
.gl-sub{margin:4px 0 0;font:600 11px/1 var(--ui);letter-spacing:.07em;text-transform:uppercase;color:var(--ink3)}
.gl-warn{font:600 13px/1.3 var(--ui)}.gl-warn.ok{color:var(--ok)}.gl-warn.bad{color:var(--danger)}
/* menus */
.stage.gl-menus .rail{gap:var(--mr-gap);padding:var(--mr-pad);border-radius:var(--mr-rad)}
.stage.gl-menus .ri{width:var(--mr-size);height:var(--mr-size);border-radius:max(8px,calc(var(--mr-rad) - var(--mr-pad)))}
.stage.gl-menus .rail.names .ri{width:auto}
.stage.gl-menus .ri svg{width:var(--mr-icon);height:var(--mr-icon)}
.stage.gl-menus .rail-sep{width:calc(var(--mr-size) * .5)}
.stage.gl-menus .rail[data-edge="top"] .rail-sep,.stage.gl-menus .rail[data-edge="bottom"] .rail-sep{width:1px;height:calc(var(--mr-size) * .5)}
.stage.gl-menus.gl-noseps .rail-sep{display:none}
.stage.gl-menus #plugbar{gap:var(--mb-gap);padding:var(--mb-pad);border-radius:calc(var(--mb-size) / 2 + var(--mb-pad))}
.stage.gl-menus #plugbar button{width:var(--mb-size);height:var(--mb-size);border-radius:calc(var(--mb-size) / 2);font-size:calc(var(--mb-size) * .46)}
.stage.gl-menus[data-bar="centre"] #plugbar{left:50%;translate:-50% 0}
.stage.gl-menus .plugcard{width:min(var(--mc-w),calc(100% - 32px));padding:var(--mc-pad);gap:var(--mc-gap);border-radius:calc(var(--mc-pad) + 12px);left:var(--mc-left,max(16px,env(safe-area-inset-left,0px)));bottom:calc(var(--mb-size) + var(--mb-pad) * 2 + 26px + env(safe-area-inset-bottom,0px))}
.stage.gl-menus[data-bar="centre"] .plugcard{bottom:calc(var(--mb-size) + var(--mb-pad) * 2 + 26px + env(safe-area-inset-bottom,0px))}
.stage.gl-menus[data-inner="glass"] :is(.plugcard .d-sec,.plugcard button.pc:not(.on),.plugcard input.pin,.ppp details,.plug,.panel .drill){background:color-mix(in srgb, var(--ink) 4%, transparent);box-shadow:inset 0 1px 0 rgba(255,255,255,.28), inset 0 0 0 .5px rgba(255,255,255,.18);border-color:transparent}
.stage.gl-menus[data-inner="lines"] :is(.plugcard .d-sec,.ppp details,.plug){background:transparent;border-radius:0;box-shadow:inset 0 -.5px 0 var(--hair);padding-left:2px;padding-right:2px}`;
document.head.appendChild(st);
/* optional refraction: an SVG displacement lens (works where backdrop-filter accepts url(), e.g. Chrome) */
const svgNS='http://www.w3.org/2000/svg', defs=document.createElementNS(svgNS,'svg'); defs.setAttribute('width',0); defs.setAttribute('height',0); defs.style.position='absolute';
defs.innerHTML=`<filter id="glRefract" x="-10%" y="-10%" width="120%" height="120%"><feTurbulence type="fractalNoise" baseFrequency="0.012" numOctaves="2" seed="7"/><feDisplacementMap in="SourceGraphic" scale="14" xChannelSelector="R" yChannelSelector="G"/></filter>`;
document.body.appendChild(defs);
const canRefract=(()=>{ try{ return CSS.supports('backdrop-filter','url(#glRefract)')&&!/^((?!chrome|android).)*safari/i.test(navigator.userAgent); }catch{ return false; } })();
const SL=[['blur','Blur',0,40,1,v=>v+'px'],['frost','Frost',0,.9,.01,v=>Math.round(v*100)+'%'],['sat','Saturation',1,2.5,.05,v=>v.toFixed(2)+'×'],['rim','Rim light',0,1,.01,v=>Math.round(v*100)+'%'],
  ['ang','Light angle',0,359,1,v=>v+'°'],['shadow','Shadow',0,1,.01,v=>Math.round(v*100)+'%'],['rad','Corners',8,44,1,v=>v+'px']];
const px=v=>v+'px';
const MSL={rail:[['rSize','Button size',34,60,1,px],['rIcon','Icon size',16,28,1,px],['rGap','Space between',0,14,1,px],['rPad','Edge padding',2,14,1,px],['rRad','Corners',10,36,1,px]],
  bar:[['bSize','Button size',30,54,1,px],['bGap','Space between',0,12,1,px],['bPad','Edge padding',2,12,1,px]],
  card:[['cW','Width',280,440,2,px],['cPad','Padding',10,24,1,px],['cGap','Space between rows',6,18,1,px]]};
const slider=([k,n,a,b,st],pre)=>`<label class="gl-row" for="${pre}-${k}"><div><span>${n}</span><output id="${pre}o-${k}"></output></div><input type="range" id="${pre}-${k}" min="${a}" max="${b}" step="${st}"></label>`;
const card=PB.card(`<h3>🔬 Glass Lab</h3>
  <div class="pr" id="glTabs"><button class="pc" data-tab="glass">Glass</button><button class="pc" data-tab="menus">Menus</button></div>
  <div class="gl-tab" id="glTabGlass">
  <div class="pr"><button class="pc" id="glOn"></button>${Object.keys(PRESETS).map(k=>`<button class="pc" data-pre="${k}">${k}</button>`).join('')}</div>
  ${SL.map(s=>slider(s,'gl')).join('')}
  <div class="gl-sub">Light comes from</div>
  <div class="pr" id="glLight"><button class="pc" data-l="finger">Your finger</button><button class="pc" data-l="fixed">Fixed</button><button class="pc" data-l="time">Time of day</button></div>
  <div class="pr"><button class="pc" id="glRef"></button></div>
  <p class="gl-warn" id="glWarn"></p>
  <div class="gl-sub">Share this glass</div>
  <div id="glCode" style="font-size:22px;letter-spacing:.06em;user-select:text;-webkit-user-select:text"></div>
  <div class="pr"><button class="pc" id="glCopy">Copy recipe</button></div><input class="pin" id="glIn" placeholder="Paste a glass recipe" aria-label="Paste a glass recipe">
  <p>Changes Today's glass only. Era looks keep their own.</p>
  </div>
  <div class="gl-tab" id="glTabMenus" hidden>
  <div class="pr"><button class="pc" id="mnOn"></button>${Object.keys(MPRE).map(k=>`<button class="pc" data-mpre="${k}">${k}</button>`).join('')}</div>
  <div class="gl-sub">Side rail</div>
  ${MSL.rail.map(s=>slider(s,'mn')).join('')}
  <div class="pr"><button class="pc" id="mnSeps"></button></div>
  <div class="gl-sub">Plugin bar</div>
  ${MSL.bar.map(s=>slider(s,'mn')).join('')}
  <div class="pr" id="mnPlace"><button class="pc" data-place="left">Bottom left</button><button class="pc" data-place="centre">Bottom centre</button></div>
  <div class="gl-sub">Plugin cards</div>
  ${MSL.card.map(s=>slider(s,'mn')).join('')}
  <div class="pr"><button class="pc" id="mnClear"></button></div>
  <div class="gl-sub">Inner sections</div>
  <div class="pr" id="mnInner"><button class="pc" data-inner="glass">Glass</button><button class="pc" data-inner="lines">Lines</button><button class="pc" data-inner="wash">Flat (old)</button></div>
  <p>Menus use the glass above in Today's look, or a material from 🧱 Materials.</p>
  </div>`);
let tab='glass';
const btn=PB.button('🔬','Glass Lab',()=>{ if(PB.toggle(card,btn)) sync(); });
card.addEventListener('input',e=>{ const id=e.target.id;
  if(id.startsWith('gl-')){ L[id.slice(3)]=+e.target.value; apply(); sync(); save(); }
  else if(id.startsWith('mn-')){ MM[id.slice(3)]=+e.target.value; applyMenus(); sync(); save(); } });
card.addEventListener('click',e=>{ const b=e.target.closest('button'); if(!b) return;
  if(b.dataset.tab){ tab=b.dataset.tab; sync(); }
  else if(b.dataset.pre){ Object.assign(L,PRESETS[b.dataset.pre]); apply(); sync(); save(); H.say(b.dataset.pre==='Beta 1'?'Can anyone read this?':`${b.dataset.pre} glass.`,1300,null,2); }
  else if(b.dataset.mpre){ Object.assign(MM,MDEF,MPRE[b.dataset.mpre],{on:true}); applyMenus(); sync(); save(); H.say(b.dataset.mpre==='Original'?'Back how it was.':`${b.dataset.mpre} menus.`,1300,null,2); }
  else if(b.dataset.l){ L.light=b.dataset.l; apply(); sync(); save(); }
  else if(b.dataset.place){ MM.bPlace=b.dataset.place; applyMenus(); sync(); save(); }
  else if(b.dataset.inner){ MM.inner=b.dataset.inner; applyMenus(); sync(); save(); }
  else if(b.id==='mnOn'){ MM.on=!MM.on; applyMenus(); sync(); save(); }
  else if(b.id==='mnSeps'){ MM.seps=!MM.seps; applyMenus(); sync(); save(); }
  else if(b.id==='mnClear'){ MM.clear=!MM.clear; applyMenus(); sync(); save(); }
  else if(b.id==='glOn'){ L.on=!L.on; apply(); sync(); save(); }
  else if(b.id==='glRef'&&canRefract){ L.refract=!L.refract; apply(); sync(); save(); }
  else if(b.id==='glCopy'){ navigator.clipboard?.writeText(code()).then(()=>H.say('Glass recipe copied.',1200,null,0),()=>H.say('Copy was blocked. Select the emoji instead.',1600,null,0)); } });
/* recipe code: 7 dials × 8 steps = 21 bits → 4 emoji + 1 check */
const EMO=Array.from('🍎🍊🍋🍇🍓🍒🍑🥝🍍🥥🥑🍆🥕🌽🍄🥐🍩🍪🎂🍭🍯🧁🍵🐝🐞🦋🐌🐙🐳🐬🐠🦊🐼🐨🐯🦁🐸🐵🦉🐧🦄🐢🌵🌲🌴🌻🌷🌹🍀🌈🌙🌟🔥🌊🎈🎁🎨🎲🎸🎺🚀🛸💎🔮');
const q=(k,a,b)=>Math.round((L[k]-a)/(b-a)*7), dq=(i,a,b)=>a+(b-a)*i/7;
function code(){ let n=0; SL.forEach(([k,,a,b])=>{ n=n*8+Math.max(0,Math.min(7,q(k,a,b))); }); const d=[(n>>18)&63,(n>>12)&63,(n>>6)&63,n&63], c=(d[0]+d[1]*3+d[2]*5+d[3]*7+31)%64; return '🔬 '+d.map(x=>EMO[x]).join('')+EMO[c]; }
function decode(str){ if(!str.includes('🔬')) return null; const e=Array.from(str).filter(ch=>EMO.includes(ch)); if(e.length<5) return null; const d=e.slice(0,4).map(ch=>EMO.indexOf(ch));
  if((d[0]+d[1]*3+d[2]*5+d[3]*7+31)%64!==EMO.indexOf(e[4])) return null; let n=(d[0]<<18)|(d[1]<<12)|(d[2]<<6)|d[3]; const out={};
  for(let i=SL.length-1;i>=0;i--){ const [k,,a,b,st]=SL[i]; const v=dq(n&7,a,b); out[k]=st>=1?Math.round(v):+v.toFixed(2); n>>=3; } return out; }
card.querySelector('#glIn').addEventListener('input',e=>{ const r=decode(e.target.value); if(r){ Object.assign(L,r,{on:true}); e.target.value=''; apply(); sync(); save(); H.say('Someone\'s glass recipe. Ooh.',1500,null,0); emote('🔬'); } });
window.addEventListener('paste',e=>{ const t=(e.clipboardData||window.clipboardData)?.getData('text')||''; const r=decode(t); if(r){ e.preventDefault(); e.stopImmediatePropagation(); Object.assign(L,r,{on:true}); apply(); sync(); save(); H.say('Someone sent you their glass. Applied!',1800,null,0); } },true);
/* apply */
let lastAng=-1;
const isDark=()=>{ const a=document.documentElement.getAttribute('data-theme'); return a?a==='dark':matchMedia('(prefers-color-scheme: dark)').matches; };
function tint(){ return isDark()?'28,26,38':'255,255,255'; }
function apply(){
  stage.classList.toggle('glasslab',L.on);
  const v=(k,x)=>stage.style.setProperty(k,x);
  v('--gl-bf',`${L.refract&&canRefract?'url(#glRefract) ':''}blur(${L.blur}px) saturate(${L.sat})`); v('--gl-frost',L.frost); v('--gl-tint',tint()); v('--gl-rim',L.rim); v('--gl-sh',L.shadow); v('--gl-rad',L.rad+'px'); setAng(L.ang);
}
function applyMenus(){
  stage.classList.toggle('gl-menus',MM.on); stage.classList.toggle('gl-noseps',!MM.seps);
  if(MM.on){ stage.dataset.bar=MM.bPlace; stage.dataset.inner=MM.inner; } else { delete stage.dataset.bar; delete stage.dataset.inner; }
  const v=(k,x)=>stage.style.setProperty(k,x+'px');
  v('--mr-size',MM.rSize); v('--mr-gap',MM.rGap); v('--mr-pad',MM.rPad); v('--mr-icon',MM.rIcon); v('--mr-rad',MM.rRad);
  v('--mb-size',MM.bSize); v('--mb-gap',MM.bGap); v('--mb-pad',MM.bPad); v('--mc-w',MM.cW); v('--mc-pad',MM.cPad); v('--mc-gap',MM.cGap);
  clearLeft=-1; nextClear=0;
}
function setAng(a){ if(Math.abs(a-lastAng)<3) return; lastAng=a; const r=a*Math.PI/180; stage.style.setProperty('--gl-rx',(-Math.cos(r)*1.4).toFixed(2)+'px'); stage.style.setProperty('--gl-ry',(-Math.sin(r)*1.4).toFixed(2)+'px'); }
/* plugin cards sit clear of the rail when it's on the left (checked a few times a second, not every frame) */
const rail=document.getElementById('rail'); let clearLeft=-1, nextClear=0;
function clearRail(){ let x=0;
  if(MM.on&&MM.clear&&rail&&rail.offsetParent&&rail.dataset.edge==='left'){ const r=H.rel(rail); x=Math.round(r.right+12); }
  if(x!==clearLeft){ clearLeft=x; if(x) stage.style.setProperty('--mc-left',x+'px'); else stage.style.removeProperty('--mc-left'); } }
H.frame.push((dt,t)=>{
  if(t>=nextClear){ nextClear=t+400; clearRail(); }
  if(!L.on) return;
  if(L.light==='finger'&&H.now()-H.P.t<4000){ const a=Math.atan2(H.P.y-stage.clientHeight/2,H.P.x-stage.clientWidth/2)*180/Math.PI; setAng((a+360)%360); }
  else if(L.light==='time'){ const h=new Date().getHours()+new Date().getMinutes()/60; setAng(180+(h-6)/12*180); }
  else if(L.light==='fixed') setAng(L.ang); });
/* readability guard: rough contrast of panel text on this glass, with the accent standing in for what's behind */
const hex=c=>{ const m=c.trim().match(/^#?([\da-f]{2})([\da-f]{2})([\da-f]{2})/i); return m?[1,2,3].map(i=>parseInt(m[i],16)):[79,123,232]; };
const lum=([r,g,b])=>{ const f=c=>(c/=255)<=.03928?c/12.92:((c+.055)/1.055)**2.4; return .2126*f(r)+.7152*f(g)+.0722*f(b); };
function sync(){
  card.querySelectorAll('#glTabs button').forEach(b=>b.classList.toggle('on',b.dataset.tab===tab));
  card.querySelector('#glTabGlass').hidden=tab!=='glass'; card.querySelector('#glTabMenus').hidden=tab!=='menus';
  const setR=(r,v)=>{ r.value=v; r.style.setProperty('--pct',(r.value-r.min)/(r.max-r.min)*100+'%'); };   /* keep the sandbox's slider fill in step */
  SL.forEach(([k,,,,,fmt])=>{ setR(card.querySelector('#gl-'+k),L[k]); card.querySelector('#glo-'+k).textContent=fmt(+L[k]); });
  [...MSL.rail,...MSL.bar,...MSL.card].forEach(([k,,,,,fmt])=>{ setR(card.querySelector('#mn-'+k),MM[k]); card.querySelector('#mno-'+k).textContent=fmt(+MM[k]); });
  const tg=(id,on,a,b)=>{ const x=card.querySelector(id); x.textContent=on?a:b; x.classList.toggle('on',on); };
  tg('#glOn',L.on,'Lab on','Lab off'); tg('#mnOn',MM.on,'Custom menus','Menus as built');
  tg('#mnSeps',MM.seps,'Separators shown','Separators hidden'); tg('#mnClear',MM.clear,'Cards clear the rail','Cards over the rail');
  card.querySelectorAll('#mnPlace button').forEach(b=>b.classList.toggle('on',b.dataset.place===MM.bPlace));
  card.querySelectorAll('#mnInner button').forEach(b=>b.classList.toggle('on',b.dataset.inner===MM.inner));
  card.querySelectorAll('#glLight button').forEach(b=>b.classList.toggle('on',b.dataset.l===L.light));
  const rb=card.querySelector('#glRef'); rb.textContent=canRefract?(L.refract?'Refraction: on':'Refraction: off'):'Refraction: not in this browser'; rb.disabled=!canRefract; rb.classList.toggle('on',L.refract&&canRefract);
  const dark=isDark(), base=dark?[28,26,38]:[255,255,255], acc=hex(getComputedStyle(document.documentElement).getPropertyValue('--accent'));
  const bg=base.map((c,i)=>c*L.frost+acc[i]*(1-L.frost)), ink=dark?[246,244,251]:[23,22,30], a=lum(bg), b=lum(ink), cr=(Math.max(a,b)+.05)/(Math.min(a,b)+.05);
  const w=card.querySelector('#glWarn'); w.textContent=cr>=4.5?`Text contrast about ${cr.toFixed(1)}:1. Readable.`:cr>=3?`Text contrast about ${cr.toFixed(1)}:1. Borderline.`:`Text contrast about ${cr.toFixed(1)}:1. Hard to read. More frost helps.`;
  w.className='gl-warn '+(cr>=4.5?'ok':'bad');
  card.querySelector('#glCode').textContent=code();
}
apply(); applyMenus(); window.PipGlassLab={L,apply,applyMenus,code,decode,open:t=>{ tab=t||'glass'; if(card.hidden) PB.toggle(card,btn); sync(); }};

})();
