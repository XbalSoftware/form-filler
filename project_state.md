# project_state.md — PDF Referral Templater (app name: Form Filler)

> Living document. Claude Code: read this at the start of every session; update it at the end of every session. `CLAUDE.md` holds the invariants and architecture — this file holds *status*.

**Last updated:** 2026-08-04 (v1.0 approved on the App Store; v1.1 submission prep begun — MARKETING_VERSION bumped to 1.1, build 2)

---

## Current status

**Roadmap complete (Stages 1–6 user-verified on device 2026-07-17), now in post-roadmap polish.**

**Polish round 1 — done, user-confirmed working 2026-07-17.** Whole-library backup/restore (single JSON file incl. PDFs), library search filter, no forced capitals in fill fields, multi-line Return=newline / Tab=next-field, `patientName` field type feeding the export filename, encrypted draft autosave vault (`DraftStore`), fill payload embedded in exported PDFs + "Reopen Exported PDF", Save/Print/Share as a blue toolbar group, dedicated "Clear form" button, editor field-name labels.

**Polish round 2 — code written, awaiting user verification (user now runs all builds/tests/commits themselves):**

1. **Checkmark & circle tools in fill mode** — segmented Type/Checkmark/Circle picker above the preview; tap stamps a ✓ (for boxes printed on the form, no template field needed), drag rings an item, tap a mark removes it. Marks render in preview and export via shared `MarkGeometry`, ride in the draft and embedded payload.
2. **Library top bar** — Reopen Exported PDF far left; centered search field (custom principal item); trailing (left→right): Arrange menu (Recently Modified / Name / Recently Added, persisted via @AppStorage), Settings gear, ＋ outermost. Drag-to-reorder was skipped in favour of sort options — say the word if you want manual ordering too.
3. **Settings sheet** — Back Up / Restore Library (moved out of the old … menu), About page (version + links), Reset App with confirmation (erases templates, draft, temp exports).
4. **Docs** — user manual and privacy policy written for the GitHub site; `Support/AppLinks.swift` holds their URLs. (Both since done: the two Markdown files were consolidated into the single `docs/index.html` that Pages serves, and `AppLinks` points at the live site.)

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

Numbers are permanent and referenced from the session log and from code comments — never renumber. When a decision is overtaken, note it in place rather than deleting the row.

