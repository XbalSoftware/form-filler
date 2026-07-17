# project_state.md — PDF Referral Templater (working name: EYEform)

> Living document. Claude Code: read this at the start of every session; update it at the end of every session. `CLAUDE.md` holds the invariants and architecture — this file holds *status*.

**Last updated:** 2026-07-06 (project inception — no code written yet)

---

## Current status

**Stage 0 — not yet started.** The Xcode project does not exist. Architecture is finalized (see CLAUDE.md). Next action: Stage 1 below.

---

## Environment

- Mac mini M4, macOS 26.5, Xcode 26.3
- Target: iPadOS (iOS 26 SDK), Swift 6, SwiftUI, Observation framework
- No third-party dependencies
- Working app name: **EYEform** (placeholder — confirm with user before creating the project; bundle ID and display name are easy now, annoying later)

---

## Roadmap

Work strictly one stage at a time. A stage is done when it compiles, its tests pass, and the user has confirmed behavior in the simulator or on device.

### Stage 1 — Skeleton, models, storage  ☐
- Create Xcode project (iPad-only target), folder structure per CLAUDE.md
- Implement `Template`, `FieldDefinition`, `FieldStyle`, `FieldType` (Codable, with `schemaVersion`)
- Implement `TemplateStore`: enumerate/load/save/duplicate/delete template folders; atomic writes
- Debug-only seed: bundle a sample PDF, create a seed template on first launch (DEBUG builds only)
- Unit tests: Codable round-trip, store CRUD, defensive decoding of a hand-written old-schema json

### Stage 2 — Template library UI  ☐
- Library grid/list with thumbnails (`ThumbnailService`)
- Import PDF via `fileImporter` / document picker; name + optional category on import
- Rename, duplicate, delete (with confirmation), edit category
- Navigation: template → Editor or Fill mode

### Stage 3 — Page canvas + coordinate layer  ☐  *(foundation for both modes)*
- `PDFRenderService`: PDFPage → UIImage at scale, cached; re-render on material zoom change only
- `ZoomablePageContainer`: SwiftUI pinch-zoom/pan container displaying the page image
- `Support/CoordinateConversion.swift`: screen↔PDF-point-space conversion incl. mediaBox offset and page rotation (0/90/180/270)
- **Unit tests for coordinate conversion are mandatory before Stage 4 begins**
- Multi-page: page strip / pager

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

## Assumptions awaiting user confirmation

- [ ] App name "EYEform" (placeholder)
- [ ] iPad-only target (not universal) — the two-pane fill layout assumes it
- [ ] Ephemeral fill sessions acceptable (no draft saving in v1)
- [ ] Helvetica as default font

Confirm these with the user at the start of Stage 1; move answers into the Decisions log.

---

## Known issues / risks

- Page rotation handling is the likeliest source of subtle bugs — covered by mandatory tests in Stage 3.
- Scanned PDFs can have unusual mediaBox origins (non-zero); conversion helpers must use the mediaBox, never assume (0,0).
- Large scanned PDFs: render at capped scale and cache; watch memory on multi-page documents.

---

## Session log

*(Claude Code: append an entry per session — date, stage, what was done, what's next.)*

- **2026-07-06** — Project inception. Architecture finalized with Claude (chat). CLAUDE.md and this file created. Next: confirm assumptions, then Stage 1.
