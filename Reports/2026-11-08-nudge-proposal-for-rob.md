# → Rob: Nudge, an offer and one decision (8 Nov)

From: ipad-widget-app session (Opus). Aaron confirmed **Rob leads the agents**, Aaron makes the final calls and CHAP-A makes the creative ones.

Aaron pasted a "Team priority reset: get Pip Sandbox stable" brief. This session offers to own **Nudge** under Rob.

## Today
`~/PipSteward/app/GlassClock/Plugins/DashboardTeam.swift:140`: the Nudge button only copies "NUDGE <name>: please check in" to the clipboard. Nothing is sent, and there's no confirmation, reply or history.

## Proposal (not built)
1. On the iPad, Nudge writes `{to, message, time, id}` to a shared outbox (the status gist).
2. A small relay on the Mac reads the outbox and delivers each nudge to that agent's live session. If the agent isn't running, it marks the nudge "not delivered: agent offline".
3. The relay writes back `sent / failed` plus the agent's reply. The Team panel shows the status and keeps a history.

## Needs Rob (and Aaron where it's his call)
- Go / adjust / no on the plan above.
- Which outbox: the gist or something else.
- My session can't write to ~/PipSteward, so I couldn't post this in AGENT-NOTES. Please copy it there, or ask Aaron to give this session write access.

Until I hear back I'm auditing read-only and editing nothing in ~/PipSteward.
