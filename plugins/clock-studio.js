/* =====================================================================
  ⏱️ CLOCK STUDIO · super plugin v1   (Dream shelf)
  Loaded by the sandbox loader (see PLUGINS in index.html).
  Where: ⏱️ in the plugin bar, or "⏱️ Clock Studio" at the top of the Clock panel.
  Studio draws its own face inside the clock card; drag, pinch, cracks, the 404 game and
  Pip's perch all still work. Switch it off (top-right switch) to get the sandbox face back.
  STYLE   12 presets (Today, Pane 1887, Station, Flip '74, Odometer, Night Stand, Poster, Words,
          Pixel Pal, Liquid, Gumdrop, Ghost) · 7 faces: Digital, Flip (split-flap), Roll (odometer),
          Analog (minimal / railway / roman / numbers / bare dial, sweeping seconds), Segments, Dots, Words
          · My clocks: save up to 12, long-press to delete
  TYPE    12 fonts (Recursive and Fraunces have live Casual / Softness axes) · size, weight, width,
          slant, spacing · leading zero, seconds, separator, blinking, am/pm
  COLOUR  card: Auto (follows your Look), Solid, Gradient, Tinted glass, Sky (changes through the day),
          No card · corners, shadow, glass edge · ink + accent · contrast check · 7 text effects
          (drop, glow, outline, pressed, gradient, glass letters) · night dimming
  EXTRAS  above / below the time: date (5 styles), second time zone, day progress, moon phase,
          countdown ("Tea in 1h 12m"), week number, your own text
  MOTION  digit changes: fade, slide, blur, drop, glitch · breathing glow · hourly chime or Pip says the time
  SHARE   every setting packs into one ⏱️ emoji code, written in a random emoji set each time
          (fruit, animals, sea, toys); all decode to the same clock. Paste a code anywhere to apply.
  ↶ ↷ undo / redo · 🎲 Surprise me (a random clock with a contrast check, and Pip names it)
  Uses Google Fonts for the extra fonts, loaded only when picked; offline falls back to system fonts.
  Sandbox notes (Claude, 29 Oct): naming a saved clock uses a field in the card (pop-up prompts are
  blocked inside the Claude app); scrolling over a saved clock no longer deletes it; a once-only
  welcome lives in the 📮 Updates plugin.
  Switch it off in the Plugins panel, or remove it from PLUGINS.
  ===================================================================== */
