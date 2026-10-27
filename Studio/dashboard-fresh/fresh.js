// Fresh layer (27 Oct 2026): six small widgets added to the desk without touching desk.js.
// The header "Fresh" button hides or shows them all. Their data lives in desk.fresh (your private desk doc).
"use strict";
{
  const FR = ["f_stop", "f_joke", "f_figma", "f_wed", "f_ideas", "f_code", "f_insp", "f_three", "f_fairy"];
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
  const NAMES = { theme: { dark: "Midnight", light: "Morning", match: "Everyday" }, bg: { bloom: "Peach", dusk: "Dusk", sea: "Tide", plain: "Paper", own: "Mine" }, glass: { solid: "Matte", frost: "Frosted", clear: "Glass" } };
  const nameOf = () => NAMES.theme[desk.look.theme] + " " + NAMES.bg[desk.look.bg] + (desk.look.glass === "frost" ? "" : ", " + NAMES.glass[desk.look.glass]);
  function apply(code) {
    try { const a = JSON.parse(atob(code.trim().replace(/^GC1-/, ""))), keys = Object.keys(LOOKS);
      keys.forEach((k, i) => { if (LOOKS[k].includes(a[i]) && !(k === "bg" && desk.look.bg === "own")) desk.look[k] = a[i]; });
      desk.look.grain = !!a[5]; desk.look.drift = !!a[6]; applyLook(); place(); saveDesk(); renderW("f_code"); toast("Look applied"); }
    catch (e) { toast("That isn't a Look code"); }
  }
  W.f_code = { t: "Look code", deps: [], render(b) {
    b.replaceChildren(); const t = el("textarea", "fr-code"); t.value = mk(); t.readOnly = true; t.setAttribute("aria-label", "Your Look code");
    const r = el("div", "fr-row"); r.append(btn("fr-chip", "Copy my code", async () => { await copyText(t.value); toast("Code copied"); }),
      btn("fr-chip", "Surprise me", () => { Object.keys(LOOKS).forEach((k) => { if (!(k === "bg" && desk.look.bg === "own")) desk.look[k] = LOOKS[k][Math.floor(Math.random() * LOOKS[k].length)]; }); applyLook(); place(); saveDesk(); renderW("f_code"); toast("Today's look: " + nameOf()); }));
    const inp = el("input", "fr-in"); inp.placeholder = "Paste a friend's code, press Enter"; inp.setAttribute("aria-label", "Paste a Look code");
    inp.addEventListener("keydown", (e) => { if (e.key === "Enter" && inp.value.trim()) apply(inp.value); });
    b.append(el("b", null, nameOf()), el("p", "status", "Your Look settings as one short code. A locked or personal background is never overwritten."), t, r, inp);
  } };

  // 4. Inspiration: loose ideas and pictures (AI-made are welcome), clearly marked as not for the final design
  let rmMode = false, sendMode = false;
  W.f_insp = { t: "Inspiration (AI welcome)", deps: [], render(b) {
    b.replaceChildren(); const f = F();
    b.append(el("span", "fr-badge", "Inspiration only. Textures, shapes, colours. Never the final look."));
    const imgs = f.insp.filter((x) => x.img), list = imgs.map((x) => ({ id: x.img, url: x.img, caption: "Inspiration (AI welcome). Not the creative direction." }));
    if (imgs.length) { const g = el("div", "fr-thumbs"); imgs.forEach((x, n) => { const i = el("img"); i.src = x.img; i.alt = x.t || "Inspiration"; i.loading = "lazy";
      i.addEventListener("click", async () => { if (sendMode) { try { await db.collection("shots").add({ url: x.img, caption: "AI inspiration: details only, not our direction", at: new Date().toISOString(), from: "you", ai: true }); toast("On the mood board, labelled AI"); } catch (e) { toast("Couldn't add it. Try again."); } } else if (rmMode) { f.insp = f.insp.filter((o) => o !== x); saveDesk(); renderW("f_insp"); } else openShot(list[n], list); }); g.append(i); }); b.append(g); }
    f.insp.filter((x) => !x.img).forEach((x) => { const c = el("div", "card"); c.append(el("span", null, x.t), btn("fr-chip", "Remove", () => { f.insp = f.insp.filter((o) => o !== x); saveDesk(); renderW("f_insp"); })); b.append(c); });
    const row = el("div", "fr-row"), pick = el("label", "fr-chip"), file = el("input"); file.type = "file"; file.accept = "image/*"; file.multiple = true; file.hidden = true;
    pick.append("Add pictures", file);
    file.addEventListener("change", async () => {
      const fs = [...file.files]; file.value = ""; if (!fs.length) return;
      if (!assets) { toast("Picture upload isn't available in this view."); return; }
      let n = 0; for (const x of fs.slice(0, 12)) { try { toast("Adding " + (++n) + " of " + fs.length + "…"); const up = await assets.upload(await shrink(x, 1000, 0.7)); f.insp.unshift({ img: up.url, at: new Date().toISOString() }); } catch (e) { toast("One picture didn't upload."); } }
      saveDesk(); renderW("f_insp"); toast("Added");
    });
    const rm = btn("fr-chip", "Remove pictures", () => { rmMode = !rmMode; sendMode = false; renderW("f_insp"); }); rm.setAttribute("aria-pressed", rmMode);
    const sd = btn("fr-chip", "To mood board (as AI)", () => { sendMode = !sendMode; rmMode = false; renderW("f_insp"); }); sd.setAttribute("aria-pressed", sendMode);
    row.append(pick); if (imgs.length) row.append(sd, rm); b.append(row);
    if (rmMode) b.append(el("p", "status", "Tap a picture to remove it."));
    if (sendMode) b.append(el("p", "status", "Tap a picture to put it on the mood board, labelled AI. Crop it to the part you like in Photos first."));
    const inp = el("input", "fr-in"); inp.placeholder = "A thought, or a picture link (https://…), then Enter"; inp.setAttribute("aria-label", "Add inspiration");
    inp.addEventListener("keydown", (e) => { const v = inp.value.trim(); if (e.key !== "Enter" || !v) return; f.insp.unshift(/^https:\/\/\S+$/.test(v) ? { img: v } : { t: v }); saveDesk(); renderW("f_insp"); });
    b.append(inp);
  } };

  // 7. Figma: the design file, one tap away
  const FIG = "https://www.figma.com/design/O6eLeKQKkIxgYTAc2LmkyT";
  const link = (cls, text, href) => { const a = el("a", cls, text); a.href = href; a.target = "_blank"; a.rel = "noopener"; return a; };
  W.f_figma = { t: "Figma", deps: [], render(b) {
    b.replaceChildren();
    b.append(el("p", "status", "Your Glass Clock design file: design system, screens and the accessibility board."));
    const r = el("div", "fr-row"); r.append(link("fr-chip fr-solid", "Open Figma file", FIG), link("fr-chip", "Accessibility board", FIG + "?node-id=9-4"));
    b.append(r, el("p", "fr-tag", "Opens in the Figma app if it is installed, otherwise in Safari."));
  } };

  function confetti() {
    if (reduced()) return; const cols = ["#ffe28a", "#ffc2b4", "#c8f0c2", "#c6dcff", "#e4cbff"];
    for (let i = 0; i < 44; i++) { const d = el("i"); const sz = 6 + Math.random() * 6; Object.assign(d.style, { position: "fixed", left: 20 + Math.random() * 60 + "vw", top: "-12px", width: sz + "px", height: sz * 0.5 + "px", background: cols[i % 5], borderRadius: "2px", zIndex: 99, pointerEvents: "none" });
      document.body.append(d); const a = d.animate([{ transform: "translate(0,0) rotate(0)", opacity: 1 }, { transform: "translate(" + (Math.random() * 160 - 80) + "px," + (innerHeight + 40) + "px) rotate(" + (Math.random() * 720 - 360) + "deg)", opacity: 0.8 }], { duration: 1600 + Math.random() * 1200, easing: "cubic-bezier(.2,.6,.4,1)", delay: Math.random() * 300 }); a.onfinish = () => d.remove(); }
  }
  // 5. Today's three
  W.f_three = { t: "Today's three", deps: [], render(b) {
    b.replaceChildren(); const f = F(); if (f.three.d !== dayKey()) f.three = { d: dayKey(), items: ["", "", ""], ok: [false, false, false] };
    const box = el("div", "fr-three"); box.style.display = "grid"; box.style.gap = "8px";
    f.three.items.forEach((txt, i) => {
      const row = el("label"), c = el("input"), t = el("input", "fr-in" + (f.three.ok[i] ? " done" : ""));
      c.type = "checkbox"; c.checked = f.three.ok[i]; c.addEventListener("change", () => { f.three.ok[i] = c.checked; t.classList.toggle("done", c.checked); if (f.three.ok.every(Boolean) && f.three.items.every((x) => x.trim()) && !f.three.cheered) { f.three.cheered = 1; confetti(); toast("All three done."); } saveDesk(); });
      t.value = txt; t.placeholder = "One small thing"; t.setAttribute("aria-label", "Task " + (i + 1)); t.addEventListener("input", () => { f.three.items[i] = t.value; saveDesk(); });
      row.append(c, t); box.append(row);
    });
    b.append(box, el("p", "status", "Clears itself each morning."));
  } };

  // 8. A quiet joke: the real time, except now and then it is 4:04
  W.f_joke = { t: "Not found", deps: [], render(b) {
    b.replaceChildren(); const t = el("div", "fr-big", "--:--"), n = el("p", "status", ""); b.append(t, n); let hold = 0;
    const tick = () => { if (!document.contains(t)) return; const d = new Date(), real = (d.getHours() % 12 || 12) + ":" + String(d.getMinutes()).padStart(2, "0"), is404 = d.getHours() % 12 === 4 && d.getMinutes() === 4;
      if (!hold && !is404 && Math.random() < 0.004) hold = 5; if (hold) hold--;
      t.textContent = is404 || hold ? "4:04" : real; n.textContent = is404 ? "Found you." : hold ? "404: time not found" : "";
      setTimeout(tick, 1000); };
    tick();
  } };

  // 6. Secret fairy: tap to flap. A prototype to feel the idea, nothing is committed for the app.
  W.f_fairy = { t: "Secret fairy", deps: [], peek: () => (F().best ? "best " + F().best : ""), render(b) {
    b.replaceChildren(); const cv = el("canvas", "fr-game"); cv.width = 420; cv.height = 280; cv.setAttribute("aria-label", "Fairy game: tap to flap");
    const info = el("p", "status", "Tap or press Space to flap. A prototype for the app's hidden game."); if (F().skin) cv.style.background = "linear-gradient(160deg,#ffd9c7,#c9c0ee 60%,#9fb4ff)";
    const skin = btn("fr-chip", "In-app look", () => { F().skin = !F().skin; saveDesk(); renderW("f_fairy"); }); skin.setAttribute("aria-pressed", !!F().skin);
    b.append(cv, info, skin);
    const g = cv.getContext("2d"); let pop = false, fall = 0, y, v, pipes, score, run = false, t0 = 0, raf = 0, trail = [], best0 = 0;
    const reset = () => { pop = false; fall = 0; trail = []; best0 = F().best || 0; y = 140; v = 0; pipes = [{ x: 460, gap: 110 }]; score = 0; };
    const flap = () => { if (pop && fall < 30) return; if (!run) { reset(); run = true; t0 = performance.now(); loop(); } v = -5.2; };
    const draw = () => {
      g.clearRect(0, 0, 420, 280);
      trail.forEach((p) => { g.fillStyle = "rgba(255,240,190," + (p.a * 0.5) + ")"; g.beginPath(); g.arc(p.x, p.y, 1 + p.a * 3, 0, 7); g.fill(); });
      const sk = !!F().skin, dy = fall * fall * 0.07;
      if (sk) { const d = new Date(); g.fillStyle = "rgba(255,255,255,.35)"; g.font = "700 90px Figtree, sans-serif"; g.textAlign = "center"; g.fillText((d.getHours() % 12 || 12) + ":" + String(d.getMinutes()).padStart(2, "0"), 210, 165); g.textAlign = "left"; }
      const panel = (x, y0, h) => { g.beginPath(); if (g.roundRect) g.roundRect(x, y0, 46, h, 14); else g.rect(x, y0, 46, h); g.fillStyle = sk ? "rgba(255,255,255,.32)" : "rgba(255,255,255,.22)"; g.fill(); if (sk) { g.strokeStyle = "rgba(255,255,255,.75)"; g.lineWidth = 1.5; g.stroke(); } };
      pipes.forEach((p) => { panel(p.x, -30 + dy, p.gap - 52 + 30); panel(p.x, p.gap + 52 + dy, 280 - p.gap); });
      g.save(); g.translate(80, y); g.rotate(Math.max(-.5, Math.min(.7, v / 9)));
      g.shadowColor = "#ffe9a8"; g.shadowBlur = 18; g.fillStyle = "#fff6d6"; g.beginPath(); g.ellipse(0, 0, 8, 11, 0, 0, 7); g.fill();
      g.fillStyle = "rgba(200,225,255,.85)"; const fl = Math.sin(performance.now() / 70) * 8; g.beginPath(); g.ellipse(-9, -4, 14, 6 + fl / 2, -.6, 0, 7); g.fill(); g.restore();
      g.fillStyle = "#fff"; g.font = "700 22px Figtree, sans-serif"; g.fillText(run ? score : pop ? "" : "Tap to start", run ? 16 : 150, run ? 34 : 140);
      if (pop && fall > 18) { g.fillStyle = "rgba(255,255,255,.85)"; g.beginPath(); if (g.roundRect) g.roundRect(130, 100, 160, 76, 18); else g.rect(130, 100, 160, 76); g.fill(); g.fillStyle = "#2a2250"; g.textAlign = "center"; g.font = "700 24px Figtree, sans-serif"; g.fillText("Score " + score, 210, 133); g.font = "500 14px Figtree, sans-serif"; g.fillText("Best " + (F().best || 0), 210, 158); g.textAlign = "left"; }
    };
    const loop = () => {
      if (!document.contains(cv)) { run = false; return; }
      v += .28; y += v; pipes.forEach((p) => (p.x -= 2.4));
      trail.push({ x: 72, y: y + (Math.random() - .5) * 8, a: 1 }); trail.forEach((p) => { p.x -= 2.4; p.a -= 0.025; }); trail = trail.filter((p) => p.a > 0);
      if (pipes[pipes.length - 1].x < 220) pipes.push({ x: 460, gap: 90 + Math.random() * 100 });
      if (pipes[0].x < -50) { pipes.shift(); score++; }
      const p = pipes.find((q) => q.x < 92 && q.x + 46 > 68);
      if (y < 0 || y > 280 || (p && (y < p.gap - 52 || y > p.gap + 52))) { run = false; const f = F(); if (score > f.best) { f.best = score; saveDesk(); nodes.f_fairy.peek.textContent = "best " + score; } info.textContent = (score > best0 && score > 0 ? "New best: " : "Score ") + score + ". Tap to go again."; if (F().skin) { pop = true; fall = 0; const col = () => { fall++; draw(); if (fall < 45 && document.contains(cv)) requestAnimationFrame(col); }; col(); } else draw(); return; }
      draw(); raf = requestAnimationFrame(loop);
    };
    cv.addEventListener("pointerdown", (e) => { e.preventDefault(); flap(); });
    cv.tabIndex = 0; cv.addEventListener("keydown", (e) => { if (e.code === "Space") { e.preventDefault(); flap(); } });
    reset(); draw();
  } };

  // 9. Stop at 4:04: a clock hand sweeps; tap to stop it on the mark. Five rounds, fewer degrees off wins.
  W.f_stop = { t: "Stop at 4:04", deps: [], peek: () => (F().stopBest != null ? "best " + F().stopBest + "\u00b0 off" : ""), render(b) {
    b.replaceChildren(); const cv = el("canvas", "fr-game"); cv.width = 300; cv.height = 300; cv.style.maxWidth = "300px"; cv.style.aspectRatio = "1"; cv.setAttribute("aria-label", "Stop the clock hand on 4:04");
    const info = el("p", "status", "A hand sweeps round. Tap to stop it on the 4:04 mark. Five rounds; fewer degrees off is better."); b.append(cv, info);
    const g = cv.getContext("2d"), TG = 24; let ang = 0, spd = 2.2, run = false, round = 0, total = 0, last = "";
    const pt = (a, r) => [150 + r * Math.sin(a * Math.PI / 180), 150 - r * Math.cos(a * Math.PI / 180)];
    const draw = () => {
      g.clearRect(0, 0, 300, 300); g.strokeStyle = "rgba(255,255,255,.55)"; g.lineWidth = 3; g.beginPath(); g.arc(150, 150, 120, 0, 7); g.stroke();
      const m = pt(TG, 120); g.fillStyle = "#ffe9a8"; g.shadowColor = "#ffe9a8"; g.shadowBlur = 14; g.beginPath(); g.arc(m[0], m[1], 8, 0, 7); g.fill(); g.shadowBlur = 0;
      const h = pt(ang, 104); g.strokeStyle = "#fff"; g.lineWidth = 5; g.lineCap = "round"; g.beginPath(); g.moveTo(150, 150); g.lineTo(h[0], h[1]); g.stroke();
      g.fillStyle = "#fff"; g.textAlign = "center"; g.font = "700 18px Figtree, sans-serif"; g.fillText(run ? "Round " + (round + 1) + " of 5" : "Tap to start", 150, 215); g.font = "500 14px Figtree, sans-serif"; g.fillText(last, 150, 240); g.textAlign = "left";
    };
    const loop = () => { if (!run || !document.contains(cv)) return; ang = (ang + spd) % 360; draw(); requestAnimationFrame(loop); };
    cv.addEventListener("pointerdown", (e) => { e.preventDefault();
      if (!run) { run = true; round = 0; total = 0; spd = 2.2; last = ""; loop(); return; }
      const d = Math.abs(ang - TG), off = Math.min(d, 360 - d); total += off; round++; last = Math.round(off) + "\u00b0 off"; spd += 0.6;
      if (round >= 5) { run = false; const t = Math.round(total); if (F().stopBest == null || t < F().stopBest) { F().stopBest = t; saveDesk(); nodes.f_stop.peek.textContent = "best " + t + "\u00b0 off"; } info.textContent = "Total " + t + "\u00b0 off. Best " + F().stopBest + "\u00b0. Tap to play again."; draw(); } });
    draw();
  } };

  // Wiring: sizes, descriptions, and the header switch
  Object.assign(DEF_LAY, { f_stop: [3, 80, 3, 9], f_joke: [0, 80, 3, 3], f_figma: [8, 70, 4, 4], f_wed: [0, 54, 4, 8], f_ideas: [4, 54, 4, 12], f_code: [8, 54, 4, 8], f_three: [8, 62, 4, 6], f_insp: [0, 62, 4, 8], f_fairy: [4, 66, 4, 10] });
  Object.assign(WINFO, { f_stop: "A tiny clock game: stop the hand on 4:04", f_joke: "The time, with a quiet 4:04 joke", f_figma: "Your Figma file, one tap", f_wed: "Countdown and a can-I-carry-on answer", f_ideas: "Your longer notes, sorted by a tap", f_code: "Share your Look as a short code", f_insp: "Loose ideas, marked not-for-final", f_three: "Three small things, fresh daily", f_fairy: "A tiny hidden game prototype" });
  const on = !off(); if (on) ALL.push(...FR);
  const sw = btn("pill", "Fresh", () => {
    const now = off(); lsSet("fresh:off", now ? "0" : "1");
    if (now) ALL.push(...FR); else FR.forEach((id) => { const i = ALL.indexOf(id); if (i >= 0) ALL.splice(i, 1); });
    sw.setAttribute("aria-pressed", now); rebuild(); toast(now ? "Fresh widgets are back" : "Fresh widgets hidden. The desk is as it was.");
    if (now) setTimeout(() => { const n = nodes.f_wed; n && n.sec.scrollIntoView({ behavior: "smooth", block: "start" }); }, 150);
  });
  sw.id = "bFreshSw"; sw.title = "Show or hide the newest widgets"; sw.setAttribute("aria-pressed", on);
  document.querySelector(".acts").insertBefore(sw, $("bArrange"));
  const fg = el("a", "pill", "Figma"); fg.href = FIG; fg.target = "_blank"; fg.rel = "noopener"; fg.title = "Open the Glass Clock Figma file"; document.querySelector(".acts").insertBefore(fg, sw);
  // Apple-style packing: widgets slide up to close gaps unless Float is on (Arrange bar). Dragging stays free until you let go.
  const flt = () => !!F().float;
  function pack() {
    mode = modeNow(); if (mode === "stack" || flt()) return;
    const lay = L(), placed = [];
    shownIds().sort((a, b) => lay[a][1] - lay[b][1] || lay[a][0] - lay[b][0]).forEach((id) => {
      while (lay[id][1] > 0) { lay[id][1]--; if (placed.some((o) => overlap(rect(lay, id), rect(lay, o)))) { lay[id][1]++; break; } }
      placed.push(id);
    });
  }
  const _place = place; place = function (skip) { if (!skip) pack(); return _place(skip); };
  const fl = btn("pill", "Float", () => { F().float = !flt(); fl.setAttribute("aria-pressed", flt()); fl.textContent = flt() ? "Float: on" : "Float: off"; saveDesk(); place(); toast(flt() ? "Widgets can float anywhere" : "Widgets pack together"); });
  fl.title = "Off: widgets always pack together. On: they stay where you put them."; fl.setAttribute("aria-pressed", flt()); fl.textContent = flt() ? "Float: on" : "Float: off";
  document.querySelector(".arr-btns").insertBefore(fl, $("bDone"));
  // One-time: the Fresh widgets go to the top, everything else moves down.
  if (!F().top2) {
    F().top2 = 1; const w = desk.lay.wide || (desk.lay.wide = clone(DEF_LAY));
    Object.keys(w).forEach((id) => { if (!FR.includes(id)) w[id][1] += 9; });
    Object.assign(w, clone({ f_wed: [0, 0, 3, 9], f_ideas: [3, 0, 3, 9], f_insp: [6, 0, 3, 9], f_figma: [9, 0, 3, 3], f_three: [9, 3, 3, 6], f_code: [0, 200, 4, 8], f_fairy: [4, 200, 4, 10] }));
    delete desk.lay.mid; saveDesk();
  }
  if (on) rebuild(); else place();
}
