---
name: scanella
description: Working rules for the Scanella app and scanella.com. Use when changing anything about Pro, the paywall, subscriptions, StoreKit, the free scan quota, onboarding screens, pricing, or the legal-site website - and before any release or TestFlight build. Covers what must survive an uninstall, which code is off limits, and how to verify a change without a device.
---

# Scanella

## Before you touch anything

- The main scanner is off limits: `lib/features/scan/`, `camera_screen.dart`,
  and the capture / edge-detection path. Change it only if asked by name.
- No TestFlight build unless asked. No version bump, no `[testflight]` in
  the commit subject. Commit and push to `main`.
- No pull request unless asked.

## Numbers live in one place

Never type a price, a scan count or a reset period into a widget.

| Value | Constant |
| --- | --- |
| 10 starter scans | `ScanQuota.starterLimit` |
| 5 scans per period | `ScanQuota.monthlyLimit` |
| 30 day period | `ScanQuota.resetDays` |
| $9.99 yearly | `LocalizedPricing.yearlyUsd` |
| $2.99 monthly | `LocalizedPricing.monthlyUsd` |

- `ScanQuota.limit` is **forward looking**. The moment the 10th starter scan
  lands it already reads 5. To report an allowance that just ran out, use
  `ScanQuota.usedUpLimit`.
- The free month is an Introductory Offer configured in App Store Connect.
  No code grants it. Never show "1 month FREE" unless `ProState.trialUsed`
  is false.
- The App Store price beats the estimated local price
  (`LocalizedPricing.forDisplay`).

## The uninstall rule

iOS deletes SharedPreferences when the app is removed. Android clears app
storage too. Any flag that decides what a returning user may do must be
stored natively.

| Fact | Storage | Survives |
| --- | --- | --- |
| Scans used | Keychain `used_v1`, Android Downloads marker | yes |
| Subscribed now | StoreKit 2 `currentEntitlements`, Keychain `entitled_v1` | yes |
| Free month taken | StoreKit `Transaction.all`, Keychain `trial_used_v1` | yes |
| When Pro runs out | Keychain `entitled_until_v1` | yes |
| Which transaction that came from | Keychain `entitled_basis_v1` | yes |
| Period start date | SharedPreferences | no |

Adding a new "has the user already..." flag means adding it to
`ScanellaProPlugin` in `ios/Runner/AppDelegate.swift`, not to prefs.

## Entitlement checks are tri-state

`ProPurchase.hasActiveEntitlement()` returns `Future<bool?>`.

- `true` subscribed, `false` not, `null` the store could not be reached.
- A `null` must leave the saved answer alone. Revoking Pro over a dropped
  connection locks out someone who is paying.
- A restore that finds nothing writes **no** answer. The user may simply be
  signed into the wrong Apple ID.
- Minimum iOS is 13.0. StoreKit 2 calls need `@available(iOS 15.0, *)` and
  a fallback below that. Do not raise the deployment target.
- Below iOS 15 nothing can silently see a cancellation, so a cached yes
  must always carry an end date. Never write an entitlement to the Keychain
  without one, and never trust a restored transaction that is not newer
  than `entitled_basis_v1` — a restore replays old history as if it were
  fresh.

## Always re-check these four journeys

Any change to Pro, quota or onboarding must still hold:

1. Free user, allowance spent, uninstall, reinstall -> same scans already
   used, PDF tools still free.
2. Subscriber, uninstall, reinstall -> still Pro, no paywall.
3. Trial cancelled and expired, uninstall, reinstall -> free user, scans
   still counted, **no free-month offer**.
4. Brand new install -> 10 scans and the free month are both offered.

## Verifying without a device

There is no Flutter toolchain, no simulator and no sandbox in this
environment. So:

- Add or update a unit test for the logic instead of claiming it works.
- Say explicitly that the change is unrun.
- For `legal-site/`, measure with headless Chromium rather than guessing.
  Colours and spacing get sampled from the screenshot, never estimated.

## The website

- Source in `legal-site/`, deployed to scanella.com.
- Support address is `support@scanella.com`.
- Pages: `index.html`, `terms/`, `privacy/`, `contact/`. `nav.js` handles
  the phone menu drawer and stamps the footer year.
