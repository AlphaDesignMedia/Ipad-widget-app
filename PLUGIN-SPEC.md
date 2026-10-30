# Writing a Pip Sandbox plugin (for any AI tool or person)

Give this page, plus the idea, to Claude, ChatGPT, Gemini or anything else. The result pastes onto the end of `pip-sandbox.html` (Stage 12) with no other changes.

## The shape
```html
<!-- ==== NAME · plugin v1 (Dream) — one line on what it does; where to find it ==== -->
<script>
(() => {
const H=window.PipHost;
if(!H||!H.registerPlugin){ console.warn('NAME: needs Pip Sandbox V2 stage 12+'); return; }
const {N,S,stage,navi}=H;
if(!H.registerPlugin({id:'myid',name:'My Plugin',icon:'🧩',shelf:'dream',desc:'One sentence.'})) return; // false = switched off
/* 1. DATA: settings, presets and lines as plain objects
   2. LOGIC: small pure functions (no DOM)
   3. DOM: styles, elements and event wiring, last */
})();
</script>
```

## What you can use: `window.PipHost` (H)
- **Pip:**
  - `N` is Pip's state (x, y, state, awake, mood…).
  - `H.say(text, ms, onEnd, level)`: level 0 always shows, 2 is chatty only.
  - `H.travel(x, y, speed, after, onArrive)`, `H.goPerch()`, `H.wake()`, `H.persona().id` (pip/tock/lumen/glint/biscuit/bevel).
- **Clock:** `H.cardRect()`, `H.cardCentre()`, `H.card`, `H.cardIn`.
- **Panels:** `H.openEls()`, `H.openPanel(id,{at:{x,y}})`, `H.closePanel(id)`, `H.rel(el)` (rect relative to the stage).
- **Every frame:** `H.frame.push((dt,t)=>{…})`. Keep it cheap.
- **Events** on `window`: `pip:tap`, `pip:crack`, `pip:smash`, `pip:crash`, `pip:restore`, `pip:collect`, `pip:drink`, `pip:look`, `pip:screen`.
- **Utilities:** `H.store.get/set(key, value)` (auto-prefixed `gs2-`), `H.simpler()` (reduced motion), `H.grounded()`, `H.clamp`, `H.pick`, `H.beep([[hz,ms]])`, `H.now()`.
- **A button and card in the plugin bar:** copy the `PipPlugBar` helper block from any existing plugin file. Then use `PB.button(icon,label,cb)`, `PB.card(html)` and `PB.toggle(card,btn)`.

## Must
- Must work and look fine with Pip switched off (`S.naviOn`).
- Calm by default, with settings to turn it up. No guilt, streaks or nags beyond a cap.
- Under `H.simpler()`: fade, don't move. Label controls for VoiceOver.
- Make-believe names only: no real brands or people. Quoting a catchphrase is fine.
- Never edit the sandbox. Never block taps on the clock or panels.
