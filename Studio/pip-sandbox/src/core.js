/* =====================================================================
   0. Helpers + storage
   Everything saved lives under localStorage keys starting "gs2-".
   ===================================================================== */
const $ = s => document.querySelector(s);
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const pick=a=>a[Math.floor(Math.random()*a.length)];
const now=()=>performance.now();
const esc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'})[c]);
const VERSION='V2 · stage 11.2';
const store={
  get(k,d){try{const v=localStorage.getItem('gs2-'+k); return v==null?d:JSON.parse(v);}catch{return d;}},
  set(k,v){try{localStorage.setItem('gs2-'+k,JSON.stringify(v));}catch{}},
  del(k){try{localStorage.removeItem('gs2-'+k);}catch{}},
  clear(){try{Object.keys(localStorage).filter(k=>k.startsWith('gs2-')).forEach(k=>localStorage.removeItem(k));}catch{}}
};

const stage=$('#stage'), card=$('#card'), cardIn=$('#cardIn'), navi=$('#navi'), nb=$('#nb'),
      bubble=$('#bubble'), toastEl=$('#toast'), rail=$('#rail'), canvas=$('#trail'), pool=$('#pool'), hint=$('#hint'), panelsEl=$('#panels');
const ctx=canvas.getContext('2d');
const root=document.documentElement;
const darkMq=matchMedia('(prefers-color-scheme: dark)');
const hostTheme=root.getAttribute('data-theme');

/* Settings. Defaults first, then whatever was saved on this device. */
const DEFAULTS={mode:'grounded', naviOn:true, simpler:null, clear:false, theme:'auto', bd:'aurora', fav:null,
  font:'system', weight:650, width:100, date:true, h24:false, name:'Pip', chat:3, follow:'pen', tips:true, care:true,
  track:'build', stageView:null, era:'today', off:{}, lastBuild:null, lastStory:null, tmMin:true, tmBody:true, hidey:false, liquidMax:true, legib:2, material:'glass', carry:{liquid:false,roam:false,glow:false}, eraMotion:false, remaster:true, form:'orb', face:'glass', sound:false, persona:'pip', names:false, outlines:false};
const S=Object.assign({},DEFAULTS,store.get('prefs',{})); S.off={...S.off}; S.carry={...DEFAULTS.carry,...S.carry};
/* Feature registry: which stage each feature arrived in. F(id) says if it's on right now. */
const LATEST=11, BUILD='11.2';   // BUILD is the label in the top-left tag
const FEATURES=[
  {id:'panels',stage:1,name:'Panels open panels',core:true},
  {id:'flick',stage:1,name:'Flick and bounce',core:true},
  {id:'anger',stage:1,name:'Pokes, annoyed, sulks'},
  {id:'care',stage:2,name:'Care spot'},
  {id:'pet',stage:2,name:'Petting'},
  {id:'pen',stage:2,name:'Follows the Pencil in Grounded'},
  {id:'notice',stage:2,name:'Noticing tips'},
  {id:'knock',stage:2,name:'Falls off a yanked clock'},
  {id:'peek',stage:2,name:'Peeks at the minute'},
  {id:'machine',stage:3,name:'Time machine',core:true},
  {id:'story',stage:3,name:'Story track'},
  {id:'eras',stage:3,name:'Era bodies'},
  {id:'warp',stage:3,name:'Time-travel flash'},
  {id:'worlds',stage:4,name:'Era worlds restyle everything'},
  {id:'forms',stage:4,name:'Bodies from V1'},
  {id:'faces',stage:4,name:'Clock faces'},
  {id:'glacio',stage:4,name:'Glacio LCD'},
  {id:'moments',stage:4,name:'Era jokes'},
  {id:'throw',stage:5,name:'Fling the clock'},
  {id:'fragile',stage:5,name:'Clock cracks'},
  {id:'game',stage:5,name:'404 slingshot game'},
  {id:'checkin',stage:6,name:'Pip checks in'},
  {id:'notes',stage:6,name:'Notes for the developer'},
  {id:'pill',stage:6,name:'Dial folds to a pill',core:true},
  {id:'liquid',stage:7,name:'Liquid glass for Today'},
  {id:'liquidmax',stage:7,name:'Liquid Max in Dream'},
  {id:'lens',stage:8,name:'Hold the glass'},
  {id:'liquidctl',stage:8,name:'Liquid controls'},
  {id:'eralight',stage:8,name:'Retro looks catch the light'},
  {id:'refresh',stage:8,name:'Today UI refresh'},
  {id:'share',stage:9,name:'Emoji face codes'},
  {id:'flickpanel',stage:10,name:'Flick panels'},
  {id:'smash',stage:10,name:'Panels crack and smash'},
  {id:'material',stage:11,name:'Glass, liquid or both'},
  {id:'shatter',stage:11,name:'Glass-break sound'}
];
const F=id=>{const f=FEATURES.find(x=>x.id===id); return (S.stageView||LATEST)>=f.stage&&!S.off[id];};
let saveT=0;
function save(){clearTimeout(saveT); saveT=setTimeout(()=>{const o={}; for(const k in DEFAULTS) if(S[k]!==DEFAULTS[k]) o[k]=S[k]; store.set('prefs',o);},250);}
const reducedOS=matchMedia('(prefers-reduced-motion: reduce)').matches;
const simpler=()=>S.simpler==null?reducedOS:S.simpler;
const grounded=()=>S.mode==='grounded';

/* =====================================================================
   1. Backdrops + colour
   ===================================================================== */
const waves=ink=>`url("data:image/svg+xml,${encodeURIComponent(`<svg xmlns='http://www.w3.org/2000/svg' width='120' height='30' viewBox='0 0 120 30'><path d='M0 15 C20 3 40 3 60 15 S100 27 120 15' fill='none' stroke='${ink}' stroke-width='1.3'/></svg>`)}")`;
const mesh=(base,a,b,c)=>`radial-gradient(at 18% 22%, ${a} 0, transparent 52%), radial-gradient(at 84% 18%, ${b} 0, transparent 48%), radial-gradient(at 62% 88%, ${c} 0, transparent 56%), ${base}`;
const BD={
  aurora:{g:'Gradients',n:'Aurora',dark:{bg:'linear-gradient(160deg,#0b1f3a 0%,#123f5c 36%,#1f7a74 66%,#5b3c8f 100%)',a:'#4f8ef0'},light:{bg:'linear-gradient(160deg,#cfe6ff 0%,#c4efe6 46%,#ddd5ff 100%)',a:'#4f7be8'}},
  sunset:{g:'Gradients',n:'Sunset',dark:{bg:'linear-gradient(170deg,#2a1033 0%,#7a2a4f 45%,#c95a3f 82%,#e99a55 100%)',a:'#e0655a'},light:{bg:'linear-gradient(170deg,#ffe2d6 0%,#ffcac4 46%,#ffdcae 100%)',a:'#df5f58'}},
  ocean:{g:'Gradients',n:'Ocean',dark:{bg:'linear-gradient(165deg,#06142e 0%,#0b3a6b 52%,#1673a8 100%)',a:'#3a8be0'},light:{bg:'linear-gradient(165deg,#dcedff 0%,#bddcff 52%,#ade4f4 100%)',a:'#2f78d0'}},
  graphite:{g:'Gradients',n:'Graphite',dark:{bg:'linear-gradient(170deg,#1b1c20 0%,#2c2e35 55%,#3a3c44 100%)',a:'#8aa4d8'},light:{bg:'linear-gradient(170deg,#eef0f3 0%,#dcdfe5 55%,#cfd3da 100%)',a:'#5a74b0'}},
  bloom:{g:'Mesh',n:'Bloom',dark:{bg:mesh('#24142e','#8a3f9e','#c2457a','#4b3fb0'),a:'#b452c0'},light:{bg:mesh('#fbeefa','#f1c3ec','#ffc4d8','#d2cbff'),a:'#a94cb8'}},
  dune:{g:'Mesh',n:'Dune',dark:{bg:mesh('#2e2218','#8a5a32','#b07a45','#5a3f2a'),a:'#c08045'},light:{bg:mesh('#fbf0e2','#f5d4a9','#f1c290','#eadac6'),a:'#b9773c'}},
  lagoon:{g:'Mesh',n:'Lagoon',dark:{bg:mesh('#0b2a2c','#137a6e','#1e9aa8','#2b5e7a'),a:'#22a597'},light:{bg:mesh('#e7fbf6','#a9eadb','#a7e2f0','#c7f0d3'),a:'#1b958a'}},
  midnight:{g:'Mesh',n:'Midnight',dark:{bg:mesh('#0b0b1e','#2a2370','#3b1d5e','#13305e'),a:'#6a5ee0'},light:{bg:mesh('#edebff','#d0caff','#dac9f6','#c8d7f8'),a:'#5b4fd6'}},
  glow:{g:'Mesh',n:'Glow',dark:{bg:mesh('#160c14','#7a2f22','#6e4a1c','#6a1f3c'),a:'#f08a5d'},light:{bg:mesh('#fff4eb','#ffcab6','#ffe1a9','#ffc2d7'),a:'#e66a45'}},
  lines:{g:'Patterns',n:'Lines',dark:{bg:'repeating-linear-gradient(135deg, rgba(255,255,255,.07) 0 1px, transparent 1px 18px), #15171d',a:'#7480f2'},light:{bg:'repeating-linear-gradient(135deg, rgba(20,20,40,.08) 0 1px, transparent 1px 18px), #f1f2f6',a:'#5d69e6'}},
  waves:{g:'Patterns',n:'Waves',dark:{bg:`${waves('rgba(255,255,255,0.10)')} 0 0/120px 30px, #0f1a2a`,a:'#3f8fd8'},light:{bg:`${waves('rgba(20,40,80,0.12)')} 0 0/120px 30px, #edf4fc`,a:'#337fcc'}},
  dots:{g:'Patterns',n:'Dots',dark:{bg:'radial-gradient(rgba(255,255,255,.12) 1.2px, transparent 1.7px) 0 0/18px 18px, #1c1418',a:'#d0567e'},light:{bg:'radial-gradient(rgba(60,20,40,.13) 1.2px, transparent 1.7px) 0 0/18px 18px, #fdf1f4',a:'#c94b74'}},
  rings:{g:'Patterns',n:'Rings',dark:{bg:'repeating-radial-gradient(circle at 50% 46%, transparent 0 24px, rgba(255,255,255,.07) 24px 25px), #0f1c18',a:'#2fae86'},light:{bg:'repeating-radial-gradient(circle at 50% 46%, transparent 0 24px, rgba(20,60,40,.09) 24px 25px), #eef8f4',a:'#24966f'}}
};
const FAVS=[['#4f7be8','Blue'],['#e0655a','Coral'],['#e6a03a','Amber'],['#2fae86','Green'],['#22a5b5','Teal'],['#b452c0','Violet'],['#d0567e','Pink'],['#6c7282','Graphite']];
const FONTS={system:['System','var(--f-system)'],rounded:['Rounded','var(--f-rounded)'],serif:['Serif','var(--f-serif)']};

function resolved(){const a=root.getAttribute('data-theme'); return (a==='dark'||a==='light')?a:(darkMq.matches?'dark':'light');}
const hexRgb=h=>{h=h.replace('#',''); return [0,2,4].map(i=>parseInt(h.slice(i,i+2),16)/255);};
const lum=h=>{const [r,g,b]=hexRgb(h).map(c=>c<=.03928?c/12.92:((c+.055)/1.055)**2.4); return .2126*r+.7152*g+.0722*b;};
const contrast=(a,b)=>{const x=lum(a),y=lum(b); return (Math.max(x,y)+.05)/(Math.min(x,y)+.05);};
let accent='#4f7be8', cardInk='#ffffff';
function applyColour(){
  const t=resolved(), v=BD[S.bd][t];
  stage.style.background=v.bg; accent=S.fav||v.a; root.style.setProperty('--accent',accent);
  /* Pick the clock ink that reads best on the chosen colour. */
  cardInk=contrast('#ffffff',accent)>=2.6?'#ffffff':'#17161e'; root.style.setProperty('--card-ink',cardInk);
  refreshPanels();
}
function applyTheme(){
  if(S.theme==='auto'){ if(hostTheme) root.setAttribute('data-theme',hostTheme); else root.removeAttribute('data-theme'); }
  else root.setAttribute('data-theme',S.theme);
  applyColour();
}
darkMq.addEventListener?.('change',applyColour);