(() => {
const H=window.PipHost;
if(!H||!H.registerPlugin){ console.warn('Clock Studio: needs Pip Sandbox V2 stage 12 or later.'); return; }
const {N,S,stage,navi}=H;
if(!H.registerPlugin({id:'clockstudio',name:'Clock Studio',icon:'⏱️',shelf:'dream',desc:'Seven faces, twelve fonts, cards, effects, complications, motion, presets, Surprise me and emoji share codes.'})) return;
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
/* CLOCK STUDIO: draws its own face inside the clock card. The card keeps everything else
   (drag, pinch, cracks, Pip's perch); the sandbox's own time and date are hidden while Studio is on. */
const cardIn=H.cardIn;
const DEF={on:false,mode:'digital',font:'host',size:100,wght:650,wd:100,slant:0,track:-2,casual:0,soft:0,lead:false,secs:false,sep:':',blink:false,ampm:'none',
  ink:'auto',inkB:'#ffd36e',fill:'auto',fillA:'#4f7be8',fillB:'#9cc0ff',ang:160,frost:26,opa:64,rad:30,border:true,shadow:3,fx:'none',
  dial:'minimal',sweep:true,words:'fuzzy',top:'date',bottom:'none',dateFmt:'short',zone:'Asia/Tokyo',cdLabel:'Tea',cdAt:'16:00',text:'Hello',
  trans:'slide',breathe:false,chime:'none',night:false};
let CS=Object.assign({},DEF,H.store.get('cs-cfg',{}));
const save=()=>H.store.set('cs-cfg',CS);

/* ---------- fonts (Google fonts only load when you pick one) ---------- */
const FONTS={host:['Sandbox','var(--clockf)'],system:['System','var(--f-system)'],rounded:['Rounded','var(--f-rounded)'],serif:['Serif','var(--f-serif)'],
  mono:['Mono','ui-monospace,"SF Mono",Menlo,monospace'],rec:['Recursive','"Recursive",system-ui,sans-serif','Recursive:slnt,wght,CASL,MONO@-15..0,300..1000,0..1,0..1'],
  fraunces:['Fraunces','"Fraunces",Georgia,serif','Fraunces:opsz,wght,SOFT,WONK@9..144,100..900,0..100,0..1'],bebas:['Poster','"Bebas Neue",Impact,"Arial Narrow",sans-serif','Bebas+Neue'],
  grotesk:['Grotesk','"Space Grotesk",system-ui,sans-serif','Space+Grotesk:wght@300..700'],didone:['Didone','"DM Serif Display",Didot,Georgia,serif','DM+Serif+Display'],
  pixel:['Pixel','"Silkscreen","Pixelify Sans",monospace','Silkscreen'],hand:['Hand','"Caveat","Bradley Hand","Segoe Print",cursive','Caveat:wght@400..700']};
const loaded=new Set();
function loadFont(k){ const g=FONTS[k]?.[2]; if(!g||loaded.has(g)) return; loaded.add(g);
  const l=document.createElement('link'); l.rel='stylesheet'; l.href='https://fonts.googleapis.com/css2?family='+g+'&display=swap'; document.head.appendChild(l); }

/* ---------- styles ---------- */
const css=document.createElement('style'); css.textContent=`
.card-in.cs-on>#time,.card-in.cs-on>#date{display:none !important}
.card.broken .cs-face{display:none}
.cs-note{display:none;margin:0}
.stage.cs-studio-on #p-clock .pb>:has(#cDate){display:none}
.cs-main:has(.cs-flip){align-items:center}
.stage.cs-studio-on #p-clock .cs-note{display:block}
.stage.cs-studio-on #p-clock .drill:is([data-open="face"],[data-open="fonts"],[data-open="share"]){display:none}
.card-in.cs-on{width:auto !important;min-width:min(220px,60vw);padding:12px 22px 18px}
.cs-face{display:grid;justify-items:center;gap:2px;color:var(--cs-ink,inherit);font-family:var(--cs-font);font-weight:var(--cs-wght);
  font-variation-settings:'wght' var(--cs-wght),'slnt' calc(var(--cs-slant) * -1),'CASL' var(--cs-casual),'SOFT' var(--cs-soft);user-select:none;-webkit-user-select:none}
.cs-main{font-size:calc(min(125px, calc(var(--sw,100vw) * .259)) * var(--cs-size));line-height:.98;letter-spacing:var(--cs-track);font-variant-numeric:tabular-nums;white-space:nowrap;
  display:flex;align-items:baseline;justify-content:center;transform:scaleX(var(--cs-wd)) skewX(var(--cs-skew));text-shadow:0 1px 0 rgba(255,255,255,.2),0 10px 26px rgba(0,0,0,.14)}
.cs-ch{display:inline-block;min-width:.1em;text-align:center}
.cs-sep{display:inline-block;padding:0 .02em}
.cs-face.blink .cs-sep{animation:csBlink 1s steps(1) infinite}
@keyframes csBlink{50%{opacity:.15}}
.cs-ampm{font-size:.24em;margin-left:.12em;letter-spacing:.02em;opacity:.85}
.cs-secs{font-size:.42em;margin-left:.08em;opacity:.8}
.cs-comp{font:500 calc(17.7px * var(--cs-size)) / 1.3 var(--ui);font-family:var(--cs-font);opacity:.9;font-variation-settings:inherit;max-width:min(90vw,520px);text-align:center;transform:skewX(var(--cs-skew))}
.cs-comp:empty{display:none}
.cs-prog{display:grid;gap:4px;justify-items:center}.cs-prog em{display:block;width:min(200px,50vw);height:6px;border-radius:3px;background:rgba(255,255,255,.25);overflow:hidden}.cs-prog em i{display:block;height:100%;background:currentColor;border-radius:3px}
/* effects */
.cs-face.fx-glow .cs-main{text-shadow:0 0 .08em var(--cs-glow),0 0 .3em var(--cs-glow)}
.cs-face.fx-outline .cs-main{-webkit-text-stroke:.025em currentColor;color:transparent;text-shadow:none}
.cs-face.fx-emboss .cs-main{color:color-mix(in srgb,var(--cs-ink,#fff) 80%,#000);text-shadow:0 1px 0 rgba(255,255,255,.55),0 -1px 0 rgba(0,0,0,.35)}
.cs-face.fx-gradient .cs-main .cs-ch,.cs-face.fx-gradient .cs-main .cs-sep{background:linear-gradient(180deg,var(--cs-ink,#fff),var(--cs-inkB));-webkit-background-clip:text;background-clip:text;color:transparent}
.cs-face.fx-gradient .cs-main{text-shadow:none}
.cs-face.fx-glass .cs-main{color:rgba(255,255,255,.28);-webkit-text-stroke:.012em rgba(255,255,255,.85);text-shadow:0 .03em .06em rgba(0,0,0,.18),0 -.01em 0 rgba(255,255,255,.6)}
.cs-face.fx-shadow .cs-main{text-shadow:.04em .05em 0 color-mix(in srgb,var(--cs-inkB) 85%,transparent)}
.cs-face.breathe .cs-main{animation:csBreathe 6s ease-in-out infinite}
@keyframes csBreathe{50%{opacity:.82;filter:brightness(1.12)}}
/* card fills (only when not Auto) */
.card-in.cs-on.cs-own{border-radius:var(--cs-rad) !important;box-shadow:inset 0 1px 0 rgba(255,255,255,.4),0 calc(var(--cs-shd) * 6px) calc(var(--cs-shd) * 16px) rgba(0,0,0,calc(var(--cs-shd) * .06)) !important}
.card-in.cs-on.cs-noborder{border-color:transparent !important}
.card-in.cs-on.cs-fill-solid{background:var(--cs-a) !important}
.card-in.cs-on.cs-fill-gradient,.card-in.cs-on.cs-fill-sky{background:linear-gradient(var(--cs-ang),var(--cs-a),var(--cs-b)) !important}
.card-in.cs-on.cs-fill-glass{background:color-mix(in srgb,var(--cs-a) calc(var(--cs-opa) * 1%),transparent) !important;-webkit-backdrop-filter:blur(var(--cs-frost)) saturate(1.6) !important;backdrop-filter:blur(var(--cs-frost)) saturate(1.6) !important}
.card-in.cs-on.cs-fill-clear{background:transparent !important;border-color:transparent !important;box-shadow:none !important;-webkit-backdrop-filter:none !important;backdrop-filter:none !important}
.card-in.cs-on.cs-night{filter:brightness(.55) sepia(.35) hue-rotate(-20deg) saturate(1.6)}
/* flip */
.cs-flip{position:relative;display:inline-block;width:.68em;height:1em;margin:0 .03em;border-radius:.09em;background:var(--cs-tile);perspective:3em;line-height:1em}
.cs-flip>span{position:absolute;left:0;right:0;height:.5em;overflow:hidden;background:inherit;border-radius:.09em .09em 0 0}
.cs-flip>span b{display:block;height:1em;line-height:1em;text-align:center;font-weight:inherit}
.cs-flip>.dn,.cs-flip>.fd{top:.5em;border-radius:0 0 .09em .09em}.cs-flip>.dn b,.cs-flip>.fd b{margin-top:-.5em}
.cs-flip>.up,.cs-flip>.fu{top:0}
.cs-flip>.fu{transform-origin:50% 100%;z-index:2}.cs-flip>.fd{transform-origin:50% 0;z-index:2}
.cs-flip::after{content:"";position:absolute;left:0;right:0;top:calc(.5em - .5px);height:1px;background:rgba(0,0,0,.35);z-index:3}
/* roll */
.cs-roll{display:inline-block;height:1em;overflow:hidden;line-height:1em}
.cs-roll>span{display:block;transition:transform .7s cubic-bezier(.2,1.25,.4,1)}
.cs-roll>span b{display:block;height:1em;font-weight:inherit}
/* analog */
.cs-analog{width:calc(190px * var(--cs-size));height:calc(190px * var(--cs-size));margin:4px 0}
.cs-analog text{font-family:var(--cs-font);font-weight:var(--cs-wght)}
/* segments, dots */
.cs-seg{display:flex;align-items:center;gap:.08em;height:1em;transform:skewX(var(--cs-skew))}
.cs-seg svg{height:1em;width:.6em;overflow:visible}
.cs-seg .off{opacity:.09}.cs-seg .on{filter:drop-shadow(0 0 .04em var(--cs-glow))}
.cs-dots{display:flex;gap:.09em;align-items:center}
.cs-dg{display:grid;grid-template-columns:repeat(5,.1em);grid-auto-rows:.1em;gap:.025em}
.cs-dg i{border-radius:50%;background:currentColor;opacity:.1}.cs-dg i.on{opacity:1;box-shadow:0 0 .05em var(--cs-glow)}
/* words */
.cs-words{font-size:calc(min(52px, calc(var(--sw,100vw) * .11)) * var(--cs-size));line-height:1.04;white-space:normal;max-width:min(78vw,560px);text-wrap:balance;text-align:center;display:block;letter-spacing:var(--cs-track)}
.cs-words b{color:var(--cs-inkB);font-weight:inherit}
/* the Studio card */
.stage .plugcard.cs-card{width:min(390px,calc(100% - 32px));gap:10px}
.cs-top{display:flex;gap:6px;align-items:center;flex-wrap:wrap}
.cs-top .sp{flex:1}
.cs-tabs{display:flex;gap:2px;padding:3px;border-radius:999px;background:var(--wash);overflow-x:auto;scrollbar-width:none}
.cs-tabs button{flex:1 0 auto;min-height:32px;border:0;border-radius:999px;background:transparent;color:var(--ink2);font:600 12.5px/1 var(--ui);cursor:pointer;padding:0 10px}
.cs-tabs button[aria-pressed="true"]{background:var(--glass-strong);color:var(--ink);box-shadow:0 1px 3px var(--shade)}
.cs-l{font:700 11px/1 var(--ui);letter-spacing:.06em;text-transform:uppercase;color:var(--ink3);margin-top:4px}
.cs-sl{display:grid;gap:5px;font:500 13px/1.2 var(--ui)}
.cs-sl div{display:flex;justify-content:space-between}.cs-sl output{color:var(--ink3);font-variant-numeric:tabular-nums}
.cs-row{display:flex;justify-content:space-between;align-items:center;gap:10px;font:500 13.5px/1.3 var(--ui)}
.cs-col{display:flex;gap:8px;align-items:center;font:500 13px/1 var(--ui)}
.cs-col input[type=color]{width:38px;height:30px;border:0;border-radius:8px;padding:0;background:none;cursor:pointer}
.cs-presets{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}
.cs-pre{display:grid;gap:5px;border:0;background:none;padding:0;cursor:pointer;color:var(--ink);font:600 12px/1.1 var(--ui);text-align:center}
.cs-pre i{display:grid;place-items:center;height:46px;border-radius:12px;font-style:normal;font-weight:700;font-size:19px;letter-spacing:-.02em;box-shadow:inset 0 0 0 1px var(--hair)}
.cs-pre[aria-pressed="true"] i{box-shadow:0 0 0 3px var(--accent)}
.cs-code{font:400 20px/1.35 system-ui;word-break:break-all;padding:8px 10px;border-radius:12px;background:var(--wash);user-select:all;-webkit-user-select:all}
.cs-card textarea,.cs-card input.cs-in,.cs-card select{min-height:36px;border:1px solid var(--hair);border-radius:10px;background:var(--wash);padding:6px 10px;font:500 14px var(--ui);color:var(--ink);box-sizing:border-box;width:100%}
.cs-card textarea{min-height:60px;resize:vertical}
.cs-mine{display:flex;flex-wrap:wrap;gap:6px}
@media (prefers-reduced-motion: reduce){ .cs-roll>span{transition:none} .cs-face.breathe .cs-main,.cs-face.blink .cs-sep{animation:none} }`;
document.head.appendChild(css);

/* ---------- time helpers ---------- */
const pad=n=>String(n).padStart(2,'0');
const NUM=['twelve','one','two','three','four','five','six','seven','eight','nine','ten','eleven','twelve','thirteen','fourteen','quarter','sixteen','seventeen','eighteen','nineteen'];
const TENS=['','','twenty','thirty','forty','fifty'];
const say2=n=>n<20?(n===15?'fifteen':NUM[n]||'zero'):TENS[Math.floor(n/10)]+(n%10?'-'+NUM[n%10]:'');
function wordsFor(d){
  const h=d.getHours(), m=d.getMinutes(), hw=k=>NUM[(k%12)||12]==='twelve'&&k%24===0?'midnight':NUM[(k%12)||12];
  if(CS.words==='exact') return m===0?`<b>${hw(h)}</b> o'clock`:`<b>${hw(h)}</b> ${m<10?'oh-'+NUM[m]:say2(m)}`;
  const r=Math.round(m/5)*5, nh=r>30?h+1:h, H=`<b>${hw(r===60?h+1:nh)}</b>`;
  const pre=m%5===0?'It\'s':Math.abs(m-r)<=2&&m<r?'It\'s nearly':'It\'s just gone';
  if(r===0||r===60) return `${pre} ${H}${hw(r===60?h+1:nh)==='midnight'?'':' o\'clock'}`;
  if(r===30) return `${pre} half past ${H}`;
  const k=r<30?r:60-r, w=k===15?'quarter':k===5?'five':k===10?'ten':k===20?'twenty':'twenty-five';
  return `${pre} ${w} ${r<30?'past':'to'} ${H}`;
}
function parts(d){
  const h24=H.S.h24, hr=h24?d.getHours():(d.getHours()%12||12);
  return {h:CS.lead||h24?pad(hr):String(hr), m:pad(d.getMinutes()), s:pad(d.getSeconds()), ap:d.getHours()<12?'AM':'PM'};
}
function moon(d){ const syn=29.530588853, p=(((d-Date.UTC(2000,0,6,18,14))/864e5)%syn+syn)%syn/syn, i=Math.round(p*8)%8;
  return ['🌑 New moon','🌒 Waxing crescent','🌓 First quarter','🌔 Waxing gibbous','🌕 Full moon','🌖 Waning gibbous','🌗 Last quarter','🌘 Waning crescent'][i]; }
function week(d){ const t=new Date(Date.UTC(d.getFullYear(),d.getMonth(),d.getDate())), n=t.getUTCDay()||7; t.setUTCDate(t.getUTCDate()+4-n); return Math.ceil(((t-Date.UTC(t.getUTCFullYear(),0,1))/864e5+1)/7); }
const ZONES=['Europe/London','Europe/Paris','America/New_York','America/Los_Angeles','America/Sao_Paulo','Asia/Dubai','Asia/Kolkata','Asia/Singapore','Asia/Tokyo','Australia/Sydney','Pacific/Auckland','Africa/Johannesburg'];
const city=z=>z.split('/').pop().replace(/_/g,' ');
function comp(kind,d){
  if(kind==='date'){ const f={short:{weekday:'short',day:'numeric',month:'short'},long:{weekday:'long',day:'numeric',month:'long'},numeric:{day:'2-digit',month:'2-digit',year:'2-digit'},day:{weekday:'long'}}[CS.dateFmt];
    return CS.dateFmt==='iso'?`${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}`:d.toLocaleDateString('en-GB',f).replace(',',''); }
  if(kind==='zone'){ try{ const t=d.toLocaleTimeString('en-GB',{timeZone:CS.zone,hour:'2-digit',minute:'2-digit',hour12:!H.S.h24}); return `${city(CS.zone)} ${t}`; }catch{ return ''; } }
  if(kind==='progress'){ const p=Math.round((d.getHours()*60+d.getMinutes())/14.4); return `<span class="cs-prog"><em><i style="width:${p}%"></i></em><span>${p}% of today</span></span>`; }
  if(kind==='moon') return moon(d);
  if(kind==='week') return 'Week '+week(d);
  if(kind==='countdown'){ const [th,tm]=(CS.cdAt||'16:00').split(':').map(Number), t=new Date(d); t.setHours(th||0,tm||0,0,0); if(t<d-60000) t.setDate(t.getDate()+1);
    const mins=Math.round((t-d)/60000), lab=esc(CS.cdLabel||'It'); return mins<=0?`${lab} time!`:`${lab} in ${mins>=60?Math.floor(mins/60)+'h ':''}${mins%60}m`; }
  if(kind==='text') return esc(CS.text||'');
  return '';
}
const esc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'})[c]);

/* ---------- the face ---------- */
const face=document.createElement('div'); face.className='cs-face'; face.setAttribute('role','timer');
face.innerHTML='<div class="cs-comp top"></div><div class="cs-main"></div><div class="cs-comp bot"></div>';
cardIn.insertBefore(face,document.getElementById('err'));
const mainEl=face.querySelector('.cs-main'), topEl=face.querySelector('.top'), botEl=face.querySelector('.bot');
let built='', prevStr='';
const DOTS={0:'01110100011001110101110011000101110',1:'00100011000010000100001000010001110',2:'01110100010000100010001000100011111',3:'11111000100010000010000011000101110',
  4:'00010001100101010010111110001000010',5:'11111100001111000001000011000101110',6:'00110010001000011110100011000101110',7:'11111000010001000100010000100001000',
  8:'01110100011000101110100011000101110',9:'01110100011000101111000010001001100'};
const SEG={0:'abcdef',1:'bc',2:'abged',3:'abgcd',4:'fgbc',5:'afgcd',6:'afgedc',7:'abc',8:'abcdefg',9:'abcdfg'};
const SEGR={a:[14,2,32,8],b:[48,12,8,33],c:[48,55,8,33],d:[14,90,32,8],e:[4,55,8,33],f:[4,12,8,33],g:[14,46,32,8]};
const segSvg=ch=>`<svg viewBox="0 0 60 100" aria-hidden="true">${Object.entries(SEGR).map(([k,[x,y,w,h]])=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="4" fill="currentColor" class="${SEG[ch]?.includes(k)?'on':'off'}"/>`).join('')}</svg>`;
const segColon=()=>`<svg viewBox="0 0 20 100" style="width:.2em" aria-hidden="true"><circle cx="10" cy="32" r="5" fill="currentColor" class="on cs-sepc"/><circle cx="10" cy="70" r="5" fill="currentColor" class="on cs-sepc"/></svg>`;
const dotsFor=ch=>`<span class="cs-dg">${(DOTS[ch]||'').split('').map(b=>`<i class="${b==='1'?'on':''}"></i>`).join('')}</span>`;
const dotColon=()=>`<span class="cs-dg" style="grid-template-columns:.1em">${'0010100'.split('').map(b=>`<i class="${b==='1'?'on':''}"></i>`).join('')}</span>`;
function animIn(el){
  if(H.simpler()||CS.trans==='none'||!el.animate) return;
  const k={fade:[{opacity:0},{opacity:1}],slide:[{transform:'translateY(-.35em)',opacity:0},{transform:'none',opacity:1}],blur:[{filter:'blur(.12em)',opacity:.2},{filter:'none',opacity:1}],
    drop:[{transform:'translateY(-.6em)'},{transform:'translateY(.06em)',offset:.7},{transform:'none'}],glitch:[{transform:'translateX(.06em)',opacity:.4},{transform:'translateX(-.05em)'},{transform:'translateX(.03em)',opacity:.8},{transform:'none',opacity:1}]}[CS.trans];
  if(k) el.animate(k,{duration:CS.trans==='glitch'?260:420,easing:CS.trans==='glitch'?'steps(4)':'cubic-bezier(.2,1,.4,1)'});
}
function flipTo(el,ch){
  const old=el.dataset.v; if(old===ch) return; el.dataset.v=ch;
  const up=el.querySelector('.up b'), dn=el.querySelector('.dn b');
  if(H.simpler()||old==null){ up.textContent=dn.textContent=ch; return; }
  const fu=document.createElement('span'); fu.className='fu'; fu.innerHTML=`<b>${old}</b>`;
  const fd=document.createElement('span'); fd.className='fd'; fd.innerHTML=`<b>${ch}</b>`; fd.style.transform='rotateX(90deg)';
  up.textContent=ch; el.append(fu,fd);
  fu.animate([{transform:'rotateX(0)'},{transform:'rotateX(-90deg)',filter:'brightness(.7)'}],{duration:220,easing:'ease-in',fill:'forwards'}).onfinish=()=>{
    fu.remove(); fd.animate([{transform:'rotateX(90deg)',filter:'brightness(1.3)'},{transform:'rotateX(0)'}],{duration:260,easing:'cubic-bezier(.3,1.5,.5,1)',fill:'forwards'}).onfinish=()=>{ dn.textContent=ch; fd.remove(); }; };
}
function analogSvg(){
  const ticks=CS.dial==='railway'?Array.from({length:60},(_,i)=>{ const a=i*6*Math.PI/180, big=i%5===0, r1=big?78:84; return `<line x1="${100+Math.sin(a)*r1}" y1="${100-Math.cos(a)*r1}" x2="${100+Math.sin(a)*90}" y2="${100-Math.cos(a)*90}" stroke="currentColor" stroke-width="${big?5:1.6}"/>`; }).join('')
    :CS.dial==='minimal'?Array.from({length:12},(_,i)=>{ const a=i*30*Math.PI/180; return `<line x1="${100+Math.sin(a)*80}" y1="${100-Math.cos(a)*80}" x2="${100+Math.sin(a)*90}" y2="${100-Math.cos(a)*90}" stroke="currentColor" stroke-width="${i%3?2:4}" stroke-linecap="round" opacity="${i%3?.6:1}"/>`; }).join('')
    :CS.dial==='roman'||CS.dial==='numbers'?Array.from({length:12},(_,i)=>{ const a=(i+1)*30*Math.PI/180, R=['I','II','III','IV','V','VI','VII','VIII','IX','X','XI','XII'][i], n=CS.dial==='roman'?R:String(i+1);
      if(CS.dial==='numbers'&&(i+1)%3) return ''; return `<text x="${100+Math.sin(a)*74}" y="${100-Math.cos(a)*74}" text-anchor="middle" dominant-baseline="central" font-size="${CS.dial==='roman'?17:24}" fill="currentColor">${n}</text>`; }).join(''):'';
  return `<svg class="cs-analog" viewBox="0 0 200 200" aria-hidden="true">${CS.dial==='railway'?'<circle cx="100" cy="100" r="94" fill="none" stroke="currentColor" stroke-width="2.5" opacity=".9"/>':''}${ticks}
    <line class="hh" x1="100" y1="112" x2="100" y2="52" stroke="currentColor" stroke-width="${CS.dial==='railway'?9:7}" stroke-linecap="${CS.dial==='railway'?'butt':'round'}"/>
    <line class="mh" x1="100" y1="116" x2="100" y2="26" stroke="currentColor" stroke-width="${CS.dial==='railway'?7:5}" stroke-linecap="${CS.dial==='railway'?'butt':'round'}"/>
    <g class="sh" ${CS.secs||CS.dial==='railway'?'':'style="display:none"'}><line x1="100" y1="126" x2="100" y2="22" stroke="${CS.dial==='railway'?'#e2372b':'var(--cs-inkB)'}" stroke-width="2"/>${CS.dial==='railway'?'<circle cx="100" cy="30" r="8" fill="#e2372b"/>':''}</g>
    <circle cx="100" cy="100" r="5" fill="currentColor"/></svg>`;
}
function render(force){
  if(!CS.on) return; const d=new Date(), p=parts(d);
  const str=CS.mode+p.h+p.m+(CS.secs?p.s:'')+p.ap+CS.sep+CS.ampm+CS.words+CS.dial;
  const key=[CS.mode,CS.secs,CS.sep,CS.ampm,CS.dial,p.h.length,CS.words].join('|');
  if(force||key!==built){ built=key; prevStr=''; mainEl.innerHTML=''; mainEl.className='cs-main';
    if(CS.mode==='analog') mainEl.innerHTML=analogSvg(); }
  if(CS.mode!=='analog'&&str===prevStr) return;
  prevStr=str;
  const digits=(p.h+p.m+(CS.secs?p.s:'')).split(''), sepHtml=`<span class="cs-sep">${esc(CS.sep===' '?' ':CS.sep)}</span>`;
  face.setAttribute('aria-label',`${p.h}:${p.m}${H.S.h24?'':' '+p.ap}`);
  if(CS.mode==='digital'){
    if(!mainEl.children.length){ mainEl.innerHTML=digits.map((c,i)=>`<span class="cs-ch" data-i="${i}"></span>${i===p.h.length-1?sepHtml:''}`).join('')+(CS.ampm!=='none'&&!H.S.h24?`<span class="cs-ampm"></span>`:'');
      mainEl.querySelectorAll('.cs-ch').forEach((e,i)=>{ if(CS.secs&&i>=p.h.length+2) e.classList.add('cs-secs'); }); }
    mainEl.querySelectorAll('.cs-ch').forEach((e,i)=>{ if(e.textContent!==digits[i]){ const first=!e.textContent; e.textContent=digits[i]; if(!first) animIn(e); } });
    const ap=mainEl.querySelector('.cs-ampm'); if(ap) ap.textContent=CS.ampm==='small'?p.ap.toLowerCase():p.ap;
  }
  else if(CS.mode==='flip'){
    if(!mainEl.children.length) mainEl.innerHTML=digits.map((c,i)=>`<span class="cs-flip"><span class="up"><b></b></span><span class="dn"><b></b></span></span>${i===p.h.length-1||(CS.secs&&i===p.h.length+1)?sepHtml:''}`).join('');
    mainEl.querySelectorAll('.cs-flip').forEach((e,i)=>flipTo(e,digits[i]));
  }
  else if(CS.mode==='roll'){
    if(!mainEl.children.length) mainEl.innerHTML=digits.map((c,i)=>`<span class="cs-roll"><span>${[0,1,2,3,4,5,6,7,8,9].map(n=>`<b>${n}</b>`).join('')}</span></span>${i===p.h.length-1||(CS.secs&&i===p.h.length+1)?sepHtml:''}`).join('');
    mainEl.querySelectorAll('.cs-roll>span').forEach((e,i)=>{ e.style.transform=`translateY(${-digits[i]}em)`; });
  }
  else if(CS.mode==='segments'){
    mainEl.innerHTML=`<span class="cs-seg">${digits.map((c,i)=>segSvg(c)+(i===p.h.length-1||(CS.secs&&i===p.h.length+1)?segColon():'')).join('')}</span>`;
  }
  else if(CS.mode==='dots'){
    mainEl.innerHTML=`<span class="cs-dots" style="font-size:1.25em">${digits.map((c,i)=>dotsFor(c)+(i===p.h.length-1||(CS.secs&&i===p.h.length+1)?dotColon():'')).join('')}</span>`;
  }
  else if(CS.mode==='words'){
    const w=wordsFor(d); if(mainEl.dataset.w!==w){ mainEl.dataset.w=w; mainEl.innerHTML=`<span class="cs-words">${w}</span>`; animIn(mainEl.firstChild); }
  }
}
function tickAnalog(){
  if(!CS.on||CS.mode!=='analog') return; const d=new Date(), s=d.getSeconds()+(CS.sweep?d.getMilliseconds()/1000:0), m=d.getMinutes()+s/60, h=(d.getHours()%12)+m/60;
  const set=(c,deg)=>mainEl.querySelector(c)?.setAttribute('transform',`rotate(${deg.toFixed(2)} 100 100)`);
  set('.hh',h*30); set('.mh',m*6); set('.sh',s*6);
}
function comps(){ if(!CS.on) return; const d=new Date(); const t=comp(CS.top,d), b=comp(CS.bottom,d); if(topEl.innerHTML!==t) topEl.innerHTML=t; if(botEl.innerHTML!==b) botEl.innerHTML=b; }

/* ---------- look ---------- */
const lum=hex=>{ const n=parseInt(hex.slice(1),16), c=[n>>16&255,n>>8&255,n&255].map(v=>{ v/=255; return v<=.03928?v/12.92:Math.pow((v+.055)/1.055,2.4); }); return .2126*c[0]+.7152*c[1]+.0722*c[2]; };
const contrast=(a,b)=>{ const x=lum(a), y=lum(b); return (Math.max(x,y)+.05)/(Math.min(x,y)+.05); };
function sky(){ const h=new Date().getHours()+new Date().getMinutes()/60;
  const S=[[0,'#0b1236','#27306b'],[5,'#2b2d6b','#f08a7a'],[7,'#ffb37a','#9fd1ff'],[11,'#5aa8ff','#bfe3ff'],[16,'#6aa0ff','#ffd28a'],[19,'#ff7a6b','#5a3f8f'],[21,'#1c1f55','#3b2f7a'],[24,'#0b1236','#27306b']];
  let i=S.findIndex(s=>s[0]>h)-1; if(i<0) i=0; return [S[i][1],S[i][2]]; }
function apply(){
  const on=CS.on; const dr=document.querySelector('.cs-drill small'); if(dr) dr.textContent=on?'On':'Off'; cardIn.classList.toggle('cs-on',on); H.stage.classList.toggle('cs-studio-on',on); face.hidden=!on;
  if(!on){ cardIn.className=cardIn.className.replace(/\bcs-\S+/g,'').trim(); H.refreshPanels(); return; }
  loadFont(CS.font);
  const st=cardIn.style, F=FONTS[CS.font]||FONTS.host;
  st.setProperty('--cs-font',F[1]); st.setProperty('--cs-size',CS.size/100); st.setProperty('--cs-wght',CS.wght); st.setProperty('--cs-wd',CS.wd/100);
  st.setProperty('--cs-slant',CS.font==='rec'?CS.slant:0); st.setProperty('--cs-skew',(CS.font==='rec'?0:-CS.slant)+'deg'); st.setProperty('--cs-track',(CS.track/100)+'em');
  st.setProperty('--cs-casual',CS.casual/100); st.setProperty('--cs-soft',CS.soft);
  let [a,b]=[CS.fillA,CS.fillB]; if(CS.fill==='sky') [a,b]=sky();
  st.setProperty('--cs-a',a); st.setProperty('--cs-b',b); st.setProperty('--cs-ang',CS.ang+'deg'); st.setProperty('--cs-frost',CS.frost+'px'); st.setProperty('--cs-opa',CS.opa);
  st.setProperty('--cs-rad',CS.rad+'px'); st.setProperty('--cs-shd',CS.shadow); st.setProperty('--cs-inkB',CS.inkB);
  st.setProperty('--cs-tile',CS.fill==='auto'||CS.fill==='clear'?'rgba(0,0,0,.28)':'color-mix(in srgb,var(--cs-a) 70%,#000)');
  if(CS.ink==='auto'){ if(CS.fill==='clear') st.setProperty('--cs-ink','var(--ink)'); else st.removeProperty('--cs-ink'); } else st.setProperty('--cs-ink',CS.ink);
  st.setProperty('--cs-glow',CS.ink==='auto'?(CS.fill==='clear'?'color-mix(in srgb,var(--ink) 50%,transparent)':'rgba(255,255,255,.7)'):CS.ink);
  cardIn.className=cardIn.className.replace(/\bcs-(fill|own|noborder|night)\S*/g,'').trim();
  if(CS.fill!=='auto'){ cardIn.classList.add('cs-fill-'+CS.fill,'cs-own'); if(!CS.border) cardIn.classList.add('cs-noborder'); }
  const hr=new Date().getHours(); if(CS.night&&(hr>=22||hr<6)) cardIn.classList.add('cs-night');
  face.className='cs-face'+(CS.fx!=='none'?' fx-'+CS.fx:'')+(CS.breathe&&!H.simpler()?' breathe':'')+(CS.blink?' blink':'');
  render(true); comps(); tickAnalog();
}
setInterval(()=>{ render(); comps(); },250);
H.frame.push(()=>{ if(CS.on&&CS.mode==='analog'&&CS.sweep) tickAnalog(); });
setInterval(()=>{ if(CS.on&&CS.mode==='analog'&&!CS.sweep) tickAnalog(); if(CS.on&&(CS.fill==='sky'||CS.night)) apply(); },1000*20);
setInterval(()=>{ if(CS.on&&CS.mode==='analog'&&!CS.sweep) tickAnalog(); },1000);
/* chimes */
let lastMin=new Date().getMinutes();
setInterval(()=>{ const d=new Date(), m=d.getMinutes(); if(m===lastMin) return; lastMin=m; if(!CS.on||m!==0) return;
  if(CS.chime==='beep') H.beep([[1046,90],[0,60],[784,140]]);
  if(CS.chime==='pip'&&S.naviOn) H.say(wordsFor(d).replace(/<\/?b>/g,'')+'.',2200,null,0); },1000);

/* ---------- history: undo / redo ---------- */
const past=[], future=[]; let histT=0, snapshot=JSON.stringify(CS);
function commit(){ clearTimeout(histT); histT=setTimeout(()=>{ const now=JSON.stringify(CS); if(now===snapshot) return; past.push(snapshot); if(past.length>40) past.shift(); future.length=0; snapshot=now; syncTop(); },350); }
function undo(){ if(!past.length) return; future.push(JSON.stringify(CS)); snapshot=past.pop(); CS=JSON.parse(snapshot); save(); apply(); sync(); }
function redo(){ if(!future.length) return; past.push(JSON.stringify(CS)); snapshot=future.pop(); CS=JSON.parse(snapshot); save(); apply(); sync(); }
function set(patch,line){ Object.assign(CS,patch); save(); apply(); commit(); sync(); if(line&&S.naviOn) H.say(line,2200,null,2); }

/* ---------- presets ---------- */
const PRESETS=[
  ['Today',{mode:'digital',font:'host',fill:'auto',ink:'auto',fx:'none',top:'date',bottom:'none',size:100,wght:650,wd:100,slant:0,track:-2,trans:'slide'},'Back to the classic.'],
  ['Pane 1887',{mode:'analog',dial:'roman',font:'didone',fill:'gradient',fillA:'#f1e3c0',fillB:'#d6bb82',ang:160,ink:'#3b2a14',inkB:'#8a4b1c',top:'none',bottom:'date',dateFmt:'long',fx:'emboss',rad:44,shadow:4,border:true,secs:false},'Ada\'s pocket watch. Mind the tea.'],
  ['Station',{mode:'analog',dial:'railway',font:'grotesk',fill:'solid',fillA:'#f7f7f4',ink:'#111111',top:'none',bottom:'none',fx:'none',rad:120,shadow:3,border:false,sweep:false},'Railway time. Very punctual.'],
  ['Flip \'74',{mode:'flip',font:'bebas',fill:'solid',fillA:'#26221f',ink:'#f3e7cf',inkB:'#f3e7cf',top:'none',bottom:'date',dateFmt:'day',size:90,wght:400,fx:'none',rad:18,shadow:5,border:false,track:2},'Clack clack. Listen for the minute.'],
  ['Odometer',{mode:'roll',font:'mono',fill:'gradient',fillA:'#2f3640',fillB:'#59636f',ang:180,ink:'#f5f7fa',top:'none',bottom:'progress',size:85,wght:600,fx:'none',rad:16,border:true},'It rolls. Very satisfying.'],
  ['Night Stand',{mode:'segments',fill:'solid',fillA:'#0b0b0d',ink:'#ff3b2f',top:'none',bottom:'none',fx:'none',slant:8,size:90,rad:14,shadow:6,border:false,blink:true,night:false},'Bedside red. Don\'t look directly at it.'],
  ['Poster',{mode:'digital',font:'bebas',fill:'gradient',fillA:'#ff5f6d',fillB:'#ffc371',ang:135,ink:'#ffffff',inkB:'#5a1a2b',fx:'shadow',top:'none',bottom:'none',size:135,wght:400,track:-1,rad:8,trans:'drop'},'Big. Loud. Correct.'],
  ['Words',{mode:'words',words:'fuzzy',font:'fraunces',soft:100,wght:500,fill:'sky',ink:'#ffffff',inkB:'#ffe39a',top:'none',bottom:'date',fx:'none',rad:34,trans:'fade'},'Less exact. More relaxed.'],
  ['Pixel Pal',{mode:'dots',fill:'solid',fillA:'#101a33',ink:'#5dff9a',top:'none',bottom:'moon',fx:'none',rad:20,shadow:4,border:true,size:100},'Beep boop. Hello, old friend.'],
  ['Liquid',{mode:'digital',font:'rec',casual:100,wght:800,fill:'clear',ink:'auto',fx:'glass',top:'none',bottom:'none',size:120,slant:0,trans:'blur'},'No card. Just glass letters.'],
  ['Gumdrop',{mode:'digital',font:'rounded',fill:'glass',fillA:'#ff9a2e',opa:72,frost:18,ink:'#ffffff',fx:'glow',rad:60,top:'date',bottom:'none',wght:800,trans:'drop'},'Tangerine. Never fully explained.'],
  ['Ghost',{mode:'digital',font:'grotesk',fill:'clear',ink:'auto',fx:'outline',wght:300,size:130,top:'none',bottom:'none',trans:'fade',breathe:true},'Barely there. Very calm.']
];
const prevStyle=p=>{ const c=Object.assign({},DEF,p); const bg=c.fill==='solid'?c.fillA:c.fill==='gradient'?`linear-gradient(${c.ang}deg,${c.fillA},${c.fillB})`:c.fill==='sky'?'linear-gradient(160deg,#5aa8ff,#ffd28a)':c.fill==='glass'?c.fillA+'bb':c.fill==='clear'?'transparent':'var(--accent)';
  const ink=c.ink==='auto'?'#fff':c.ink; const font=(FONTS[c.font]||FONTS.host)[1];
  return `background:${bg};color:${ink};font-family:${font}${c.fill==='clear'?';color:var(--ink)':''}`; };
const prevTxt=p=>({analog:'🕘',flip:'9|41',roll:'9:41',segments:'8:88',dots:'⠿⠿',words:'nearly ten'})[p.mode]||'9:41';

/* ---------- surprise me ---------- */
const ADJ=['Midnight','Velvet','Paper','Lemon','Quiet','Tidal','Rusty','Sugar','Neon','Foggy','Copper','Moss','Biscuit','Glacier','Sunday','Static'];
const NOUN=['Biscuit','Lighthouse','Teacup','Comet','Parade','Orchard','Signal','Marble','Tram','Kettle','Pebble','Arcade','Harbour','Lantern'];
const hsl=(h,s,l)=>{ s/=100; l/=100; const k=n=>(n+h/30)%12, a=s*Math.min(l,1-l), f=n=>l-a*Math.max(-1,Math.min(k(n)-3,9-k(n),1)); return '#'+[f(0),f(8),f(4)].map(x=>Math.round(x*255).toString(16).padStart(2,'0')).join(''); };
function surprise(){
  const r=a=>a[Math.floor(Math.random()*a.length)], h=Math.random()*360, dark=Math.random()<.45;
  const A=hsl(h,55+Math.random()*30,dark?14+Math.random()*12:52+Math.random()*16), B=hsl((h+(Math.random()<.5?35:180))%360,60,dark?26:70);
  let ink=dark?hsl((h+180)%360,80,72):'#ffffff'; if(contrast(ink,A)<3.2) ink=lum(A)>.4?'#151515':'#ffffff';
  const mode=r(['digital','digital','digital','flip','roll','analog','segments','dots','words']);
  const p={mode,font:r(['system','rounded','serif','mono','rec','fraunces','bebas','grotesk','didone','pixel','hand']),fill:r(['solid','gradient','gradient','glass','sky','clear']),fillA:A,fillB:B,ang:r([135,160,180,200]),ink,inkB:hsl((h+40)%360,90,70),
    fx:r(['none','none','glow','shadow','gradient','emboss','outline']),wght:r([300,400,500,650,800,900]),wd:r([85,95,100,100,110]),slant:r([0,0,0,6,10]),track:r([-4,-2,0,3]),
    casual:Math.random()<.5?100:0,soft:r([0,50,100]),rad:r([8,18,30,44,60]),shadow:r([1,3,5]),border:Math.random()<.6,dial:r(['minimal','railway','roman','numbers']),
    top:r(['none','date','none','zone','moon']),bottom:r(['none','date','progress','week','countdown']),trans:r(['slide','fade','blur','drop','glitch']),size:r([90,100,110,125])};
  const name=r(ADJ)+' '+r(NOUN); set(p); H.store.set('cs-name',name);
  if(S.naviOn){ if(!N.awake) H.wake(); H.say(`This one's called ${name}.`,2400,null,0); }
  sync();
}

