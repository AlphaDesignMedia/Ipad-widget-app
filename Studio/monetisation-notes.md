# Monetisation notes (for later, not for v1.0)

**Launch free and clean.** Don't add payment to v1.0. It adds review risk and delay.

## The stance (owner, 22 Oct 2026)
Free, and ethical about making money:
- Every feature is free: nothing locked, no ads, no tracking, no data collected.
- **Pay what you want:** a tip jar with a few amounts (for example £0.99, £2.99, £4.99), plus a heartfelt line about who made it.
- Ask once, at a happy moment (after the first Apply to Widget), and keep it in Settings after that. Never nag, never block, and no fake "free trial".
- Tipping can give a small thank-you that isn't a feature, such as a thank-you note or an extra app icon. Nothing that makes the free app feel worse.
- The family-of-widgets idea fits this: one free app, every widget free, one tip jar.

## Idea: a drinks menu for tips (owner, 22 Oct 2026)
The owner bought a coffee for the maker of a free, open-source Mac app they use. If they'd do that, so would plenty of others. So the tips read like a little menu:

| Item | What it is | Rough price (UK) |
|---|---|---|
| Glass of water | Leave a review. Costs nothing, means a lot | Free |
| Coffee | A small tip | £2.99 |
| Beer | A bigger thank-you | £4.99 |
| Something fancier (a cocktail?) | The top tier, still not high | £9.99 |

**How it fits Apple's rules and the fairness idea:**
- In the app, tips have to be **App Store in-app purchases** (consumables), not a Buy Me a Coffee link. Apple's rules on outside payment links vary by country and change; read the current guideline before linking anywhere. The Buy Me a Coffee page can still go on the website and the App Store description's support page.
- **Fair prices by country come built in:** set the prices in pounds and the App Store shows each person their own currency, with no need to ask where they are. The automatic prices only follow exchange rates, not the cost of living. But each country's price can be set by hand (lower where a coffee costs less), which is exactly the "fair for everyone" idea.
- **Minimum:** the lowest App Store price is about 29p. Apple keeps 15% (Small Business Program), so the smallest tier should be worth sending.
- **The glass of water:** asking for a review is fine. Rewarding one isn't allowed, so it's only ever a kind ask, using Apple's own review prompt or a link to the App Store review page.
- **Not yet decided:** whether a future bundle of widgets is free with tips, or has a small one-off price (£5 was mentioned). Free with tips matches the stance above.

**Decide:** add the tip jar in v1.0, or in v1.1 a few weeks after launch? It needs the paid Apple Developer account and the Paid Apps Agreement either way.

## Options to explore after launch
| Option | Idea | Things to check |
|---|---|---|
| Tip jar | Optional in-app purchases (e.g. £1.99 / £4.99 / £9.99 "buy me a coffee") | Standard StoreKit consumables. The simplest route that follows Apple's rules. |
| Pay-what-you-want link | External donation link (Ko-fi, Buy Me a Coffee) | Apple's rules on external payment links differ by country and change. Read the current guideline before adding. |
| Pro unlock | Free base app, one-off purchase for extra fonts/presets | Needs paid-apps agreement, tax and banking set up in App Store Connect |
| Bundle / subscription | Several utilities under one price | Only worth it once there are 3+ apps people use |

## Before any money moves
- Complete the **Paid Apps Agreement**, bank and tax details in App Store Connect.
- Check UK tax: income from apps counts as self-employed income. Ask an accountant.