/* =====================================================================
   2. Icons
   ===================================================================== */
const ICONS={
  pip:'<circle cx="10" cy="10" r="7.3"/><path d="M8 8.4v2.4M12 8.4v2.4" stroke-width="1.9"/>',
  clock:'<rect x="2.5" y="5" width="15" height="10" rx="3"/><path d="M6.5 8.4v3.2M9.2 8.4h1.6v3.2M13.5 8.4v3.2"/>',
  colour:'<path d="M10 2.5a7.5 7.5 0 1 0 0 15c1.2 0 1.7-.8 1.7-1.6 0-1.3-1-1.5-1-2.6 0-.9.7-1.5 1.6-1.5h1.9a3.3 3.3 0 0 0 3.3-3.3C17.5 5.4 14.2 2.5 10 2.5Z"/><circle cx="6.3" cy="9" r=".9" fill="currentColor"/><circle cx="8.6" cy="5.9" r=".9" fill="currentColor"/><circle cx="12.3" cy="6" r=".9" fill="currentColor"/>',
  fonts:'<path d="M2.5 15.5 7 4.5l4.5 11M4.2 11.5h5.6M13 9.6c.5-.8 1.3-1.1 2.2-1.1 1.4 0 2.3.8 2.3 2.2v4.8M17.5 12.4c-2.8 0-4.5.6-4.5 1.8 0 .9.7 1.4 1.7 1.4 1.6 0 2.8-1.2 2.8-3.2"/>',
  backdrop:'<rect x="2.5" y="3.5" width="15" height="13" rx="2.5"/><path d="m2.5 13 4-4 3.5 3.5 2.5-2.5 5 5"/>',
  access:'<circle cx="10" cy="10" r="7.3"/><circle cx="10" cy="6.4" r="1.1" fill="currentColor"/><path d="M6.3 8.6 10 9.4l3.7-.8M10 9.4v2.8l-2 3.2M10 12.2l2 3.2"/>',
  dev:'<path d="m7 6-4 4 4 4M13 6l4 4-4 4M11.2 4.5l-2.4 11"/>',
  plug:'<path d="M7.5 2.5v4M12.5 2.5v4M5 6.5h10v3a5 5 0 0 1-10 0v-3ZM10 14.5v3"/>',
  now:'<path d="M2.5 10h3l2-4.5 3 9 2-4.5h5"/>',
  names:'<path d="M3.5 5.5h13M3.5 10h9M3.5 14.5h11"/>',
  look:'<rect x="2.5" y="5.5" width="11" height="11" rx="2.4"/><path d="M6.5 5.5V5a2.5 2.5 0 0 1 2.5-2.5h6A2.5 2.5 0 0 1 17.5 5v6a2.5 2.5 0 0 1-2.5 2.5h-1.5"/>',
  chev:'<path d="m7.5 4.5 5.5 5.5-5.5 5.5"/>',
  back:'<path d="M12.5 4.5 7 10l5.5 5.5"/>'
};
const svg=(k,sw=1.6)=>`<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[k]}</svg>`;
const drill=(id,label,val='')=>`<button class="drill" data-open="${id}" aria-expanded="false"><span>${label}</span><small data-val="${id}">${val}</small>${svg('chev',1.8)}</button>`;
const sw=(id,label)=>`<div class="row"><label for="${id}">${label}</label><input type="checkbox" class="switch" id="${id}"></div>`;

/* =====================================================================
   3. Panel registry
   A panel with no `parent` gets a rail button. A panel with a `parent`
   opens beside it from a drill row: data-open="<id>".
   build() returns the body HTML; wire(el) hooks it up; sync(el) refreshes it.
   ===================================================================== */
const CHAT=['Off','Quiet','Normal','Chatty'];
/* Personalities: a strong default (Pip), and each preset name brings its own temperament.
   fuse: how fast pokes drain patience. bounce: how lively they move. Names and meanings from V1. */