/* ---------- my clocks + share codes ---------- */
let mine=H.store.get('cs-mine',[]), naming=false;
/* the emoji code packs every setting into a big number, then writes it in one of four emoji
   alphabets picked at random. Same clock, different emoji each time; all decode the same. */
const ALPH=[
  [...'🍎🍐🍊🍋🍌🍉🍇🍓🫐🍈🍒🍑🥭🍍🥥🥝🍅🍆🥑🥦🥕🌽🥐🍞🧀🥚🥞🧇🥓🍔🍟🍕'],
  [...'🐶🐱🐭🐹🐰🦊🐻🐼🐨🐯🦁🐮🐷🐸🐵🐔🐧🐦🐤🦆🦉🦇🐺🐗🐴🦄🐝🐛🦋🐌🐞🐢'],
  [...'🫧🐚🌊🐠🐟🐡🦀🐙🦑🐳🐬🦭🦐🐋🦞🌀💧🧊🔮💎🌙🌟🌈🌸🌺🌻🌼🌷🍀🍁🍄🌵'],
  [...'🎈🎀🎁🎨🎭🎪🎲🎯🎳🎮🎸🎺🎻🥁🎹📷🔭💡🔦🧸🪀🪁🧩🎩👑💍👓🧦🧤🧣👟🎒']];