| # | Decision | Rationale | Date |
|---|----------|-----------|------|
| 1 | Field rects stored in PDF page point space, mediaBox-relative, un-rotated | Device/zoom independence; matches the export drawing space | 2026-07-06 |
| 2 | PDFKit as engine only; custom image-based zoomable canvas for editor and preview | `PDFView` overlay sync is unreliable during zoom/scroll | 2026-07-06 |
| 3 | Export via Core Graphics re-render, not annotation flattening | Consistent rendering across viewers; the original is never touched | 2026-07-06 |
| 4 | Folder-per-template storage + Codable JSON; no SwiftData | Debuggable, portable, trivial import/export and sync later | 2026-07-06 |
| 5 | Fill values are ephemeral, memory only — **amended by #23** | PHI hygiene; the only artifact carrying patient data is the exported PDF | 2026-07-06 |
| 6 | Enum-based `FieldType` with a switch arm per site, not protocol-per-type | Cheap extensibility, compiler-enforced exhaustiveness (Lessons learned lists the current switch sites) | 2026-07-06 |
| 7 | Default font Helvetica, per-field override | PDF-native, safe metrics | 2026-07-06 |
| 8 | Auto-shrink text to fit the field rect | Referral forms have tiny boxes; avoids constant size fiddling | 2026-07-06 |
| 9 | App name **Form Filler**; deployment target **iOS 18.6+** | User decision at Stage 1 | 2026-07-17 |
| 10 | iPad-only target (`TARGETED_DEVICE_FAMILY = 2`) | Confirmed in project settings | 2026-07-17 |
| 11 | Debug seed PDF generated at runtime, not bundled | No binary asset in the repo, and one layout struct drives both the drawing and the field rects so they always align | 2026-07-17 |
| 12 | `duplicate()` regenerates field IDs as well as the template ID | Keeps IDs globally unique; cheap insurance for cross-template features | 2026-07-17 |
| 13 | The store never bumps `modifiedAt`; callers own dates | Predictable writes, deterministic tests | 2026-07-17 |
| 14 | Keep `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` on the app target; mark models and `TemplateStore` explicitly `nonisolated` | UI code stays simple under MainActor-by-default while data and storage types remain usable from any context (tests, background export) | 2026-07-17 |
| 15 | Editor gestures: one finger edits (tap / drag / resize), two fingers pan and pinch-zoom | Standard iPad canvas pattern; cleanly avoids UIScrollView vs. field-drag conflicts | 2026-07-17 |
| 16 | Editor persists on every committed mutation; no Save button | Atomic tiny JSON writes, nothing to forget, matches iOS editing conventions | 2026-07-17 |
| 17 | Font picker offers a small PDF-safe list (Helvetica ×3, Times, Courier) | Export renders with the same names; avoids fonts that may not embed cleanly | 2026-07-17 |
| 18 | `FieldDefinition` gained optional `dateFormat` and `staticText` (defensive decode) | Per-field date format and static-text content had nowhere to live. `dateFormat` is vestigial since #38, kept only so old templates decode | 2026-07-17 |
| 19 | Default date format dd/MM/yyyy — **moot since #38** | UK/Australian convention for the app's owner | 2026-07-17 |
| 20 | Date fields start unset ("Set Date") rather than pre-filled with today — **moot since #38** | No accidental wrong dates on exports | 2026-07-17 |
| 21 | Export draws page content via `CGPDFPage.getDrawingTransform` + `drawPDFPage`, not `PDFPage.draw(with:to:)` | Deviates from invariant #5's letter but honors its spirit (vector CG re-render, no flattening). Quartz's transform API has documented `/Rotate` and mediaBox handling where PDFKit's draw behavior is underdocumented | 2026-07-17 |
| 22 | Share by writing the PDF to disk first, then handing `UIActivityViewController` the **concrete file URL** — never ShareLink + `FileRepresentation` | `FileRepresentation` offers a lazy file promise, which the EMR rejects; it requires a real URL to a `.pdf` file | 2026-07-17 |
| 23 | Invariant #3 amended: fill data may persist ONLY via `FillSessionPayload` — the encrypted draft vault and the payload embedded in exported PDFs | Both explicitly requested. `FieldValue` stays non-Codable so nothing else can casually persist patient data | 2026-07-17 |
| 24 | The embedded reopen payload lives in the **Keywords** PDF Info key as `FormFiller1:` + base64 JSON, with a one-shot PDFKit re-serialize fallback (`ensuringEmbeddedSource`) | It must be a documented Info key: `CGPDFContext` silently drops custom ones, and device builds have been seen dropping `documentInfo` entirely, hence the read-back check. Any pipeline that rewrites the PDF may strip it, and only PDFs exported after this feature carry it | 2026-07-17 |
| 25 | Draft vault: AES-GCM, key in Keychain `AfterFirstUnlockThisDeviceOnly` (no user-presence gate), `draft.sealed` excluded from backup, complete file protection. Leaving the fill screen autosaves silently and resume is offered by prompt; **exporting does NOT clear the draft**, but "Clear form" and "Start Fresh" do | Restore is deliberately silent. The back-button discard confirmation was removed since nothing is lost on exit, which also restored edge-swipe back | 2026-07-17 |
| 26 | `patientName` feeds the export filename | The value only ever comes from a field the user typed. Partly superseded: #46 allows multiple name fields, and the order later became `<Patient> – <Template> – <date>.pdf` | 2026-07-17 |
| 27 | Library backup is ONE JSON file with PDFs base64-inline; restore only ever adds (same-ID templates skipped, never overwritten) | Native-frameworks-only rules out reading zips, JSON stays debuggable, and add-only restore cannot destroy local work | 2026-07-17 |
| 28 | Multi-line fill fields are `TextEditor` (Return = newline) with `.onKeyPress(.tab)` moving focus; all fill text inputs use `.textInputAutocapitalization(.never)` | Return must insert a newline inside multi-line fields, Tab must keep the tab-between-fields flow, and forced capitals break email addresses | 2026-07-17 |
| 29 | Ad-hoc fill marks are `AdHocMark` values in PDF-space rects, Codable, carried in `FillSessionPayload`; stroke geometry is shared between preview and export via `MarkGeometry`. Tap places or removes, drag draws circles; a `.comment` kind was added later | Lets the user tick boxes already printed on the form without templating a field for each. Vector strokes avoid glyph-availability problems (✓ isn't in Helvetica) | 2026-07-17 |
| 30 | Library arrangement is sort options (Recently Modified default / Name / Recently Added) persisted in `@AppStorage`, not drag-to-reorder | Avoids inventing a persisted manual-order field; revisit if manual ordering is wanted | 2026-07-17 |
| 31 | `signature` FieldType whose session value REUSES `.checkbox(Bool)`; the image is drawn aspect-fit in preview and export, included in library backups (add-only restore) and erased by Reset App. Drawn in-app (transparent PNG, stroke-cropped) or imported PNG/JPEG. Storage as a single app-wide image (`SignatureStore`) is **superseded by #35** | Reusing the checkbox value case leaves `FieldValue`, `CodableFieldValue` and the payload untouched, so old drafts and exported payloads stay decodable. The signature is the user's own info, not PHI, so plain storage and backup inclusion are fine | 2026-07-18 |
| 32 | New editor fields arrive with their placeholder name focused and fully selected (`fieldAwaitingName` one-shot in the editor VM + `TextField(selection:)`) | Type the real name immediately, no select-all fiddling | 2026-07-18 |
| 33 | Reopen-exported-PDF pushes detail-then-fill onto the navigation path, and the restored session is vaulted to the draft immediately | Back lands on the fill/edit chooser like the normal flow, and backing out can never lose a reopened form — the resume prompt offers it on the next fill entry | 2026-07-18 |
| 34 | Practitioner profiles (`PractitionerProfile` + `practitioners.json`): six auto-populated field types (doctorName / officeAddress / officeFax / officePhone / officeEmail / practitionerID) **materialized into `values` as plain `.text`** when the session starts or the profile changes, and hidden from the fill form. `officeAddress` wraps (`FieldType.isMultiline`); a picker appears when there is more than one profile; profiles ride in backups (add-only by ID); `hasAnyValues` EXCLUDES practitioner values | Materializing means preview, export, draft and embedded payload need zero special cases, and a reopened PDF shows exactly what was printed. Excluding them from `hasAnyValues` keeps untouched forms from autosaving drafts or enabling "Clear form" | 2026-07-18 |
| 35 | Signature rolled into practitioner profiles: `PractitionerProfile.signatureBase64`, which rides in `practitioners.json` and backups automatically. The fill session stamps the SELECTED profile's signature, falling back to the legacy app-wide `SignatureStore` image; the profile picker also shows for templates with only signature fields (`usesProfileSelection`) | One doctor across multiple locations means per-profile signatures, so switching profile switches signature. The legacy fallback keeps pre-profile setups working with zero migration, and `SignatureStore` is retained solely for that | 2026-07-18 |
| 36 | Self-labeling field types name themselves: choosing a type whose name would be redundant (all patient and practitioner types, `patientName`, `signature` — `FieldType.isSelfLabeling`) sets `field.name = type.displayName` via `setSelectedFieldType`, and the inspector hides the Name box. Generic types (single-line, multi-line, static text) keep the manual name box and tab-to-rename | Redundant to both type "Office Fax" and pick Office Fax as the type. Existing stored names decode unchanged — only re-selecting the type renames | 2026-08-03 |
| 37 | Patient demographic field types (`patientAddress`, `patientDateOfBirth`, `patientHealthcareNumber`, `patientPhone`, alongside the existing `patientName`) — the **field type is the mapping key** for patient-PDF import, with no separate role attribute. They are ordinary user-fillable fields, not hidden like practitioner fields; `patientAddress` wraps and the rest are single-line; DOB is plain text, not a date picker; `FieldType.isPatientField` groups them and the count per template is unrestricted | Type-as-key reuses the proven `patientName` and practitioner pattern with zero new model attributes. Multiple allowed since a form may print DOB or address more than once | 2026-08-03 |
| 38 | Removed the `date` and `checkbox` `FieldType` cases — dates are typed as text, and boxes printed on the form use the ad-hoc checkmark tool. `FieldValue.date`/`.checkbox` are KEPT (signature reuses `.checkbox`, payload format unchanged), `FieldDefinition.dateFormat` is kept as a vestigial decode-compat property, and any pre-existing date/checkbox fields decode to `.singleLineText` via the defensive fallback | Both types became redundant. Keeping the `FieldValue` cases avoids breaking drafts, embedded payloads and the signature value | 2026-08-03 |
| 39 | Patient-PDF autofill Phase 1: parse, review, apply. `PatientDemographicsParser` and `PatientDemographics` live in `Support/` and are pure text→struct, anchored on the IRIS "FILE EXCERPT" divider plus label and pattern matching, every field independent and defensive (a miss is `nil`, never a throw). An editable `DemographicsReviewSheet` always precedes `applyDemographics` | Phased so a fully testable core shipped first. The review step is non-negotiable for patient data because the parser is tuned to one layout, and it is the correctness backstop on real files | 2026-08-03 |
| 40 | Imported DOB is reformatted from IRIS's ISO `yyyy-MM-dd` to `DD MON YYYY` (zero-padded day, caps month abbreviation) via a fixed `en_US_POSIX`/UTC `DateFormatter`; unparseable dates are kept verbatim | A caps month removes day/month ambiguity on a referral form, and `en_US_POSIX` keeps abbreviations stable regardless of device locale | 2026-08-03 |
| 41 | Imported name reformatted "First Last" → "LAST, First" with the surname upper-cased. The surname runs from the first recognized particle (von / van / de / der / del / di / la / le / st / dos … in `surnameParticles`) to the end, otherwise just the last word, so middle names stay with the given name. One-word names are unchanged | Unambiguous LAST, First, with particle detection covering the common hard cases. Irreducible ambiguity — a multi-word non-particle surname vs. a middle name — is left for the review sheet to correct | 2026-08-03 |
| 42 | Patient-PDF autofill Phase 2 is share-from-IRIS intake. The app declares it opens `com.adobe.pdf` (a one-time Xcode Document Types step) so it appears in the EMR Share sheet. `Form_FillerApp` owns a `PatientImportInbox` (`@Observable`, in-memory only) injected via `.environment`; `.onOpenURL` → `receive(pdfAt:)` parses and then **deletes the Documents/Inbox copy**. Opening documents in place is deliberately NOT declared, so shares always land in that inbox and are ours to scrub | Direct share removes Phase 1's "save to Files first" PHI exposure, and reuses the Phase 1 review-and-apply core wholesale | 2026-08-03 |
| 43 | Exam-findings import: 8 clinical FieldTypes — `patientRefractionOD/OS`, `patientVisualAcuityOD/OS`, `patientKeratometryOD/OS`, `patientIntraocularPressureOD/OS`. All are `isPatientField` (mapped, reviewed, manually fillable) and single-line. Refraction and VA come from the FIRST "Subjective Refraction (BVA)" section (the most recent), sphere/cyl/axis only with ADD dropped, VA normalized to "20/15" / "20/15-1"; keratometry from its own section; IOP from `Intraocular Pressure` → `Measurements` → `NCT`, stored as a bare number. All read through `odosValues(afterLineContaining:requiring:)`, which anchors to the section header THEN takes the next OD:/OS: — necessary because autorefractor, keratometry and final Rx all reuse those labels — with `requiring: "mmHg"` stopping an adjacent Pachymetry (µm) line being read as IOP on exams without pressures. `PatientDemographics` uses a `nonisolated(unsafe)` static `fieldMap` (FieldType→keyPath) so `value(for:)`, `limited(to:)` and `isEmpty` share one source of truth | Exam values commonly go on referrals and are a large time saver. IRIS-only and format-fragile, so the review sheet is the backstop | 2026-08-03 |
| 44 | Keratometry reformatted to a compact "##.##@###/##.##" — first power, first axis zero-padded to three digits, second power, second axis dropped — via `reformattedKeratometry` + the `keratometryReading` regex. E.g. "44.00 @10° × 44.25 @100°" → "44.00@010/44.25" | The full K string is too bulky for form boxes | 2026-08-03 |
| 45 | `referralDate` FieldType: editable, defaulting to today ("DD MON YYYY", caps month). It appears in the fill form as a normal single-line field, and both `FieldValueFormatting.displayText` and `referralDateBinding` return the stored override if set, else `todayReferralDate()` recomputed each render. Today is never STORED — only an override is. Self-labeling, in the editor's "General" picker group, keyboard-navigable | Wanted visible and overrideable for back- or post-dated referrals. Store-only-on-override means an untouched field is never stale, only an override counts toward `hasAnyValues` and the draft, and clearing reverts to today — no materialization and no `hasAnyValues` exclusion needed | 2026-08-03 |
| 46 | Multiple `patientName` fields allowed (the editor's one-per-template restriction removed). They share ONE value via `Template.valueKey(for:)` — patientName maps to the primary (first) field's id, every other field to its own — resolved on read by both the preview (`displayText`) and the export. The fill form shows only the primary input, tapping any name overlay focuses it, and the filename still uses the primary | A two-page referral needs the name on both pages. Resolve-on-read beats mirror-on-write: no stale ids, no drift, and a name field added later auto-mirrors | 2026-08-03 |
| 47 | Share Template uses a hybrid in `TemplateShareService.pdfWithEmbeddedTemplate`: try the PDFKit re-serialize first (exact geometry, so no regression for templates that already work), and only on failure fall back to `PDFExportService.pdfCopy(ofSource:keywords:)`, a clean CG re-render that drops the tag tree and embeds Keywords reliably via `format.documentInfo` + `ensuringKeywords` | Tagged/accessible PDFs — common from generated EMR and clinic forms — have structure trees that defeat `dataRepresentation()`, leaving the payload unreadable so the share threw. Geometry is preserved for un-rotated origin-0 pages; a rotated, non-zero-origin, tagged scan is the theoretical weak spot, but those hard-failed before | 2026-08-03 |
| 48 | Patient Phone auto-formats to "(###) ###-####" when exactly 10 digits remain after stripping whitespace and the punctuation `( ) - .` — `Support/PhoneFormatting.autoFormat`, applied in `FillFormListView`'s `textBinding` setter only when `field.type == .patientPhone`. Idempotent on already-formatted input; 11+ digits, letters, or an extension are left verbatim | Format-on-complete with a digits-only guard avoids clobbering deliberate input | 2026-08-03 |
| 49 | Re-sharing a template whose PDF was ITSELF an imported Form Filler share must verify that the SPECIFIC new payload reads back (`embeds(_:in:)`), not merely that some template is embedded, and falls back to `freshDocumentData(copyingPagesFrom:keywords:)` — rebuilding into a NEW `PDFDocument` from `PDFPage.copy()` — before the CG re-render tier | Two causes: the source PDF already carried template Keywords, and iOS PDFKit will not overwrite an existing Keywords value (macOS will), so the check accepted the OLD payload and returned early, exporting stale field placement. The fresh copy has no stale keywords to fight and preserves geometry exactly, where a CG re-render might not on rotated pages. Already-broken PDFs self-heal after one more re-export | 2026-08-03 |

## Assumptions awaiting user confirmation

- [x] App name — **Form Filler** (confirmed 2026-07-17)
- [x] iPad-only target — confirmed via project settings (2026-07-17)
- [x] ~~Ephemeral fill sessions~~ — superseded: user requested the encrypted draft vault (Decision #25)
- [ ] Helvetica as default font — proceeding per Decision #7; flag if wrong
- [x] `AppLinks` URLs — live GitHub Pages addresses wired in (2026-07-18)

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

## Lessons learned

Durable gotchas. Re-read this before debugging something that "should just work".

**Toolchain / build**
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Xcode 26 default, deliberately kept — Decision #14) implicitly isolates every type. Models, stores, and anything the tests call must be explicitly `nonisolated` — and **`nonisolated` has to be restated on each extension**, because extensions don't inherit it from the type.
- Swift 6 MemberImportVisibility: import every module a file touches, even indirectly. Repeat offenders — `CoreGraphics` (CGRect/CGFloat), `UniformTypeIdentifiers` (`.pdf`), `UIKit` in a model holding an image.
- Long SwiftUI modifier chains blow the type-checker's budget. Fix by splitting `body` into a thin `body` plus a content property, or by factoring the chain into a `ViewModifier` (`FillSessionView` and `LibraryView` both needed this).
- `.greatestFiniteMagnitude` is ambiguous without an explicit `CGFloat` annotation.
- ViewModels stay UI-free: `Array.move(fromOffsets:toOffset:)` is SwiftUI-only, so reordering is hand-rolled.
- The pbxproj still carries a stale project-level `IPHONEOS_DEPLOYMENT_TARGET = 26.2`; the target-level 18.6 overrides it. Harmless.
- Filesystem-synchronized groups mean new source *and* test files join their targets with no pbxproj edit.

**PDF / PDFKit**
- ShareLink's `FileRepresentation` hands over a lazy *file promise*, which the EMR rejects. Write the PDF to disk first, then give `UIActivityViewController` a concrete file URL (Decision #22).
- iOS PDFKit's `dataRepresentation()` will not **overwrite** an existing Keywords value (macOS will). So always verify that the *specific* new payload reads back — never just "a payload exists" — and fall back to a fresh `PDFDocument` built from `PDFPage.copy()`, then to a CG re-render (Decision #49).
- `CGPDFContext` silently drops custom Info keys, and some device builds drop `documentInfo` entirely. Hence documented-key-only payloads plus a read-back check and fallback chain (Decision #24).
- Tagged/accessible PDFs can defeat PDFKit re-serialization completely; `TemplateShareService` falls back to a CG re-render for them (Decision #47).
- Text auto-shrink must be fitted against the **display-space** rect, not the PDF-space rect, or preview and export disagree on rotated pages.

**Focus / keyboard**
- Setting a `TextField` selection immediately after focusing it gets wiped by first-responder placement — apply it ~80ms later (hidden focusables need ~50ms).
- Never let SwiftUI's system Tab traversal coexist with the app's manual traversal. Every text field must route Tab through the same `.onKeyPress(.tab)` → `moveFocus` path; mixing the two engines was the root cause of the long-standing "backwards Tab loops or traps" bug.

**Model changes**
- Adding a `FieldType` touches six switch sites — `displayName`, `FieldListView` icon, `FieldValueFormatting`, `FillFormListView` row, `handleOverlayTap`, `PDFExportService` draw — **plus the editor's Type-picker groups** in `FieldInspectorForm`. Miss the last one and the type exists but can't be chosen. (CLAUDE.md's "exactly two places" line predates this growth.)

---

## Session log

*(Claude Code: add an entry per session at the top — date, what changed, what's next.)*

### 2026-08-04 — v1.1 submission prep
v1.0 approved on the App Store. Bumped `MARKETING_VERSION` 1.0→1.1 and `CURRENT_PROJECT_VERSION` 1→2 in both app-target configs (test target untouched — it doesn't ship). v1.1 covers polish rounds 3–8, patient-PDF autofill Phases 1–2, and exam-findings import.

Still unverified on device (everything since the 1.0 submission was written but never user-run):
- Rounds 3–8: signature restamping when the profile changes, white field backgrounds, comment move/resize/edit, template share → re-import, editor name select-all, Tab cycling in both fill and edit mode (the hidden edit-mode Tab-catcher is the riskiest part).
- Patient autofill Phases 1–2 and exam-findings import end to end; confirm no leftover file in the app's Inbox after a share-in.
- The Xcode GUI step for Phase 2 if not already done: target → Info → Document Types → add PDF (`com.adobe.pdf`), and do **not** enable "opening documents in place".
- Print-sheet presentation on iPad, rotated-scan export orientation, EMR acceptance of an export.

Next: user verifies, then archives and uploads via Xcode Organizer and updates the App Store Connect listing.

### 2026-08-03 — patient-PDF autofill, exam findings, field-type cleanup
- Self-labeling types now name themselves and hide the Name box (#36). Four patient demographic types added, with the **field type as the mapping key** for import — no separate role attribute (#37).
- Removed the `.date` and `.checkbox` `FieldType` cases (#38). `FieldValue.date`/`.checkbox` are kept (signature reuses `.checkbox`, payload format unchanged) and `FieldDefinition.dateFormat` is kept purely for decode compatibility. Type picker regrouped into headerless sections.
- **Autofill Phase 1** (#39): `PatientDemographics` + `PatientDemographicsParser` in `Support/` — pure text→struct, anchored on the IRIS "FILE EXCERPT" divider plus label/pattern matching, every field independent and defensive (a miss is `nil`, never a throw). A mandatory, editable `DemographicsReviewSheet` always precedes `applyDemographics`; that review step is the correctness backstop and is non-negotiable, since the parser is tuned to one layout.
- **Autofill Phase 2** (#42): share-from-IRIS. `PatientImportInbox` (`@Observable`, in-memory only) receives via `.onOpenURL`, parses, then **deletes the Documents/Inbox copy** — because opening in place is deliberately not declared, shares always land there and are ours to scrub. `FillSessionView` consumes pending imports on appear and on change; at the library root a "Patient Details Ready" alert points the user at a form.
- Import formatting: DOB → `DD MON YYYY` with a caps month via a fixed `en_US_POSIX`/UTC formatter (#40); name → `LAST, First` with particle detection for van/von/de-style surnames (#41); healthcare number normalized; patient phone auto-formats only when exactly 10 digits remain after stripping punctuation (#48).
- **Exam findings** (#43): eight clinical types (refraction / VA / keratometry / IOP, per eye). `odosValues(afterLineContaining:)` anchors to a section header *then* reads the next `OD:`/`OS:` — necessary because autorefractor, keratometry and final Rx all reuse those labels. Refraction and VA come from the first "Subjective Refraction (BVA)" section (the most recent); keratometry is compacted to `##.##@###/##.##` (#44); IOP sits under `Intraocular Pressure` → `Measurements` → `NCT` and is stored as a bare number, guarded by `requiring: "mmHg"` so an adjacent Pachymetry (µm) OD/OS line can't be grabbed when IOP is absent. Both IRIS export types (FILE EXCERPT report and Complete Exam) share the same structure.
- `referralDate` type (#45): editable, defaults to today, and is **stored only when overridden** — so an untouched field is never stale, never counts toward `hasAnyValues`, and clearing it reverts to today.
- Patient-name mirroring (#46): multiple `patientName` fields are allowed and all resolve through `Template.valueKey(for:)` on read, so a name typed once repeats on every page and can't drift.
- Template-share fixes for tagged PDFs (#47) and for re-sharing a template whose PDF was itself an imported share (#49) — see Lessons learned. Already-broken re-shared PDFs self-heal after one more export.
- Tab navigation fixed in both fill and edit mode (see Lessons learned). Edit mode needs a hidden focusable "Tab-catcher" because self-labeling types have no name box to hold focus.

### 2026-07-19 — App Store prep
Straight to the public App Store, no TestFlight. Added `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` to both app-target configs — the CryptoKit draft vault uses only Apple's built-in encryption, so the standard exemption applies and the export-compliance questionnaire is skipped on every upload. Audit: icon complete, signing set, `AppLinks` live, Release has no debug seed so reviewers see an empty library. App Privacy = "Data Not Collected", category Productivity. The App Store listing name can't be plain "Form Filler" (uniqueness rules).

### 2026-07-18 — polish rounds 3–8
- **Round 3** — signatures (#31); new editor fields arrive with the name focused and selected (#32); reopen-exported-PDF pushes detail-then-fill and vaults the restored session immediately (#33). Known wrinkle: a reopened PDF silently overwrites an existing draft belonging to a *different* template — accepted.
- **Round 4** — practitioner profiles (#34): `PractitionerProfile`, `PractitionerStore` (`practitioners.json`, atomic), profile UI in Settings. Profiles ride in backups (add-only by ID), and `hasAnyValues` counts only user entries so an untouched form never autosaves a draft.
- Profile labels: `label` is the picker name, independent of the printed doctor name (`"<doctor> — <location>"`), with `displayLabel` falling back to the doctor name.
- **Round 5** — signature folded into profiles (#35); the app-wide `SignatureStore` survives only as the legacy fallback.
- **Round 6** — `FieldDefinition.whiteBackground: Bool?` (nil = per-type default, on for multi-line), painted only when the field has content, identically in preview and export.
- **Round 7** — editor/fill ergonomics: only the bottom-left handle (drawn red) changes height, the other three are width-only; editor labels render at the true `TextFitting` size, font and alignment the value will use; Tab hops between fields with the name selected; export filename order became `<Patient> – <Template> – <date>.pdf`; comment tool added (`AdHocMark.kind == .comment`), with tap-to-delete restricted to the same kind so a checkmark can't remove a typed comment.
- **Round 8** — styled comments via `CommentEditorSheet` (size, bold, border, white background) rendered identically in preview and export; signature fields auto-stamp with no form row and no toggle whenever the selected profile has a signature; **template sharing** through `TemplateShareService` — the template JSON rides in Keywords under `FormFillerTemplate1:`, distinct from the fill payload's `FormFiller1:`, with profiles and signatures deliberately excluded. Import offers Import Template / Import as Blank PDF.
- Comments became interactive while the Comment tool is active — drag to move, corner dot to resize, tap to edit — via `InteractiveCommentOverlay` rendered above the tool layer.
- Website (user-authorized): public repo `github.com/XbalSoftware/form-filler` with full source. The whole site is a single `docs/index.html` (quick start → user manual → privacy policy → contact, light/dark, anchored sections), and **GitHub Pages is configured as branch `main`, path `/docs`** — not the repo root. `AppLinks` points at https://xbalsoftware.github.io/form-filler/ with `#user-manual` and `#privacy-policy` anchors, and those URLs are compiled into the shipped app, so `docs/index.html` and its anchor ids must not be renamed.

### 2026-07-17 — Stages 1–6, then polish rounds 1–2
- Stages 1–5 written and confirmed in sequence: models + store → library UI → page canvas and coordinate math → editor → fill mode. Rotation math for clockwise `/Rotate` was derived as: the PDF bottom-left corner lands top-left at 90°, top-right at 180°, bottom-right at 270°.
- `PDFRenderService` is `@unchecked Sendable` — a read-only `PDFDocument` plus a thread-safe `NSCache`.
- Stage 6 export: Core Graphics vector re-render (#21). A rotated-page fit bug in `FillFieldOverlay` was found and fixed here (fit in display space, matching export).
- Stage 6 sharing reworked after the EMR rejected ShareLink's file promise: `exportToTemporaryFile()` plus an `ActivityShareSheet` popover carrying the concrete URL (#22). Temp exports live in `tmp/Exports/`, purged at launch and on leaving the fill screen — deliberately *not* on share completion, so open-in-place receivers can finish copying.
- **Polish round 1** (user-confirmed): `FillSessionPayload` + `CodableFieldValue` (the only sanctioned fill-value serialization), the `DraftStore` encrypted vault, `LibraryBackupService`, the `patientName` type feeding the export filename, the embedded reopen payload, a reworked fill screen (Print/Save/Share group, dedicated "Clear form", no discard dialog since leaving autosaves), no forced capitals, multi-line Return=newline / Tab=next-field, and library search. Decisions #23–28. From here the user owns all builds, tests and commits.
- **Polish round 2**: `AdHocMark` + `MarkGeometry` and the fill-mode Type/Checkmark/Circle tool picker (#29); library top bar rearranged with a custom centered search field and an Arrange sort menu (#30); `SettingsView` + `AboutView` (backup/restore moved here, About, Reset App); user-manual and privacy-policy docs for the GitHub site.

### 2026-07-06 — inception
Architecture finalized; `CLAUDE.md` and this file created.
