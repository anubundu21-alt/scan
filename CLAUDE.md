# Scanella

Flutter offline document scanner (iOS + Android), Dart package `scan2`,
bundle id `com.scanella.mobile`. The marketing and legal site lives in
`legal-site/` and is deployed to scanella.com.

## How to talk to me

- Answer in simple English bullet points or a small table.
- No long explanations. No preamble, no recap of what I already know.
- Say plainly what works, what does not, and what is untested.
- Never claim something is tested when it was not run.

## Hard rules

- **Do not modify the main scanner.** `lib/features/scan/`,
  `camera_screen.dart`, and the edge-detection / capture path stay as they
  are unless I ask for them by name.
- **Never push to TestFlight unless I say so.** A build only happens when
  I ask; that means no version bump and no `[testflight]` in the commit
  subject. Commit and push to `main` otherwise.
- Do not open a pull request unless I ask.
- Prices, scan limits and reset periods shown on screen must be read from
  `ScanQuota` and `LocalizedPricing`, never typed into a widget as text.

## The free plan

| Thing | Value | Where it is set |
| --- | --- | --- |
| Starter scans, one time | 10 | `ScanQuota.starterLimit` |
| Scans per period after that | 10 | `ScanQuota.monthlyLimit` |
| Period length | 30 days | `ScanQuota.resetDays` |
| App-granted Pro trial | 30 days (1 month) | `ProTrial.courtesyDays` |
| PDF tools | always free, no limit | not quota-gated |
| Yearly | $9.99 | `LocalizedPricing.yearlyUsd` |
| Monthly | $2.99 | `LocalizedPricing.monthlyUsd` |

- The introductory free month is an **Introductory Offer in App Store
  Connect**. No code grants it.
- The app can also grant **1 month (30 days) of Pro** once per device (`ProTrial`).
  That is not Apple’s month. It lives in Keychain so an uninstall cannot
  reset it.
- The App Store price always wins over the estimated local price.

## What must survive an uninstall

iOS wipes SharedPreferences when an app is deleted. Anything that decides
what a returning user is allowed to do must live somewhere else.

| Fact | Where it lives | Survives uninstall |
| --- | --- | --- |
| Scans used | Keychain `used_v1` / Android Downloads marker | yes |
| Subscribed right now | StoreKit 2, Keychain `entitled_v1` | yes |
| Free month already taken | StoreKit history, Keychain `trial_used_v1` | yes |
| App 1-month trial used / until | Keychain `courtesy_used_v1` / `courtesy_until_v1` | yes |
| When Pro runs out | Keychain `entitled_until_v1` | yes |
| Which transaction that came from | Keychain `entitled_basis_v1` | yes |
| Period start date | SharedPreferences | no |

Before adding any new "has the user already…" flag, put it in the Keychain
plugin in `ios/Runner/AppDelegate.swift`, not in SharedPreferences.
