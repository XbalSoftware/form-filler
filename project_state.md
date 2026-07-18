# project_state.md — PDF Referral Templater (app name: Form Filler)

> Living document. Claude Code: read this at the start of every session; update it at the end of every session. `CLAUDE.md` holds the invariants and architecture — this file holds *status*.

**Last updated:** 2026-07-17 (post-roadmap polish round 2 written; awaiting user build/test/verification)

---

## Current status

**Roadmap complete (Stages 1–6 user-verified on device 2026-07-17), now in post-roadmap polish.**

**Polish round 1 — done, user-confirmed working 2026-07-17.** Whole-library backup/restore (single JSON file incl. PDFs), library search filter, no forced capitals in fill fields, multi-line Return=newline / Tab=next-field, `patientName` field type feeding the export filename, encrypted draft autosave vault (`DraftStore`), fill payload embedded in exported PDFs + "Reopen Exported PDF", Save/Print/Share as a blue toolbar group, dedicated "Clear form" button, editor field-name labels.

**Polish round 2 — code written, awaiting user verification (user now runs all builds/tests/commits themselves):**

1. **Checkmark & circle tools in fill mode** — segmented Type/Checkmark/Circle picker above the preview; tap stamps a ✓ (for boxes printed on the form, no template field needed), drag rings an item, tap a mark removes it. Marks render in preview and export via shared `MarkGeometry`, ride in the draft and embedded payload.
2. **Library top bar** — Reopen Exported PDF far left; centered search field (custom principal item); trailing (left→right): Arrange menu (Recently Modified / Name / Recently Added, persisted via @AppStorage), Settings gear, ＋ outermost. Drag-to-reorder was skipped in favour of sort options — say the word if you want manual ordering too.
3. **Settings sheet** — Back Up / Restore Library (moved out of the old … menu), About page (version + links), Reset App with confirmation (erases templates, draft, temp exports).
4. **Docs** — `docs/user-manual.md` and `docs/privacy-policy.md` ready for the GitHub site; `Support/AppLinks.swift` holds placeholder URLs (**TODO: point at the real GitHub Pages site**).

Verification notes for round 2: Print button uses `UIPrintInteractionController.present(animated:)` — check it presents properly on iPad; check the centered search field width feels right; note Reset App in a DEBUG build reseeds the sample template on next launch.

---

## Environment

- Mac mini M4, macOS 26.5, Xcode 26.3
- Target: iPadOS only (`TARGETED_DEVICE_FAMILY = 2`), **deployment target iOS 18.6+** (user decision 2026-07-17), Swift 6 language mode, SwiftUI, Observation framework
- App name: **Form Filler** · bundle ID `Xbal.Form-Filler` · scheme `Form Filler` · module `Form_Filler`
- Xcode project uses filesystem-synchronized groups — files added under `Form Filler/Form Filler/` join the app target automatically; no pbxproj edits needed for new source files
- No third-party dependencies

---

## Roadmap

Work strictly one stage at a time. A stage is done when it compiles, its tests pass, and the user has confirmed behavior in the simulator or on device.

### Stage 1 — Skeleton, models, storage  ✅ (done; user-confirmed on device 2026-07-17)
- ✅ Xcode project (iPad-only target, created by user), folder structure per CLAUDE.md
- ✅ `Template`, `FieldDefinition`, `FieldStyle`, `FieldType`, `FieldValue` (Codable with `schemaVersion`, defensive decoding, unknown-enum fallbacks)
- ✅ `TemplateStore`: enumerate/load/save/duplicate/delete; atomic writes (staged-folder create, `.atomic` JSON); stored PDF chmod'd read-only
- ✅ Debug-only seed: sample referral PDF **generated at runtime** via `UIGraphicsPDFRenderer` (no bundled asset), seed template with 5 fields on first launch, DEBUG builds only
- ✅ Unit tests written (Swift Testing): Codable round-trip, old-schema defensive decode, store CRUD — ☐ test target not yet created in Xcode, tests not yet run