const MODES=['digital','flip','roll','analog','segments','dots','words'], FKEYS=Object.keys(FONTS), FILLS=['auto','solid','gradient','glass','sky','clear'],
  FXS=['none','glow','outline','emboss','gradient','glass','shadow'], COMPS=['none','date','zone','progress','moon','countdown','week','text'], TRANS=['none','fade','slide','blur','drop','glitch'];
const col=c=>[4096,v=>{ const n=parseInt((v||'#000000').slice(1),16); return ((n>>20&15)<<8)|((n>>12&15)<<4)|(n>>4&15); },n=>'#'+[n>>8,n>>4&15,n&15].map(x=>(x*17).toString(16).padStart(2,'0')).join('')];
const en=list=>[list.length,v=>Math.max(0,list.indexOf(v)),n=>list[n]];
const nm=(lo,hi,st)=>[Math.round((hi-lo)/st)+1,v=>Math.round((H.clamp(+v,lo,hi)-lo)/st),n=>lo+n*st];
const bo=[2,v=>v?1:0,n=>!!n];
const SCHEMA=[['mode',en(MODES)],['font',en(FKEYS)],['size',nm(60,160,5)],['wght',nm(100,1000,10)],['wd',nm(70,130,5)],['slant',nm(0,15,1)],['track',nm(-8,20,1)],
  ['casual',nm(0,100,50)],['soft',nm(0,100,50)],['lead',bo],['secs',bo],['sep',en([':','·','∶',' ','.','|'])],['blink',bo],['ampm',en(['none','small','large'])],
  ['inkAuto',bo],['ink',col()],['inkB',col()],['fill',en(FILLS)],['fillA',col()],['fillB',col()],['ang',nm(0,315,45)],['frost',nm(0,40,4)],['opa',nm(0,100,10)],['rad',nm(0,120,4)],
  ['border',bo],['shadow',nm(0,6,1)],['fx',en(FXS)],['dial',en(['minimal','railway','roman','numbers','none'])],['sweep',bo],['words',en(['fuzzy','exact'])],
  ['top',en(COMPS)],['bottom',en(COMPS)],['dateFmt',en(['short','long','numeric','iso','day'])],['zone',en(ZONES)],['trans',en(TRANS)],['breathe',bo],['chime',en(['none','beep','pip'])],['night',bo]];