const PERSONAS=[
  {id:'pip',name:'Pip',what:'Playful',why:'Like the little time-signal pips: small, bright and on time.',chat:3,fuse:1,bounce:1.15,hi:['Hello!','Yes?','Hi again!','That tickles.'],wake:'Oh! Hello.'},
  {id:'tock',name:'Tock',what:'Calm',why:'The other half of tick. Their heartbeat is the clock\'s.',chat:1,fuse:.7,bounce:.6,hi:['Hello.','Mm.','I\'m here.'],wake:'Mm. Morning.'},
  {id:'lumen',name:'Lumen',what:'Gentle',why:'A unit of light, for someone who lives in glass.',chat:2,fuse:.85,bounce:.85,hi:['Oh, hello.','Hi.','Lovely to see you.'],wake:'Oh. Hello, you.'},
  {id:'glint',name:'Glint',what:'Cheeky',why:'Light catching the edge of a glass panel.',chat:3,fuse:1.3,bounce:1.4,hi:['Oi.','What?','Again?','Ha!'],wake:'Wha— I wasn\'t asleep.'},
  {id:'biscuit',name:'Biscuit',what:'Sleepy',why:'Best with tea. Usually napping.',chat:2,fuse:.8,bounce:.5,hi:['Mm… hello.','Is it teatime?','Five more minutes.'],wake:'Is it teatime?'},
  {id:'bevel',name:'Bevel',what:'Retro',why:'Grey, chunky and proud of it. Has opinions about 1997.',chat:3,fuse:1.1,bounce:1,hi:['It looks like you\'re tapping me!','Hello, user.','Beep.'],wake:'System ready.'}
];
const persona=()=>PERSONAS.find(x=>x.id===S.persona)||PERSONAS[0];
/* plugin shelves: where each idea belongs. dream = sandbox only, trial = test pilots, grounded = the shipping app, core = always on */
const SHELVES=['dream','trial','grounded','core'], SHELF_NAME={dream:'Dream',trial:'Trial',grounded:'Grounded',core:'Core'};
const shelfOf=p=>store.get('pluginShelf',{})[p.id]||p.shelfDefault||p.shelf||'dream';
const PANELS={
  pip:{title:()=>S.name, icon:'pip', label:'Companion',
    build:()=>`
      <div class="row"><label for="pName">Name</label><input class="txt" id="pName" maxlength="16" autocomplete="off" spellcheck="false"></div>
      <label class="sl" for="pChat"><div><span>Chattiness</span><output id="oChat"></output></div><input type="range" id="pChat" min="0" max="3" step="1"></label>
      <div class="lbl">Follows</div>
      <div class="mseg" id="pFollow"><button data-v="off">Nobody</button><button data-v="pen">Pencil</button><button data-v="any">+ Mouse</button></div>
      ${sw('pTips','Offers tips')}${sw('pCare','Care spot')}
      <div class="btns"><button class="btn" id="pAsk">Ask me something</button><button class="btn" id="pTour">Grand tour</button></div>
      ${drill('persona','Personality')}${drill('pipBody','Body')}${drill('pipNow','Right now')}
      <p class="note">Grounded keeps them small and close to the clock. Dream lets them roam, glow and hide behind glass.</p>`,
    wire(el){
      el.querySelector('#pName').addEventListener('input',e=>{S.name=e.target.value.trim()||'Pip'; save(); nameChanged();});
      el.querySelector('#pChat').addEventListener('input',e=>{S.chat=+e.target.value; save(); el.querySelector('#oChat').textContent=CHAT[S.chat];
        if(S.chat===0) bubble.classList.remove('on'); else say(['','Mm.','Alright.','Oh, we\'re talking now? Lovely.'][S.chat],1400,null,0); N.said=0; learnt('quiet');});
      el.querySelector('#pAsk').addEventListener('click',()=>ask(true));
      el.querySelector('#pTour').addEventListener('click',()=>{ TOUR.active=false; TOUR.started=true; tourStart(true,true); });
      el.querySelector('#pFollow').addEventListener('click',e=>{const b=e.target.closest('button'); if(!b) return; S.follow=b.dataset.v; save(); if(S.follow==='off') stopFollow(true); refreshPanels();});
      el.querySelector('#pTips').addEventListener('change',e=>{S.tips=e.target.checked; save();});
      el.querySelector('#pCare').addEventListener('change',e=>{S.care=e.target.checked; save();});
    },
    sync(el){ const n=el.querySelector('#pName'); if(document.activeElement!==n) n.value=S.name==='Pip'?'':S.name; n.placeholder='Pip';
      el.querySelector('#pChat').value=S.chat; el.querySelector('#oChat').textContent=CHAT[S.chat];
      el.querySelectorAll('#pFollow button').forEach(x=>x.setAttribute('aria-pressed',x.dataset.v===S.follow));
      el.querySelector('[data-val="persona"]').textContent=persona().what;
      el.querySelector('[data-val="pipBody"]').textContent=FORMS.find(f=>f[0]===S.form)[1];
      el.querySelector('#pTips').checked=S.tips; el.querySelector('#pCare').checked=S.care; }
  },
  pipNow:{parent:'pip', title:'Right now', icon:'now',
    build:()=>`<div class="lbl">Patience</div><div class="meter"><i id="nowPat"></i></div>
      <dl class="kv" id="nowKv"></dl>
      <button class="btn" id="nowForget">Forget the tips already given</button>
      <p class="note">Poke quickly to watch patience drain. Rub back and forth to pet. Tea fixes a sulk.</p>`,
    wire(el){ el.querySelector('#nowForget').addEventListener('click',()=>{ taught.clear(); store.del('taught'); Object.assign(OFFER,{pending:null,count:0,ignored:0,lastAt:-1e9,done:false}); N.said=0; toast('Tips forgotten. They\'ll be offered again.'); }); },
    tick(el){
      const t=now(), mood=t<N.dizzyUntil?'dizzy':N.state==='sleep'?'asleep':N.mood==='sulk'?'sulking':N.pet?'being petted':N.drink?'drinking':N.pat<.45?'annoyed':N.pat<.72?'put out':'content';
      const rows=[['Mood',mood],['Doing',{sleep:'sleeping',perch:'sitting on the clock',free:'floating',travel:'moving',follow:'following you',held:'being held'}[N.state]],
        ['Care spot',careNeed||'empty'],['Offers this visit',`${OFFER.count} of 3${OFFER.done?' (backed off)':''}`],['Tips learnt',`${taught.size} of ${Object.keys(NOTICES).length-1}`],['Sulk ends', N.mood==='sulk'?Math.ceil((N.sulkUntil-t)/1000)+'s':'–']];
      el.querySelector('#nowKv').innerHTML=rows.map(([k,v])=>`<dt>${k}</dt><dd>${v}</dd>`).join('');
      const m=el.querySelector('#nowPat'); m.style.width=(N.pat*100).toFixed(0)+'%'; m.style.background=N.pat<.45?'var(--danger)':N.pat<.72?'#e6a03a':'var(--accent)';
    }
  },
  persona:{parent:'pip', title:'Personality', icon:'pip',
    build:()=>`<div class="personas">${PERSONAS.map(x=>`<button class="pers" data-p="${x.id}"><b>${x.name}</b><small>${x.what}</small><span>${x.why}</span></button>`).join('')}</div>
      <p class="note">Picking one sets the name and the temperament. Type your own name in the panel above and the temperament stays.</p>`,
    wire(el){ el.addEventListener('click',e=>{const b=e.target.closest('[data-p]'); if(!b) return; const x=PERSONAS.find(q=>q.id===b.dataset.p);
      S.persona=x.id; S.name=x.name; S.chat=x.chat; save(); nameChanged(); refreshPanels(); N.hopT=now(); N.squash=.3; setMood('happy',1400); say(x.hi[0],1400,null,1); }); },
    sync(el){ el.querySelectorAll('[data-p]').forEach(b=>b.setAttribute('aria-pressed',b.dataset.p===S.persona)); }
  },
  pipBody:{parent:'pip', title:'Body', icon:'pip',
    build:()=>`<div class="sws">${FORMS.map(([k,n])=>`<button class="sw" data-form="${k}"><i class="form-prev fp-${k}"></i>${n}</button>`).join('')}</div>
      <p class="note">Same personality in every body. Some years in the Story track lend their own.</p>`,
    wire(el){ el.addEventListener('click',e=>{const b=e.target.closest('[data-form]'); if(!b) return; S.form=b.dataset.form; save(); applyForm(); refreshPanels(); N.hopT=now(); N.squash=.3;
      say({orb:'Back to basics.',clip:'Oh. This old thing.',robot:'Beep. Boop. Sorry, habit.',fairy:'Wings! Lovely.'}[S.form],1400,null,2); }); },
    sync(el){ el.querySelectorAll('[data-form]').forEach(b=>b.setAttribute('aria-pressed',b.dataset.form===S.form)); }
  },
  face:{parent:'clock', title:'Face', icon:'clock',
    build:()=>`<div class="sws">${FACES.map(([k,n,bg])=>`<button class="sw" data-face="${k}"><i style="background:${bg}"></i>${n}</button>`).join('')}</div>
      <p class="note">Faces change just the clock. Travel to a year in the Story track to change the whole world.</p>`,
    wire(el){ el.addEventListener('click',e=>{const b=e.target.closest('[data-face]'); if(!b) return; S.face=b.dataset.face; save(); applyFace(); refreshPanels(); react('face');}); },
    sync(el){ el.querySelectorAll('[data-face]').forEach(b=>b.setAttribute('aria-pressed',b.dataset.face===S.face)); }
  },
  share:{parent:'clock', title:'Share this face', icon:'look',
    build:()=>`<div class="code" id="shCode" aria-live="polite"></div>
      <button class="btn" id="shCopy">Copy code</button>
      <div class="lbl">Try one on</div>
      <input class="txt sh-in" id="shIn" placeholder="Paste a code here" autocomplete="off" aria-label="Paste a face code">
      <p class="note">Four emoji carry this face: style, colour, backdrop, font, weight and format. The last one is a check, so a mistyped code won't load. You can also paste a code anywhere.</p>`,
    wire(el){
      el.querySelector('#shCopy').addEventListener('click',async()=>{ const c=encodeFace();
        try{ await navigator.clipboard.writeText(c); toast('Code copied'); }catch{ const n=el.querySelector('#shCode'); const r=document.createRange(); r.selectNodeContents(n); getSelection().removeAllRanges(); getSelection().addRange(r); toast('Select and copy the code'); }
        say('Send it to someone. I\'ll help them try it on.',1800,null,2); });
      el.querySelector('#shIn').addEventListener('input',e=>{ const v=e.target.value.trim(); if(!v) return; const f=decodeFace(v);
        if(f){ previewFace(f); e.target.value=''; } else if([...v].filter(ch=>EMO.includes(ch)).length>=4) say('That code\'s smudged. Check the last emoji?',1800,null,0); });
    },
    sync(el){ el.querySelector('#shCode').textContent=encodeFace(); }
  },
  clock:{title:'Clock', icon:'clock',
    build:()=>`${drill('face','Face')}${drill('fonts','Font')}${drill('share','Share this face')}
      ${sw('cDate','Show date')}${sw('c24','24-hour')}
      <p class="note">Hold the clock to edit. Double-tap it for the next font. Pinch to resize.</p>`,
    wire(el){
      el.querySelector('#cDate').addEventListener('change',e=>{S.date=e.target.checked; save(); applyClock();});
      el.querySelector('#c24').addEventListener('change',e=>{S.h24=e.target.checked; save(); tick();});
    },
    sync(el){ el.querySelector('[data-val="face"]').textContent=FACES.find(f=>f[0]===S.face)[1]; el.querySelector('#cDate').checked=S.date; el.querySelector('#c24').checked=S.h24; el.querySelector('[data-val="fonts"]').textContent=FONTS[S.font][0]; }
  },
  fonts:{parent:'clock', title:'Font', icon:'fonts',
    build:()=>`<div class="mseg" id="fontSeg">${Object.entries(FONTS).map(([k,[n]])=>`<button data-v="${k}">${n}</button>`).join('')}</div>
      <label class="sl" for="fWeight"><div><span>Weight</span><output id="oWeight"></output></div><input type="range" id="fWeight" min="200" max="900" step="1"></label>
      <label class="sl" for="fWidth"><div><span>Width</span><output id="oWidth"></output></div><input type="range" id="fWidth" min="80" max="120" step="1"></label>`,
    wire(el){
      el.querySelector('#fontSeg').addEventListener('click',e=>{const b=e.target.closest('button'); if(!b) return; S.font=b.dataset.v; save(); applyClock(); OB.fontViaPanel++; react('font');});
      el.querySelector('#fWeight').addEventListener('input',e=>{S.weight=+e.target.value; save(); applyClock();});
      el.querySelector('#fWidth').addEventListener('input',e=>{S.width=+e.target.value; save(); applyClock();});
    },
    sync(el){ el.querySelectorAll('#fontSeg button').forEach(x=>x.setAttribute('aria-pressed',x.dataset.v===S.font));
      el.querySelector('#fWeight').value=S.weight; el.querySelector('#oWeight').textContent=S.weight;
      el.querySelector('#fWidth').value=S.width; el.querySelector('#oWidth').textContent=S.width+'%'; }
  },
  look:{title:'Look', icon:'look',
    build:()=>`<div class="looks" id="looks"></div>
      <div class="lbl">Material</div>
      <div class="mseg" id="lMat"><button data-v="glass">Glass</button><button data-v="liquid">Liquid</button><button data-v="both">Both</button></div>
      ${sw('lGlass','Glass remaster')}${sw('lMotion','Era behaviour')}
      ${sw('lMax','Liquid Max in Dream')}
      <div class="lbl">Carry from Dream to Grounded</div>
      ${sw('cLiquid','Liquid look')}${sw('cRoam','Roaming')}${sw('cGlow','Glow')}
      <label class="sl" for="lLegib"><div><span>Legibility</span><output id="oLegib"></output></div><input type="range" id="lLegib" min="1" max="6" step="1"></label>
      <p class="note">A look redraws everything. Glass remaster keeps the era's colours, shapes and type but makes its surfaces real glass. Flicking, pinching and panels stay modern unless Era behaviour is on. The time machine's Story track uses the same setting.</p>`,
    wire(el){
      el.querySelector('#looks').addEventListener('click',e=>{const b=e.target.closest('[data-look]'); if(!b) return; setLook(b.dataset.look);});
      el.querySelector('#lGlass').addEventListener('change',e=>{S.remaster=e.target.checked; save(); applyStageView(); say(S.remaster?'Ooh. Same era, better glass.':'The original. Flat as it was.',1500,null,2);});
      [['cLiquid','liquid'],['cRoam','roam'],['cGlow','glow']].forEach(([id,k])=>el.querySelector('#'+id).addEventListener('change',e=>{S.carry[k]=e.target.checked; applyCarry();}));
      el.querySelector('#lMat').addEventListener('click',e=>{const b=e.target.closest('button'); if(!b) return; S.material=b.dataset.v; save(); applyLiquid(); refreshPanels();
        say({glass:'Glass. Rigid. Breakable. Careful.',liquid:'Liquid! Nothing breaks. Everything splashes.',both:'Both. Bit chaotic. I like it.'}[S.material],1600,null,2);});
      el.querySelector('#lMax').addEventListener('change',e=>{S.liquidMax=e.target.checked; save(); applyStageView(); if(!grounded()) say(S.liquidMax?'Ooh. So clear. Too clear.':'Phew. I can read again.',1500,null,1);});
      el.querySelector('#lLegib').addEventListener('input',e=>{S.legib=+e.target.value; save(); applyLiquid(); el.querySelector('#oLegib').textContent=LEGIB[S.legib];
        if(!grounded()&&S.liquidMax&&S.legib===1) say('Can anyone read this?',1400,null,1); if(S.legib===6) say('They fixed it.',1200,null,2);});
      el.querySelector('#lMotion').addEventListener('change',e=>{S.eraMotion=e.target.checked; save(); applyStageView();});
    },
    sync(el){
      el.querySelector('#looks').innerHTML=YEARS.slice().sort((a,b)=>a.era==='today'?-1:b.era==='today'?1:0).map(y=>{const k=y.era, cur=S.era===k;
        return `<button class="look-tile" data-look="${k}" aria-pressed="${cur}" aria-label="${LOOKNAME[k]} look">${lookPreview(k)}<b>${LOOKNAME[k]}</b><small>${k==='today'?'Home':y.y}</small></button>`;}).join('');
      el.querySelector('#lMotion').checked=S.eraMotion; el.querySelector('#lGlass').checked=S.remaster;
      el.querySelector('#cLiquid').checked=S.carry.liquid; el.querySelector('#cRoam').checked=S.carry.roam; el.querySelector('#cGlow').checked=S.carry.glow;
      el.querySelectorAll('#lMat button').forEach(x=>x.setAttribute('aria-pressed',x.dataset.v===S.material));
      el.querySelector('#lMax').checked=S.liquidMax; el.querySelector('#lLegib').value=S.legib; el.querySelector('#oLegib').textContent=LEGIB[S.legib];
    }
  },
  colour:{title:'Colour', icon:'colour',
    build:()=>`<div class="lbl">Appearance</div>
      <div class="mseg" id="themeSeg"><button data-v="auto">Auto</button><button data-v="light">Light</button><button data-v="dark">Dark</button></div>
      <div class="lbl">Favourite colour</div>
      <div class="dots" id="favs"><button class="dot auto" data-c="" aria-label="Match the backdrop"></button>${FAVS.map(([c,n])=>`<button class="dot" data-c="${c}" style="background:${c}" aria-label="${n}"></button>`).join('')}</div>
      ${drill('backdrop','Backdrop')}`,
    wire(el){
      el.querySelector('#themeSeg').addEventListener('click',e=>{const b=e.target.closest('button'); if(!b) return; S.theme=b.dataset.v; save(); applyTheme(); react('theme');});
      el.querySelector('#favs').addEventListener('click',e=>{const b=e.target.closest('.dot'); if(!b) return; S.fav=b.dataset.c||null; save(); applyColour(); react('fav');});
    },
    sync(el){ el.querySelectorAll('#themeSeg button').forEach(x=>x.setAttribute('aria-pressed',x.dataset.v===S.theme));
      el.querySelectorAll('#favs .dot').forEach(x=>x.setAttribute('aria-pressed',(x.dataset.c||null)===S.fav));
      el.querySelector('[data-val="backdrop"]').textContent=BD[S.bd].n; }
  },
  backdrop:{parent:'colour', title:'Backdrop', icon:'backdrop',
    build:()=>['Gradients','Mesh','Patterns'].map(g=>`<div class="lbl">${g}</div><div class="sws">${
      Object.entries(BD).filter(([,v])=>v.g===g).map(([k,v])=>`<button class="sw" data-bd="${k}"><i></i>${v.n}</button>`).join('')}</div>`).join(''),
    wire(el){ el.addEventListener('click',e=>{const b=e.target.closest('.sw'); if(!b) return; S.bd=b.dataset.bd; save(); applyColour(); react('bd');}); },
    sync(el){ const t=resolved(); el.querySelectorAll('.sw').forEach(b=>{b.querySelector('i').style.background=BD[b.dataset.bd][t].bg; b.setAttribute('aria-pressed',b.dataset.bd===S.bd);}); }
  },
  access:{title:'Accessibility', short:'Access', icon:'access',
    build:()=>`${sw('aSimpler','Simpler effects')}${sw('aClear','Clearer glass')}
      ${sw('aSound','Sounds')}
      <p class="note">Simpler effects follows your device's Reduce Motion until you change it here.</p>
      <button class="btn danger" id="aReset">Reset everything</button>`,
    wire(el){
      el.querySelector('#aSimpler').addEventListener('change',e=>{S.simpler=e.target.checked; save(); applyEffects();});
      el.querySelector('#aClear').addEventListener('change',e=>{S.clear=e.target.checked; save(); applyEffects();});
      el.querySelector('#aSound').addEventListener('change',e=>{S.sound=e.target.checked; save(); if(S.sound) beep([[1760,60],[0,60],[1760,60]]);});
      armReset(el.querySelector('#aReset'));
    },
    sync(el){ el.querySelector('#aSimpler').checked=simpler(); el.querySelector('#aClear').checked=S.clear; el.querySelector('#aSound').checked=S.sound; }
  },
  notes:{parent:'dev', title:'Notes from Pip', icon:'now',
    build:()=>`<div class="notes" id="notesList"></div>
      <div class="btns"><button class="btn" id="nCopy">Copy notes</button><button class="btn danger" id="nClear">Clear</button></div>
      <p class="note">What you told Pip, kept on this device. Copy them to send to the developer. No AI reads these.</p>`,
    wire(el){
      el.querySelector('#nCopy').addEventListener('click',async()=>{ const txt=NOTES.map(n=>`${n.when} · ${n.q} → ${n.a}  (${n.look}, stage ${n.stage})`).join('\n')||'No notes yet.';
        try{await navigator.clipboard.writeText(txt); toast('Notes copied');}catch{toast('Copy was blocked here');} });
      el.querySelector('#nClear').addEventListener('click',()=>{ NOTES.length=0; store.set('notes',NOTES); store.del('asked'); ASKED.clear(); refreshPanels(); toast('Notes cleared'); });
    },
    sync(el){ el.querySelector('#notesList').innerHTML=NOTES.length?NOTES.slice().reverse().map(n=>`<div class="nt"><small>${esc(n.when)} · ${esc(LOOKNAME[n.look]||n.look)}</small><span>${esc(n.q)}</span><b>${esc(n.a)}</b></div>`).join(''):'<p class="note">No notes yet. Pip asks now and then, or tap “Ask me something” in Pip’s panel.</p>'; }
  },
  plugins:{title:'Plugins', icon:'plug',
    tick(el){ PANELS.plugins.cost(el); },
    cost(el){ const H=window.PipHost; if(!H||!H.cost) return; const c=H.cost(), L=window.PipPlugins||[];
      const ms=v=>v==null?'–':v<.01?'<0.01':v.toFixed(2), budget=c.fps>90?1000/120:1000/60;
      const plugAvg=Object.values(c.plug).reduce((a,b)=>a+b,0), free=Math.max(0,budget-c.core-plugAvg), pc=v=>(Math.min(100,v/budget*100)).toFixed(1)+'%';
      el.querySelector('#plBar').innerHTML=`<i class="cb-core" style="width:${pc(c.core)}" title="Sandbox ${ms(c.core)} ms"></i><i class="cb-plug" style="width:${pc(plugAvg)}" title="Plugins ${ms(plugAvg)} ms"></i>`;
      el.querySelector('#plBar').setAttribute('aria-label',`Frame budget ${ms(budget)} ms: sandbox ${ms(c.core)}, plugins ${ms(plugAvg)}, free ${ms(free)}`);
      el.querySelector('#plLegend').innerHTML=`<span><i class="sw-core"></i>Sandbox ${ms(c.core)} ms</span><span><i class="sw-plug"></i>Plugins ${ms(plugAvg)} ms</span><span>Free ${ms(free)} of ${ms(budget)} ms</span>`;
      el.querySelector('#plCost').innerHTML=`<dt>Frame rate</dt><dd>${c.fps} fps</dd><dt>Sandbox, worst frame</dt><dd>${ms(c.coreWorst)} ms</dd>
        <dt>Page memory</dt><dd>${c.heapMB==null?'Not shared here':c.heapMB.toFixed(1)+' MB'}</dd><dt>Page elements</dt><dd>${c.elements}</dd>`;
      L.forEach(p=>{ const o=el.querySelector(`[data-cost="${p.id}"]`); if(!o) return;
        if(p.status!=='on'){ o.textContent=p.status==='off'?'Not loaded, so no cost.':''; return; }
        const a=c.plug[p.id]||0, w=c.worst[p.id]||0;
        o.textContent=`${ms(a)} ms a frame (${(a/budget*100).toFixed(1)}% of budget) · worst ${ms(w)} ms · ${p.bytes?(p.bytes/1024).toFixed(1)+' KB':'size –'} · +${p.nodes??'–'} elements · ready in ${ms(p.loadMs)} ms`; });
      PANELS.plugins._last=c; },
    build:()=>`<p class="note" id="plSum"></p>
      <div class="lbl">Cost right now</div>
      <div class="cost-bar" id="plBar" role="img"></div>
      <p class="cost-legend" id="plLegend"></p>
      <dl class="kv" id="plCost"></dl>
      <div class="lbl">Plugins</div><div class="plugs" id="plList"></div>
      <div class="lbl">Pip’s tours</div><div class="btns" id="plTours"></div>
      <div class="lbl">Built-in features</div>
      <p class="note">The sandbox’s own features, switchable live like plugins. Core parts stay on. A/B test measures a feature on for 3 s, then off for 3 s: play normally while it runs, as most features only cost something while they’re happening.</p>
      <div class="ab"><select id="abPick" aria-label="Feature to test"></select><button class="btn" id="abRun">A/B test</button></div>
      <p class="note" id="abOut" hidden></p>
      <details class="feats"><summary>All features <small id="ftCount"></small></summary><div id="ftList"></div></details>
      <div class="btns" id="plApply" hidden><button class="btn" id="plReload">Reload to apply</button></div>
      <div class="btns"><button class="btn" id="plCopy">Copy cost report</button></div>
      <div class="lbl">Bridge</div><dl class="kv" id="plKv"></dl>
      <p class="note">Cost figures are estimates from this browser, averaged each second. Time counts each plugin’s per-frame work, not its tap handlers. Safari doesn’t share memory figures; the real app gets measured in Xcode.</p>
      <p class="note">Shelves are where you think each idea belongs: Dream (sandbox only) → Trial (test pilots) → Grounded (the app you ship) → Core (always on). Use ‹ › to move one.</p>
      <p class="note">Plugins are files in plugins/ listed in PLUGINS in index.html. Switch one off here and it won’t load next time. A plugin that crashes is switched off for this visit; the sandbox keeps running.</p>`,
    wire(el){
      el.querySelector('#plList').addEventListener('change',e=>{ const id=e.target.dataset.plug; if(!id) return;
        const off=new Set(store.get('pluginsOff',[])); e.target.checked?off.delete(id):off.add(id); store.set('pluginsOff',[...off]);
        el.querySelector('#plApply').hidden=false; toast(e.target.checked?'Turns on after reload':'Turns off after reload'); });
      el.querySelector('#plReload').addEventListener('click',()=>location.reload());
      el.querySelector('#plList').addEventListener('click',e=>{ const b=e.target.closest('[data-shelf]'); if(!b) return; const p=(window.PipPlugins||[]).find(p=>p.id===b.dataset.shelf); if(!p) return;
        const i=clamp(SHELVES.indexOf(shelfOf(p))+(+b.dataset.dir),0,SHELVES.length-1), o=store.get('pluginShelf',{}); o[p.id]=SHELVES[i]; store.set('pluginShelf',o);
        toast(`${p.name} → ${SHELF_NAME[SHELVES[i]]}`); PANELS.plugins.sync(el); });
      const ftApply=()=>{ save(); applyStageView(); renderTM(); };
      el.querySelector('#ftList').addEventListener('change',e=>{ const id=e.target.dataset.ft; if(!id) return; if(e.target.checked) delete S.off[id]; else S.off[id]=true; ftApply(); PANELS.plugins.sync(el); });
      el.querySelector('#abRun').addEventListener('click',async e=>{ const H=window.PipHost, id=el.querySelector('#abPick').value, f=FEATURES.find(x=>x.id===id), out=el.querySelector('#abOut'), b=e.currentTarget;
        if(!H?.measure||!f) return; const was=!!S.off[id], ms=v=>v<.01?'<0.01':v.toFixed(2), budget=1000/60;
        b.disabled=true; out.hidden=false; out.textContent=`Measuring “${f.name}” on…`;
        delete S.off[id]; ftApply(); const a=await H.measure(3000);
        out.textContent=`Now “${f.name}” off…`; S.off[id]=true; ftApply(); const c=await H.measure(3000);
        if(was) S.off[id]=true; else delete S.off[id]; ftApply(); b.disabled=false; const d=a.ms-c.ms;
        out.textContent=`${f.name}: on ${ms(a.ms)} ms a frame (worst ${ms(a.worst)}, ${a.fps} fps) · off ${ms(c.ms)} ms (worst ${ms(c.worst)}, ${c.fps} fps) · ${Math.abs(d)<.02?'no clear difference':d>0?`costs about ${ms(d)} ms a frame (${(d/budget*100).toFixed(1)}% of budget)`:'off measured higher, so it’s noise'}.`;
        PANELS.plugins.sync(el); });
      el.querySelector('#plTours').addEventListener('click',e=>{ const b=e.target.closest('[data-tour]'); if(!b) return; const t=(window.PipHost?.tours||[]).find(t=>t.id===b.dataset.tour);
        if(t&&!t.start()) toast(!S.naviOn?'Turn Pip on first':chat()<1?'Pip is set to quiet. Raise Chattiness in Pip’s panel.':'Pip is busy. Try again in a moment.'); });
      el.querySelector('#plCopy').addEventListener('click',async()=>{ const c=window.PipHost?.cost?.(); if(!c) return; const f=v=>v==null?'–':v.toFixed(3);
        const txt=[`Pip Sandbox cost report · ${new Date().toLocaleString()} · ${navigator.userAgent}`,`Frame rate ${c.fps} fps · sandbox ${f(c.core)} ms/frame (worst ${f(c.coreWorst)}) · memory ${c.heapMB==null?'n/a':c.heapMB.toFixed(1)+' MB'} · ${c.elements} elements`]
          .concat((window.PipPlugins||[]).map(p=>`${p.name} ${p.version||''} [${p.status}]: ${f(c.plug[p.id])} ms/frame, worst ${f(c.worst[p.id])} ms, ${p.bytes?(p.bytes/1024).toFixed(1)+' KB':'size n/a'}, +${p.nodes??'–'} elements, ready in ${f(p.loadMs)} ms`)).join('\n');
        try{ await navigator.clipboard.writeText(txt); toast('Cost report copied'); }catch{ toast('Copy was blocked here'); } });
      window.addEventListener('pip:plugins',()=>{ if(!el.hidden) PANELS.plugins.sync(el); });
    },
    sync(el){ const L=window.PipPlugins||[], off=new Set(store.get('pluginsOff',[])), H=window.PipHost;
      const word={on:'On',off:'Off',failed:'Failed',loading:'Loading'};
      el.querySelector('#plSum').textContent=L.length?`${L.filter(p=>p.status==='on').length} of ${L.length} running · `+SHELVES.slice().reverse().map(k=>`${SHELF_NAME[k]} ${L.filter(p=>shelfOf(p)===k).length}`).join(' · '):'No plugins yet.';
      el.querySelector('#plList').innerHTML=L.map(p=>`<div class="plug" data-st="${p.status}">
        <div class="plug-top">${p.icon?`<span class="plug-ic">${p.icon}</span>`:''}<b>${esc(p.name)}</b><small>${esc(p.version||'')}</small><span class="plug-st">${word[p.status]||p.status}</span>
          <input type="checkbox" class="switch" data-plug="${esc(p.id)}" aria-label="${esc(p.name)} on" ${off.has(p.id)?'':'checked'}></div>
        ${p.what?`<p class="note">${esc(p.what)}</p>`:''}
        ${p.error?`<p class="note plug-err">${esc(p.error)}</p>`:''}
        <div class="shelf" data-st-shelf="${shelfOf(p)}"><button class="sh-btn" data-shelf="${esc(p.id)}" data-dir="-1" aria-label="Move ${esc(p.name)} towards Dream" ${shelfOf(p)==='dream'?'disabled':''}>‹</button><span>${SHELF_NAME[shelfOf(p)]}</span><button class="sh-btn" data-shelf="${esc(p.id)}" data-dir="1" aria-label="Promote ${esc(p.name)} towards Core" ${shelfOf(p)==='core'?'disabled':''}>›</button></div>
        <small class="plug-cost" data-cost="${esc(p.id)}"></small>
        <small class="plug-meta">${p.added?'Added '+esc(p.added)+' · ':''}${esc(p.file)}</small></div>`).join(''); PANELS.plugins.cost(el);
      const stv=S.stageView||LATEST, FT=FEATURES.filter(f=>f.stage<=stv), pick=el.querySelector('#abPick'), keep=pick.value;
      el.querySelector('#ftCount').textContent=`${FT.filter(f=>f.core||!S.off[f.id]).length} of ${FT.length} on`;
      el.querySelector('#ftList').innerHTML=FT.map(f=>`<div class="row"><label for="ft-${f.id}">${esc(f.name)} <small>${f.core?'core':'stage '+f.stage}</small></label><input type="checkbox" class="switch" id="ft-${f.id}" data-ft="${f.id}" ${f.core||!S.off[f.id]?'checked':''} ${f.core?'disabled':''}></div>`).join('');
      pick.innerHTML=FT.filter(f=>!f.core).map(f=>`<option value="${f.id}">${esc(f.name)}</option>`).join(''); if(keep) pick.value=keep;
      const T=H?.tours||[]; el.querySelector('#plTours').innerHTML=T.length?T.map(t=>`<button class="btn" data-tour="${esc(t.id)}">${esc(t.name)}</button>`).join(''):'<p class="note">No tours yet. A plugin can add one.</p>';
      el.querySelector('#plKv').innerHTML=`<dt>PipHost</dt><dd>${H?'Ready':'Missing'}</dd><dt>Frame hooks</dt><dd>${H?H.frame.length:0}</dd><dt>Bump hooks</dt><dd>${H?H.bump.length:0}</dd>`; }
  },
  dev:{title:'Developer', short:'Dev', icon:'dev',
    tick(el){ const o=el.querySelector('#devFps'); if(o) o.textContent=FPS.v+' fps'; },
    build:()=>`<div class="lbl">Contrast</div><dl class="kv" id="devKv"></dl>
      ${sw('dOut','Show outlines')}
      ${drill('notes','Notes from Pip')}
      <div class="lbl">Testing</div>
      <div class="btns"><button class="btn" id="dReload">Reload</button><button class="btn" id="dFix">Fix everything</button></div>
      <div class="btns"><button class="btn" id="dPip">Reset Pip</button><button class="btn" id="dTour">Grand tour</button></div>
      <button class="btn danger" id="dCrash">Crash the clock</button>
      <div class="btns"><button class="btn" id="dLayout">Reset layout</button><button class="btn" id="dCopy">Copy settings</button></div>
      <p class="note">Panels come from one registry. Add an entry and it gets a rail button, or a parent to open beside.</p>`,
    wire(el){
      el.querySelector('#dReload').addEventListener('click',()=>location.reload());
      el.querySelector('#dFix').addEventListener('click',()=>{ for(const k in FL) delete FL[k]; CT=null; C.tvx=C.tvy=0; if(G.on) restore(true); else { G.cracks=0; delete cardIn.dataset.cracks; }
        Object.values(PS).forEach(({el:p})=>{ p._cracks=0; p.querySelectorAll('.pcrack').forEach(c=>c.remove()); p.style.transform=''; clampPanel(p); });
        C.s=clamp(C.s,.6,1.7); C.x=clamp(C.x,40,stage.clientWidth-40); C.y=clamp(C.y,90,stage.clientHeight-40); setCard(); holdEnd(); askEl.hidden=true; ASK.open=null; toast('Everything fixed'); });
      el.querySelector('#dPip').addEventListener('click',()=>{ Object.assign(N,{pat:1,mood:'',hard:[],tiredUntil:0,dizzyUntil:0,drink:null,pet:null,back:false,vx:0,vy:0}); sipEl.hidden=true;
        if(S.naviOn){ N.awake=true; N.state='free'; goPerch(); setMood('happy',1500); say('Fresh start. Hello!',1500,null,0); } toast('Pip reset'); });
      el.querySelector('#dTour').addEventListener('click',()=>{ store.del('seen'); TOUR.active=false; TOUR.started=true; if(!N.awake&&S.naviOn) wake(); tourStart(true,true); });
      el.querySelector('#dCrash').addEventListener('click',()=>{ if(G.on) restore(true); else crash(); });
      el.querySelector('#dOut').addEventListener('change',e=>{S.outlines=e.target.checked; save(); applyEffects();});
      el.querySelector('#dLayout').addEventListener('click',()=>{store.del('layout'); Object.keys(PS).forEach(id=>{PS[id].el.hidden=true;}); zOrder=[]; layout(true); toast('Layout reset');});
      el.querySelector('#dCopy').addEventListener('click',async()=>{const txt=JSON.stringify({version:VERSION,prefs:S},null,2);
        try{await navigator.clipboard.writeText(txt); toast('Settings copied');}catch{toast('Copy was blocked here');}});
    },
    sync(el){
      const c=contrast(cardInk,accent), p=resolved()==='dark'?'#f6f4fb':'#17161e';
      const ok=(r,n)=>`${r.toFixed(1)}:1 <span class="${r>=n?'pass':'fail'}">${r>=n?'pass':'low'}</span>`;
      el.querySelector('#devKv').innerHTML=`<dt>Frame rate</dt><dd id="devFps">${FPS.v} fps</dd><dt>Clock text</dt><dd>${ok(c,3)}</dd><dt>Accent on panel</dt><dd>${ok(contrast(accent,resolved()==='dark'?'#1c1a24':'#f4f5f9'),3)}</dd><dt>Build</dt><dd>${VERSION}</dd>`;
      el.querySelector('#dOut').checked=S.outlines; void p;
    }
  }
};

