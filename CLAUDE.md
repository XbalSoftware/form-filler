# CLAUDE.md — PDF Referral Templater (app name: Form Filler)

This file governs how Claude Code works on this project. Read it fully before making changes. `project_state.md` (repo root) tracks current progress, decisions, and next steps — read it at the start of every session and update it at the end of every work session.

## What this app is

A native **iPadOS** app (SwiftUI, Xcode 26.3, iOS 26 SDK, Swift 6) for templating PDF referral forms. The user (an optometrist) imports a PDF once, defines fillable field locations on it, then repeatedly fills those fields with patient information and exports a brand-new completed PDF.

It is **not** a PDF editor or annotation app. Scope discipline matters: resist feature creep beyond `project_state.md`'s roadmap.

## Non-negotiable invariants

1. **The original PDF is never modified.** After import, `original.pdf` is opened read-only, always. Exports are new documents rendered from scratch. Nothing in the codebase may open a template's PDF for writing.
2. **Field geometry is stored in PDF page point space** — bottom-left origin, relative to the page's mediaBox, un-rotated. Never store screen/view coordinates. All screen↔PDF conversion goes through the helpers in `Support/CoordinateConversion.swift` and nowhere else.
3. **Filled patient values are never persisted to disk — except via two explicitly user-requested channels** (amended 2026-07-17): (a) the encrypted on-device draft vault (`DraftStore`: AES-GCM via CryptoKit, key in Keychain `ThisDeviceOnly`, file `draft.sealed` excluded from backups) which autosaves the single active fill session until the user clears it; and (b) the `FillSessionPayload` embedded in every exported PDF's Keywords Info key so exports can be reopened for re-editing. `FieldValue` stays deliberately non-Codable; every serialization of fill data must go through `FillSessionPayload`/`CodableFieldValue`. No other caching, persistence, or state restoration of fill values. Exclude fill-session UI state from iOS state restoration snapshots.
4. **PDFKit is a rendering/parsing engine only, never an interactive view.** Do not use `PDFView` for the editor or fill preview. Pages are rendered to images and displayed in our own SwiftUI zoomable container; overlays are plain SwiftUI views positioned by our own coordinate math.
5. **Export uses Core Graphics re-rendering** (`UIGraphicsPDFRenderer` / `CGContext`): draw each original page via `PDFPage.draw(with:to:)`, then draw field values as attributed strings in PDF space. No `PDFAnnotation` flattening.

## Architecture

MVVM using the Observation framework (`@Observable`). Do **not** use `ObservableObject`/`@Published` — the deployment target makes Observation available everywhere.

```
Form Filler/
  App/                    # entry point, root navigation
  Models/                 # Template, FieldDefinition, FieldStyle, FieldType, FieldValue
  Services/
    TemplateStore.swift       # folder enumeration, load/save/duplicate/delete
    PDFRenderService.swift    # PDFPage → UIImage at scale, with caching
    PDFExportService.swift    # Core Graphics export of completed PDFs
    ThumbnailService.swift
  ViewModels/
    LibraryViewModel.swift
    TemplateEditorViewModel.swift
    FillSessionViewModel.swift
  Views/
    Library/
    Editor/               # page canvas, field overlays, field inspector
    Fill/                 # form column (left) + live preview column (right)
    Shared/               # ZoomablePageContainer, field overlay views
  Support/                # CoordinateConversion, CGRect helpers, Color↔hex
Tests/                    # unit tests; coordinate conversion is priority #1
```

Services are plain structs/classes with no UI imports where possible. ViewModels own services; Views own nothing but their ViewModel and layout. Keep views small — extract subviews before any body exceeds ~80 lines.

## Data model (canonical shapes)