function encode(){
  let n=0n; const v=Object.assign({},CS,{inkAuto:CS.ink==='auto',ink:CS.ink==='auto'?'#ffffff':CS.ink});
  for(let i=SCHEMA.length-1;i>=0;i--){ const [k,[rad,enc]]=SCHEMA[i]; n=n*BigInt(rad)+BigInt(enc(v[k])); }
  const A=ALPH[Math.floor(Math.random()*ALPH.length)], out=[];
  do{ out.push(A[Number(n%32n)]); n/=32n; }while(n>0n);
  return '⏱️'+A[1]+out.join('');   /* the first emoji is the format version (1) */
}
function decode(code){
  const ch=[...code.replace(/[️⏱\s]/g,'')]; if(ch.length<3) return null;
  const A=ALPH.find(a=>a.includes(ch[0])); if(!A||A.indexOf(ch[0])!==1) return null;
  let n=0n; for(let i=ch.length-1;i>=1;i--){ const k=A.indexOf(ch[i]); if(k<0) return null; n=n*32n+BigInt(k); }
  const p={}; for(const [k,[rad,,dec]] of SCHEMA){ p[k]=dec(Number(n%BigInt(rad))); n/=BigInt(rad); }
  if(p.inkAuto) p.ink='auto'; delete p.inkAuto; return p;
}
function importText(t){
  t=(t||'').trim(); if(!t) return false; let p=null;
  if(t.startsWith('{')){ try{ p=JSON.parse(t); }catch{} } else p=decode(t);
  if(!p) return false; const clean={}; Object.keys(DEF).forEach(k=>{ if(k in p&&k!=='on') clean[k]=p[k]; }); set(Object.assign(clean,{on:true}),'Got it. That\'s their clock now.'); return true;
}
/* paste a clock code anywhere and it applies */
addEventListener('paste',e=>{ const t=e.clipboardData?.getData('text')||''; if(/^\s*⏱/.test(t)&&!e.target.closest?.('textarea,input')){ if(importText(t)){ e.preventDefault(); } } });