function armReset(btn){
  let armedT=0;
  btn.addEventListener('click',()=>{
    if(!btn.classList.contains('armed')){ btn.classList.add('armed'); btn.textContent='Tap again to erase settings and layout'; clearTimeout(armedT);
      armedT=setTimeout(()=>{btn.classList.remove('armed'); btn.textContent='Reset everything';},4000); return; }
    store.clear(); location.reload();
  });
}

/* =====================================================================
   4. Panel engine: build, open beside parent, drag (children follow),
      close (children close too), bring to front, save layout.
   ===================================================================== */
const PS={};           // id -> {el, dock}
let zOrder=[];         // open panels, back to front
let SR=stage.getBoundingClientRect();
const pv={};           // panel drag velocity, for nudging the companion
/* rel() is cached for one frame: positions are read once, not dozens of times per frame. */
const RC=new Map();
function rel(el){ let c=RC.get(el); if(c) return c; const r=el.getBoundingClientRect(); c={left:r.left-SR.left, top:r.top-SR.top, right:r.right-SR.left, bottom:r.bottom-SR.top, width:r.width, height:r.height}; RC.set(el,c); return c; }
const titleOf=id=>{const t=PANELS[id].title; return typeof t==='function'?t():t;};
const kids=id=>Object.keys(PANELS).filter(k=>PANELS[k].parent===id);
const openIds=()=>zOrder.slice();
const openEls=()=>zOrder.map(id=>PS[id].el);

