---
name: ship-testflight
description: >-
  How to ship a Scanella TestFlight build. Use when bumping the version,
  writing a [testflight] commit, or the user asks to upload to TestFlight.
  Always run verify-user-flows first. Never ship a one-line guess.
---

# Ship TestFlight

## 1. Prove the user flow

Read and follow `.cursor/skills/verify-user-flows/SKILL.md`.

If the change is sign / export / PDF / home tools, the saved-file pixel tests
must pass **before** you touch `pubspec.yaml`.

```bash
flutter test
```

Do not bump the version on red tests.

## 2. Version

In `pubspec.yaml`, bump **both** name and build (`1.5.32+791` → next). Never
reuse a build number. Put `[testflight]` in the **commit subject** on
`cursor/**` (or `main`).

## 3. Commit, push, PR

One feature-complete commit is better than: change, TestFlight, fail, change,
TestFlight. If CI fails because GitHub billing blocked the macOS runner, say
so — do not "fix" product code.

## 4. Confirm the upload

The iOS Release log must contain:

- `Successfully uploaded the new binary to App Store Connect`
- `TestFlight build <name> (<number>) finished processing and is ready for internal testing`

A green `iOS CI (simulator)` job alone is not a TestFlight build.
