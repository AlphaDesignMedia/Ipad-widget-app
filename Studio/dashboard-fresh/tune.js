// Tune layer (27 Oct 2026): side margin + layout lock (Look menu), grab by the corner without Arrange, a refresh button.
// Needs desk.js. Remove the tune tags in index.html to go back.
"use strict";
{
  const SIDE = { s: 12, m: 22, l: 36, xl: 52 };
  const locked = () => desk.look.lock === "on";
  desk.look.side = desk.look.side || (innerWidth < 700 ? "m" : "s");

  // Side margin: room at the edges for a thumb to scroll.
  const _al = applyLook;
  applyLook = function () {
    _al(); desk.look.side = desk.look.side || "s";
    document.documentElement.style.setProperty("--side", (SIDE[desk.look.side] || 16) + "px");
    document.body.classList.toggle("locked", locked()); const b = $("bLock"); if (b) { b.textContent = locked() ? "Locked" : "Lock"; b.setAttribute("aria-pressed", locked()); }
    $("bArrange").disabled = locked(); requestAnimationFrame(() => place());
  };
  const _lm = lookMenu;
  lookMenu = function () {
    _lm();
    const h = [...pop.children].find((c) => /Spacing between/.test(c.textContent));
    const side = segRow("Side margin (room to scroll)", "side", [["s", "Slim"], ["m", "Comfy"], ["l", "Roomy"], ["xl", "Wide"]]);
    const lock = segRow("Layout", "lock", [["off", "Free"], ["on", "Locked"]]);
    h ? h.after(side, lock) : pop.append(side, lock);
  };

  // Lock: stops every drag and resize, and blocks Arrange.
  document.addEventListener("pointerdown", (e) => { if (locked() && e.target.closest(".w-head, .w-corner")) e.stopPropagation(); }, true);
  const _sa = setArrange;
  setArrange = function (on) { if (on && locked()) { toast("Layout is locked. Tap Locked to unlock."); return; } _sa(on); };
  const lk = btn("pill", "Lock", () => { desk.look.lock = locked() ? "off" : "on"; if (locked() && arranging) _sa(false); applyLook(); saveDesk(); toast(locked() ? "Layout locked. Scroll freely." : "Layout unlocked."); });
  lk.id = "bLock"; lk.title = "Lock the layout so nothing can be moved by accident";
  const acts = document.querySelector(".acts"); acts.insertBefore(lk, $("bArrange"));

  // Corner grab: grabbing a widget's corner resizes it with no Arrange needed (same trick as grabbing a title).
  let tmp = false;
  deskEl.addEventListener("pointerdown", (e) => {
    if (arranging || mode === "stack" || locked() || !e.target.closest(".w-corner")) return;
    arranging = true; tmp = true;
  }, true);
  const end = () => { if (!tmp) return; tmp = false; setTimeout(() => { if (!drag) { arranging = false; place(); } }, 0); };
  document.addEventListener("pointerup", end); document.addEventListener("pointercancel", end);

  // Refresh: reloads the dashboard (your layout and drafts are kept).
  const rf = btn("pill", "↻", () => { toast("Refreshing…"); setTimeout(() => location.reload(), 150); });
  rf.id = "bRefresh"; rf.title = "Refresh the dashboard"; rf.setAttribute("aria-label", "Refresh");
  acts.insertBefore(rf, acts.firstChild);

  applyLook();
}

// Text boxes (28 Oct 2026): Talk is honest, every box can Tidy up, boxes grow and have a "taller" handle.
(function () {
  try { voiceBlocked = true; } catch (e) {} // dictation inside the page never starts; the button says Dictate and points at the keyboard mic
  let busy = false;
  function fix() {
    if (busy) return; busy = true;
    try {
      document.querySelectorAll("#desk textarea").forEach((t) => {
        if (t.dataset.tuned) return; t.dataset.tuned = "1";
        const sticky = t.closest(".w.sticky");
        const grow = () => { t.style.height = "auto"; t.style.height = Math.min(Math.max(t.scrollHeight + 4, 70), 520) + "px"; };
        if (!sticky) {
          t.addEventListener("input", grow); setTimeout(grow, 0);
          const host = t.parentElement;
          if (sampler && host && ![...host.querySelectorAll("button")].some((x) => /tidy/i.test(x.textContent))) {
            const r = el("div", "row"); addTidy(t, r); t.after(r);
          }
          const tall = btn("btn small", "Taller", () => { t.style.height = Math.min(t.offsetHeight + 120, 520) + "px"; });
          (host.querySelector(".row") || host).append(tall);
        }
      });
    } catch (e) {} busy = false;
  }
  let q = 0; new MutationObserver(() => { cancelAnimationFrame(q); q = requestAnimationFrame(fix); }).observe(deskEl, { childList: true, subtree: true });
  fix();
})();