function ensure(id){
  if(PS[id]) return PS[id].el;
  const d=PANELS[id], el=document.createElement('section');
  el.className='panel glass'+(d.parent?' child':''); el.id='p-'+id; el.hidden=true; el.setAttribute('aria-label',titleOf(id)+' panel');
  el.innerHTML=`<header class="ph">${d.parent?`<button class="icon-btn" data-back aria-label="Back to ${esc(titleOf(d.parent))}">${svg('back',2)}</button>`:svg(d.icon)}
    <h2>${d.parent?`<span class="crumb">${esc(titleOf(d.parent))}</span>`:''}<span class="ttl">${esc(titleOf(id))}</span></h2>
    <button class="icon-btn" data-close aria-label="Close ${esc(titleOf(id))}">×</button></header><div class="pb">${d.build()}</div>`;
  panelsEl.appendChild(el); PS[id]={el,dock:true};
  d.wire?.(el); d.sync?.(el); wireDrag(id,el);
  el.querySelectorAll('.mseg').forEach(liquidSeg); el.querySelectorAll('input[type=range]').forEach(fillRange);
  el.querySelector('[data-close]').addEventListener('click',()=>closePanel(id));
  el.querySelector('[data-back]')?.addEventListener('click',()=>closePanel(id));
  return el;
}
function front(id){ zOrder=zOrder.filter(x=>x!==id); zOrder.push(id); zOrder.forEach((x,i)=>PS[x].el.style.zIndex=20+Math.min(i,8)); }
function pos(el,x,y){ el.style.left=x+'px'; el.style.top=y+'px'; RC.delete(el); }
function clampPanel(el){
  const W=stage.clientWidth,H=stage.clientHeight;
  const floor=H-(typeof tmEl!=='undefined'&&!tmEl.hidden?dockH():0);
  pos(el, clamp(parseFloat(el.style.left)||0,8,Math.max(8,W-el.offsetWidth-8)), clamp(parseFloat(el.style.top)||0,64,Math.max(64,floor-el.offsetHeight-8)));
}
function placeTop(el){
  const W=stage.clientWidth,H=stage.clientHeight, w=el.offsetWidth;
  if(W>=760){
    const others=openIds().filter(x=>!PANELS[x].parent).map(x=>PS[x].el).filter(o=>o!==el);
    let x=W-w-16, y=76;
    for(let col=0; col<3; col++){
      const inCol=others.filter(o=>Math.abs(parseFloat(o.style.left)-x)<w/2);
      y=inCol.length?Math.max(...inCol.map(o=>parseFloat(o.style.top)+o.offsetHeight+12)):76;
      const floor=H-(typeof tmEl!=='undefined'?dockH():0);
      if(y+Math.min(el.offsetHeight,floor-84)<=floor-8) break; x-=w+12; y=76;
    }
    pos(el,x,y);
  } else {
    /* phone: one top-level panel at a time, docked bottom-right */
    openIds().filter(x=>!PANELS[x].parent&&PS[x].el!==el).forEach(closePanel);
    pos(el,W-w-16,H-dockH()-el.offsetHeight-8);
  }
  clampPanel(el);
}
function placeChild(el,parentEl){
  const W=stage.clientWidth, p=rel(parentEl), w=el.offsetWidth;
  let x, y=p.top;
  if(p.right+12+w<=W-8) x=p.right+12;
  else if(p.left-12-w>=8) x=p.left-12-w;
  else { x=p.left+22; y=p.top+40; }   // no room beside: stack on top, offset like a card deck
  pos(el,x,y); clampPanel(el);
}
function openPanel(id,opts={}){
  const d=PANELS[id], el=ensure(id), was=!el.hidden;
  if(d.parent && (!PS[d.parent]||PS[d.parent].el.hidden)) openPanel(d.parent);
  if(d.parent) kids(d.parent).filter(k=>k!==id).forEach(closePanel);   // one child per parent
  el.hidden=false; el._cracks=0; el.querySelectorAll('.pcrack').forEach(c=>c.remove()); d.sync?.(el); front(id);
  if(!was){
    if(opts.at){ pos(el,opts.at.x,opts.at.y); clampPanel(el); PS[id].dock=opts.at.dock!==false; }
    else if(d.parent){ placeChild(el,PS[d.parent].el); PS[id].dock=true; }
    else placeTop(el);
    if(!simpler()&&el.animate&&!opts.quiet){
      const from=d.parent?{translate:(parseFloat(el.style.left)>parseFloat(PS[d.parent].el.style.left)?'-14px':'14px')+' 0',opacity:0}:{translate:'0 10px',opacity:0};
      el.animate([from,{translate:'0 0',opacity:1}],{duration:260,easing:'cubic-bezier(.2,1.1,.4,1)'});
    }
  }
  syncChrome(); if(!opts.quiet) saveLayout();
}
function closePanel(id){
  if(!PS[id]||PS[id].el.hidden) return;
  kids(id).forEach(closePanel);
  PS[id].el.hidden=true; zOrder=zOrder.filter(x=>x!==id); PS[id].el.style.setProperty('--la',0);
  syncChrome(); saveLayout();
}
function togglePanel(id){ (PS[id]&&!PS[id].el.hidden)?closePanel(id):openPanel(id); }
function syncChrome(){
  rail.querySelectorAll('.ri[data-sec]').forEach(b=>b.setAttribute('aria-current',!!(PS[b.dataset.sec]&&!PS[b.dataset.sec].el.hidden)));
  document.querySelectorAll('.drill[data-open]').forEach(b=>b.setAttribute('aria-expanded',!!(PS[b.dataset.open]&&!PS[b.dataset.open].el.hidden)));
}
function refreshPanels(){ Object.keys(PS).forEach(id=>{ if(!PS[id].el.hidden){ PANELS[id].sync?.(PS[id].el); PS[id].el.querySelectorAll('input[type=range]').forEach(fillRange); } }); }
function nameChanged(){
  ['pip'].forEach(id=>{ if(PS[id]) PS[id].el.querySelector('.ttl').textContent=titleOf(id); });
  ['pipNow','persona','pipBody'].forEach(id=>{ if(PS[id]) PS[id].el.querySelector('.crumb').textContent=titleOf('pip'); });
  $('#naviSwLbl').textContent=S.name; rail.querySelector('[data-sec="pip"]').setAttribute('aria-label',S.name);
  rail.querySelector('[data-sec="pip"] span').textContent=S.name;
}
function wireDrag(id,el){
  const h=el.querySelector('.ph'); let d=null;
  let holdT=0, hs=null;
  el.addEventListener('pointerdown',e=>{ if(!F('lens')||e.target.closest('button,input,label,.drill,.ph,.sw,.look-tile,.pers,.mseg')) return;
    hs={x:e.clientX,y:e.clientY}; clearTimeout(holdT); holdT=setTimeout(()=>{ if(hs) holdStart(el,e); },300); });
  el.addEventListener('pointermove',e=>{ if(hold&&hold.el===el){ holdMove(e); return; } if(hs&&Math.hypot(e.clientX-hs.x,e.clientY-hs.y)>8){ clearTimeout(holdT); hs=null; } });
  const hup=()=>{ clearTimeout(holdT); hs=null; if(hold&&hold.el===el) holdEnd(); };
  el.addEventListener('pointerup',hup); el.addEventListener('pointercancel',hup);
  el.addEventListener('pointerdown',e=>{ e.stopPropagation(); front(id);
    if((!grounded()||N.back)&&S.naviOn&&!e.target.closest('button,input,label,.drill')){ const r=rel(el); if(N.x>r.left&&N.x<r.right&&N.y>r.top&&N.y<r.bottom) popOut(el,e); } });
  h.addEventListener('pointerdown',e=>{ if(e.target.closest('button')) return; h.setPointerCapture(e.pointerId);
    const docked=kids(id).filter(k=>PS[k]&&!PS[k].el.hidden&&PS[k].dock).map(k=>({el:PS[k].el,ox:parseFloat(PS[k].el.style.left),oy:parseFloat(PS[k].el.style.top)}));
    d={sx:e.clientX,sy:e.clientY,ox:parseFloat(el.style.left)||0,oy:parseFloat(el.style.top)||0,lx:e.clientX,ly:e.clientY,lt:now(),docked,moved:false};
    el.classList.add('lifted'); });
  h.addEventListener('pointermove',e=>{ if(!d) return; const t=now(), dt=Math.max(1,t-d.lt)/1000;
    pv[el.id]={x:(e.clientX-d.lx)/dt,y:(e.clientY-d.ly)/dt}; d.lx=e.clientX; d.ly=e.clientY; d.lt=t;
    const dx=e.clientX-d.sx, dy=e.clientY-d.sy; if(Math.hypot(dx,dy)>4) d.moved=true;
    pos(el,d.ox+dx,d.oy+dy); clampPanel(el);
    const rx=parseFloat(el.style.left)-d.ox, ry=parseFloat(el.style.top)-d.oy;
    d.docked.forEach(c=>{pos(c.el,c.ox+rx,c.oy+ry);});
    if((isLiquid()||stage.classList.contains('lmax'))&&!simpler()){ const v=pv[el.id]; el.style.transition='transform .16s ease-out';
      el.style.transform=`skew(${clamp(-v.x/180,-8,8).toFixed(2)}deg,${clamp(-v.y/300,-4,4).toFixed(2)}deg) scale(${(1+Math.min(.04,Math.hypot(v.x,v.y)/40000)).toFixed(3)})`; }
    if(d.moved&&PANELS[id].parent) PS[id].dock=false; });
  const up=()=>{ if(!d) return; el.style.transition=''; el.style.transform=''; const v=pv[el.id], fresh=now()-d.lt<70, kids=d.docked.map(c=>c.el);
    d.docked.forEach(c=>clampPanel(c.el)); const m=d.moved; d=null; pv[el.id]=null; el.classList.remove('lifted');
    if(m&&v&&fresh&&F('flickpanel')&&Math.hypot(v.x,v.y)>500){ const sp=Math.hypot(v.x,v.y), cap=Math.min(1,3400/sp); FL[id]={vx:v.x*cap,vy:v.y*cap,kids}; }
    else if(m) saveLayout(); };
  h.addEventListener('pointerup',up); h.addEventListener('pointercancel',up);
}
stage.addEventListener('click',e=>{ const b=e.target.closest('.drill[data-open]'); if(b) togglePanel(b.dataset.open); });
addEventListener('keydown',e=>{ if(e.key==='Escape'&&zOrder.length){ closePanel(zOrder[zOrder.length-1]); } });

