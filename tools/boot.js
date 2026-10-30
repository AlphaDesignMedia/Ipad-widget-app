const {chromium}=require('playwright');
(async()=>{
  const b=await chromium.launch();
  const out=[];
  for (const vp of [{w:1180,h:820,n:'landscape'},{w:820,h:1180,n:'portrait'}]){
    const pg=await b.newPage({viewport:{width:vp.w,height:vp.h},deviceScaleFactor:1,hasTouch:true});
    const errs=[]; pg.on('pageerror',e=>errs.push('pageerror: '+e.message)); pg.on('console',m=>{if(m.type()==='error')errs.push('console: '+m.text())});
    pg.on('requestfailed',r=>errs.push('reqfail: '+r.url()));
    await pg.goto(process.env.URL||'http://localhost:8765/index.html'); await pg.waitForTimeout(4000);
    const info=await pg.evaluate(()=>({host:document.documentElement.dataset.host, errors:document.documentElement.dataset.errors||'',
      plugins:(window.PipPlugins||[]).map(p=>p.id+':'+p.status+(p.error?'('+p.error+')':'')), nodes:document.getElementsByTagName('*').length,
      failMsg:[...document.querySelectorAll('p')].map(p=>p.textContent).filter(t=>t.includes('failed to load'))}));
    await pg.screenshot({path:`tools/boot-${vp.n}.png`});
    out.push({vp:vp.n,...info,errs});
    await pg.close();
  }
  console.log(JSON.stringify(out,null,1)); await b.close();
})();
