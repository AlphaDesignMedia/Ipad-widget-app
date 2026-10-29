/* =====================================================================
  PIP GUIDE · plugin v1
  Pip as the guide: flies to each new thing, lights it up and explains it.
  Tap Pip to go to the next step. Chattiness 0 (Pip's panel) means no tours.
  Adds a "Plugins and cost" tour, offered once when Pip is awake, and always
  available from Plugins → Pip's tours. Other plugins can push their own
  tours to PipHost.tours the same way.
  ===================================================================== */
(() => {
const PIP_GUIDE={
  offer:true,        // offer the tour once, the first time Pip is awake
  offerAfterMs:4000  // wait this long after load before offering
};
const H=window.PipHost;
if(!H||!H.tour){ console.warn('Pip Guide: needs PipHost with tours (host.js).'); return; }
const {N,stage}=H;

const css=document.createElement('style'); css.textContent=`
.pip-spot{outline:2px solid var(--accent) !important;outline-offset:3px;box-shadow:0 0 0 7px color-mix(in srgb, var(--accent) 22%, transparent) !important;transition:outline-offset .3s, box-shadow .3s}
@media (prefers-reduced-motion: reduce){ .pip-spot{transition:none} }`;
document.head.appendChild(css);

/* light up one thing at a time, scroll it into view and fly Pip beside it */
let lit=null;
function spot(get){
  lit?.classList.remove('pip-spot'); lit=null;
  const el=typeof get==='function'?get():get?document.querySelector(get):null; if(!el) return;
  el.classList.add('pip-spot'); lit=el; el.scrollIntoView({block:'nearest',behavior:'smooth'});
  setTimeout(()=>{ if(lit!==el) return; const r=H.rel(el);
    const left=r.left>N.r*2+40, x=left?r.left-N.r-16:r.right+N.r+16;
    H.travel(H.clamp(x,N.r,stage.clientWidth-N.r),H.clamp(r.top+22,70,stage.clientHeight-N.r),380,'free'); },320);
}
const card=id=>()=>document.querySelector(`[data-cost="${id}"]`)?.closest('.plug');
const panel=()=>document.getElementById('plList')?.closest('.panel')||document.getElementById('plList')?.parentElement;
const emote=(c,o)=>window.PipSpatial?.emote(c,o);

const STEPS=[
  {act:()=>{ H.openPanel('plugins'); setTimeout(()=>spot(panel),120); emote('🔌',{pri:3}); },
   say:'New: the Plugins panel. Every add-on I’m wearing lives here, each with its own on/off switch.'},
  {act:()=>spot('#plBar'),
   say:'This bar is one frame: 16.7 milliseconds. Grey is me and the sandbox, blue is plugins. The rest is spare.'},
  {act:()=>{ spot(card('pip-spatial')); emote('💡',{pri:3}); },
   say:'Pip Spatial is my thinking cap. Push me slowly into a panel and I sneak behind. Flick me hard and I hop over.'},
  {act:()=>{ spot(card('panel-flap')); emote('🕹️',{pri:3}); },
   say:'Panel Flap turns a broken clock into a game. Crash it from Developer, then tap to flap round it.'},
  {act:()=>spot('#plCopy'),
   say:'Copy cost report grabs these numbers for Claude. Too chatty? Turn my Chattiness down in my panel.'},
  {act:()=>{ spot(null); setTimeout(()=>H.goHome(),2600); emote('👋',{pri:3}); },
   say:'That’s the tour. Find it again under Pip’s tours. Off you go!'}
];
function start(){ return H.tour(STEPS,'I’ve got new tricks to show you. Tap me to start.'); }
window.addEventListener('pip:tourEnd',()=>spot(null));
H.tours.push({id:'plugins-cost',name:'Plugins and cost',start});

/* offer once, when Pip is awake and not busy */
let t0=0, offered=false; try{ offered=localStorage.getItem('gs2-guide-offered')==='1'; }catch{}
H.frame.push((dt,t)=>{
  if(offered||!PIP_GUIDE.offer) return; if(!t0) t0=t;
  if(t-t0<PIP_GUIDE.offerAfterMs||!N.awake||H.touring()||H.G.on||H.chat()<1) return;
  if(start()){ offered=true; try{ localStorage.setItem('gs2-guide-offered','1'); }catch{} }
});
window.PipGuide={config:PIP_GUIDE,start,spot};
})();
