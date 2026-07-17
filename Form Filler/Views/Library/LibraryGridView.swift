//
//  LibraryGridView.swift
//  Form Filler
//

import SwiftUI

struct LibraryGridView: View {
    let templates: [Template]
    let thumbnails: [UUID: UIImage]
    let onEditDetails: (Template) -> Void
    let onDuplicate: (Template) -> Void
    let onDelete: (Template) -> Void

    private let columns = [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 24)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(templates) { template in
                    NavigationLink(value: template.id) {
                        TemplateCardView(template: template, thumbnail: thumbnails[template.id])
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Edit Details", systemImage: "pencil") {
                            onEditDetails(template)
                        }
                        Button("Duplicate", systemImage: "plus.square.on.square") {
                            onDuplicate(template)
                        }
                        Divider()
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            onDelete(template)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}
