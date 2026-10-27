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
