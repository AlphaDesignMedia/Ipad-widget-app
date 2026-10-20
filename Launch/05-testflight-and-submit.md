# TestFlight and submission

1. **Xcode:** Settings → Accounts → sign in with the paid Apple ID.
2. Project → both targets (app + widget): Signing & Capabilities → select your team.
3. Check the **App Groups** capability on both targets (see `06-technical-preflight.md`).
4. Product → Destination → **Any iOS Device (arm64)**, then Product → **Archive**.
5. Organizer → **Distribute App → App Store Connect → Upload**.
6. In App Store Connect → **TestFlight**, wait for the build to finish processing.
7. Add yourself as an internal tester. Install on your iPad through the TestFlight app.
8. Test for 2-3 days: all widget sizes, all Home Screen styles, restart the iPad, change time format, reset.
9. In App Store Connect → the app → **Distribution**, select the build, fill in the remaining items (checklist section E), and press **Add for Review → Submit**.
10. Choose **Release manually** so you control the launch moment.

If Apple rejects it: read the message in Resolution Center. Most first-time rejections are about missing review notes, a broken URL, or "minimum functionality" (guideline 4.2). The notes and the large customiser are your answer to the last one.
