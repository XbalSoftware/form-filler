//
//  PractitionerProfilesView.swift
//  Form Filler
//
//  Settings sub-page: manage the practitioner profiles that auto-populate
//  the practitioner field types (doctor name, office address/fax/phone,
//  email, practitioner ID). Multiple profiles allowed; the fill screen
//  offers a picker when more than one exists.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PractitionerProfilesView: View {
    @State private var profiles: [PractitionerProfile] = []
    @State private var profileBeingEdited: PractitionerProfile?
    @State private var isAddingProfile = false
    @State private var saveError: String?

    private let store = PractitionerStore()

    var body: some View {
        List {
            Section {
                ForEach(profiles) { profile in
                    Button {
                        profileBeingEdited = profile
                    } label: {
                        row(for: profile)
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete { offsets in
                    profiles.remove(atOffsets: offsets)
                    persist()
                }
            } footer: {
                Text("Profiles fill the practitioner field types (Doctor Name, Office Address, Office Fax, Office Phone, Email, Practitioner ID) automatically when filling a form. Profiles are included in library backups.")
            }
        }
        .overlay {
            if profiles.isEmpty {
                ContentUnavailableView(
                    "No Profiles",
                    systemImage: "person.badge.plus",
                    description: Text("Add a practitioner profile to auto-fill your details on forms.")
                )
            }
        }
        .navigationTitle("Practitioner Profiles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Add Profile", systemImage: "plus") { isAddingProfile = true }
        }
        .sheet(isPresented: $isAddingProfile) {
            PractitionerProfileForm(profile: PractitionerProfile(), title: "New Profile") { saved in
                profiles.append(saved)
                persist()
            }
        }
        .sheet(item: $profileBeingEdited) { profile in
            PractitionerProfileForm(profile: profile, title: "Edit Profile") { saved in
                if let index = profiles.firstIndex(where: { $0.id == saved.id }) {
                    profiles[index] = saved
                    persist()
                }
            }
        }
        .alert(
            "Couldn't Save Profiles",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
        .onAppear { profiles = store.load() }
    }

    private func row(for profile: PractitionerProfile) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(profile.displayLabel)
            if let subtitle = subtitle(for: profile) {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The doctor name when a distinct label hides it; otherwise the ID.
    private func subtitle(for profile: PractitionerProfile) -> String? {
        if !profile.label.isEmpty && !profile.name.isEmpty && profile.label != profile.name {
            return profile.name
        }
        return profile.practitionerID.isEmpty ? nil : profile.practitionerID
    }

    private func persist() {
        do {
            try store.save(profiles)
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct PractitionerProfileForm: View {
    @State var profile: PractitionerProfile
    let title: String
    let onSave: (PractitionerProfile) -> Void

    @State private var isDrawingSignature = false
    @State private var isPickingSignatureImage = false
    @State private var signatureError: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Profile name (optional)", text: $profile.label)
                } footer: {
                    Text("How this profile appears in lists and the fill-screen picker — handy when one doctor has a profile per location, e.g. \"Dr Smith — Downtown\". Leave blank to use the doctor name.")
                }
                Section {
                    TextField("Doctor name", text: $profile.name)
                        .textContentType(.name)
                    TextField("Practitioner ID", text: $profile.practitionerID)
                        .textInputAutocapitalization(.characters)
                }
                Section("Office") {
                    TextField("Address", text: $profile.officeAddress, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Phone", text: $profile.officePhone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    TextField("Fax", text: $profile.officeFax)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $profile.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                signatureSection
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(profile)
                        dismiss()
                    }
                    .disabled(profile.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .fileImporter(
                isPresented: $isPickingSignatureImage,
                allowedContentTypes: [.png, .jpeg]
            ) { result in
                if case .success(let url) = result {
                    importSignature(from: url)
                }
            }
            .sheet(isPresented: $isDrawingSignature) {
                SignatureDrawingView { data in
                    setSignature(data)
                }
            }
            .alert(
                "Couldn't Save Signature",
                isPresented: Binding(
                    get: { signatureError != nil },
                    set: { if !$0 { signatureError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(signatureError ?? "")
            }
        }
    }

    private var signatureSection: some View {
        Section {
            if let image = profile.signatureImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 80)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            Button("Draw Signature…", systemImage: "signature") {
                isDrawingSignature = true
            }
            Button("Import from Image File…", systemImage: "photo") {
                isPickingSignatureImage = true
            }
            if profile.signatureBase64 != nil {
                Button("Remove Signature", role: .destructive) {
                    profile.signatureBase64 = nil
                }
            }
        } header: {
            Text("Signature")
        } footer: {
            Text("Stamped by Signature fields when this profile is selected. PNG with transparency works best for imports.")
        }
    }

    /// Validates the bytes decode as an image before attaching them.
    private func setSignature(_ data: Data) {
        guard UIImage(data: data) != nil else {
            signatureError = "That file isn't a readable PNG or JPEG image."
            return
        }
        profile.signatureBase64 = data.base64EncodedString()
    }

    private func importSignature(from url: URL) {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            signatureError = "Couldn't read the selected file."
            return
        }
        setSignature(data)
    }
}