/* ---------- Liquid controls: a glass droplet you can drag across segments; ranges fill. ---------- */
function liquidSeg(seg){
  if(seg._liq) return; seg._liq=true; seg.classList.add('lseg');
  const drop=document.createElement('i'); drop.className='drop'; drop.setAttribute('aria-hidden','true'); seg.prepend(drop);
  const btns=()=>[...seg.querySelectorAll('button')];
  const sync=()=>{ const b=btns().find(x=>x.getAttribute('aria-pressed')==='true'); drop.style.opacity=b?1:0; if(b&&!seg._drag){ drop.style.width=b.offsetWidth+'px'; drop.style.transform=`translateX(${b.offsetLeft}px)`; } };
  new MutationObserver(sync).observe(seg,{subtree:true,attributes:true,attributeFilter:['aria-pressed']});
  new ResizeObserver(sync).observe(seg); requestAnimationFrame(sync);
  seg.addEventListener('pointerdown',e=>{ if(!stage.classList.contains('lctl')) return; e.stopPropagation(); seg.setPointerCapture(e.pointerId); seg.classList.add('pressed');
    seg._drag={sx:e.clientX,lx:e.clientX,lt:now(),moved:false,w:drop.offsetWidth}; });
  seg.addEventListener('pointermove',e=>{ const d=seg._drag; if(!d) return; if(Math.abs(e.clientX-d.sx)>5) d.moved=true; if(!d.moved) return;
    const r=seg.getBoundingClientRect(), x=clamp(e.clientX-r.left-d.w/2,3,r.width-d.w-3), t=now(), v=(e.clientX-d.lx)/Math.max(1,t-d.lt)*1000; d.lx=e.clientX; d.lt=t;
    drop.classList.add('dragging'); drop.style.transform=`translateX(${x}px) scaleX(${(1+Math.min(.35,Math.abs(v)/2400)).toFixed(3)})`; });
  const up=e=>{ const d=seg._drag; seg._drag=null; seg.classList.remove('pressed'); drop.classList.remove('dragging'); if(!d) return;
    if(d.moved){ const r=seg.getBoundingClientRect(), cx=e.clientX-r.left; const b=btns().reduce((a,b)=>Math.abs(b.offsetLeft+b.offsetWidth/2-cx)<Math.abs(a.offsetLeft+a.offsetWidth/2-cx)?b:a); b.click(); }
    else { const b=document.elementFromPoint(e.clientX,e.clientY)?.closest('button'); if(b&&seg.contains(b)) b.click(); }
    sync(); };
  seg.addEventListener('pointerup',up); seg.addEventListener('pointercancel',up);
  seg.addEventListener('click',e=>{ if(stage.classList.contains('lctl')&&e.isTrusted&&e.detail>0) e.stopImmediatePropagation(); },true);
}
function fillRange(r){ const k=(r.value-r.min)/(r.max-r.min)*100; r.style.setProperty('--pct',k+'%'); }
document.addEventListener('input',e=>{ if(e.target.type==='range') fillRange(e.target); });

/* ---------- Hold the glass: press and hold a panel and the frost clears under your finger. ---------- */
const lensEl=$('#lens'); let hold=null;
function holdStart(el,e){
  hold={el,id:e.pointerId,found:false}; el.setPointerCapture(e.pointerId); el.classList.add('holding'); lensEl.classList.add('on'); learnt('lens'); holdMove(e);
  if(navigator.vibrate) try{navigator.vibrate(8);}catch{}
}
function holdMove(e){
  if(!hold) return; const r=rel(hold.el), x=e.clientX-SR.left, y=e.clientY-SR.top;
  hold.el.style.setProperty('--hx',(x-r.left)+'px'); hold.el.style.setProperty('--hy',(y-r.top)+'px'); lensEl.style.transform=`translate(${x-64}px,${y-64}px)`;
  P.x=x; P.y=y; P.t=now();
  if(!hold.found&&N.back&&S.naviOn&&Math.hypot(N.x-x,N.y-y)<64){ hold.found=true; N.lookPt={x,y}; N.lookUntil=now()+1500; N.hopT=now(); setMood('happy',1500); say(N.mood==='sulk'?'Hey! I\'m sulking in here.':pick(['Oh! Hello.','You found me.','I can see you too.']),1400,null,1); }
}
function holdEnd(){ if(!hold) return; hold.el.classList.remove('holding'); lensEl.classList.remove('on'); hold=null; }

/* ---------- Emoji face codes: mixed-radix number → three emoji (64 each) + one check emoji. ---------- */
const EMO=Array.from('🍎🍊🍋🍇🍓🍒🍑🥝🍍🥥🥑🍆🥕🌽🍄🥐🍩🍪🎂🍭🍯🧁🍵🐝🐞🦋🐌🐙🐳🐬🐠🦊🐼🐨🐯🦁🐸🐵🦉🐧🦄🐢🌵🌲🌴🌻🌷🌹🍀🌈🌙🌟🔥🌊🎈🎁🎨🎲🎸🎺🚀🛸💎🔮');
const WEIGHTS=[300,500,650,850];
const FIELDS=()=>[['face',FACES.map(f=>f[0])],['fav',[null,...FAVS.map(f=>f[0])]],['bd',Object.keys(BD)],['font',Object.keys(FONTS)],['weight',WEIGHTS],['date',[true,false]],['h24',[false,true]]];
function encodeFace(){
  let n=0; FIELDS().forEach(([k,opts])=>{ let v=k==='weight'?WEIGHTS.reduce((a,b)=>Math.abs(b-S.weight)<Math.abs(a-S.weight)?b:a):S[k]; let i=opts.indexOf(v); if(i<0) i=0; n=n*opts.length+i; });
  const d=[Math.floor(n/4096)%64,Math.floor(n/64)%64,n%64], c=(d[0]+d[1]*3+d[2]*7+11)%64;
  return d.map(x=>EMO[x]).join('')+EMO[c];
}
function decodeFace(str){
  const e=Array.from(str).filter(ch=>EMO.includes(ch)); if(e.length<4) return null;
  const d=e.slice(0,3).map(ch=>EMO.indexOf(ch)), c=EMO.indexOf(e[3]); if((d[0]+d[1]*3+d[2]*7+11)%64!==c) return null;
  let n=d[0]*4096+d[1]*64+d[2]; const f={}, fl=FIELDS();
  for(let i=fl.length-1;i>=0;i--){ const [k,opts]=fl[i]; f[k]=opts[n%opts.length]; n=Math.floor(n/opts.length); }
  return n===0?f:null;
}
let faceBackup=null;
function setFaceFields(f){ Object.assign(S,f); save(); applyTheme(); applyClock(); applyFace(); tick(); refreshPanels(); }
function previewFace(f){
  if(!F('share')) return; const keys=Object.keys(f); faceBackup=Object.fromEntries(keys.map(k=>[k,S[k]])); setFaceFields(f);
  if(!S.naviOn){ toast('Face applied'); faceBackup=null; return; }
  if(!N.awake) wake(); N.hopT=now(); N.lookPt=mid(cardRect()); N.lookUntil=now()+2500; clearTimeout(bubbleT); bubble.classList.remove('on'); bubbleOn=false;
  ASK.open={id:'_face'}; $('#askQ').textContent='Someone sent you a face. Keep it?';
  $('#askChips').innerHTML='<button class="chip" data-face-keep>Keep</button><button class="chip ghost" data-face-undo>Undo</button>'; askEl.hidden=false;
}
document.addEventListener('paste',e=>{ const t=e.target; if(t&&(t.tagName==='INPUT'||t.tagName==='TEXTAREA')&&t.id!=='shIn') return;
  const txt=(e.clipboardData||window.clipboardData)?.getData('text')||''; const f=decodeFace(txt);
  if(f){ e.preventDefault(); previewFace(f); } else if(Array.from(txt).filter(ch=>EMO.includes(ch)).length>=4){ e.preventDefault(); say('That code\'s smudged. Check the last emoji?',1800,null,0); } });

