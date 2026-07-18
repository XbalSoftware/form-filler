# project_state.md — PDF Referral Templater (app name: Form Filler)

> Living document. Claude Code: read this at the start of every session; update it at the end of every session. `CLAUDE.md` holds the invariants and architecture — this file holds *status*.

**Last updated:** 2026-07-17 (Stage 1 code written; awaiting build, test target, and user verification)

---

## Current status

**Stage 6 — code complete, unverified.** Stages 1–5 are done (user-confirmed on device 2026-07-17). Stage 6 (the final roadmap stage) is written and awaits user verification:

1. ⌘U — 44 existing + 6 new tests (`PDFExportServiceTests`) must all pass.
2. Fill a form → **Export** (share sheet): receivers get a URL to a real `.pdf` file named `<Template> – <yyyy-MM-dd>.pdf`. **Critical user requirement: verify the EMR accepts it from the share sheet.**
3. Verify exported PDF fidelity: AirDrop/save a copy and open in Preview.app, Acrobat, and Files Quick Look — original page content crisp (vector, not rasterized), values exactly where the preview showed them, auto-shrunk text matching.
4. Share sheet also covers Save to Files and Print — try both.
5. Back button in fill mode now confirms before discarding entered values; Clear All unchanged; exported temp files are purged on app launch and when leaving the fill screen.
6. If a rotated (scanned sideways) PDF is available: export it and confirm orientation is correct — rotation handling uses Quartz's documented `getDrawingTransform` but deserves a real-world check.

After verification: the roadmap is complete. Remaining niceties live under "Future".

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
- ✅ Share via `ShareLink` + `FileRepresentation` (`ExportedFormPDF`): receivers get a URL to a named `.pdf` file — **required for the user's EMR software**; covers AirDrop, Save to Files, Print; default filename `<TemplateName> – <yyyy-MM-dd>.pdf` (sanitized, never contains patient data)
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
| 22 | Share via ShareLink + FileRepresentation handing receivers a URL to a named .pdf file | User's EMR only accepts share-sheet items that are URLs to PDF files; also gives every receiver a proper filename | 2026-07-17 |

## Assumptions awaiting user confirmation

- [x] App name — **Form Filler** (confirmed 2026-07-17)
- [x] iPad-only target — confirmed via project settings (2026-07-17)
- [ ] Ephemeral fill sessions acceptable (no draft saving in v1) — proceeding per CLAUDE.md invariant #3; flag if wrong
- [ ] Helvetica as default font — proceeding per Decision #7; flag if wrong

---

## Known issues / risks

- Page rotation handling is the likeliest source of subtle bugs — covered by mandatory tests in Stage 3.
- Scanned PDFs can have unusual mediaBox origins (non-zero); conversion helpers must use the mediaBox, never assume (0,0).
- Large scanned PDFs: render at capped scale and cache; watch memory on multi-page documents.
- ~~Fill mode: an accidental back-swipe discards all entered values without confirmation~~ — fixed in Stage 6 (custom back button with discard confirmation; note the edge-swipe-back gesture is disabled on the fill screen as a side effect).
- Fill preview text uses SwiftUI layout while export uses Core Graphics — same fitted font size via shared TextFitting, but baseline placement could differ by a point or two; user should verify side-by-side.
- Rotated-page export uses Quartz `getDrawingTransform` (documented) but hasn't been verified against a real sideways-scanned PDF yet.

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