```swift
struct Template: Codable, Identifiable {
    let id: UUID
    var name: String
    var category: String?
    var createdAt: Date
    var modifiedAt: Date
    var pdfFileName: String          // relative to the template's folder
    var fields: [FieldDefinition]
}

struct FieldDefinition: Codable, Identifiable {
    let id: UUID
    var name: String
    var type: FieldType
    var pageIndex: Int
    var rect: CGRect                 // PDF point space (invariant #2)
    var style: FieldStyle
    var sortOrder: Int               // fill-form ordering
}

enum FieldType: String, Codable {
    case singleLineText, multiLineText, date, checkbox, staticText, patientName
}
// patientName behaves as single-line text whose value also feeds the export
// filename; the editor enforces at most one per template.

// Ad-hoc fill-session marks (checkmarks stamped on the form's own boxes,
// circles drawn around items) are `AdHocMark` values: session data like
// FieldValue, but Codable because they travel in FillSessionPayload.
// Their stroke paths live in Support/MarkGeometry.swift, shared by the
// preview overlay and the export renderer.

struct FieldStyle: Codable {
    var fontName: String             // default "Helvetica"
    var fontSize: CGFloat
    var alignment: TextAlignmentOption
    var colorHex: String
}
```

Fill values: transient `[UUID: FieldValue]` keyed by field ID, owned by `FillSessionViewModel`. Not Codable-persisted (invariant #3).

**Adding a field type** = one enum case + a switch arm in exactly two places: the overlay view factory and the export renderer. Keep it that way; do not introduce a protocol-per-field-type architecture.

**Codable evolution:** decode defensively (`decodeIfPresent` with defaults) so old `template.json` files keep loading as the model grows. Include a `schemaVersion: Int` in `Template` from day one.

## Storage layout

Folder per template under Application Support:

```
Templates/
  <UUID>/
    original.pdf        # imported bytes, byte-for-byte, read-only forever
    template.json       # Template (metadata + fields), pretty-printed
    thumbnail.png       # cached library thumbnail
```

`TemplateStore` enumerates these folders at launch. Writes go via write-to-temp-then-atomic-replace. Duplicating a template = copy folder, new UUID, new folder name, updated json ids/dates.

Alongside (not inside) `Templates/`, Application Support holds `draft.sealed` — the encrypted fill-session draft (see invariant #3). Whole-library backup/restore is `LibraryBackupService`: one JSON file with every template plus its PDF bytes base64-encoded (no patient data).

## Behavioral details already decided

- Editor: tap creates a field at a default size (~180×24pt single-line); drag to move; corner handles to resize; nudge buttons for fine placement; duplicate-field action; light edge-snapping against other fields.
- Fill mode: two-pane iPad layout — ordered form list left, live preview right. Keyboard toolbar with next/previous field. Date fields use a date picker with per-field format string. Checkboxes render as "X" sized to the rect.
- **Auto-shrink:** text overflowing its rect steps the font size down to fit rather than clipping.
- Export filename default: `<TemplateName> – <PatientName> – <yyyy-MM-dd>.pdf`; the patient segment appears only when the template's patientName field is filled (user decision 2026-07-17, superseding the earlier never-in-filename rule).
- Export destinations: Share Sheet (covers AirDrop), Save to Files, Print.
- Multi-page templates supported; editor and preview get a page strip/pager.

## Handling PDF rotation

Some scanned referral forms carry a `/Rotate` value. Coordinate conversion must account for `PDFPage.rotation` in both directions, and the export renderer must draw text correctly on rotated pages. Include rotated-page cases in the coordinate conversion unit tests (0/90/180/270).

## Code style

- Swift 6 language mode; resolve concurrency warnings properly (actor isolation, `@MainActor` on ViewModels), don't suppress them.
- Native frameworks only. No third-party dependencies without explicit user approval.
- Small, pure, testable functions in `Support/`. Coordinate math must have unit tests before the editor is built on top of it.
- Prefer clarity over cleverness; this codebase should be readable by its owner, who reviews everything.

## Working process

- Build after every meaningful change: `xcodebuild -scheme "Form Filler" -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build` (adjust simulator name to what's installed; `xcrun simctl list devices` to check). The user handles builds/tests/commits; Claude writes the code.
- Run tests with the same destination via `xcodebuild test`.
- One roadmap stage at a time (see `project_state.md`). Do not start the next stage until the current one compiles, tests pass, and the user has confirmed it works on device/simulator.
- Update `project_state.md` at the end of every session: what was completed, decisions made, known issues, next step.
- When a design question arises that isn't settled here or in `project_state.md`, ask the user rather than guessing — then record the answer in `project_state.md` under Decisions.