/* ---------- Flick and smash: panels fly, bounce, crack where they hit, and shatter. ---------- */
const FL={};
/* impact hooks: a plugin can answer a panel hitting the wall its own way (return true to replace the default) */
const IMPACT=[];
function panelFling(dt){
  const W=stage.clientWidth, H=stage.clientHeight-dockH();
  for(const id in FL){ const f=FL[id], el=PS[id]?.el; if(!el||el.hidden){ delete FL[id]; continue; }
    const w=el.offsetWidth, h=el.offsetHeight, k=Math.exp(-2.6*dt), x0=parseFloat(el.style.left), y0=parseFloat(el.style.top);
    let x=x0+f.vx*dt, y=y0+f.vy*dt; f.vx*=k; f.vy*=k;
    const hit=(sp,lx,ly,nx,ny)=>{ if(IMPACT.some(f=>{ try{ return f(el,{sp,lx,ly,nx,ny}); }catch(err){ console.error(err); } })) return; if(sp>300&&isLiquid()) splash(el,lx,ly,sp,nx,ny); if(sp>900&&F('smash')&&canBreak()) crackPanel(id,el,lx,ly,sp,nx,ny); else if(sp>350&&!isLiquid()) beep([[140,25]]); };
    if(x<8){ x=8; if(f.vx<0){ hit(-f.vx,0,clamp(h/2+f.vy*.08,24,h-24),1,0); f.vx=-f.vx*.5; } }
    if(x>W-w-8){ x=W-w-8; if(f.vx>0){ hit(f.vx,w,clamp(h/2+f.vy*.08,24,h-24),-1,0); f.vx=-f.vx*.5; } }
    if(y<64){ y=64; if(f.vy<0){ hit(-f.vy,clamp(w/2+f.vx*.08,24,w-24),0,0,1); f.vy=-f.vy*.5; } }
    if(y>H-h-8&&h<H-80){ y=H-h-8; if(f.vy>0){ hit(f.vy,clamp(w/2+f.vx*.08,24,w-24),h,0,-1); f.vy=-f.vy*.5; } }
    if(!FL[id]) continue;
    pos(el,x,y); f.kids.forEach(c=>{ if(!c.hidden) pos(c,parseFloat(c.style.left)+x-x0,parseFloat(c.style.top)+y-y0); });
    pv[el.id]={x:f.vx,y:f.vy};
    if(Math.hypot(f.vx,f.vy)<25){ delete FL[id]; pv[el.id]=null; f.kids.forEach(clampPanel); saveLayout(); } }
}
/* Cracks radiate from the impact point; the spread leans away from the wall it hit. */
function crackPanel(id,el,lx,ly,sp,nx,ny){
  el._cracks=(el._cracks||0)+1; G.lastHit=now();
  if(el._cracks>=2||sp>2700){ smashPanel(id,el,lx,ly,sp,nx,ny); return; }
  const w=el.offsetWidth, h=el.offsetHeight, base=Math.atan2(ny,nx), n=6+Math.round(sp/500);
  let d=''; for(let i=0;i<n;i++){ const a=base+(Math.random()-.5)*2.4, L=40+Math.random()*(70+sp/18); let x=lx, y=ly; d+=`M${x.toFixed(1)} ${y.toFixed(1)}`;
    for(let j=1;j<=3;j++){ x+=Math.cos(a+(Math.random()-.5)*.6)*L/3; y+=Math.sin(a+(Math.random()-.5)*.6)*L/3; d+=` L${x.toFixed(1)} ${y.toFixed(1)}`; } }
  const svg=document.createElementNS('http://www.w3.org/2000/svg','svg'); svg.setAttribute('class','pcrack'); svg.setAttribute('viewBox',`0 0 ${w} ${h}`); svg.setAttribute('aria-hidden','true');
  svg.innerHTML=`<circle cx="${lx}" cy="${ly}" r="${4+sp/400}"/><path d="${d}"/>`; el.appendChild(svg);
  if(S.sound&&F('shatter')) shatterSound(sp*.35); else beep([[200,60]]); if(!simpler()&&el.animate) el.animate([{translate:'0 0'},{translate:`${nx*-6}px ${ny*-6}px`},{translate:'0 0'}],{duration:180});
  if(N.awake&&S.naviOn){ N.lookPt={x:rel(el).left+lx,y:rel(el).top+ly}; N.lookUntil=now()+1400; say(pick(['Ooh, that cracked.','Mind the glass!','That\'ll leave a mark.']),1300,null,1); }
}
/* Literal liquid glass: squash against the wall, ripple back, splash droplets that arc and fall. */
function splash(el,lx,ly,sp,nx,ny){
  const r=rel(el), ix=r.left+lx, iy=r.top+ly, k=Math.min(.2,sp/9000);
  if(!simpler()&&el.animate) el.animate([{transformOrigin:`${lx}px ${ly}px`,scale:'1 1'},{transformOrigin:`${lx}px ${ly}px`,scale:`${1-k*Math.abs(nx)+k*.5*Math.abs(ny)} ${1-k*Math.abs(ny)+k*.5*Math.abs(nx)}`,offset:.25},{transformOrigin:`${lx}px ${ly}px`,scale:`${1+k*.35*Math.abs(nx)} ${1+k*.35*Math.abs(ny)}`,offset:.55},{transformOrigin:`${lx}px ${ly}px`,scale:'1 1'}],{duration:620,easing:'ease-out'});
  if(!simpler()){ const n=Math.min(16,4+Math.round(sp/260));
    for(let i=0;i<n;i++){ const dr=document.createElement('i'); dr.className='drop-fx'; const sz=5+Math.random()*12; dr.style.width=dr.style.height=sz+'px';
      const a=Math.atan2(ny,nx)+(Math.random()-.5)*1.9, v=(.2+Math.random()*.55)*Math.min(sp,2600)*.3, x0=ix+(Math.random()-.5)*30, y0=iy+(Math.random()-.5)*30;
      const x1=x0+Math.cos(a)*v, y1=y0+Math.sin(a)*v; stage.appendChild(dr);
      dr.animate([{transform:`translate(${x0}px,${y0}px) scale(1)`,opacity:.95},{transform:`translate(${(x0+x1)/2}px,${Math.min(y0,y1)-30-Math.random()*40}px) scale(1)`,opacity:.9,offset:.45},{transform:`translate(${x1}px,${y1+90+Math.random()*80}px) scale(.5)`,opacity:0}],
        {duration:650+Math.random()*450,easing:'cubic-bezier(.3,.4,.6,1)'}).onfinish=()=>dr.remove(); } }
  bloop(sp);
  if(sp>1400&&N.awake&&S.naviOn&&now()-(splash._t||0)>4000){ splash._t=now(); say(pick(['Splash!','Liquid glass. Literally.','Wet. Very wet.']),1200,null,2); }
}
function noiseBurst(t,dur,vol,hp){ const len=Math.floor(actx.sampleRate*dur), buf=actx.createBuffer(1,len,actx.sampleRate), d=buf.getChannelData(0);
  for(let i=0;i<len;i++) d[i]=(Math.random()*2-1)*Math.pow(1-i/len,2.5);
  const src=actx.createBufferSource(), f=actx.createBiquadFilter(), g=actx.createGain(); src.buffer=buf; f.type='highpass'; f.frequency.value=hp; g.gain.value=vol; src.connect(f).connect(g).connect(actx.destination); src.start(t); }
/* The glass breaks: a noise crash plus a few bright tinkles. Bigger hits, bigger break. Needs Sounds on. */
function shatterSound(sp){ if(!S.sound||!F('shatter')) return; try{ actx=actx||new (window.AudioContext||window.webkitAudioContext)(); const t=actx.currentTime, k=Math.min(1,sp/2600);
  noiseBurst(t,.35+.3*k,.25+.25*k,1800); noiseBurst(t+.02,.12,.15,5000);
  for(let i=0;i<4+Math.round(6*k);i++){ const o=actx.createOscillator(), g=actx.createGain(), tt=t+.05+Math.random()*.45; o.type='sine'; o.frequency.value=2600+Math.random()*3400;
    g.gain.setValueAtTime(.05,tt); g.gain.exponentialRampToValueAtTime(.0001,tt+.12+Math.random()*.2); o.connect(g).connect(actx.destination); o.start(tt); o.stop(tt+.4); } }catch{} }
function bloop(sp){ if(!S.sound) return; try{ actx=actx||new (window.AudioContext||window.webkitAudioContext)(); const t=actx.currentTime, o=actx.createOscillator(), g=actx.createGain();
  o.type='sine'; o.frequency.setValueAtTime(320+Math.min(300,sp/8),t); o.frequency.exponentialRampToValueAtTime(110,t+.18); g.gain.setValueAtTime(.12,t); g.gain.exponentialRampToValueAtTime(.0001,t+.22); o.connect(g).connect(actx.destination); o.start(t); o.stop(t+.25); }catch{} }
function smashPanel(id,el,lx,ly,sp,nx,ny){
  const r=rel(el), ix=r.left+lx, iy=r.top+ly, f=FL[id]; delete FL[id];
  const dir=f?Math.atan2(f.vy,f.vx):Math.atan2(ny,nx);
  if(!simpler()){ const n=Math.min(34,10+Math.round(sp/160));
    for(let i=0;i<n;i++){ const sh=document.createElement('i'); sh.className='pshard'; const sz=8+Math.random()*26;
      const sx=r.left+Math.random()*r.width, sy=r.top+Math.random()*r.height, near=Math.random()<.5;
      const x0=near?ix+(Math.random()-.5)*60:sx, y0=near?iy+(Math.random()-.5)*60:sy;
      const a=(near?Math.atan2(ny,nx):dir)+(Math.random()-.5)*1.6, v=(.25+Math.random()*.5)*Math.min(sp,3000)*.35;
      const x1=x0+Math.cos(a)*v, y1=y0+Math.sin(a)*v+120+Math.random()*160, rot=(Math.random()-.5)*720;
      sh.style.cssText=`width:${sz}px;height:${sz*(.6+Math.random()*.8)}px;clip-path:polygon(${Math.random()*40}% 0,100% ${Math.random()*50}%,${50+Math.random()*50}% 100%,0 ${50+Math.random()*50}%)`;
      stage.appendChild(sh);
      sh.animate([{transform:`translate(${x0}px,${y0}px) rotate(0deg)`,opacity:1},{transform:`translate(${(x0+x1)/2}px,${(y0+y1)/2-40}px) rotate(${rot/2}deg)`,opacity:.9,offset:.4},{transform:`translate(${x1}px,${y1}px) rotate(${rot}deg)`,opacity:0}],
        {duration:700+Math.random()*500,easing:'cubic-bezier(.2,.5,.5,1)'}).onfinish=()=>sh.remove(); } }
  if(S.sound&&F('shatter')) shatterSound(sp); else beep([[180,50],[120,90]]);
  el._cracks=0; el.querySelectorAll('.pcrack').forEach(c=>c.remove()); closePanel(id);
  if(N.awake&&S.naviOn){ N.lookPt={x:ix,y:iy}; N.lookUntil=now()+1600; N.hopT=now(); say(pick(['The glass breaks!','Smashing.','The glass breaks. I\'ll sweep up.','That was a panel.']),1600,null,1); }
}

/* layout save / restore */
let layoutT=0;
function saveLayout(){ clearTimeout(layoutT); layoutT=setTimeout(()=>{
  store.set('layout',{rail:rail.dataset.edge, card:{x:C.x,y:C.y,s:C.s},
    panels:zOrder.map(id=>({id,x:parseFloat(PS[id].el.style.left),y:parseFloat(PS[id].el.style.top),dock:PS[id].dock}))});
},200); }

/* =====================================================================
   5. Rail (built from the registry; hold to carry it to another edge)
   ===================================================================== */
