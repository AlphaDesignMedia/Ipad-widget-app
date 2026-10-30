/* =====================================================================
  PIP CAM · plugin v1
  Loaded by the sandbox loader (see PLUGINS in index.html). Needs window.PipHost (host.js).
  Works on its own. Plays nicely with the other plugins; with Spatial installed,
  Pip also reacts with emoji bubbles.
  Where: 📷 in the plugin bar

  A tiny photo booth. Pip poses, the screen flashes, and you get a crayon-style polaroid of your
  layout, clock and Pip, with a caption. Keep up to 6 in an album on this device.

  Switch it off in the Plugins panel, or remove it from PLUGINS.
  =====================================================================
*/
(() => {
const H=window.PipHost;
if(!H||!H.openPanel){ console.warn('PIP CAM: needs Pip Sandbox V2 stage 11.5 or later.'); return; }
const {N,S,stage,navi}=H;
if(H.registerPlugin&&!H.registerPlugin({id:'cam',name:'Pip Cam',icon:'📷',shelf:'trial',desc:'A photo booth with crayon polaroids.'})) return;
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

/* A tiny photo booth: Pip poses, and you get a crayon polaroid of your layout. Up to 6 kept in an album. */
const card=PB.card(`<h3>📷 Pip Cam</h3><div id="camShot"></div><div class="pr"><button class="pc" id="camSnap">Take a photo</button><button class="pc" id="camKeep" disabled>Keep it</button></div><div class="pr" id="camAlbum"></div><p>Photos stay on this device.</p>`);
const btn=PB.button('📷','Pip Cam',()=>{ if(PB.toggle(card,btn)) album(); });
const st=document.createElement('style'); st.textContent=`.camflash{position:absolute;inset:0;z-index:50;background:#fff;pointer-events:none;animation:camF .5s ease-out forwards}@keyframes camF{from{opacity:.9}to{opacity:0}}
#camShot canvas,#camAlbum img{display:block;width:100%;border-radius:4px;box-shadow:0 6px 18px rgba(0,0,0,.18)}#camAlbum img{width:60px;cursor:pointer}`; document.head.appendChild(st);
let last=null;
const jit=(v,a=2.2)=>v+(Math.random()-.5)*a;
function crayonRect(c,x,y,w,h,col){ c.strokeStyle=col; c.lineWidth=2.4; c.lineJoin='round'; for(let k=0;k<2;k++){ c.beginPath(); c.moveTo(jit(x),jit(y)); c.lineTo(jit(x+w),jit(y)); c.lineTo(jit(x+w),jit(y+h)); c.lineTo(jit(x),jit(y+h)); c.closePath(); c.stroke(); } }
function snap(){
  const W=stage.clientWidth, Hh=stage.clientHeight, s=280/W, cv=document.createElement('canvas'); cv.width=300; cv.height=Math.round(Hh*s)+56; const c=cv.getContext('2d');
  const acc=getComputedStyle(document.documentElement).getPropertyValue('--accent').trim()||'#4f7be8';
  c.fillStyle='#fdfcf7'; c.fillRect(0,0,cv.width,cv.height);
  c.save(); c.translate(10,10); c.fillStyle=acc; c.globalAlpha=.16; c.fillRect(0,0,280,Hh*s); c.globalAlpha=1;
  for(let i=0;i<260;i++){ c.fillStyle=`rgba(0,0,0,${Math.random()*.03})`; c.fillRect(Math.random()*280,Math.random()*Hh*s,2,2); }
  H.openEls().forEach(p=>{ const r=H.rel(p); c.fillStyle='rgba(255,255,255,.55)'; c.fillRect(r.left*s,r.top*s,r.width*s,r.height*s); crayonRect(c,r.left*s,r.top*s,r.width*s,r.height*s,'#5a6170');
    for(let k=0;k<3;k++){ c.strokeStyle='#9aa0ad'; c.lineWidth=1.6; c.beginPath(); const yy=r.top*s+16+k*12; c.moveTo(r.left*s+8,jit(yy)); c.lineTo(r.left*s+r.width*s*(.5+Math.random()*.35),jit(yy)); c.stroke(); } });
  const cr=H.cardRect(); c.fillStyle=acc; c.globalAlpha=.7; c.fillRect(cr.left*s,cr.top*s,cr.width*s,cr.height*s); c.globalAlpha=1; crayonRect(c,cr.left*s,cr.top*s,cr.width*s,cr.height*s,'#2b3040');
  c.fillStyle='#fff'; c.font=`bold ${Math.round(cr.height*s*.55)}px "Comic Neue","Comic Sans MS",cursive`; c.textAlign='center'; c.textBaseline='middle';
  c.fillText(document.getElementById('time').getAttribute('aria-label')||document.getElementById('time').textContent,(cr.left+cr.width/2)*s,(cr.top+cr.height*.58)*s);
  if(S.naviOn){ const x=N.x*s, y=N.y*s, r=Math.max(7,N.r*s*1.6); c.fillStyle=acc; c.beginPath(); c.arc(x,y,r,0,7); c.fill(); c.strokeStyle='#2b3040'; c.lineWidth=2; c.beginPath(); c.arc(jit(x,1),jit(y,1),r,0,7); c.stroke();
    c.fillStyle='#1d1830'; c.fillRect(x-r*.35,y-r*.25,2.5,4); c.fillRect(x+r*.2,y-r*.25,2.5,4); c.beginPath(); c.arc(x,y+r*.2,r*.35,.2,Math.PI-.2); c.stroke(); }
  c.restore();
  c.fillStyle='#3a3f4c'; c.font='18px "Comic Neue","Comic Sans MS",cursive'; c.textAlign='left'; c.fillText(`${S.name} & you · ${new Date().toLocaleDateString('en-GB',{day:'numeric',month:'short'})}`,14,cv.height-20);
  return cv;
}
card.querySelector('#camSnap').addEventListener('click',()=>{
  if(S.naviOn){ if(!N.awake) H.wake(); N.lookPt=null; N.squash=.25; N.hopT=H.now(); emote(H.pick(['😁','✌️','📸']),{pri:3}); H.say(H.pick(['Cheese!','Get my good side.','Say tea!']),1100,null,1); }
  setTimeout(()=>{ const f=document.createElement('i'); f.className='camflash'; stage.appendChild(f); setTimeout(()=>f.remove(),600); H.beep([[1800,30],[0,30],[900,60]]);
    last=snap(); const box=card.querySelector('#camShot'); box.innerHTML=''; box.appendChild(last); card.querySelector('#camKeep').disabled=false; },650);
});
card.querySelector('#camKeep').addEventListener('click',()=>{ if(!last) return; const a=H.store.get('plug-album',[]); a.unshift(last.toDataURL('image/jpeg',.7)); H.store.set('plug-album',a.slice(0,6)); card.querySelector('#camKeep').disabled=true; album(); H.say('Into the album it goes.',1400,null,1); });
function album(){ const a=H.store.get('plug-album',[]); card.querySelector('#camAlbum').innerHTML=a.map((u,i)=>`<img src="${u}" alt="Photo ${i+1}" data-i="${i}">`).join(''); }
card.querySelector('#camAlbum').addEventListener('click',e=>{ const im=e.target.closest('img'); if(!im) return; const box=card.querySelector('#camShot'); box.innerHTML=''; const big=new Image(); big.src=im.src; big.style.width='100%'; big.style.borderRadius='4px'; box.appendChild(big); });

})();
