//
//  TemplateCardView.swift
//  Form Filler
//

import SwiftUI

struct TemplateCardView: View {
    let template: Template
    let thumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnailArea
            Text(template.name)
                .font(.headline)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var thumbnailArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary.opacity(0.5))
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            } else {
                Image(systemName: "doc.text")
                    .font(.system(size: 44))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: 210)
    }

    private var subtitle: String {
        let fieldCount = "\(template.fields.count) field\(template.fields.count == 1 ? "" : "s")"
        if let category = template.category {
            return "\(category) · \(fieldCount)"
        }
        return fieldCount
    }
}