### Stage 2 — Template library UI  ✅ (done; user-confirmed on device 2026-07-17)
- ✅ Library grid with thumbnails (`ThumbnailService`: PDFKit page-1 render, cached as `thumbnail.png`, off-main via `@concurrent`)
- ✅ Import PDF via `fileImporter` (validated with PDFKit); name + optional category sheet
- ✅ Edit Details (rename + category), Duplicate, Delete with confirmation — via card context menu (long-press)
- ✅ Navigation: card → `TemplateDetailView` with Editor/Fill entry points (disabled placeholders until Stages 4/5)

### Stage 3 — Page canvas + coordinate layer  ✅ (done; user-confirmed on device 2026-07-17)  *(foundation for both modes)*
- ✅ `Support/CoordinateConversion.swift`: `PageCoordinateSpace` — pure PDF↔view math (mediaBox offset, rotation 0/90/180/270, point + rect, both directions); single sanctioned `PDFPage` bridge
- ✅ `PDFRenderService`: page → UIImage at quantized half-step scale, NSCache'd, 4096px edge cap, `@concurrent` (off-main); re-renders only on settled zoom change
- ✅ `ZoomablePageContainer`: UIScrollView-backed pinch/pan hosting SwiftUI content (page + overlays scale together); reports stable zoom for re-render
- ✅ `PageCanvasView`: GeometryReader fit + render orchestration + overlay closure `(PageCoordinateSpace, pageSize)` for Stages 4/5
- ✅ Multi-page: `PageStripView` thumbnail strip (shown when pageCount > 1); debug seed PDF now has 2 pages
- ✅ **11 `CoordinateConversionTests`** (corner mapping per rotation, offset mediaBox, scaling, round-trips, normalization, degenerate sizes) — written; must be green before Stage 4

### Stage 4 — Template editor  ✅ (done; user-confirmed on device 2026-07-17)
- ✅ Tap to place field (default 180×24pt, centered on tap, clamped to page); drag to move; 4 corner handles to resize (min 16×10 view pts)
- ✅ Inspector: field list in fill order (tap-select, Reorder mode rewrites sortOrder, swipe-delete) ↔ field form (name, type, PDF-safe font list, size stepper 6–36, alignment segmented, ColorPicker→hex)
- ✅ Duplicate field (+12/−12pt offset), delete, 1-pt nudge arrows (screen-direction, rotation-aware), light edge-snapping (`Support/EdgeSnapping.swift`, 6pt tolerance, nearest edge, per-axis)
- ✅ Every mutation persists immediately via `TemplateStore.save` (atomic); `onPersist` callback refreshes the library
- ✅ Gesture model: one finger edits, two fingers pan/pinch (`panRequiresTwoTouches` on ZoomablePageContainer)
- ✅ 9 new tests: `EdgeSnappingTests` + `ColorHexTests` (`Support/ColorHex.swift`)

