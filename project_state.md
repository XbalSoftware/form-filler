# project_state.md — PDF Referral Templater (app name: Form Filler)

> Living document. Claude Code: read this at the start of every session; update it at the end of every session. `CLAUDE.md` holds the invariants and architecture — this file holds *status*.

**Last updated:** 2026-07-17 (Stage 1 code written; awaiting build, test target, and user verification)

---

## Current status

**Stage 5 — code complete, unverified.** Stages 1–4 are done (user-confirmed on device 2026-07-17). Stage 5 code is written and awaits user verification:

1. ⌘U — 33 existing + 11 new tests (`FieldValueFormattingTests`, `TextFittingTests`) must all pass.
2. On iPad: template detail → **Fill Form** (enabled once the template has fields). Two panes: entry form left, live preview right.
3. Exercise: type into text fields (value appears on the page live; overlong text auto-shrinks); date fields via "Set Date" → date picker (per-field format); checkboxes render "X" (toggle from the form *or* by tapping the box on the preview); focused field highlighted on the page; keyboard ▲/▼ moves through text fields and jumps pages.
4. Invariant #3 check: fill some fields, leave the screen, come back — everything must be empty. Nothing is ever written to disk.
5. Editor additions: date fields now have a Date Format picker; Static Text fields have a text box for their fixed content.

Then Stage 6 (export + polish) begins — the Export button is already in the fill toolbar, disabled.

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

### Stage 5 — Fill mode  ◐ (code written 2026-07-17; awaiting user verification)
- ✅ Two-pane layout: `FillSessionView` = ordered form list (360pt, `FillFormListView`) + live preview with value overlays (`FillPageOverlayView` in PageCanvasView's overlay slot)
- ✅ In-memory `[UUID: FieldValue]` only (`FillSessionViewModel`); Clear All with confirmation; PHI footer note in the form
- ✅ Keyboard toolbar ▲/▼/Done cycling text fields; focus ↔ preview sync both ways (focused field highlighted, page auto-jumps); preview taps: checkbox toggles, text/date focuses
- ✅ Date picker with per-field format (`FieldDefinition.dateFormat`, default dd/MM/yyyy, editor picker); unset-until-"Set Date", clearable; checkbox renders "X"
- ✅ Auto-shrink via shared `Support/TextFitting.swift` — fitted in PDF points, scaled to view, so preview == future export; `Support/FieldValueFormatting.swift` resolves field+value → drawn string (shared with export)
- ✅ `FieldDefinition` gained optional `dateFormat` + `staticText` (defensive decode; old templates unaffected); static-text content editable in inspector, rendered on preview, excluded from the form
- ✅ 11 new tests (`FillSupportTests.swift`)

### Stage 6 — Export + polish  ☐
- `PDFExportService`: Core Graphics re-render (CLAUDE.md invariant #5), incl. rotated pages
- Auto-shrink applied identically at export (single shared fit function)
- Share Sheet, Save to Files, Print; default filename `<TemplateName> – <yyyy-MM-dd>.pdf`
- Verify exported PDF fidelity in Preview.app, Acrobat, and iOS Files Quick Look
- Polish pass: empty states, error alerts, haptics, accessibility labels

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
- Fill mode: an accidental back-swipe discards all entered values without confirmation (values are ephemeral by design, invariant #3). Consider a "discard entries?" confirmation in the Stage 6 polish pass.
- Fill preview text uses SwiftUI layout while export will use Core Graphics — same fitted font size via shared TextFitting, but baseline placement could differ by a point or two; verify side-by-side in Stage 6.

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
