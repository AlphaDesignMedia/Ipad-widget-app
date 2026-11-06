# Proposal for Rob: one home for Pip's speech-bubble rule

Status: **PROPOSAL ONLY. Not implemented.** Needs Rob's approval, then Aaron's go. Follows the 6 Nov core ownership check-in.
Owner of the change: core owner (Rob/Greg, to be confirmed). Small, generic, no behaviour change.

## The problem (checked in source, 6 Nov)

The rule "does Pip's text box sit above or below Pip" is written twice:
- `pip-sandbox-claude-code/app/GlassClock/Pieces/Pip.swift:527`: `let above = pip.pos.y > 68 + 12 * pip.scale`
- `pip-sandbox-claude-code/app/GlassClock/Plugins/PipEmotes.swift:65`: `let boxAbove = p.y > 68 + 12 * host.pip.scale` (its comment says the two never overlap)

If someone changes the number in one place, emotes will overlap Pip's text again, silently.

Also found: the earlier notes asked for `host.pipTalking`. **That is not needed.** `host.pip.bubble != nil` already means "Pip is talking" and PipEmotes uses it (`PipEmotes.swift:66`). Drop that request.

## Smallest fix (phase 1, about 6 lines, no visible change)

In `Pip.swift`, add one computed property on the Pip model:

```swift
/// True when Pip's text box sits above Pip (it flips below near the top of the screen).
var boxAbove: Bool { pos.y > 68 + 12 * scale }
```

- `Pip.swift` `bubble()` uses `pip.boxAbove` instead of its own `above`.
- `PipEmotes.swift` uses `host.pip.boxAbove` instead of its own `boxAbove`.

Result: one rule, one place. Plugins read it, never copy it.

## Optional later (phase 2, only if a plugin truly needs it)

A measured `bubbleFrame: CGRect` (window space, null when Pip is quiet), published with `onGeometryChange(... frame(in: .global))` like `panelFrame`/`barFrame`/`cardFrame` in `PluginHost.swift`. Costs: one more `onGeometryChange` (the notes flag these as a possible feedback-loop cost), and it only matters when a plugin must avoid the real text rectangle rather than just above/below. No plugin needs this today, so **don't build it yet**.

## Checks before it lands (per PLAN.md)

1. Builds clean (0 errors, 0 warnings).
2. Simulator launch screenshot (after a relaunch; the first launch after install shows white for a few seconds).
3. Pip near the top of the screen and near the bottom: the text box and an emote never overlap, same as before.
4. Independent check by Gene, not the implementer.
5. Install on the iPad only after the above.

## Risk and rollback

Risk: very low (moves a one-line expression). Rollback: `git revert` the single commit.
