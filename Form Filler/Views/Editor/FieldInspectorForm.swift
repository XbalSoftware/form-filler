//
//  FieldInspectorForm.swift
//  Form Filler
//
//  Inspector state when a field is selected: name, type, text style,
//  nudge controls, duplicate and delete.
//

import SwiftUI

struct FieldInspectorForm: View {
    let viewModel: TemplateEditorViewModel

    @FocusState private var isNameFieldFocused: Bool
    @State private var nameSelection: TextSelection?
    /// Holds keyboard focus for self-labeling fields (which have no name
    /// box), so Tab can still cycle field selection through them.
    @FocusState private var isTabCatcherFocused: Bool

    /// PDF-safe fonts only; the export renderer draws with these same names.
    private static let fontOptions: [(label: String, name: String)] = [
        ("Helvetica", "Helvetica"),
        ("Helvetica Bold", "Helvetica-Bold"),
        ("Helvetica Oblique", "Helvetica-Oblique"),
        ("Times New Roman", "TimesNewRomanPSMT"),
        ("Courier", "Courier"),
    ]

    var body: some View {
        if let field = viewModel.selectedField {
            form(for: field)
        }
    }

    private func form(for field: FieldDefinition) -> some View {
        Form {
            Section {
                Button {
                    viewModel.selectedFieldID = nil
                } label: {
                    Label("All Fields", systemImage: "chevron.backward")
                }
            }
            Section {
                // Self-labeling types (patient/practitioner/signature) are
                // named after their type, so the name box is redundant and
                // hidden. Generic types keep it — a just-created (or
                // tabbed-to) field arrives with its name focused and fully
                // selected, so typing replaces it.
                if !field.type.isSelfLabeling {
                    TextField("Name", text: binding(\.name, default: ""), selection: $nameSelection)
                        .focused($isNameFieldFocused)
                        .onKeyPress(.tab, phases: .down) { press in
                            moveSelection(backward: press.modifiers.contains(.shift))
                        }
                        .onAppear { highlightNameIfNewField() }
                        .onChange(of: viewModel.selectedFieldID) { _, _ in highlightNameIfNewField() }
                } else {
                    // Self-labeling types have no name box; this invisible
                    // focusable row receives Tab so field-to-field cycling
                    // still works when one of them is selected.
                    Color.clear
                        .frame(height: 1)
                        .focusable()
                        .focusEffectDisabled()
                        .focused($isTabCatcherFocused)
                        .onKeyPress(.tab, phases: .down) { press in
                            moveSelection(backward: press.modifiers.contains(.shift))
                        }
                        .listRowInsets(EdgeInsets())
                        .accessibilityHidden(true)
                }
                // Grouped for easier navigation: general text, then patient
                // details, then referring-clinic details. Headerless sections
                // render as divided groups in the menu.
                Picker("Type", selection: typeBinding) {
                    Section { typeRows(Self.generalTypes) }
                    Section { typeRows(Self.patientTypes) }
                    Section("Exam Findings") { typeRows(Self.examTypes) }
                    Section { typeRows(Self.clinicTypes) }
                }
                if field.type == .staticText {
                    TextField("Static text (printed on every form)", text: staticTextBinding, axis: .vertical)
                        .lineLimit(1...3)
                }
                LabeledContent("Page", value: "\(field.pageIndex + 1)")
            } header: {
                Text("Field")
            } footer: {
                if field.type == .patientName {
                    Text("The patient's name feeds the exported PDF's file name. Add more than one (e.g. on each page) and they share the same value.")
                } else if field.type.isPractitionerField {
                    Text("Auto-filled from the selected practitioner profile (Settings → Practitioner Profiles) when filling.")
                } else if field.type.isPatientField {
                    Text("A patient detail. Type it while filling, or fill it automatically from an imported patient PDF.")
                }
            }
            Section("Text Style") {
                Picker("Font", selection: binding(\.style.fontName, default: "Helvetica")) {
                    ForEach(Self.fontOptions, id: \.name) { option in
                        Text(option.label).tag(option.name)
                    }
                }
                Stepper(
                    "Size: \(Int(field.style.fontSize)) pt",
                    value: binding(\.style.fontSize, default: 12),
                    in: 6...36,
                    step: 1
                )
                Picker("Alignment", selection: binding(\.style.alignment, default: .leading)) {
                    Text("Left").tag(TextAlignmentOption.leading)
                    Text("Center").tag(TextAlignmentOption.center)
                    Text("Right").tag(TextAlignmentOption.trailing)
                }
                .pickerStyle(.segmented)
                ColorPicker("Color", selection: colorBinding, supportsOpacity: false)
                Toggle("White Background", isOn: whiteBackgroundBinding)
            }
            Section("Position") {
                LabeledContent("Frame") {
                    Text(String(
                        format: "x %.0f  y %.0f  w %.0f × h %.0f",
                        field.rect.minX, field.rect.minY, field.rect.width, field.rect.height
                    ))
                    .font(.caption.monospacedDigit())
                }
                LabeledContent("Nudge") {
                    HStack(spacing: 6) {
                        nudgeButton("arrow.left", dx: -1, dy: 0)
                        nudgeButton("arrow.up", dx: 0, dy: -1)
                        nudgeButton("arrow.down", dx: 0, dy: 1)
                        nudgeButton("arrow.right", dx: 1, dy: 0)
                    }
                }
            }
            Section {
                Button("Duplicate Field", systemImage: "plus.square.on.square") {
                    viewModel.duplicateSelected()
                }
                Button("Delete Field", systemImage: "trash", role: .destructive) {
                    viewModel.deleteSelected()
                }
            }
        }
        .onAppear { focusTabCatcherIfNeeded() }
        .onChange(of: viewModel.selectedFieldID) { _, _ in focusTabCatcherIfNeeded() }
    }

