//
//  LibrarySortOrder.swift
//  Form Filler
//
//  How the library grid is arranged. Persisted via @AppStorage (String
//  raw values), so renaming a case would silently reset users' choice —
//  don't.
//

import Foundation

nonisolated enum LibrarySortOrder: String, CaseIterable {
    case recentlyModified
    case name
    case recentlyAdded

    var displayName: String {
        switch self {
        case .recentlyModified: "Recently Modified"
        case .name: "Name"
        case .recentlyAdded: "Recently Added"
        }
    }

    func sorted(_ templates: [Template]) -> [Template] {
        switch self {
        case .recentlyModified:
            templates.sorted { $0.modifiedAt > $1.modifiedAt }
        case .name:
            templates.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .recentlyAdded:
            templates.sorted { $0.createdAt > $1.createdAt }
        }
    }
}
