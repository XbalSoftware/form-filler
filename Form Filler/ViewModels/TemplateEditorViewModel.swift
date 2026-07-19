//
//  TemplateEditorViewModel.swift
//  Form Filler
//
//  Owns the working copy of a template during editing. Every committed
//  mutation persists immediately to template.json via TemplateStore
//  (atomic write), so there's no separate save step to forget.
//

import Foundation
import CoreGraphics
import Observation

@MainActor
@Observable
final class TemplateEditorViewModel {
    private(set) var template: Template
    var selectedFieldID: UUID?
    var currentPageIndex = 0
    var errorMessage: String?
    /// Set when a field was just created with its default "Field n" name;
    /// the inspector consumes it to focus + select the name for instant
    /// renaming.
    private(set) var fieldAwaitingName: UUID?

    let renderService: PDFRenderService?

    private let store: TemplateStore
    private let onPersist: () -> Void

    /// Smallest allowed field size while dragging handles, in view points.
    static let minimumViewSize = CGSize(width: 16, height: 10)

    init(template: Template, store: TemplateStore, onPersist: @escaping () -> Void = {}) {
        self.template = template
        self.store = store
        self.onPersist = onPersist
        self.renderService = PDFRenderService(url: store.pdfURL(for: template))
    }

    var selectedField: FieldDefinition? {
        guard let selectedFieldID else { return nil }
        return template.fields.first { $0.id == selectedFieldID }
    }

    var orderedFields: [FieldDefinition] { template.orderedFields }

    func fields(onPage index: Int) -> [FieldDefinition] {
        template.fields.filter { $0.pageIndex == index }
    }

    // MARK: - Canvas interactions

    /// Empty-canvas tap: deselect if something is selected, otherwise
    /// create a new field centered on the tap point.
    func handleCanvasTap(at point: CGPoint, space: PageCoordinateSpace, pageSize: CGSize) {
        if selectedFieldID != nil {
            selectedFieldID = nil
        } else {
            addField(at: point, space: space, pageSize: pageSize)
        }
    }

    private func addField(at point: CGPoint, space: PageCoordinateSpace, pageSize: CGSize) {
        guard pageSize.width > 0, space.displaySize.width > 0 else { return }
        let scale = pageSize.width / space.displaySize.width
        let size = CGSize(
            width: FieldDefinition.defaultSize.width * scale,
            height: FieldDefinition.defaultSize.height * scale
        )
        let origin = CGPoint(
            x: (point.x - size.width / 2).clamped(to: 0...max(0, pageSize.width - size.width)),
            y: (point.y - size.height / 2).clamped(to: 0...max(0, pageSize.height - size.height))
        )
        let field = FieldDefinition(
            name: "Field \(template.fields.count + 1)",
            type: .singleLineText,
            pageIndex: currentPageIndex,
            rect: space.pdfRect(fromViewRect: CGRect(origin: origin, size: size), in: pageSize),
            sortOrder: nextSortOrder()
        )
        template.fields.append(field)
        selectedFieldID = field.id
        fieldAwaitingName = field.id
        persist()
    }

    /// One-shot: true (and clears the flag) if `id` was just created and
    /// its placeholder name should be selected for typing over.
    func consumeNameFocusRequest(for id: UUID) -> Bool {
        guard fieldAwaitingName == id else { return false }
        fieldAwaitingName = nil
        return true
    }

    /// Tab/Shift-Tab in the inspector's name box: selects the next or
    /// previous field in fill order with ITS name ready to type over —
    /// so a whole form can be named without leaving the detail view.
    /// Returns false at either end (the keypress falls through).
    func selectAdjacentField(offset: Int) -> Bool {
        let ordered = orderedFields
        guard let selectedFieldID,
              let index = ordered.firstIndex(where: { $0.id == selectedFieldID }),
              ordered.indices.contains(index + offset)
        else { return false }
        let field = ordered[index + offset]
        select(field)
        fieldAwaitingName = field.id
        return true
    }

    /// Commits a move or resize. The rect arrives in view space; it's
    /// clamped to the page and minimum size, then stored in PDF space.
    func setFieldRect(_ id: UUID, fromViewRect rect: CGRect, space: PageCoordinateSpace, pageSize: CGSize) {
        var adjusted = rect
        adjusted.size.width = max(adjusted.width, Self.minimumViewSize.width)
        adjusted.size.height = max(adjusted.height, Self.minimumViewSize.height)
        adjusted.origin.x = adjusted.minX.clamped(to: 0...max(0, pageSize.width - adjusted.width))
        adjusted.origin.y = adjusted.minY.clamped(to: 0...max(0, pageSize.height - adjusted.height))
        updateField(id) { $0.rect = space.pdfRect(fromViewRect: adjusted, in: pageSize) }
    }