    /// Tab / Shift-Tab: select the adjacent field in fill order. Handled
    /// when a move happened; otherwise ignored so the key can fall through
    /// at the ends.
    private func moveSelection(backward: Bool) -> KeyPress.Result {
        viewModel.selectAdjacentField(offset: backward ? -1 : 1) ? .handled : .ignored
    }

    /// When a self-labeling field (no name box) is selected, park keyboard
    /// focus on its hidden Tab-catcher so Tab keeps cycling fields. Named
    /// fields focus their name box via highlightNameIfNewField instead.
    private func focusTabCatcherIfNeeded() {
        guard viewModel.selectedField?.type.isSelfLabeling == true else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            guard viewModel.selectedField?.type.isSelfLabeling == true else { return }
            isTabCatcherFocused = true
        }
    }

    private func highlightNameIfNewField() {
        guard let id = viewModel.selectedFieldID,
              viewModel.consumeNameFocusRequest(for: id)
        else { return }
        isNameFieldFocused = true
        // Select-all must land AFTER the field becomes first responder —
        // set immediately, the platform resets the caret to the end.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            guard let name = viewModel.selectedField?.name, !name.isEmpty else { return }
            nameSelection = TextSelection(range: name.startIndex..<name.endIndex)
        }
    }

    // Type-picker groups, in menu order.
    private static let generalTypes: [FieldType] = [.singleLineText, .multiLineText, .staticText, .referralDate]
    private static let patientTypes: [FieldType] = [
        .patientName, .patientDateOfBirth, .patientPhone, .patientHealthcareNumber, .patientAddress,
    ]
    private static let examTypes: [FieldType] = [
        .patientRefractionOD, .patientRefractionOS,
        .patientVisualAcuityOD, .patientVisualAcuityOS,
        .patientKeratometryOD, .patientKeratometryOS,
        .patientIntraocularPressureOD, .patientIntraocularPressureOS,
    ]
    private static let clinicTypes: [FieldType] = [
        .doctorName, .officeAddress, .officeEmail, .officePhone, .officeFax, .practitionerID, .signature,
    ]

    @ViewBuilder
    private func typeRows(_ types: [FieldType]) -> some View {
        ForEach(types, id: \.self) { type in
            Text(type.displayName).tag(type)
        }
    }

    private func nudgeButton(_ systemImage: String, dx: CGFloat, dy: CGFloat) -> some View {
        Button {
            viewModel.nudgeSelected(dxDisplay: dx, dyDisplay: dy)
        } label: {
            Image(systemName: systemImage)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    /// Type changes route through the VM so self-labeling types can rename
    /// the field to match (see setSelectedFieldType).
    private var typeBinding: Binding<FieldType> {
        Binding(
            get: { viewModel.selectedField?.type ?? .singleLineText },
            set: { newType in viewModel.setSelectedFieldType(newType) }
        )
    }

    private func binding<T>(_ keyPath: WritableKeyPath<FieldDefinition, T>, default defaultValue: T) -> Binding<T> {
        Binding(
            get: { viewModel.selectedField?[keyPath: keyPath] ?? defaultValue },
            set: { newValue in viewModel.updateSelectedField { $0[keyPath: keyPath] = newValue } }
        )
    }

    private var staticTextBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedField?.staticText ?? "" },
            set: { newValue in
                viewModel.updateSelectedField { $0.staticText = newValue.isEmpty ? nil : newValue }
            }
        )
    }

    /// Resolved default (on for multi-line) until the user chooses
    /// explicitly; the explicit choice then sticks across type changes.
    private var whiteBackgroundBinding: Binding<Bool> {
        Binding(
            get: { viewModel.selectedField?.fillsWhiteBackground ?? false },
            set: { newValue in viewModel.updateSelectedField { $0.whiteBackground = newValue } }
        )
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { ColorHex.color(from: viewModel.selectedField?.style.colorHex ?? "#000000") ?? .black },
            set: { newColor in
                guard let hex = ColorHex.hex(from: newColor) else { return }
                viewModel.updateSelectedField { $0.style.colorHex = hex }
            }
        )
    }
}
