---
name: verify-user-flows
description: >-
  Verify Scanella the way a user does before TestFlight. Use when shipping,
  signing PDFs, exporting, editing PDFs, touching the home grid, or when a
  previous TestFlight build looked wrong. Do not treat widget labels as proof
  the saved file is correct.
---

# Verify user flows before TestFlight

Tiny UI tests plus a TestFlight hop is how we shipped a signature that was a
white box, then a signature that vanished from the saved PDF. Do not do that.

A flow is done only when the **file the user keeps** is correct: the PDF, the
page JPEG, Photos. Not the in-app overlay. Not a `%PDF-` header.

## Required: sign and export

Act as the user:

1. Open a document (gray/blue page is fine in tests).
2. Sign it (black ink PNG, placed at the bottom).
3. Save / export PDF (and the page JPEG path used by Photos).
4. Open the saved bytes and **look at pixels**.

Must pass, in `test/unit/export_service_test.dart` and
`test/unit/document_store_test.dart` / `test/unit/page_editor_test.dart`:

- Ink is dark on the saved page (`r,g` low in the stamp region).
- The rest of the page is still the document, not a white rectangle.
- `setPageStamps` bakes ink into the page JPEG so the library thumbnail and
  a later export still show the signature even if stamp metadata is empty.
- `buildPdfBytes` of a baked page (no stamps) still contains that ink.
- A **drawn** signature (`encodeSignaturePng`, the pad the user fingers) is
  ink in the exported PDF — not only a solid black test rectangle.
  `test/widget/sign_export_pixels_test.dart`

Must also pass: a page the compositor cannot decode **keeps** stamp metadata
so export can still try. Clearing stamps after a no-op bake is how a signed
PDF shipped unsigned.

Run:

```bash
flutter test test/unit/page_editor_test.dart test/unit/export_service_test.dart test/unit/document_store_test.dart
```

If you cannot decode the saved PDF/JPEG and point at ink pixels, you have not
checked the flow. A test that only asserts `bytes.startsWith('%PDF-')` is not
enough.

## Also check

Run the matching tests; add one if the change has no pixel/file assertion.

| User action | What must be true |
| --- | --- |
| Home | Three shortcuts (Scan from photos, Import from file, Scan from camera) plus All tools. Converters live on All tools. Import from file is not a scan picker. `test/widget/home_drawer_test.dart` |
| Upload PDF | File picker → Edit PDF tools (rotate, add, merge, split). Not crop/scan. |
| Scan a document | Add page + Export. No Sign on that screen. `test/widget/document_edit_test.dart` |
| Sign PDF | Asks to upload a PDF and lists existing uploaded PDFs — not camera scans. `test/widget/home_drawer_test.dart`. Draw pad leaves ink. Saved PNG is transparent around the stroke. Placing bakes into the page. |
| Export | Share PDF, Save PDF to Files, Save to Photos all go through composited/baked page bytes. |
| Rotate after sign | JPEG rotation keeps the burnt-in ink (page bytes rotate; stamps were cleared on bake so they cannot stamp twice). Same `document_store_test`. |

Then:

```bash
flutter test
```

## Do not ship yet if

- You only pumped a widget and read a label.
- You did not open the exported PDF or page JPEG.
- Image cache could still show the unsigned thumbnail (same path, new bytes).
- Stamp files live only at an absolute iOS container path with no bake.

## After tests pass

Follow `.cursor/skills/ship-testflight/SKILL.md` for the version bump and
`[testflight]` commit. Do not upload hoping the device will catch it.