    /// Light edge-snapping against the other fields on the current page.
    func snappedRect(for rect: CGRect, excluding id: UUID?, space: PageCoordinateSpace, pageSize: CGSize) -> CGRect {
        let others = fields(onPage: currentPageIndex)
            .filter { $0.id != id }
            .map { space.viewRect(fromPDFRect: $0.rect, in: pageSize) }
        return EdgeSnapping.snapped(rect, toEdgesOf: others)
    }

    // MARK: - Selection & list

    func select(_ field: FieldDefinition) {
        selectedFieldID = field.id
        currentPageIndex = field.pageIndex
    }

    // MARK: - Field mutations

    func updateField(_ id: UUID, _ transform: (inout FieldDefinition) -> Void) {
        guard let index = template.fields.firstIndex(where: { $0.id == id }) else { return }
        transform(&template.fields[index])
        persist()
    }

    func updateSelectedField(_ transform: (inout FieldDefinition) -> Void) {
        guard let selectedFieldID else { return }
        updateField(selectedFieldID, transform)
    }

    /// Nudges the selected field by 1pt steps in *displayed* directions —
    /// "left" means left on screen regardless of page rotation.
    func nudgeSelected(dxDisplay: CGFloat, dyDisplay: CGFloat) {
        guard let field = selectedField,
              let space = renderService?.coordinateSpace(forPage: field.pageIndex) else { return }
        let size = space.displaySize
        let moved = space.viewRect(fromPDFRect: field.rect, in: size)
            .offsetBy(dx: dxDisplay, dy: dyDisplay)
        updateField(field.id) { $0.rect = space.pdfRect(fromViewRect: moved, in: size) }
    }

    func duplicateSelected() {
        guard let field = selectedField else { return }
        let copy = FieldDefinition(
            name: field.name + " Copy",
            type: field.type,
            pageIndex: field.pageIndex,
            rect: field.rect.offsetBy(dx: 12, dy: -12),
            style: field.style,
            sortOrder: nextSortOrder()
        )
        template.fields.append(copy)
        selectedFieldID = copy.id
        persist()
    }

    func deleteSelected() {
        guard let selectedFieldID else { return }
        deleteField(id: selectedFieldID)
    }

    func deleteField(id: UUID) {
        template.fields.removeAll { $0.id == id }
        if selectedFieldID == id { selectedFieldID = nil }
        persist()
    }

    /// Delete via swipe in the ordered field list.
    func deleteFields(atOrderedOffsets offsets: IndexSet) {
        let ids = Set(offsets.map { orderedFields[$0].id })
        template.fields.removeAll { ids.contains($0.id) }
        if let selectedFieldID, ids.contains(selectedFieldID) {
            self.selectedFieldID = nil
        }
        persist()
    }

    /// Reorder in the field list; sortOrder is rewritten to match.
    /// (Same semantics as SwiftUI's `move(fromOffsets:toOffset:)`, done by
    /// hand so the ViewModel doesn't import SwiftUI: `destination` is an
    /// index into the pre-removal array.)
    func reorderFields(from source: IndexSet, to destination: Int) {
        var ordered = orderedFields
        var moved: [FieldDefinition] = []
        for index in source.sorted(by: >) {
            moved.insert(ordered.remove(at: index), at: 0)
        }
        let insertionIndex = destination - source.count(where: { $0 < destination })
        ordered.insert(contentsOf: moved, at: min(insertionIndex, ordered.count))
        for (newOrder, field) in ordered.enumerated() {
            if let index = template.fields.firstIndex(where: { $0.id == field.id }) {
                template.fields[index].sortOrder = newOrder
            }
        }
        persist()
    }

    // MARK: - Plumbing

    private func nextSortOrder() -> Int {
        (template.fields.map(\.sortOrder).max() ?? -1) + 1
    }

    private func persist() {
        template.modifiedAt = .now
        do {
            try store.save(template)
        } catch {
            errorMessage = "Couldn't save changes: \(error.localizedDescription)"
        }
        onPersist()
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
