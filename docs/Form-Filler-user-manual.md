# Form Filler — User Manual

Form Filler is an iPad app for templating PDF referral forms. Import a form once, mark where its fields are, then fill it out and export a completed PDF as often as you like. The original PDF is never modified, and everything stays on your iPad.

---

## The Library

The library is the home screen — a grid of your templates.

- **Import a form**: tap **＋** (top right), pick a PDF, give it a name and optional category.
- **Search**: use the search field in the centre of the top bar. It matches template names and categories.
- **Arrange**: the ↑↓ button chooses the order — Recently Modified, Name, or Recently Added.
- **Template actions**: long-press a card for Edit Details (rename / category), Duplicate, or Delete.
- **Reopen Exported PDF** (top left): open a PDF previously exported by Form Filler to continue or correct it — see [Reopening an exported PDF](#reopening-an-exported-pdf).
- **Settings** (gear): backup, restore, About, and Reset App.

## Setting up a template (the editor)

Open a template and tap **Edit Template**.

- **Tap** an empty spot on the page to add a field. **Drag** to move it; drag the corner handles to resize. Each box shows its field name in small grey print so you always know which is which.
- **Two fingers** pan and zoom the page.
- The inspector (right column) lists fields in fill order — tap one to edit its name, type, font, size, alignment, colour, and date format; use Reorder to change fill order.
- Nudge arrows move the selected field one point at a time.

### Field types

| Type | Behaviour |
|---|---|
| Single-line Text | One line, auto-shrinks to fit the box |
| Multi-line Text | Wraps and supports carriage returns; fills its box white behind your answer (hides ruled lines — toggleable per field) |
| Date | Filled with a date picker; per-field date format |
| Checkbox | Tap to toggle; prints an X |
| Static Text | Fixed text printed on every copy (e.g. your provider number) |
| Patient Name | Like single-line text, but its value is also added to the exported file's name. One per form. |
| Signature | Stamps your stored signature (see below); toggled on per form |
| Doctor Name, Office Address, Office Fax, Office Phone, Email, Practitioner ID | Auto-filled from your practitioner profile (see below); never typed per form |

## Practitioner profiles

Enter your own details once in **Settings → Practitioner Profiles** — doctor name, office address, fax, phone, email, and practitioner ID. Place the matching field types on your templates and they fill themselves on every form. You can keep several profiles (multiple practitioners, multiple locations); when a template uses practitioner fields and more than one profile exists, a picker at the top of the fill form chooses which one to use. Each profile can have its own name separate from the doctor name — so one doctor practising at two locations keeps, say, "Dr Smith — Downtown" and "Dr Smith — Northside". Profiles are included in library backups.

## Your signature

Each practitioner profile carries its own signature: in **Settings → Practitioner Profiles**, open a profile and draw the signature with a finger or Apple Pencil, or import a PNG/JPEG (a PNG with a transparent background works best). Place **Signature** fields on any template that needs signing; while filling, flip the field's toggle (or tap its box on the preview) to stamp the selected profile's signature, scaled to fit — switching profile switches the signature. Signatures live inside the profiles, so they're included in library backups automatically.

## Filling a form

Open a template and tap **Fill Form**. The form list is on the left; a live preview is on the right.

- **Keyboard flow**: Tab (or the ▲/▼ toolbar buttons) moves between fields. In multi-line fields, Return starts a new line and Tab still moves on. Nothing is auto-capitalised.
- **Tap the preview** to jump to a field, toggle a checkbox, or focus a text box.
- **Checkmark and circle tools**: above the preview, switch from **Type** to **Checkmark** (tap the form to stamp a tick — for ticking boxes printed on the form itself, no template field needed) or **Circle** (drag to ring an item). Tap any mark to remove it.
- **Drafts**: your entries autosave every few seconds to an encrypted draft that never leaves the iPad. You can leave the screen — even go adjust the template — and pick up where you left off; you'll be offered **Resume** when you return. **Clear form** (top left) erases the entries and the draft.

## Exporting

The blue buttons at the top right:

- **Share** — send the finished PDF anywhere (AirDrop, EMR, email…).
- **Save** — save a copy into the Files app.
- **Print** — print directly.

The file is named `Template – Patient Name – Date.pdf` (the patient segment appears when the form has a Patient Name field).

## Reopening an exported PDF

Every PDF Form Filler exports invisibly carries its own entry data. **Reopen Exported PDF** (library, top left) opens such a file straight back into the fill screen with every value, date, tick, and circle restored — useful for "same referral as last year" or fixing a typo after the fact.

Reopening also saves the restored entries to the on-device draft straight away, so you can hop out — say, to add a missing field in the template editor — and resume without losing anything.

Notes:

- Only PDFs exported by Form Filler can be reopened, and the matching template must still be in your library.
- Another app that rewrites the PDF may strip the hidden data.
- The data inside is the same information visible on the page — sharing the PDF shares no more than what's printed on it.

## Backup & restore

**Settings → Back Up Library…** writes one file containing every template — the field layouts *and* the original PDFs — which can rebuild your library from scratch on a new iPad or after a reset. Store it anywhere; backups contain no patient data.

**Settings → Restore from Backup…** imports a backup file. Templates already in the library are left untouched; missing ones are recreated.

## Reset App

**Settings → Reset App…** permanently erases all templates, imported PDFs, and the saved fill draft. Back up first.

## Privacy at a glance

- No accounts, no analytics, no network access.
- Patient data exists only in your current fill session, its encrypted on-device draft, and the PDFs you explicitly export.
- The draft is AES-encrypted, excluded from iCloud/computer backups, and readable only on the iPad that wrote it.

See the [Privacy Policy](Form-Filler-privacy-policy.md) for the full statement.
