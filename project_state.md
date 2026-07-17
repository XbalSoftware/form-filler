# project_state.md — PDF Referral Templater (app name: Form Filler)

> Living document. Claude Code: read this at the start of every session; update it at the end of every session. `CLAUDE.md` holds the invariants and architecture — this file holds *status*.

**Last updated:** 2026-07-17 (Stage 1 code written; awaiting build, test target, and user verification)

---

## Current status

**Stage 3 — code complete, unverified.** Stages 1–2 are done (user-confirmed on device 2026-07-17). Stage 3 code is written and awaits user verification:

1. ⌘U — 13 existing tests + 11 new `CoordinateConversionTests` must all pass.
2. On iPad: open a template → interactive zoomable page preview (pinch to zoom, image sharpens when the gesture settles, pan while zoomed, content stays centered).
3. Multi-page: import any multi-page PDF (or delete all templates and relaunch to regenerate the now-two-page debug seed) → page strip appears below the canvas, tapping a thumbnail switches pages and resets zoom.

Then Stage 4 (template editor) begins — its overlays plug into `PageCanvasView`'s overlay closure.

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

### Stage 3 — Page canvas + coordinate layer  ◐ (code written 2026-07-17; awaiting user verification)  *(foundation for both modes)*
- ✅ `Support/CoordinateConversion.swift`: `PageCoordinateSpace` — pure PDF↔view math (mediaBox offset, rotation 0/90/180/270, point + rect, both directions); single sanctioned `PDFPage` bridge
- ✅ `PDFRenderService`: page → UIImage at quantized half-step scale, NSCache'd, 4096px edge cap, `@concurrent` (off-main); re-renders only on settled zoom change
- ✅ `ZoomablePageContainer`: UIScrollView-backed pinch/pan hosting SwiftUI content (page + overlays scale together); reports stable zoom for re-render
- ✅ `PageCanvasView`: GeometryReader fit + render orchestration + overlay closure `(PageCoordinateSpace, pageSize)` for Stages 4/5
- ✅ Multi-page: `PageStripView` thumbnail strip (shown when pageCount > 1); debug seed PDF now has 2 pages
- ✅ **11 `CoordinateConversionTests`** (corner mapping per rotation, offset mediaBox, scaling, round-trips, normalization, degenerate sizes) — written; must be green before Stage 4

### Stage 4 — Template editor  ☐
- Tap to place field (default ~180×24pt); drag to move; corner handles to resize
- Inspector panel: name, type, font, size, alignment, color, sortOrder (reorder fill sequence)
- Duplicate field, delete field, nudge controls, light edge-snapping
- Persist field edits to `template.json` via TemplateStore

### Stage 5 — Fill mode  ☐
- Two-pane layout: ordered form list (left) + live page preview with value overlays (right)
- In-memory `[UUID: FieldValue]` only — no persistence (CLAUDE.md invariant #3)
- Keyboard toolbar: next/previous field
- Date picker with per-field format string; checkbox toggle rendering "X"
- Auto-shrink font-to-fit behavior in the preview overlays (shared logic with export)

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

---

## Session log

*(Claude Code: append an entry per session — date, stage, what was done, what's next.)*

- **2026-07-06** — Project inception. Architecture finalized with Claude (chat). CLAUDE.md and this file created. Next: confirm assumptions, then Stage 1.
- **2026-07-17** — Stage 1 code written. User created the Xcode project (iPad-only, iOS 18.6+, name Form Filler). Claude: raised `SWIFT_VERSION` to 6.0 in the pbxproj; created `App/`, `Models/`, `Services/`, `Support/`, `ViewModels/`, `Views/Library/` structure; replaced boilerplate `ContentView`/root app file; implemented models with defensive decoding, `TemplateStore` with atomic writes + read-only PDFs, runtime-generated DEBUG seed, slim `LibraryViewModel` + placeholder `LibraryView` (Stage 2 replaces it); wrote Swift Testing suites in `Form FillerTests/` (target must be added in Xcode). Note: pbxproj has stale project-level `IPHONEOS_DEPLOYMENT_TARGET = 26.2` in both configs — harmless, target-level 18.6 overrides it. Next: user builds, adds test target, runs tests + simulator, confirms seed template appears → then Stage 2 (library UI).
- **2026-07-17 (b)** — User added the test target; test build failed: the app target's Xcode-26 default `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` had implicitly made all models and TemplateStore MainActor-isolated, which the (nonisolated) test code couldn't call. Fixed by marking Template, FieldDefinition, FieldStyle, TextAlignmentOption, FieldType, FieldValue, TemplateStore, and TemplateStoreError explicitly `nonisolated` (Decision #14); added missing `import CoreGraphics` to both test files (MemberImportVisibility); raised the test target to Swift 6.0. User will test on a physical iPad rather than the simulator. Awaiting: green test run + seed template visible on device.
- **2026-07-17 (c)** — Stage 1 confirmed by user; Stage 2 written. New: `ThumbnailService` (PDFKit first-page render at 640px wide, PNG-cached in the template folder, `@concurrent` so it runs off-main, rotation-aware aspect); `LibraryViewModel` expanded (import with PDF validation via security-scoped URL, updateDetails/duplicate/delete, per-template async thumbnail loading with in-flight dedup, error alert binding); views split per the ~80-line rule: `LibraryView` (nav + sheets + dialogs), `LibraryGridView` (adaptive LazyVGrid + context menus), `TemplateCardView`, `TemplateFormSheet` (shared by import & edit-details), `TemplateDetailView` (Editor/Fill placeholders). No new unit tests (UI/rendering layer). Next: user verifies on iPad → Stage 3 (page canvas + coordinate conversion, tests mandatory before Stage 4).
- **2026-07-17 (d)** — Stage 2 confirmed (after adding a missing `import UniformTypeIdentifiers` to LibraryView — MemberImportVisibility strikes again; remember explicit imports for every module a file touches). Stage 3 written: `PageCoordinateSpace` in Support/CoordinateConversion.swift (rotation math derived for clockwise /Rotate: pdf bottom-left corner lands top-left at 90°, top-right at 180°, bottom-right at 270°); `PDFRenderService` (@unchecked Sendable — read-only PDFDocument + thread-safe NSCache); `ZoomablePageContainer` (UIScrollView + UIHostingController, content centered via insets, `onStableZoomChange` on gesture end); `PageCanvasView` (fit + `.task(id:)` render keyed on page/width/zoom, `@Environment(\.displayScale)`); `PageStripView`; TemplateDetailView now shows the live canvas; debug seed PDF grew a second page ("Continuation Sheet", one multi-line field, pageIndex 1). 11 new coordinate tests. Next: user verifies (tests + zoom/pan/page-switch on iPad) → Stage 4 (template editor).