/* ---------- the Studio card ---------- */
let tab=H.store.get('cs-tab','style');
const card=PB.card(`<div class="cs-top"><h3>⏱️ Clock Studio</h3><span class="sp"></span>
  <button class="pc" id="csUndo" aria-label="Undo">↶</button><button class="pc" id="csRedo" aria-label="Redo">↷</button><button class="pc" id="csDice" aria-label="Surprise me">🎲</button>
  <input type="checkbox" class="switch" id="csOn" aria-label="Use Clock Studio's face"></div>
  <div class="cs-tabs" role="group" aria-label="Studio sections">${[['style','Style'],['type','Type'],['color','Colour'],['extras','Extras'],['motion','Motion'],['share','Share']].map(([k,l])=>`<button data-tab="${k}">${l}</button>`).join('')}</div>
  <div id="csBody"></div>`);
card.classList.add('cs-card');
const btn=PB.button('⏱️','Clock Studio',()=>{ if(PB.toggle(card,btn)) sync(); });
const seg=(k,opts)=>`<div class="pr">${opts.map(([v,l])=>`<button class="pc${String(CS[k])===String(v)?' on':''}" data-k="${k}" data-v="${v}">${l}</button>`).join('')}</div>`;
const sl=(k,lab,min,max,step,fmt=v=>v)=>`<label class="cs-sl"><div><span>${lab}</span><output>${fmt(CS[k])}</output></div><input type="range" data-k="${k}" min="${min}" max="${max}" step="${step}" value="${CS[k]}" style="--pct:${(CS[k]-min)/(max-min)*100}%"></label>`;
const swc=(k,lab)=>`<label class="cs-row">${lab}<input type="checkbox" class="switch" data-k="${k}" ${CS[k]?'checked':''}></label>`;
const colr=(k,lab,auto)=>`<label class="cs-col"><input type="color" data-k="${k}" value="${CS[k]==='auto'?'#ffffff':CS[k]}">${lab}${auto?` <button class="pc${CS[k]==='auto'?' on':''}" data-k="${k}" data-v="auto">Auto</button>`:''}</label>`;
const L=t=>`<div class="cs-l">${t}</div>`;
function body(){
  if(tab==='style') return `${L('Presets')}<div class="cs-presets">${PRESETS.map(([n,p],i)=>`<button class="cs-pre" data-pre="${i}"><i style="${prevStyle(p)}">${prevTxt(p)}</i>${n}</button>`).join('')}</div>
    ${L('Face')}${seg('mode',[['digital','Digital'],['flip','Flip'],['roll','Roll'],['analog','Analog'],['segments','Segments'],['dots','Dots'],['words','Words']])}
    ${CS.mode==='analog'?L('Dial')+seg('dial',[['minimal','Minimal'],['railway','Railway'],['roman','Roman'],['numbers','Numbers'],['none','Bare']])+swc('sweep','Sweeping second hand'):''}
    ${CS.mode==='words'?seg('words',[['fuzzy','Roughly'],['exact','Exactly']]):''}
    ${L('My clocks')}<div class="cs-mine">${mine.map((m,i)=>`<button class="pc" data-mine="${i}">${esc(m.name)}</button>`).join('')}${naming?'':'<button class="pc" id="csSave">＋ Save this one</button>'}</div>
    ${naming?`<div class="cs-col"><input class="cs-in" id="csName" maxlength="24" value="${esc(H.store.get('cs-name','')||('Clock '+(mine.length+1)))}" aria-label="Name this clock"><button class="pc on" id="csNameOk">Save</button></div>`:''}
    ${mine.length?`<p>Long-press a saved clock to delete it.</p>`:''}`;
  if(tab==='type') return `${seg('font',Object.entries(FONTS).map(([k,[n]])=>[k,n]))}
    ${sl('size','Size',60,160,5,v=>v+'%')}${sl('wght','Weight',100,1000,10)}${sl('wd','Width',70,130,5,v=>v+'%')}${sl('slant','Slant',0,15,1,v=>v+'°')}${sl('track','Spacing',-8,20,1,v=>(v/100).toFixed(2)+'em')}
    ${CS.font==='rec'?sl('casual','Casual',0,100,50,v=>v+'%'):''}${CS.font==='fraunces'?sl('soft','Softness',0,100,50,v=>v+'%'):''}
    ${L('Digits')}${swc('lead','Leading zero')}${swc('secs','Seconds')}${L('Separator')}${seg('sep',[[':',':'],['·','·'],['∶','∶'],[' ','space'],['.','.'],['|','|']])}${swc('blink','Blinking separator')}
    ${H.S.h24?'':L('AM / PM')+seg('ampm',[['none','Hidden'],['small','am'],['large','AM']])}`;
  if(tab==='color'){ const A=CS.fill==='sky'?sky()[0]:CS.fillA, ink=CS.ink==='auto'?'#ffffff':CS.ink, c=CS.fill==='clear'||CS.fill==='auto'?null:contrast(ink,A);
    return `${L('Card')}${seg('fill',[['auto','Auto'],['solid','Solid'],['gradient','Gradient'],['glass','Tinted glass'],['sky','Sky'],['clear','No card']])}
    ${CS.fill==='auto'?'<p>Auto follows your Look and face, like the sandbox does.</p>':''}
    ${['solid','gradient','glass'].includes(CS.fill)?colr('fillA','Colour'):''}${CS.fill==='gradient'?colr('fillB','Second colour')+sl('ang','Angle',0,315,45,v=>v+'°'):''}
    ${CS.fill==='glass'?sl('opa','Tint',0,100,10,v=>v+'%')+sl('frost','Frost',0,40,4,v=>v+'px'):''}${CS.fill==='sky'?'<p>Changes colour through the day: dawn, noon, sunset, night.</p>':''}
    ${CS.fill!=='auto'&&CS.fill!=='clear'?sl('rad','Corners',0,120,4,v=>v+'px')+sl('shadow','Shadow',0,6,1)+swc('border','Glass edge'):''}
    ${L('Ink')}${colr('ink','Numbers',true)}${colr('inkB','Accent (effects, words, second hand)')}
    ${c?`<p>${c>=4.5?'✓':'⚠️'} Contrast about ${c.toFixed(1)}:1. ${c>=4.5?'Easy to read.':c>=3?'Fine for big numbers.':'Hard to read. Try a lighter or darker ink.'}</p>`:''}
    ${L('Effect')}${seg('fx',[['none','None'],['shadow','Drop'],['glow','Glow'],['outline','Outline'],['emboss','Pressed'],['gradient','Gradient'],['glass','Glass letters']])}
    ${swc('night','Dim and warm at night (10pm–6am)')}`; }
  if(tab==='extras'){ const cs=[['none','None'],['date','Date'],['zone','Second time zone'],['progress','Day progress'],['moon','Moon phase'],['countdown','Countdown'],['week','Week number'],['text','My text']];
    return `${L('Above the time')}${seg('top',cs)}${L('Below the time')}${seg('bottom',cs)}
    ${[CS.top,CS.bottom].includes('date')?L('Date style')+seg('dateFmt',[['short','Thu 29 Oct'],['long','Thursday 29 October'],['numeric','29/10/26'],['iso','2026-10-29'],['day','Thursday']]):''}
    ${[CS.top,CS.bottom].includes('zone')?`${L('Time zone')}<select data-k="zone">${ZONES.map(z=>`<option value="${z}" ${z===CS.zone?'selected':''}>${city(z)}</option>`).join('')}</select>`:''}
    ${[CS.top,CS.bottom].includes('countdown')?`${L('Countdown to')}<div class="cs-col"><input class="cs-in" data-k="cdLabel" value="${esc(CS.cdLabel)}" aria-label="What"><input class="cs-in" type="time" data-k="cdAt" value="${CS.cdAt}" aria-label="When"></div>`:''}
    ${[CS.top,CS.bottom].includes('text')?`${L('My text')}<input class="cs-in" data-k="text" value="${esc(CS.text)}" maxlength="40">`:''}`; }
  if(tab==='motion') return `${L('When a digit changes')}${seg('trans',[['none','Instant'],['fade','Fade'],['slide','Slide'],['blur','Blur'],['drop','Drop'],['glitch','Glitch']])}
    ${swc('breathe','Breathing glow')}${swc('blink','Blinking separator')}${CS.mode==='analog'?swc('sweep','Sweeping second hand'):''}
    ${L('On the hour')}${seg('chime',[['none','Silent'],['beep','Chime'],['pip','Pip says the time']])}
    <p>Simpler motion (Accessibility) turns every animation here into a plain change.</p>`;
  if(tab==='share') return `<p>Every setting packs into one emoji code. Each copy uses a random emoji set (fruit, animals, sea or toys) and they all mean the same clock.</p>
    <div class="cs-code" id="csCode">${encode()}</div><div class="pr"><button class="pc" id="csCopy">Copy code</button><button class="pc" id="csNew">New emoji</button><button class="pc" id="csJson">Copy as text</button></div>
    ${L('Use a code')}<textarea id="csPaste" placeholder="Paste a ⏱️ code or text here" aria-label="Paste a clock code"></textarea><div class="pr"><button class="pc" id="csApply">Apply</button></div>
    <p>Or just paste a ⏱️ code anywhere on the sandbox. Custom words (countdown, my text) travel in "Copy as text".</p>`;
  return '';
}
function syncTop(){ card.querySelector('#csUndo').disabled=!past.length; card.querySelector('#csRedo').disabled=!future.length;
  card.querySelector('#csUndo').style.opacity=past.length?1:.35; card.querySelector('#csRedo').style.opacity=future.length?1:.35; card.querySelector('#csOn').checked=CS.on; }