### Stage 5 — Fill mode  ✅ (done; user-confirmed on device 2026-07-17)
- ✅ Two-pane layout: `FillSessionView` = ordered form list (360pt, `FillFormListView`) + live preview with value overlays (`FillPageOverlayView` in PageCanvasView's overlay slot)
- ✅ In-memory `[UUID: FieldValue]` only (`FillSessionViewModel`); Clear All with confirmation; PHI footer note in the form
- ✅ Keyboard toolbar ▲/▼/Done cycling text fields; focus ↔ preview sync both ways (focused field highlighted, page auto-jumps); preview taps: checkbox toggles, text/date focuses
- ✅ Date picker with per-field format (`FieldDefinition.dateFormat`, default dd/MM/yyyy, editor picker); unset-until-"Set Date", clearable; checkbox renders "X"
- ✅ Auto-shrink via shared `Support/TextFitting.swift` — fitted in PDF points, scaled to view, so preview == future export; `Support/FieldValueFormatting.swift` resolves field+value → drawn string (shared with export)
- ✅ `FieldDefinition` gained optional `dateFormat` + `staticText` (defensive decode; old templates unaffected); static-text content editable in inspector, rendered on preview, excluded from the form
- ✅ 11 new tests (`FillSupportTests.swift`)

### Stage 6 — Export + polish  ◐ (code written 2026-07-17; awaiting user verification)
- ✅ `PDFExportService`: Core Graphics re-render — vector page content via `CGPDFPage` + `getDrawingTransform` (rotation/mediaBox-aware, Decision #21), values drawn as attributed strings in display space via the shared `PageCoordinateSpace` math
- ✅ Auto-shrink identical at export: same `TextFitting` call, same display-space fit box as the preview (a rotated-page fit bug in the preview was found & fixed during this work)
- ✅ Share: Export button writes the PDF to disk first, then presents `UIActivityViewController` (`ActivityShareSheet`, popover-anchored) with the **concrete file URL** — required for the user's EMR (Decision #22; ShareLink's file promise was rejected by it); covers AirDrop, Save to Files, Print; default filename `<TemplateName> – <yyyy-MM-dd>.pdf` (sanitized, never contains patient data)
- ✅ Temp-file hygiene: exports staged in `tmp/Exports/`, purged at app launch and on leaving the fill screen
- ✅ Polish: back-button discard confirmation in fill mode; editor selection haptic; accessibility labels on editor + fill overlays
- ✅ 6 new tests (`PDFExportServiceTests`): output re-parsed — page count/size, original content survives, values + static text extractable as real PDF text, per-page assignment, source bytes untouched (invariant #1), filename sanitization
- ☐ User fidelity verification (Preview/Acrobat/Quick Look, EMR acceptance, rotated-scan orientation)

### Future (do not build without explicit request)
Searchable library · favorites · recently used · auto-fill doctor/clinic profile · patient database · Apple Pencil annotations · image insertion · signatures · cloud sync · OCR · intelligent field detection · template library import/export (zip of template folders) · multiple fonts / rich formatting · batch export

---

## Decisions log

| # | Decision | Rationale | Date |
|---|----------|-----------|------|
| 1 | Field rects stored in PDF page point space, mediaBox-relative, un-rotated | Device/zoom independence; matches export drawing space | 2026-07-06 |
| 2 | PDFKit as engine only; custom image-based zoomable canvas for editor/preview | PDFView overlay sync is unreliable during zoom/scroll | 2026-07-06 |
| 3 | Export via Core Graphics re-render, not annotation flattening | Consistent rendering across viewers; original never touched | 2026-07-06 |
| 4 | Folder-per-template file storage + Codable JSON; no SwiftData | Debuggable, portable, trivial future import/export & sync | 2026-07-06 |
| 5 | Fill values are ephemeral (memory only) | PHI hygiene; only artifact with patient data is the exported PDF | 2026-07-06 |
| 6 | Enum-based FieldType with two switch sites, not protocol-per-type | Cheap extensibility, compiler-enforced exhaustiveness | 2026-07-06 |
| 7 | Default font Helvetica; per-field override | PDF-native, safe metrics | 2026-07-06 |
| 8 | Auto-shrink text to fit field rect | Referral forms have tiny boxes; avoids constant size fiddling | 2026-07-06 |
| 9 | App name **Form Filler**; deployment target **iOS 18.6+** | User decision at Stage 1 start | 2026-07-17 |
| 10 | iPad-only target confirmed | User created project with `TARGETED_DEVICE_FAMILY = 2` | 2026-07-17 |
| 11 | Debug seed PDF generated at runtime, not bundled | No binary asset in repo; layout struct drives both drawing and field rects so they always align | 2026-07-17 |
| 12 | `duplicate()` regenerates field IDs as well as the template ID | Keeps IDs globally unique; cheap insurance for future cross-template features | 2026-07-17 |
| 13 | Store never bumps `modifiedAt`; callers own dates | Keeps store writes predictable and tests deterministic | 2026-07-17 |
| 14 | Keep Xcode 26's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` on the app target; mark models + TemplateStore explicitly `nonisolated` | UI code stays simple under MainActor-by-default; data/storage types must be usable from any context (tests, future background export) | 2026-07-17 |
| 15 | Editor gesture model: one finger edits (tap/drag/resize), two fingers pan + pinch-zoom | Standard iPad canvas-editor pattern; cleanly avoids UIScrollView vs. field-drag gesture conflicts | 2026-07-17 |
| 16 | Editor persists on every committed mutation (no explicit Save button) | Atomic tiny JSON writes; nothing to forget; matches iOS editing conventions | 2026-07-17 |
| 17 | Font picker offers a small PDF-safe list (Helvetica ×3, Times, Courier) | Export renders with the same names; avoids fonts that may not embed cleanly | 2026-07-17 |
| 18 | `FieldDefinition` gained optional `dateFormat` and `staticText` (defensive decode) | Roadmap requires per-field date format + static-text content; canonical model had nowhere to store them | 2026-07-17 |
| 19 | Default date format dd/MM/yyyy | Australian/UK convention for the app's owner; overridable per field | 2026-07-17 |
| 20 | Date fields start unset ("Set Date" button) rather than pre-filled with today | Empty overlay until deliberately set; no accidental wrong dates on exports | 2026-07-17 |
| 21 | Export draws page content via `CGPDFPage.getDrawingTransform` + `drawPDFPage`, not `PDFPage.draw(with:to:)` | Deviates from invariant #5's letter, honors its spirit (vector CG re-render, no flattening); Quartz's transform API has documented /Rotate + mediaBox handling vs. PDFKit's underdocumented draw behavior | 2026-07-17 |
| 22 | Share by writing the PDF file first, then handing `UIActivityViewController` the **concrete file URL** — never ShareLink + FileRepresentation | ShareLink's FileRepresentation offers a lazy *file promise*, which the user's EMR software rejects (same failure previously seen in their EYEreport app; direct-URL sharing was the proven fix). EMR requires a real URL to a .pdf file | 2026-07-17 |
| 23 | Invariant #3 amended: fill data may persist ONLY via `FillSessionPayload` — the encrypted draft vault + the payload embedded in exported PDFs | Both explicitly requested by the user (adapted from their EYEreport app); `FieldValue` stays non-Codable so nothing else can casually persist patient data | 2026-07-17 |
| 24 | Embedded reopen payload lives in the **Keywords** PDF Info key, `FormFiller1:` + base64 JSON, with a one-shot PDFKit re-serialize fallback (`ensuringEmbeddedSource`) | Must be a documented Info key — CGPDFContext silently drops custom keys; device builds were seen dropping documentInfo entirely in EYEreport, hence the read-back check + fallback. A pipeline that rewrites the PDF may strip it; only PDFs exported after this feature carry it | 2026-07-17 |
| 25 | Draft vault: AES-GCM, key in Keychain `AfterFirstUnlockThisDeviceOnly` (no user-presence gate), `draft.sealed` excluded from backup, complete file protection; leaving the fill screen autosaves silently; resume is offered by prompt; **exporting does NOT clear the draft**; "Clear form" / "Start Fresh" do | Mirrors the proven EYEreport design; restore deliberately silent; back-button discard confirmation removed since nothing is lost on exit (edge-swipe back works again) | 2026-07-17 |
| 26 | `patientName` field type feeds the export filename `<Template> – <Patient> – <date>.pdf`; editor enforces one per template | User decision, supersedes the never-in-filename rule; value only ever comes from a field the user typed | 2026-07-17 |
| 27 | Library backup = ONE JSON file, PDFs base64-inline; restore only ever adds (same-ID templates skipped, never overwritten) | Native-frameworks-only rules out zip reading; JSON stays debuggable; add-only restore can't destroy local work | 2026-07-17 |
| 28 | Multi-line fill fields are `TextEditor` (Return = newline) with `.onKeyPress(.tab)` moving focus; all fill text inputs `.textInputAutocapitalization(.never)` | User: Return must be a carriage return inside multi-line fields, Tab must keep the tab-between-fields flow, and forced capitals break email addresses | 2026-07-17 |
| 29 | Ad-hoc fill marks (check/circle) are `AdHocMark`s in PDF-space rects, Codable, carried in `FillSessionPayload`; stroke geometry shared preview↔export via `MarkGeometry`; tap places/removes, drag draws circles | User request: tick boxes printed on the form without templating a field for each; circle items. Vector strokes avoid glyph-availability issues (✓ isn't in Helvetica) | 2026-07-17 |
| 30 | Library arrangement = sort options (Recently Modified default / Name / Recently Added) persisted in @AppStorage, not drag-to-reorder | Answers "arrange templates" without inventing a persisted manual-order field; revisit if the user wants manual ordering | 2026-07-17 |

## Assumptions awaiting user confirmation

- [x] App name — **Form Filler** (confirmed 2026-07-17)
- [x] iPad-only target — confirmed via project settings (2026-07-17)
- [x] ~~Ephemeral fill sessions~~ — superseded: user requested the encrypted draft vault (Decision #25)
- [ ] Helvetica as default font — proceeding per Decision #7; flag if wrong
- [ ] `AppLinks` placeholder URLs — need the real GitHub Pages addresses once docs are hosted

---

## Known issues / risks

- Page rotation handling is the likeliest source of subtle bugs — covered by mandatory tests in Stage 3.
- Scanned PDFs can have unusual mediaBox origins (non-zero); conversion helpers must use the mediaBox, never assume (0,0).
- Large scanned PDFs: render at capped scale and cache; watch memory on multi-page documents.
- ~~Fill mode: an accidental back-swipe discards all entered values without confirmation~~ — fixed in Stage 6 (custom back button with discard confirmation; note the edge-swipe-back gesture is disabled on the fill screen as a side effect).
- Fill preview text uses SwiftUI layout while export uses Core Graphics — same fitted font size via shared TextFitting, but baseline placement could differ by a point or two; user should verify side-by-side.
- Rotated-page export uses Quartz `getDrawingTransform` (documented) but hasn't been verified against a real sideways-scanned PDF yet.
- Print uses `UIPrintInteractionController.present(animated:)` — Apple's docs prefer the anchored `present(from:in:)` variants on iPad; verify the print sheet appears correctly on device (round 2, unverified).
- Reopen-exported-PDF only works for PDFs exported after the embedded-payload feature; pipelines that rewrite PDFs (some EMRs, some mail servers) may strip the Keywords payload.
- Reset App in DEBUG builds reseeds the sample template on next launch (seeder runs when the library is empty) — cosmetic, DEBUG-only.
- The mark tools capture one-finger gestures over the whole page while active; two-finger pan/zoom still works, and switching back to Type restores field taps.

---

## Session log

*(Claude Code: append an entry per session — date, stage, what was done, what's next.)*

- **2026-07-06** — Project inception. Architecture finalized with Claude (chat). CLAUDE.md and this file created. Next: confirm assumptions, then Stage 1.
- **2026-07-17** — Stage 1 code written. User created the Xcode project (iPad-only, iOS 18.6+, name Form Filler). Claude: raised `SWIFT_VERSION` to 6.0 in the pbxproj; created `App/`, `Models/`, `Services/`, `Support/`, `ViewModels/`, `Views/Library/` structure; replaced boilerplate `ContentView`/root app file; implemented models with defensive decoding, `TemplateStore` with atomic writes + read-only PDFs, runtime-generated DEBUG seed, slim `LibraryViewModel` + placeholder `LibraryView` (Stage 2 replaces it); wrote Swift Testing suites in `Form FillerTests/` (target must be added in Xcode). Note: pbxproj has stale project-level `IPHONEOS_DEPLOYMENT_TARGET = 26.2` in both configs — harmless, target-level 18.6 overrides it. Next: user builds, adds test target, runs tests + simulator, confirms seed template appears → then Stage 2 (library UI).
- **2026-07-17 (b)** — User added the test target; test build failed: the app target's Xcode-26 default `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` had implicitly made all models and TemplateStore MainActor-isolated, which the (nonisolated) test code couldn't call. Fixed by marking Template, FieldDefinition, FieldStyle, TextAlignmentOption, FieldType, FieldValue, TemplateStore, and TemplateStoreError explicitly `nonisolated` (Decision #14); added missing `import CoreGraphics` to both test files (MemberImportVisibility); raised the test target to Swift 6.0. User will test on a physical iPad rather than the simulator. Awaiting: green test run + seed template visible on device.
- **2026-07-17 (c)** — Stage 1 confirmed by user; Stage 2 written. New: `ThumbnailService` (PDFKit first-page render at 640px wide, PNG-cached in the template folder, `@concurrent` so it runs off-main, rotation-aware aspect); `LibraryViewModel` expanded (import with PDF validation via security-scoped URL, updateDetails/duplicate/delete, per-template async thumbnail loading with in-flight dedup, error alert binding); views split per the ~80-line rule: `LibraryView` (nav + sheets + dialogs), `LibraryGridView` (adaptive LazyVGrid + context menus), `TemplateCardView`, `TemplateFormSheet` (shared by import & edit-details), `TemplateDetailView` (Editor/Fill placeholders). No new unit tests (UI/rendering layer). Next: user verifies on iPad → Stage 3 (page canvas + coordinate conversion, tests mandatory before Stage 4).
- **2026-07-17 (d)** — Stage 2 confirmed (after adding a missing `import UniformTypeIdentifiers` to LibraryView — MemberImportVisibility strikes again; remember explicit imports for every module a file touches). Stage 3 written: `PageCoordinateSpace` in Support/CoordinateConversion.swift (rotation math derived for clockwise /Rotate: pdf bottom-left corner lands top-left at 90°, top-right at 180°, bottom-right at 270°); `PDFRenderService` (@unchecked Sendable — read-only PDFDocument + thread-safe NSCache); `ZoomablePageContainer` (UIScrollView + UIHostingController, content centered via insets, `onStableZoomChange` on gesture end); `PageCanvasView` (fit + `.task(id:)` render keyed on page/width/zoom, `@Environment(\.displayScale)`); `PageStripView`; TemplateDetailView now shows the live canvas; debug seed PDF grew a second page ("Continuation Sheet", one multi-line field, pageIndex 1). 11 new coordinate tests. Next: user verifies (tests + zoom/pan/page-switch on iPad) → Stage 4 (template editor).
- **2026-07-17 (e)** — Stage 3 confirmed (one fix en route: `nonisolated` restated on the `PageCoordinateSpace.init(page:)` extension — extensions don't inherit the type's `nonisolated` under MainActor-by-default; add `nonisolated` to every extension member intended to be non-main-actor). Stage 4 written: `TemplateEditorViewModel` (all mutations + immediate persist + `onPersist`→library refresh); `Views/Editor/` = TemplateEditorView (canvas + 320pt inspector, save-error alert), EditorPageOverlayView (tap-catcher: deselect-or-create; named coordinate space "editorPage"), FieldOverlayView (move drag w/ live snap, 4 resize handles w/ −10pt inset touch targets), FieldListView (EditMode reorder), FieldInspectorForm (keyPath-based bindings into `updateSelectedField`); `EdgeSnapping` + `ColorHex` in Support with 9 tests; `FieldType.displayName`; ZoomablePageContainer gained `panRequiresTwoTouches` (Decision #15). Detail-screen Edit button now live via `EditorRoute` navigationDestination. Decisions #15–17 logged. Next: user verifies → Stage 5 (fill mode).
- **2026-07-17 (f)** — Stage 4 confirmed (two build fixes en route: `getRed` argument labels; replaced SwiftUI-only `Array.move(fromOffsets:toOffset:)` with a hand-rolled reorder to keep the VM UI-free). Stage 5 written: `FieldDefinition` + `dateFormat`/`staticText` (Decision #18); shared `TextFitting` (fit in PDF points; preview scales the result — export must call the same function) and `FieldValueFormatting`; `FillSessionViewModel` (transient values, focus/page sync, overlay taps, keyboard-adjacency); `Views/Fill/` = FillSessionView (360pt form + preview, Clear All confirmation, disabled Export placeholder for Stage 6), FillFormListView (@FocusState ↔ VM two-way sync with equality guards, keyboard ▲/▼/Done, "Set Date"/clear pattern), FillPageOverlayView (fitted text, dashed empty outlines, focus highlight); inspector gained date-format picker + static-text box; detail Fill button live (disabled when no fields). 11 new tests. Decisions #18–20, two new Known issues (back-swipe discard; preview-vs-export baseline). Next: user verifies → Stage 6 (export + polish).
- **2026-07-17 (g)** — Stage 5 confirmed (one build fix: ambiguous `.greatestFiniteMagnitude` needed explicit `CGFloat`). Stage 6 written — user requirement surfaced: **EMR software only accepts share-sheet items that are URLs to PDF files** → `ExportedFormPDF` Transferable with `FileRepresentation(exportedContentType: .pdf)` returning `SentTransferredFile` (Decision #22). `PDFExportService`: CGPDFPage vector re-render (Decision #21), values drawn in display space (shared PageCoordinateSpace/TextFitting/FieldValueFormatting), per-field pages, filename `<Name> – <yyyy-MM-dd>.pdf` sanitized. Found+fixed rotated-page fit bug in FillFieldOverlay (was fitting against PDF-space rect; now display-space, matching export). Temp exports in `tmp/Exports/` purged at launch + fill-screen exit. Polish: fill back-button discard confirmation, editor selection haptic, overlay accessibility labels. 6 new tests (50 total). Next: user verifies (incl. EMR acceptance + fidelity in Preview/Acrobat/Quick Look + rotated scan) → roadmap complete; future work only from the "Future" list.
- **2026-07-17 (h)** — Stage 6 verified except EMR share: the EMR rejected ShareLink's lazy FileRepresentation (file promise), exactly matching the user's prior EYEreport experience. Reworked (Decision #22 amended): deleted `ExportedFormPDF.swift`; `FillSessionViewModel.exportToTemporaryFile()` writes the PDF eagerly on Export tap; new `Views/Shared/ActivityShareSheet.swift` (UIActivityViewController representable) presented in a popover off the Export button with the concrete file URL; export-error alert added to the fill screen. Purge behavior unchanged (launch + fill-screen exit; not on share completion, so open-in-place receivers finish copying safely). Awaiting: EMR acceptance re-test.
- **2026-07-17 (i)** — Polish round 1 (ten user-listed issues). New: `Support/FillSessionPayload.swift` (+`CodableFieldValue`, the ONLY sanctioned fill-value serialization), `Services/DraftStore.swift` (encrypted vault, EYEreport-adapted), `Services/LibraryBackupService.swift` (single-file JSON backup, add-only restore), `Views/Shared/DocumentExportPicker.swift`; `FieldType.patientName` (+ filename feed, editor one-per-form rule); embedded reopen payload in `PDFExportService` (Keywords key + `ensuringEmbeddedSource` PDFKit fallback + `embeddedPayload(in:)` reader); fill screen reworked (blue Print/Save/Share group, own "Clear form" button, no discard dialog — leaving autosaves, resume prompt on return); fill entry: no autocap, multi-line `TextEditor` with Return=newline / Tab=next via `.onKeyPress`; library `.searchable` filter + … menu (backup/restore/reopen); `PayloadAndBackupTests.swift`. Decisions #23–#28. User confirmed everything works; user now owns build/test/commit.
- **2026-07-17 (j)** — Polish round 2. New: `Models/AdHocMark.swift` + `Support/MarkGeometry.swift` + fill-mode Type/Checkmark/Circle tool picker (tap to stamp/remove ✓, drag to circle; marks in preview, export, draft, embedded payload — Decision #29); library top bar rearranged (Reopen far left, centered custom search field replacing `.searchable`, Arrange sort menu + gear + ＋ trailing, … menu removed; `LibrarySortOrder` via @AppStorage — Decision #30); `Views/Settings/SettingsView.swift` + `AboutView.swift` (backup/restore moved here, About with `AppLinks` placeholder URLs, Reset App → `TemplateStore.deleteAll` + draft clear + temp purge); `docs/user-manual.md` + `docs/privacy-policy.md` for the GitHub site. Payload round-trip test extended with marks. NOT yet built/tested — user verifies (esp. iPad print-sheet presentation and search-field placement).
