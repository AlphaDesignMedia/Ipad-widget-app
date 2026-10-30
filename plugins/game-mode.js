/* =====================================================================
  GAME MODE · plugin v1   (Trial shelf)
  Loaded by the sandbox loader (see PLUGINS in index.html). No button: it works quietly.
  Like a video game's graphics setting, but for busyness. Levels:
    Ultra     everything, all the time (= switching this plugin off)
    Balanced  (default) background plugins run at half rate and pause while something
              important is happening: you dragging, drawing, a tour, a surprise, the flap game.
              One voice at a time: background chatter waits if Pip spoke in the last 6 s.
              Small emoji pop-ups are spaced out. Flying glass shards are capped.
    Low       Balanced, plus background plugins at a quarter rate and fewer shards.
  Auto drops to Low if frames slow down (under 48 fps for 3 s) and comes back after 10 good seconds.
  window.PipGame.set('ultra'|'balanced'|'low'|'auto'), .stats().
  Switch it off in the Plugins panel to compare.
  ===================================================================== */
(() => {
const H=window.PipHost;
if(!H||!H.registerPlugin||!H.isBusy){ console.warn('Game Mode: needs PipHost with isBusy (host.js).'); return; }
const {N,S,stage}=H;
if(!H.registerPlugin({id:'game-mode',name:'Game Mode',icon:'🎮',shelf:'trial',desc:'Quietly balances busyness: background effects slow or pause so the thing you are doing stays smooth.'})) return;

const LEVELS={ultra:{every:1,pause:false,voice:0,emote:0,shards:999},balanced:{every:2,pause:true,voice:6000,emote:2500,shards:36},low:{every:4,pause:true,voice:9000,emote:4000,shards:14}};
let mode=H.store.get('gm-mode','auto'), level=mode==='auto'?'balanced':mode;
const L=()=>LEVELS[level];
/* background plugins: nice to have, never the thing you're doing */
const BACKGROUND=new Set(['weather-window','shadow-puppets','night-shift','eager-pip','era-eggs','glass-harp','oops','postcards','stack-attack','focus-bubble','pip-remembers','dashboard-link','screen-awareness','adaptive-layout','materials','glass-lab']);
const DECOR=new Set(['weather-window','shadow-puppets','night-shift','eager-pip','era-eggs','oops']);   /* paused outright during focus */

/* focus: something important is happening right now */
let down=0; addEventListener('pointerdown',()=>down++,true); addEventListener('pointerup',()=>{ down=Math.max(0,down-1); },true); addEventListener('pointercancel',()=>{ down=0; },true);
const focus=()=>down>0||H.isBusy()||H.G.on||stage.classList.contains('sketching');
const ST={skipped:0,ran:0,quiet:0,emotes:0,shards:0,since:Date.now(),low:0};

/* wrap background frame hooks (also ones added later) */
function wrap(f){ if(f._gm||!BACKGROUND.has(f._pid)) return f; let acc=0, n=0;
  const w=function(dt,t){ const l=L();
    if(l.pause&&DECOR.has(f._pid)&&focus()){ ST.skipped++; return; }
    if(l.every<=1){ ST.ran++; return f(dt,t); }
    acc+=dt; if(++n<l.every){ ST.skipped++; return; } n=0; const d=Math.min(acc,.1); acc=0; ST.ran++; return f(d,t); };
  w._pid=f._pid; w._gm=true; return w; }
const sweep=()=>{ for(let i=0;i<H.frame.length;i++){ const f=H.frame[i]; if(!f._gm&&BACKGROUND.has(f._pid)) H.frame[i]=wrap(f); } };
sweep(); setInterval(sweep,2000);

/* one voice at a time: plugin chatter (level 2+) waits its turn */
let lastLine=0; const say0=H.say;
H.say=function(text,ms,done,lvl){ const t=H.now(), l=L();
  if(l.voice&&(lvl??1)>=2&&t-lastLine<l.voice){ ST.quiet++; return; }
  lastLine=t; return say0.apply(this,arguments); };
/* emoji pop-ups: low-priority ones are spaced out */
let lastEm=0;
const hookEmote=()=>{ const P=window.PipSpatial; if(!P||!P.emote||P.emote._gm) return; const em0=P.emote;
  const e=function(c,o={}){ const t=H.now(), l=L(); if(l.emote&&(o.pri??1)<=1&&t-lastEm<l.emote){ ST.emotes++; return; } lastEm=t; return em0.apply(this,arguments); };
  e._gm=true; try{ P.emote=e; }catch{} };
hookEmote(); setTimeout(hookEmote,3000);
/* shards and droplets: keep the newest few */
new MutationObserver(ms=>{ if(!ms.some(m=>m.addedNodes.length)) return; const cap=L().shards;
  const fx=stage.querySelectorAll(':scope > .pshard, :scope > .drop-fx'); for(let i=0;i<fx.length-cap;i++){ fx[i].remove(); ST.shards++; } }).observe(stage,{childList:true});

/* auto: watch the frame rate */
let slow=0, good=0;
setInterval(()=>{ if(mode!=='auto'||document.hidden) return; const fps=H.cost().fps||60;
  if(fps<48){ slow++; good=0; if(slow>=3&&level!=='low'){ level='low'; ST.low++; } }
  else if(fps>=56){ good++; slow=0; if(good>=10&&level==='low') level='balanced'; } },1000);

window.PipGame={set(m){ mode=m in LEVELS||m==='auto'?m:'auto'; level=mode==='auto'?'balanced':mode; H.store.set('gm-mode',mode); return level; },
  get:()=>({mode,level}), stats:()=>({...ST,mode,level,minutes:+((Date.now()-ST.since)/60000).toFixed(1)})};
})();
