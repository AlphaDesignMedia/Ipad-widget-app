# Technical preflight (Xcode)

Found by reading the project on 20 Oct 2026. Check each before archiving.

| # | Check | Why | Status |
|---|---|---|---|
| 1 | **App icon image missing.** `AppIcon.appiconset` has only a `Contents.json`. | Upload fails without a 1024 icon. | ☐ |
| 2 | **Signing team is blank** in the project (the iPad script injects a free team). | Archive needs the paid team on both targets. | ☐ |
| 3 | **App Group vs keychain.** Free builds share settings through a keychain group (`Config/FreeTeam.entitlements`). The App Store build should use `Config/GlassClock.entitlements` (App Group `group.com.aarondennel.glassclock`). Confirm the code supports both, and register the App Group in your developer account. | If the widget can't read the app's settings, it shows defaults. | ☐ |
| 4 | **Debug-only style gallery** (`GlassClockApp.swift`, `#if DEBUG`). | It compiles out of Release builds. Just confirm on a Release run. | ☐ |
| 5 | **Version** is 1.0, build 1. Raise the build number for every upload. | App Store Connect rejects duplicates. | ☐ |
| 6 | **Encryption flag** `ITSAppUsesNonExemptEncryption = NO`. | Skips a question on every upload. | ☐ |
| 7 | **Font licences.** Roboto Flex and Google Sans Flex are bundled with their OFL licence files. Check both licence files are correct, and (optional) show credits in the app. | Open-licence fonts need their licence kept. | ☐ |
| 8 | **Uncommitted changes** to the widget and `Shared/` files at time of writing. | Commit before archiving so the build matches GitHub. | ☐ |
| 9 | **Deployment target** iPadOS 26.0, iPad only. Fine. | Make sure the listing says "iPadOS 26 or later". | ☐ |
| 10 | **README says "Nothing to build yet".** | Out of date. Update it for GitHub visitors. | ☐ |

Note: Xcode is not installed in the cloud workspace, so these checks need running on your Mac (Claude Code can do them).
