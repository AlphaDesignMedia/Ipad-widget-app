# Launch checklist

Tick items off as you go. Items marked ⏳ involve waiting on Apple, so start them first.

## A. Accounts (do first, they have waiting time)
- [ ] ⏳ **A1. Enrol in the Apple Developer Program** at developer.apple.com/programs/enroll (use the Apple Developer app on iPhone/iPad or the website).
  - Choose **Individual**. It is the fastest. Your legal name will show as the seller.
  - Organisation (Alpha Design Media) needs a D-U-N-S number and takes longer. You can transfer or move later if needed.
  - Check the fee shown at checkout (the PRD says $99/year; you expected about £95).
  - You need two-factor authentication on your Apple ID and photo ID may be requested.
- [ ] **A2. Decide your public contact details.** UK/EU rules for "traders" mean Apple may show your address, phone and email on the listing. Use a business/PO address and a dedicated email if you can.
- [ ] **A3. Pick the support email** (e.g. a new address or an Alpha Design Media one).

## B. Web pages (App Store requires URLs)
- [ ] **B1. Privacy policy page live** (text in `03-privacy-policy.md`). Host on your portfolio site, GitHub Pages or Google Sites.
- [ ] **B2. Support page live** (a single page with email + short FAQ).
- [ ] B3. Optional: marketing URL (your portfolio page for the app).

## C. App assets
- [ ] **C1. App icon** 1024x1024. iPadOS 26 icons have Default, Dark and Tinted looks. Build in Icon Composer or Affinity and drop into `GlassClock/Assets.xcassets/AppIcon.appiconset`.
- [ ] **C2. Screenshots** per `04-screenshots-plan.md` (13-inch iPad size).
- [ ] C3. Optional: 15-30 sec app preview video.

## D. Technical (see `06-technical-preflight.md`)
- [ ] D1. Switch signing to your paid team, use the App Group entitlement
- [ ] D2. Confirm app and widget share settings with the App Group build
- [ ] D3. Release build runs on iPad with no debug UI
- [ ] D4. Version 1.0, build 1
- [ ] D5. Archive and upload

## E. App Store Connect
- [ ] ⏳ **E1. Check the name is free** (try "Glass Clock", else backups in `02-app-store-listing.md`).
- [ ] E2. Create the app record (bundle ID `com.aarondennel.glassclock`).
- [ ] E3. Paste listing text, upload screenshots, set category (Utilities), price (Free).
- [ ] E4. App Privacy: **Data Not Collected**.
- [ ] E5. Age rating questionnaire (expect 4+).
- [ ] E6. Export compliance: uses no non-exempt encryption.
- [ ] E7. App Review notes: how to add the widget (text in `02-app-store-listing.md`).

## F. Test and submit
- [ ] ⏳ F1. TestFlight build processed (can take about 30 minutes to a few hours)
- [ ] F2. Install via TestFlight, check widget in all four sizes and all Home Screen styles for 2-3 days
- [ ] F3. Submit for review
- [ ] ⏳ F4. Review (usually 1-3 days). If rejected, read the message, fix, resubmit.
- [ ] F5. Release it. 🎉

## G. After launch (v1.1, only after it's live)
- [ ] Add a "tip / pay what you want" link (check Apple's rules first, see `Studio/monetisation-notes.md`)
- [ ] Gather first reviews and feedback
