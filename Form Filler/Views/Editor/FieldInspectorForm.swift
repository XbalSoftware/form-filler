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
            Section("Field") {
                TextField("Name", text: binding(\.name, default: ""))
                Picker("Type", selection: binding(\.type, default: .singleLineText)) {
                    ForEach(FieldType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                if field.type == .date {
                    Picker("Date Format", selection: dateFormatBinding) {
                        ForEach(Self.dateFormatOptions, id: \.self) { format in
                            Text(Self.formatPreview(format)).tag(format)
                        }
                    }
                }
                if field.type == .staticText {
                    TextField("Static text (printed on every form)", text: staticTextBinding, axis: .vertical)
                        .lineLimit(1...3)
                }
                LabeledContent("Page", value: "\(field.pageIndex + 1)")
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

    private func binding<T>(_ keyPath: WritableKeyPath<FieldDefinition, T>, default defaultValue: T) -> Binding<T> {
        Binding(
            get: { viewModel.selectedField?[keyPath: keyPath] ?? defaultValue },
            set: { newValue in viewModel.updateSelectedField { $0[keyPath: keyPath] = newValue } }
        )
    }

    private static let dateFormatOptions = [
        "dd/MM/yyyy", "d MMM yyyy", "d MMMM yyyy", "MM/dd/yyyy", "yyyy-MM-dd",
    ]

    private static func formatPreview(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: .now)
    }

    private var dateFormatBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedField?.dateFormat ?? FieldValueFormatting.defaultDateFormat },
            set: { newValue in viewModel.updateSelectedField { $0.dateFormat = newValue } }
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
