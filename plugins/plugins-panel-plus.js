/* =====================================================================
  PLUGINS PANEL+ · plugin v1.1   (Grounded shelf)
  Loaded by the sandbox loader (see PLUGINS in index.html). Needs window.PipHost (host.js).
  Where: Developer › Plugins (it replaces the list there).
  - Plugins grouped by shelf (Core, Grounded, Trial, Dream), each collapsible, remembered.
  - Compact rows: icon, name, switch. Switched-off or failed plugins are dimmed and say so.
  - Tap a row for its description, cost, and ▲ promote / ▼ demote (named: "▲ Grounded").
  - A search box appears once you have more than six plugins.
  It drives the original controls underneath, so everything else keeps working.
  v1.1 (Claude): wired to this sandbox's list (switches, shelf buttons, pluginsOff), adds status and cost.
  ===================================================================== */
(() => {
const H=window.PipHost;
if(!H||!H.registerPlugin){ console.warn('Plugins Panel+: needs Pip Sandbox V2 stage 12 or later.'); return; }
if(!H.registerPlugin({id:'plugpanel',name:'Plugins Panel+',icon:'🗂️',shelf:'grounded',desc:'Developer › Plugins grouped by shelf: collapsible, compact rows, tap for details, search.'})) return;
/* PLUGINS PANEL+: the Developer › Plugins list, grouped by shelf and tidied.
   Collapsible shelves, compact rows (icon, name, switch), tap a row for details and promote/demote. */
const st=document.createElement('style'); st.textContent=`
#plList.ppp-hide{display:none}
.ppp{display:grid;gap:8px}
.ppp details{border-radius:16px;background:var(--wash);padding:4px 6px}
.ppp summary{display:flex;align-items:center;gap:8px;min-height:38px;padding:0 6px;cursor:pointer;list-style:none;font:600 13px/1 var(--ui);color:var(--ink)}
.ppp summary::-webkit-details-marker{display:none}
.ppp summary::after{content:"›";margin-left:auto;color:var(--ink3);font-size:18px;transition:rotate .2s}.ppp details[open] summary::after{rotate:90deg}
.ppp .n{font:500 12px/1 var(--ui);color:var(--ink3)}
.ppp .row{display:grid;grid-template-columns:1fr auto;gap:6px 8px;align-items:center;padding:2px 6px;border-top:1px solid var(--hair);min-height:0}
.ppp .main{display:flex;align-items:center;gap:10px;min-height:42px;border:0;background:none;padding:0;color:var(--ink);text-align:left;cursor:pointer;font:600 14px/1.2 var(--ui)}
.ppp .main span{font-size:19px;width:24px;text-align:center}
.ppp .main em{font:600 10.5px/1 var(--ui);font-style:normal;letter-spacing:.05em;text-transform:uppercase;padding:3px 6px;border-radius:999px;background:var(--hair);color:var(--ink2)}
.ppp .main em.bad{color:var(--danger);background:color-mix(in srgb,var(--danger) 16%,transparent)}
.ppp .off .main>span,.ppp .off .main>b{opacity:.45}
.ppp .main b{font:inherit}
.ppp .more{grid-column:1/-1;display:grid;gap:8px;padding:0 0 8px 34px}
.ppp .more small{font:400 12.5px/1.35 var(--ui);color:var(--ink2)}
.ppp .more small.meta{color:var(--ink3);font-variant-numeric:tabular-nums}
.ppp .acts{display:flex;gap:6px;flex-wrap:wrap}
.ppp .acts .chip{min-height:30px;padding:0 11px;font-size:12px}.ppp .acts .chip:disabled{opacity:.3}
.ppp .search{min-height:36px;border:1px solid var(--hair);border-radius:12px;background:var(--wash);padding:0 12px;font:500 14px var(--ui);color:var(--ink)}`;
document.head.appendChild(st);
const NAMES={dream:'Dream',trial:'Trial',grounded:'Grounded',core:'Core'}, ORDER=['core','grounded','trial','dream'], UP=['dream','trial','grounded','core'];
const esc=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
let exp='', q='';
const open=H.store.get('ppp-open',{core:true,grounded:true,trial:true,dream:true});
function build(list){
  const host=list.parentElement; let ui=host.querySelector('.ppp');
  if(!ui){ ui=document.createElement('div'); ui.className='ppp'; list.after(ui);
    ui.addEventListener('pointerdown',e=>e.stopPropagation());
    ui.addEventListener('click',e=>{ const m=e.target.closest('[data-exp]'); if(m){ exp=exp===m.dataset.exp?'':m.dataset.exp; render(); return; }
      const a=e.target.closest('[data-act]'); if(a){ list.querySelector(`[data-shelf="${a.dataset.id}"][data-dir="${a.dataset.act==='up'?1:-1}"]`)?.click(); } });
    ui.addEventListener('change',e=>{ const c=e.target.closest('[data-sw]'); if(!c) return; const orig=list.querySelector(`[data-plug="${c.dataset.sw}"]`); if(orig){ orig.checked=c.checked; orig.dispatchEvent(new Event('change',{bubbles:true})); } render(); });
    ui.addEventListener('input',e=>{ if(e.target.classList.contains('search')){ q=e.target.value.toLowerCase(); render(true); } });
    ui.addEventListener('toggle',e=>{ const d=e.target; if(d.dataset?.shelf&&!q){ open[d.dataset.shelf]=d.open; H.store.set('ppp-open',open); } },true); }
  list.classList.add('ppp-hide');
  function render(keepSearch){
    const off=new Set(H.store.get('pluginsOff',[])), all=H.plugins, c=H.cost?.()||{plug:{},worst:{}}, ms=v=>v==null?'–':v<.01?'<0.01':v.toFixed(2);
    const ps=all.filter(m=>!q||(m.name+' '+(m.what||'')).toLowerCase().includes(q));
    const tag=m=>m.status==='failed'?'<em class="bad">Failed</em>':off.has(m.id)?(m.status==='on'?'<em>Off after reload</em>':'<em>Off</em>'):m.status==='off'?'<em>On after reload</em>':'';
    const groups=ORDER.map(sh=>{ const items=ps.filter(m=>H.shelfOf(m)===sh); if(!items.length) return '';
      return `<details data-shelf="${sh}" ${open[sh]||q?'open':''}><summary><span class="shelf" data-st-shelf="${sh}"><span>${NAMES[sh]}</span></span><span class="n">${items.length}</span></summary>${items.map(m=>{ const i=UP.indexOf(sh), x=exp===m.id;
        return `<div class="row${off.has(m.id)||m.status!=='on'?' off':''}"><button class="main" data-exp="${esc(m.id)}" aria-expanded="${x}"><span>${m.icon||'🧩'}</span><b>${esc(m.name)}</b>${tag(m)}</button><input type="checkbox" class="switch" data-sw="${esc(m.id)}" ${off.has(m.id)?'':'checked'} aria-label="${esc(m.name)} on">
          ${x?`<div class="more"><small>${esc(m.what||'')}</small>${m.error?`<small style="color:var(--danger)">${esc(m.error)}</small>`:''}
            <small class="meta">${m.status==='on'?`${ms(c.plug[m.id])} ms a frame · worst ${ms(c.worst[m.id])} ms · `:''}${m.bytes?(m.bytes/1024).toFixed(1)+' KB · ':''}${m.added?'added '+esc(m.added):''}</small>
            <div class="acts"><button class="chip ghost" data-act="down" data-id="${esc(m.id)}" ${i<=0?'disabled':''}>▼ ${i>0?NAMES[UP[i-1]]:''}</button><button class="chip" data-act="up" data-id="${esc(m.id)}" ${i>=3?'disabled':''}>▲ ${i<3?NAMES[UP[i+1]]:''}</button></div></div>`:''}</div>`; }).join('')}</details>`; }).join('');
    const sv=ui.querySelector('.search'), had=sv&&document.activeElement===sv;
    ui.innerHTML=`${all.length>6?`<input class="search" placeholder="Find a plugin" value="${esc(q)}" aria-label="Find a plugin">`:''}${groups||'<p class="note">No matches.</p>'}`;
    if(had||keepSearch){ const n=ui.querySelector('.search'); n?.focus(); n?.setSelectionRange(q.length,q.length); }
  }
  render();
  ui._render=render;
}
/* the sandbox re-renders #plList on every sync: rebuild our view each time */
const watch=new MutationObserver(ms=>{ if(!ms.some(m=>m.target.id==='plList'||(m.target.id==='panels'&&[...m.addedNodes].some(n=>n.querySelector?.('#plList'))))) return;
  const list=document.getElementById('plList'); if(list) build(list); });
watch.observe(document.getElementById('panels'),{subtree:true,childList:true});
const now=document.getElementById('plList'); if(now) build(now);

})();
