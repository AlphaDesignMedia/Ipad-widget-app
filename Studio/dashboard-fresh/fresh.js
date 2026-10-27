// Fresh layer (27 Oct 2026): six small widgets added to the desk without touching desk.js.
// The header "Fresh" button hides or shows them all. Their data lives in desk.fresh (your private desk doc).
"use strict";
{
  const FR = ["f_wed", "f_ideas", "f_code", "f_insp", "f_three", "f_fairy"];
  const F = () => (desk.fresh = desk.fresh || { tags: {}, insp: [], three: { d: "", items: ["", "", ""], ok: [false, false, false] }, best: 0 });
  const off = () => lsGet("fresh:off") === "1";
  const dayKey = () => new Date().toDateString();

  // 1. Until Wednesday: one glance answers "can I carry on?"
  // Your own reading wins when it is newer than the last one Claude saved, so this stays right without spending credits.
  const reading = () => { const w = wk(), m = F().pct; if (m && (!w || !S.usage || new Date(m.at) > new Date(S.usage.at))) return { percentUsed: m.v, resetsAt: (w && w.resetsAt) || "2026-10-28T14:00:00Z", own: true }; return w; };
  const TIPS = [[90, ["Ideas, notes and reading only.", "Write briefs now, build after the reset.", "Let Claude do one small edit at most."]], [70, ["Small edits and one question at a time.", "Batch feedback into one message.", "No research or big builds."]], [0, ["Normal work is fine.", "Still batch feedback.", "Save big builds for a fresh week."]]];
  W.f_wed = { t: "Until the reset", deps: ["usage"], peek: () => { const w = reading(); return w ? w.percentUsed + "% used" : ""; }, render(b) {
    b.replaceChildren(); const w = reading();
    if (!w) { b.append(el("p", "empty", "No weekly reading yet. Type your % below.")); }
    else {
      const ms = new Date(w.resetsAt) - Date.now(), h = Math.max(0, Math.floor(ms / 3600000)), m = Math.max(0, Math.floor(ms / 60000) % 60);
      const p = w.percentUsed, verdict = p >= 90 ? "Keep it tiny: notes, ideas, no builds." : p >= 70 ? "Small jobs only." : "Plenty of room.";
      const bar = el("div", "fr-bar"), i = el("i"); i.style.width = p + "%"; i.style.background = pctColour(p); bar.append(i);
      b.append(el("div", "fr-big", ms > 0 ? h + "h " + m + "m" : "Reset is here"), bar, el("p", "status", verdict + (w.own ? " (your reading)" : "")));
      const tips = el("ul", "fr-tips"); TIPS.find((x) => p >= x[0])[1].forEach((t) => tips.append(el("li", null, t))); b.append(tips);
    }
    const row = el("div", "fr-row"), inp = el("input", "fr-in"); inp.type = "number"; inp.min = 0; inp.max = 100; inp.placeholder = "Your % now"; inp.style.width = "110px"; inp.setAttribute("aria-label", "Weekly usage percent");
    inp.addEventListener("keydown", (e) => { const v = Math.round(Number(inp.value)); if (e.key === "Enter" && inp.value !== "" && v >= 0 && v <= 100) { F().pct = { v, at: new Date().toISOString() }; saveDesk(); renderW("f_wed"); toast("Saved " + v + "%"); } });
    row.append(inp, el("span", "fr-tag", "press Enter")); b.append(row);
    const row2 = el("div", "fr-row"); row2.append(el("span", "fr-tag", "Before a big job:"));
    [["Proceed fully", "Proceed fully."], ["Reduce scope", "Reduce scope to the smallest useful version."], ["Wait", "Defer until after the Wednesday reset."]].forEach(([l, t]) => row2.append(btn("fr-chip", l, async () => { await copyText(t); toast("Copied: " + t); })));
    b.append(row2);
  } };
  const wk = () => ((S.usage && S.usage.windows) || []).find((x) => /week/i.test(x.label));
  setInterval(() => nodes.f_wed && renderW("f_wed"), 60000);

  // 2. Idea vault: your longer notes as cards you can sort (Love it / Park / Later)
  let tagFilter = "all";
  W.f_ideas = { t: "Idea vault", deps: ["notes"], peek: () => ideas().length + " ideas", render(b) {
    b.replaceChildren(); const t = F().tags, list = ideas();
    const bar = el("div", "fr-row"); [["all", "All"], ["love", "Love it"], ["soon", "Soon"], ["park", "Parked"]].forEach(([k, l]) => { const c = btn("fr-chip", l, () => { tagFilter = k; renderW("f_ideas"); }); c.setAttribute("aria-pressed", tagFilter === k); bar.append(c); });
    b.append(bar);
    list.filter((n) => tagFilter === "all" || t[n.id] === tagFilter).forEach((n) => {
      const c = el("div", "card"), first = String(n.text).split("\n").find((x) => x.trim()) || "";
      c.append(el("b", null, clip(first.replace(/^#+\s*/, ""), 70)), el("p", "status", clip(String(n.text).slice(first.length), 150)));
      const r = el("div", "fr-row"); [["love", "Love it"], ["soon", "Soon"], ["park", "Park"]].forEach(([k, l]) => { const x = btn("fr-chip", l, () => { if (t[n.id] === k) delete t[n.id]; else t[n.id] = k; saveDesk(); renderW("f_ideas"); }); x.setAttribute("aria-pressed", t[n.id] === k); r.append(x); });
      c.append(r); b.append(c);
    });
    if (!b.querySelector(".card")) b.append(el("p", "empty", "Nothing in this pile."));
  } };
  const ideas = () => S.notes.filter((n) => n.flagged || String(n.text || "").length > 300).sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt))).slice(0, 12);

  // 3. Look code: your Look settings as a short code to send to a friend (the cheat-code idea, tried on the desk)
  const LOOKS = { theme: ["match", "light", "dark"], glass: ["solid", "frost", "clear"], space: ["s", "m", "l"], bg: ["bloom", "dusk", "sea", "plain"], text: ["s", "m", "l"] };
  const mk = () => "GC1-" + btoa(JSON.stringify([desk.look.theme, desk.look.glass, desk.look.space, desk.look.bg, desk.look.text, desk.look.grain ? 1 : 0, desk.look.drift ? 1 : 0])).replace(/=+$/, "");
  function apply(code) {
    try { const a = JSON.parse(atob(code.trim().replace(/^GC1-/, ""))), keys = Object.keys(LOOKS);
      keys.forEach((k, i) => { if (LOOKS[k].includes(a[i]) && !(k === "bg" && desk.look.bg === "own")) desk.look[k] = a[i]; });
      desk.look.grain = !!a[5]; desk.look.drift = !!a[6]; applyLook(); place(); saveDesk(); renderW("f_code"); toast("Look applied"); }
    catch (e) { toast("That isn't a Look code"); }
  }
  W.f_code = { t: "Look code", deps: [], render(b) {
    b.replaceChildren(); const t = el("textarea", "fr-code"); t.value = mk(); t.readOnly = true; t.setAttribute("aria-label", "Your Look code");
    const r = el("div", "fr-row"); r.append(btn("fr-chip", "Copy my code", async () => { await copyText(t.value); toast("Code copied"); }),
      btn("fr-chip", "Surprise me", () => { Object.keys(LOOKS).forEach((k) => { if (!(k === "bg" && desk.look.bg === "own")) desk.look[k] = LOOKS[k][Math.floor(Math.random() * LOOKS[k].length)]; }); applyLook(); place(); saveDesk(); renderW("f_code"); }));
    const inp = el("input", "fr-in"); inp.placeholder = "Paste a friend's code, press Enter"; inp.setAttribute("aria-label", "Paste a Look code");
    inp.addEventListener("keydown", (e) => { if (e.key === "Enter" && inp.value.trim()) apply(inp.value); });
    b.append(el("p", "status", "Your Look settings as one short code. A locked or personal background is never overwritten."), t, r, inp);
  } };

  // 4. Inspiration: loose ideas and picture links, clearly marked as not for the final design
  W.f_insp = { t: "Inspiration (AI welcome)", deps: [], render(b) {
    b.replaceChildren(); const f = F();
    b.append(el("span", "fr-badge", "Inspiration only. Never in the final designs."));
    const imgs = f.insp.filter((x) => x.img);
    if (imgs.length) { const g = el("div", "fr-thumbs"); imgs.forEach((x) => { const i = el("img"); i.src = x.img; i.alt = x.t || "Inspiration"; i.loading = "lazy"; i.addEventListener("click", () => { f.insp = f.insp.filter((o) => o !== x); saveDesk(); renderW("f_insp"); }); i.title = "Tap to remove"; g.append(i); }); b.append(g); }
    f.insp.filter((x) => !x.img).forEach((x) => { const c = el("div", "card"); c.append(el("span", null, x.t), btn("fr-chip", "Remove", () => { f.insp = f.insp.filter((o) => o !== x); saveDesk(); renderW("f_insp"); })); b.append(c); });
    const inp = el("input", "fr-in"); inp.placeholder = "A thought, or a picture link (https://…), then Enter"; inp.setAttribute("aria-label", "Add inspiration");
    inp.addEventListener("keydown", (e) => { const v = inp.value.trim(); if (e.key !== "Enter" || !v) return; f.insp.unshift(/^https:\/\/\S+$/.test(v) ? { img: v } : { t: v }); saveDesk(); renderW("f_insp"); });
    b.append(inp);
  } };

  // 5. Today's three
  W.f_three = { t: "Today's three", deps: [], render(b) {
    b.replaceChildren(); const f = F(); if (f.three.d !== dayKey()) f.three = { d: dayKey(), items: ["", "", ""], ok: [false, false, false] };
    const box = el("div", "fr-three"); box.style.display = "grid"; box.style.gap = "8px";
    f.three.items.forEach((txt, i) => {
      const row = el("label"), c = el("input"), t = el("input", "fr-in" + (f.three.ok[i] ? " done" : ""));
      c.type = "checkbox"; c.checked = f.three.ok[i]; c.addEventListener("change", () => { f.three.ok[i] = c.checked; t.classList.toggle("done", c.checked); saveDesk(); });
      t.value = txt; t.placeholder = "One small thing"; t.setAttribute("aria-label", "Task " + (i + 1)); t.addEventListener("input", () => { f.three.items[i] = t.value; saveDesk(); });
      row.append(c, t); box.append(row);
    });
    b.append(box, el("p", "status", "Clears itself each morning."));
  } };

  // 6. Secret fairy: tap to flap. A prototype to feel the idea, nothing is committed for the app.
  W.f_fairy = { t: "Secret fairy", deps: [], peek: () => (F().best ? "best " + F().best : ""), render(b) {
    b.replaceChildren(); const cv = el("canvas", "fr-game"); cv.width = 420; cv.height = 280; cv.setAttribute("aria-label", "Fairy game: tap to flap");
    const info = el("p", "status", "Tap or press Space to flap. A prototype for the app's hidden game."); b.append(cv, info);
    const g = cv.getContext("2d"); let y, v, pipes, score, run = false, t0 = 0, raf = 0;
    const reset = () => { y = 140; v = 0; pipes = [{ x: 460, gap: 110 }]; score = 0; };
    const flap = () => { if (!run) { reset(); run = true; t0 = performance.now(); loop(); } v = -5.2; };
    const draw = () => {
      g.clearRect(0, 0, 420, 280);
      g.fillStyle = "rgba(255,255,255,.22)"; pipes.forEach((p) => { g.fillRect(p.x, 0, 46, p.gap - 52); g.fillRect(p.x, p.gap + 52, 46, 280); });
      g.save(); g.translate(80, y); g.rotate(Math.max(-.5, Math.min(.7, v / 9)));
      g.shadowColor = "#ffe9a8"; g.shadowBlur = 18; g.fillStyle = "#fff6d6"; g.beginPath(); g.ellipse(0, 0, 8, 11, 0, 0, 7); g.fill();
      g.fillStyle = "rgba(200,225,255,.85)"; const fl = Math.sin(performance.now() / 70) * 8; g.beginPath(); g.ellipse(-9, -4, 14, 6 + fl / 2, -.6, 0, 7); g.fill(); g.restore();
      g.fillStyle = "#fff"; g.font = "700 22px Figtree, sans-serif"; g.fillText(run ? score : "Tap to start", run ? 16 : 150, run ? 34 : 140);
    };
    const loop = () => {
      if (!document.contains(cv)) { run = false; return; }
      v += .28; y += v; pipes.forEach((p) => (p.x -= 2.4));
      if (pipes[pipes.length - 1].x < 220) pipes.push({ x: 460, gap: 90 + Math.random() * 100 });
      if (pipes[0].x < -50) { pipes.shift(); score++; }
      const p = pipes.find((q) => q.x < 92 && q.x + 46 > 68);
      if (y < 0 || y > 280 || (p && (y < p.gap - 52 || y > p.gap + 52))) { run = false; const f = F(); if (score > f.best) { f.best = score; saveDesk(); nodes.f_fairy.peek.textContent = "best " + score; } info.textContent = "Score " + score + ". Tap to go again."; draw(); return; }
      draw(); raf = requestAnimationFrame(loop);
    };
    cv.addEventListener("pointerdown", (e) => { e.preventDefault(); flap(); });
    cv.tabIndex = 0; cv.addEventListener("keydown", (e) => { if (e.code === "Space") { e.preventDefault(); flap(); } });
    reset(); draw();
  } };

  // Wiring: sizes, descriptions, and the header switch
  Object.assign(DEF_LAY, { f_wed: [0, 54, 4, 8], f_ideas: [4, 54, 4, 12], f_code: [8, 54, 4, 8], f_three: [8, 62, 4, 6], f_insp: [0, 62, 4, 8], f_fairy: [4, 66, 4, 10] });
  Object.assign(WINFO, { f_wed: "Countdown and a can-I-carry-on answer", f_ideas: "Your longer notes, sorted by a tap", f_code: "Share your Look as a short code", f_insp: "Loose ideas, marked not-for-final", f_three: "Three small things, fresh daily", f_fairy: "A tiny hidden game prototype" });
  const on = !off(); if (on) ALL.push(...FR);
  const sw = btn("pill", "Fresh", () => {
    const now = off(); lsSet("fresh:off", now ? "0" : "1");
    if (now) ALL.push(...FR); else FR.forEach((id) => { const i = ALL.indexOf(id); if (i >= 0) ALL.splice(i, 1); });
    sw.setAttribute("aria-pressed", now); rebuild(); toast(now ? "Fresh widgets are back" : "Fresh widgets hidden. The desk is as it was.");
    if (now) setTimeout(() => { const n = nodes.f_wed; n && n.sec.scrollIntoView({ behavior: "smooth", block: "start" }); }, 150);
  });
  sw.id = "bFreshSw"; sw.title = "Show or hide the newest widgets"; sw.setAttribute("aria-pressed", on);
  document.querySelector(".acts").insertBefore(sw, $("bArrange"));
  if (on) rebuild();
}
