//
//  LibraryViewModel.swift
//  Form Filler
//

import Foundation
import Observation

@MainActor
@Observable
final class LibraryViewModel {
    private(set) var templates: [Template] = []
    private(set) var loadErrorMessage: String?

    private let store: TemplateStore

    init(store: TemplateStore = TemplateStore()) {
        self.store = store
    }

    /// Called when the library appears. Seeds sample content in DEBUG
    /// builds, then loads the template list.
    func onAppear() {
        #if DEBUG
        DebugSeeder.seedIfNeeded(using: store)
        #endif
        refresh()
    }

    func refresh() {
        do {
            templates = try store.loadAll()
            loadErrorMessage = nil
        } catch {
            templates = []
            loadErrorMessage = error.localizedDescription
        }
    }
}