function sync(){
  if(card.hidden) return; syncTop();
  card.querySelectorAll('[data-tab]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.tab===tab)));
  const B=card.querySelector('#csBody'), y=card.scrollTop; B.innerHTML=body(); card.scrollTop=y;
  if(!CS.on) B.insertAdjacentHTML('afterbegin','<p>Studio is off, so the clock shows the sandbox face. Pick anything below, or flip the switch, to turn it on.</p>');
  const dr=document.querySelector('.cs-drill small'); if(dr) dr.textContent=CS.on?'On':'Off';
}
const val=(el)=>el.type==='checkbox'?el.checked:el.type==='range'?+el.value:el.value;
card.addEventListener('click',e=>{
  const t=e.target.closest('[data-tab]'); if(t){ tab=t.dataset.tab; H.store.set('cs-tab',tab); sync(); return; }
  const b=e.target.closest('button[data-k]'); if(b){ const k=b.dataset.k, v=b.dataset.v, cur=CS[k]; set({[k]:typeof cur==='number'?+v:v,on:true}); return; }
  const pr=e.target.closest('[data-pre]'); if(pr){ const [n,p,line]=PRESETS[+pr.dataset.pre]; set(Object.assign({},DEF,p,{on:true}),line); H.store.set('cs-name',n); return; }
  const mi=e.target.closest('[data-mine]'); if(mi&&!mi._lp){ set(Object.assign({},mine[+mi.dataset.mine].cs,{on:true}),'Your '+mine[+mi.dataset.mine].name+'.'); return; }
  if(e.target.closest('#csSave')){ naming=true; sync(); const f=card.querySelector('#csName'); f?.focus(); f?.select(); return; }
  if(e.target.closest('#csNameOk')) return saveMine();
  if(e.target.closest('#csUndo')) return undo(); if(e.target.closest('#csRedo')) return redo(); if(e.target.closest('#csDice')) return surprise();
  if(e.target.closest('#csNew')){ card.querySelector('#csCode').textContent=encode(); return; }
  if(e.target.closest('#csCopy')||e.target.closest('#csJson')){ const txt=e.target.closest('#csJson')?JSON.stringify(CS):card.querySelector('#csCode').textContent;
    navigator.clipboard?.writeText(txt).then(()=>{ e.target.textContent='Copied ✓'; },()=>{ e.target.textContent='Copy blocked: select the code'; }); return; }
  if(e.target.closest('#csApply')){ const ok=importText(card.querySelector('#csPaste').value); if(!ok) card.querySelector('#csPaste').value='That code didn\'t work. Check it starts with ⏱️.'; }
});
function saveMine(){ const f=card.querySelector('#csName'), n=(f?.value||'').trim()||('Clock '+(mine.length+1));
  mine.push({name:n.slice(0,24),cs:Object.assign({},CS)}); mine=mine.slice(-12); H.store.set('cs-mine',mine); naming=false; sync(); }
card.addEventListener('keydown',e=>{ if(e.target.id==='csName'&&e.key==='Enter'){ e.preventDefault(); saveMine(); } });
/* long-press a saved clock to delete it (a scroll or drag cancels) */
card.addEventListener('pointerdown',e=>{ const mi=e.target.closest('[data-mine]'); if(!mi) return; mi._lp=false;
  mi._t=setTimeout(()=>{ mi._lp=true; mine.splice(+mi.dataset.mine,1); H.store.set('cs-mine',mine); sync(); },650); });
['pointerup','pointercancel','pointerleave'].forEach(t=>card.addEventListener(t,e=>{ const mi=e.target.closest?.('[data-mine]'); if(mi) clearTimeout(mi._t); },true));
card.addEventListener('input',e=>{ const el=e.target.closest('[data-k]'); if(!el||el.tagName==='BUTTON') return;
  if(el.type==='range'){ const o=el.closest('.cs-sl')?.querySelector('output'); el.style.setProperty('--pct',(el.value-el.min)/(el.max-el.min)*100+'%'); }
  CS[el.dataset.k]=val(el); CS.on=true; save(); apply(); commit();
  if(el.type==='range'){ const o=el.closest('.cs-sl').querySelector('output'), lab=el.closest('.cs-sl').querySelector('span').textContent;
    o.textContent={Size:v=>v+'%',Width:v=>v+'%',Slant:v=>v+'°',Spacing:v=>(v/100).toFixed(2)+'em',Casual:v=>v+'%',Softness:v=>v+'%',Angle:v=>v+'°',Tint:v=>v+'%',Frost:v=>v+'px',Corners:v=>v+'px'}[lab]?.(el.value)??el.value; }
});
card.addEventListener('change',e=>{ if(e.target.id==='csOn'){ set({on:e.target.checked},e.target.checked?'Studio face on.':'Back to the sandbox face.'); return; }
  const el=e.target.closest('[data-k]'); if(!el) return; if(el.type==='checkbox'||el.tagName==='SELECT'||el.type==='color'){ CS[el.dataset.k]=val(el); CS.on=true; save(); apply(); commit(); sync(); } });

/* a way in from the sandbox's own Clock panel */
new MutationObserver(()=>{ const pb=document.querySelector('#p-clock .pb'); if(!pb||pb.querySelector('.cs-drill')) return;
  /* same shape as the panel's own rows; while Studio is on, Face, Font and Share step aside */
  const b=document.createElement('button'); b.className='drill cs-drill'; b.innerHTML='<span>Clock Studio</span><small>'+(CS.on?'On':'Off')+'</small>'+(pb.querySelector('.drill svg')?.outerHTML||'');
  b.addEventListener('click',e=>{ e.stopPropagation(); if(card.hidden) PB.toggle(card,btn); sync(); });
  const note=document.createElement('p'); note.className='note cs-note'; note.textContent='Clock Studio is styling the clock. Switch it off in Studio to use Face, Font and the date here.';
  pb.prepend(b,note);
}).observe(document.getElementById('panels'),{childList:true,subtree:true});

/* Pip notices */
let lastNote=0;
function pipNotice(){ if(!S.naviOn||!N.awake||H.now()-lastNote<20000) return; lastNote=H.now(); N.lookPt=H.cardCentre(); N.lookUntil=H.now()+1500; emote(H.pick(['😍','🤩','👀','✨'])); }
const _set=set; set=function(p,l){ _set(p,l); pipNotice(); };

apply();
window.PipClockStudio={usePreset:i=>{ const [n,p,line]=PRESETS[i]||[]; if(!p) return; set(Object.assign({},DEF,p,{on:true}),line); H.store.set('cs-name',n); },open:()=>{ if(card.hidden) PB.toggle(card,btn); sync(); },get:()=>Object.assign({},CS),set,encode,decode,importText,presets:PRESETS};
})();