const TOPS=Object.keys(PANELS).filter(k=>!PANELS[k].parent);
rail.innerHTML=TOPS.map(k=>{const n=k==='pip'?S.name:titleOf(k), sh=k==='pip'?n:(PANELS[k].short||n); return `<button class="ri" data-sec="${k}" aria-label="${esc(n)}">${svg(PANELS[k].icon)}<span>${esc(sh)}</span></button>`;}).join('')+
  `<div class="rail-sep"></div><button class="ri" id="namesBtn" aria-pressed="false" aria-label="Show names">${svg('names')}<span>Names</span></button>`;
let railSuppress=false;
rail.addEventListener('click',e=>{
  const b=e.target.closest('.ri'); if(!b) return;
  if(railSuppress){railSuppress=false; return;}
  if(b.id==='namesBtn'){S.names=!S.names; save(); applyNames(); return;}
  OB.panelToggles++; togglePanel(b.dataset.sec);
});
function applyNames(){ rail.classList.toggle('names',S.names); $('#namesBtn').setAttribute('aria-pressed',S.names); }
let railPress=null, railTimer=0;
rail.addEventListener('pointerdown',e=>{
  e.stopPropagation();
  railPress={id:e.pointerId,sx:e.clientX,sy:e.clientY,carried:false};
  clearTimeout(railTimer);
  railTimer=setTimeout(()=>{ if(!railPress) return; railPress.carried=true; rail.setPointerCapture(railPress.id); rail.classList.add('carried'); moveRail(railPress.sx,railPress.sy); },380);
});
rail.addEventListener('pointermove',e=>{
  if(!railPress||e.pointerId!==railPress.id) return;
  if(!railPress.carried){ if(Math.hypot(e.clientX-railPress.sx,e.clientY-railPress.sy)>8){clearTimeout(railTimer); railPress=null;} return; }
  moveRail(e.clientX,e.clientY);
});
function nearestEdge(x,y){const W=stage.clientWidth,H=stage.clientHeight; const d={left:x,right:W-x,top:y,bottom:H-y}; return Object.keys(d).reduce((a,b)=>d[a]<d[b]?a:b);}
function moveRail(cx,cy){
  const p={x:cx-SR.left,y:cy-SR.top};
  rail.dataset.edge=nearestEdge(p.x,p.y);
  Object.assign(rail.style,{left:p.x+'px',top:p.y+'px',right:'auto',bottom:'auto',transform:'translate(-50%,-50%)'});
}
function endRail(){
  clearTimeout(railTimer);
  if(railPress&&railPress.carried){
    railSuppress=true; setTimeout(()=>railSuppress=false,60);
    const first=rail.getBoundingClientRect();
    rail.removeAttribute('style'); rail.classList.remove('carried');
    const last=rail.getBoundingClientRect();
    const dx=(first.left+first.width/2)-(last.left+last.width/2), dy=(first.top+first.height/2)-(last.top+last.height/2);
    if(!simpler() && rail.animate) rail.animate([{translate:`${dx}px ${dy}px`},{translate:'0px 0px'}],{duration:420,easing:'cubic-bezier(.2,1.3,.4,1)'});
    learnt('rail'); react('rail'); saveLayout();
  }
  railPress=null;
}
rail.addEventListener('pointerup',endRail); rail.addEventListener('pointercancel',endRail);

/* =====================================================================
   6. Clock card
   ===================================================================== */
/* Glacio: a real seven-segment LCD with ghost segments */
const SEG={0:'abcdef',1:'bc',2:'abged',3:'abgcd',4:'fgbc',5:'afgcd',6:'afgedc',7:'abc',8:'abcdefg',9:'abcdfg',' ':''};
const SEGP={a:'8,2 36,2 40,6 36,10 8,10 4,6',g:'8,34 36,34 40,38 36,42 8,42 4,38',d:'8,66 36,66 40,70 36,74 8,74 4,70',f:'2,8 6,4 10,8 10,32 6,36 2,32',b:'34,8 38,4 42,8 42,32 38,36 34,32',e:'2,44 6,40 10,44 10,68 6,72 2,68',c:'34,44 38,40 42,44 42,68 38,72 34,68'};
const lcdDigit=ch=>`<svg viewBox="0 0 44 76" aria-hidden="true">${Object.entries(SEGP).map(([k,pts])=>`<polygon class="s${SEG[ch].includes(k)?' on':''}" points="${pts}"/>`).join('')}</svg>`;
const lcd=(hh,mm,colonOn)=>`<span class="lcd" aria-hidden="true">${[...hh].map(lcdDigit).join('')}<svg class="colon${colonOn?'':' off'}" viewBox="0 0 12 76"><rect class="s on" x="2" y="22" width="8" height="8"/><rect class="s on" x="2" y="48" width="8" height="8"/></svg>${[...mm].map(lcdDigit).join('')}</span>`;
const glacioOn=()=>F('glacio')&&((eraOn()&&F('worlds')&&S.era==='1983')||card.classList.contains('face-1983'));
let actx=null;
function beep(notes){ if(!S.sound) return; try{ actx=actx||new (window.AudioContext||window.webkitAudioContext)(); let t=actx.currentTime;
  notes.forEach(([f,ms])=>{ if(f){ const o=actx.createOscillator(), g=actx.createGain(); o.type='square'; o.frequency.value=f; g.gain.setValueAtTime(.04,t); g.gain.exponentialRampToValueAtTime(.0001,t+ms/1000); o.connect(g).connect(actx.destination); o.start(t); o.stop(t+ms/1000); } t+=ms/1000; }); }catch{} }
let lightT=0;
function glacioLight(){ cardIn.classList.add('lit'); beep([[2093,40]]); clearTimeout(lightT); lightT=setTimeout(()=>cardIn.classList.remove('lit'),2600); }
let lastMin=-1;
function tick(){const d=new Date(); presentTime(d); if(lastMin!==-1&&d.getMinutes()!==lastMin) minuteTurned(d); lastMin=d.getMinutes(); const h=S.h24?String(d.getHours()).padStart(2,'0'):(d.getHours()%12||12);
  const mm=String(d.getMinutes()).padStart(2,'0'), timeEl=$('#time');
  if(glacioOn()){ timeEl.innerHTML=lcd(String(h).padStart(2,' '),mm,d.getSeconds()%2===0); timeEl.setAttribute('aria-label',`${h}:${mm}`); }
  else { timeEl.textContent=`${h}:${mm}`; timeEl.removeAttribute('aria-label'); }
  $('#date').textContent=d.toLocaleDateString('en-GB',{weekday:'short',day:'numeric',month:'short'}).replace(',','');}
function minuteTurned(d){
  if(typeof N==='undefined'||!F('peek')||!S.naviOn||!N.awake||N.state!=='perch'||N.mood==='sulk'||N.drink||N.pet) return;
  const c=cardRect(); N.lookPt={x:c.left+c.width*.62,y:c.top+c.height*.6}; N.lookUntil=now()+1600; N.hopT=now()+250;
  if(d.getMinutes()===0&&glacioOn()) beep([[2093,90],[0,80],[2093,90]]);
  if(d.getMinutes()===0) say(pick([`${d.getHours()%12||12} o'clock. Just so you know.`,'Top of the hour.']),1800,null,2);
}
function applyClock(){ card.style.setProperty('--clockf',FONTS[S.font][1]); card.style.setProperty('--cwt',S.weight); card.style.setProperty('--cwd',S.width/100);
  $('#date').hidden=!S.date; refreshPanels(); }
tick(); setInterval(tick,1000);

const C={x:0,y:0,s:1,jx:0,jy:0,vx:0,vy:0,tvx:0,tvy:0};
function setCard(){RC.delete(cardIn); card.style.transform=`translate(${C.x+C.jx}px,${C.y+C.jy}px) translate(-50%,-50%) scale(${C.s})`;}
const cptr=new Map(); let cd=null, pinch=null, cLP=0, lastCardTap=0;
card.addEventListener('pointerdown',e=>{
  if(e.target.closest('#done')) return;
  e.stopPropagation(); card.setPointerCapture(e.pointerId); cptr.set(e.pointerId,{x:e.clientX,y:e.clientY});
  if(cptr.size===1){ cd={sx:e.clientX,sy:e.clientY,ox:C.x,oy:C.y,moved:false,lp:false};
    C.tvx=C.tvy=0; clearTimeout(cLP); cLP=setTimeout(()=>{ if(cd&&!cd.moved&&!G.on){cd.lp=true; enterEdit();} },480); }
  else if(cptr.size===2){ clearTimeout(cLP); const [a,b]=[...cptr.values()]; pinch={d:Math.hypot(a.x-b.x,a.y-b.y)||1,s:C.s}; cd=null; }
});
card.addEventListener('pointermove',e=>{
  if(!cptr.has(e.pointerId)) return; cptr.set(e.pointerId,{x:e.clientX,y:e.clientY});
  if(pinch&&cptr.size>=2){const [a,b]=[...cptr.values()]; C.s=clamp(pinch.s*Math.hypot(a.x-b.x,a.y-b.y)/pinch.d,.6,1.7); setCard(); return;}
  if(!cd) return; const dx=e.clientX-cd.sx, dy=e.clientY-cd.sy;
  if(!cd.moved&&Math.hypot(dx,dy)>6){cd.moved=true; clearTimeout(cLP); card.classList.add('carried'); CT=null;}
  const tt=now(), cdt=Math.max(8,tt-(cd.lt||tt-16))/1000, cvx=(e.clientX-(cd.lx??e.clientX))/cdt, cvy=(e.clientY-(cd.ly??e.clientY))/cdt; cd.lx=e.clientX; cd.ly=e.clientY; cd.lt=tt; cd.vx=cvx; cd.vy=cvy;
  if(cd.moved&&F('knock')&&N.state==='perch'&&S.naviOn&&Math.hypot(cvx,cvy)>2200){ /* yank the clock and they fall off */
    N.state='free'; N.vx=-cvx*.45; N.vy=-Math.abs(cvy)*.25-220; N.dizzyUntil=tt+900; N.pat=Math.max(0,N.pat-.05); say(pick(['Whoa!','Hey!','Steady!']),900,null,1); }
  if(cd.moved){C.x=clamp(cd.ox+dx,40,stage.clientWidth-40); C.y=clamp(cd.oy+dy,90,stage.clientHeight-40); setCard();}
});
function cardUp(e){
  if(!cptr.has(e.pointerId)) return; cptr.delete(e.pointerId); clearTimeout(cLP);
  if(cptr.size<2&&pinch){pinch=null; learnt('pinch'); react('big'); saveLayout();}
  if(cd&&cptr.size===0){
    if(!cd.moved&&!cd.lp&&glacioOn()) glacioLight();
    if(!cd.moved&&!cd.lp){ const t=now(); if(t-lastCardTap<330){ lastCardTap=0; const order=Object.keys(FONTS); S.font=order[(order.indexOf(S.font)+1)%order.length]; save(); applyClock(); learnt('dbl'); react('font'); } else lastCardTap=t; }
    if(cd.moved){ OB.drags++; saveLayout();
      const fresh=now()-(cd.lt||0)<70, sp=Math.hypot(cd.vx||0,cd.vy||0);
      if(F('throw')&&fresh&&sp>700){ const cap=Math.min(1,3200/sp); C.tvx=cd.vx*.9*cap; C.tvy=cd.vy*.9*cap; } }
    cd=null;
  }
  if(cptr.size===0) card.classList.remove('carried');
}
card.addEventListener('pointerup',cardUp); card.addEventListener('pointercancel',cardUp);
stage.addEventListener('wheel',e=>{ if(!e.ctrlKey) return; e.preventDefault(); C.s=clamp(C.s*Math.exp(-e.deltaY*.01),.6,1.7); setCard(); learnt('pinch'); saveLayout(); },{passive:false});
let gs=1; card.addEventListener('gesturestart',e=>{e.preventDefault(); gs=C.s; learnt('pinch');}); card.addEventListener('gesturechange',e=>{e.preventDefault(); if(cptr.size<2){C.s=clamp(gs*e.scale,.6,1.7); setCard();}});
const doneBtn=$('#done');
function enterEdit(){card.classList.add('editing'); doneBtn.hidden=false; react('edit');}
function exitEdit(){card.classList.remove('editing'); doneBtn.hidden=true;}
doneBtn.addEventListener('click',exitEdit); doneBtn.addEventListener('pointerdown',e=>e.stopPropagation());
