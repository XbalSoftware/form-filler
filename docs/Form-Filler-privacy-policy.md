# Form Filler — Privacy Policy

_Last updated: 17 July 2026_

Form Filler is an iPad app for templating and filling PDF referral forms. It is designed so that your data — and in particular your patients' data — stays under your control on your device.

## The short version

- Form Filler makes **no network connections**. Nothing you do in the app is transmitted anywhere.
- There are **no accounts, no analytics, no tracking, and no third-party services**.
- Patient information exists only in three places, all controlled by you: the current fill session, an **encrypted draft on the device**, and the **PDF files you explicitly export**.

## What the app stores

**Templates** (the imported blank forms and their field layouts) are stored in the app's private storage on your iPad. Templates contain no patient information. They are included in normal device backups, and in any library backup file you choose to create.

**Fill-session drafts.** While you fill a form, your entries are automatically saved to a single draft so they survive leaving the screen or quitting the app. This draft is:

- encrypted (AES-GCM) with a key held in the device Keychain, restricted to this device only;
- **excluded from iCloud and computer backups** — it can never leave the iPad;
- deleted when you use **Clear form**, choose **Start Fresh** at the resume prompt, or **Reset App**.

**Exported PDFs.** A PDF you export contains the completed form, and additionally carries an invisible copy of the entry data so the app can reopen it for editing later. This embedded data contains the **same information that is visibly printed on the form** — no more — so sharing the PDF discloses nothing beyond the document itself. Where you send exported PDFs, and how long you keep them, is entirely up to you.

**Practitioner profiles.** Your own professional details (name, office address, fax, phone, email, practitioner ID) and each profile's signature image are stored on the device to auto-fill practitioner and signature fields on forms, and are included in library backups. They are your information, not patient data; a signature appears on a form only when you explicitly toggle a signature field.

**Library backups.** A backup file you create from Settings contains your templates, their blank PDFs, your signature image, and your practitioner profiles — never patient data or drafts.

## What the app never does

- It never modifies your original imported PDFs.
- It never sends data over the network.
- It never stores patient information outside the encrypted draft and the PDFs you export.
- It never shares anything with third parties.

## Your responsibilities

Exported PDFs contain patient health information. Handle them according to your professional and legal obligations (e.g. your local health-privacy legislation). Form Filler's job is to ensure the only copies that exist are the ones you deliberately create.

## Contact

Questions about this policy can be raised via the project's GitHub repository issues page.
