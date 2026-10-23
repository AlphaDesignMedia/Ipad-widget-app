# Working rhythm (built for ADHD + a new job)

Starting point, change anything that doesn't fit.

1. **Three active tasks maximum.** The dashboard enforces it.
2. **Two short sessions a week, not one long one.** Aim for about 90 minutes each, with a clear first task written down before you stop.
3. **Always leave a "next step" note.** End every session by writing the next physical action in `00-START-HERE.md`.
4. **Waiting tasks first.** Start anything Apple has to approve early, then do other work while you wait.
5. **Ideas go to the parking lot.** Don't act on them mid-session. Write one line and carry on.
6. **Strange Store gets a small fixed slot** (about 30-60 minutes a week) until the app is live, then more.
7. **Stop at "good enough".** v1.0 only needs to be solid and honest. Fonts, presets and extra widgets are v1.1.
8. **Protect rest.** Crisis Space shifts come first. Skip a session without guilt and restart from the next-step note.

## Using AI for this
- Claude Code builds and fixes the app. Claude chat plans, writes copy and keeps this folder tidy.
- Give AI one task at a time, check the result on the iPad, then move on.

## Glass Dashboard widget (since 23 Oct 2026)
- The **Glass Dashboard** app on the iPad has a Home Screen widget that mirrors the progress dashboard: what needs you, what's waiting to try, what's up next, the build on the iPad and the latest update.
- The widget can't sign in to Claude, so it reads a small file of numbers kept in a secret GitHub Gist. **Whenever Claude updates the dashboard, it also runs `Scripts/publish-status.sh`** (save the `decisions`, `items`, `builds` and `chat` collections with ArtifactData, then pass that folder to the script). Otherwise the widget falls behind.
- The widget checks for new numbers about every 20 minutes and says "Updated X ago". Offline, it keeps the last numbers and says so.
- To reinstall it on the iPad: `Scripts/run-dashboard-on-ipad.sh`.
