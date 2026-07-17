//
//  PageStripView.swift
//  Form Filler
//
//  Horizontal page-thumbnail strip for multi-page templates.
//

import SwiftUI

struct PageStripView: View {
    let renderService: PDFRenderService
    @Binding var selectedPage: Int

    @State private var thumbnails: [Int: UIImage] = [:]

    private static let thumbnailHeight: CGFloat = 68

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(0..<renderService.pageCount, id: \.self) { index in
                    pageCell(index)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(height: Self.thumbnailHeight + 36)
    }

    private func pageCell(_ index: Int) -> some View {
        Button {
            selectedPage = index
        } label: {
            VStack(spacing: 4) {
                thumbnail(for: index)
                    .frame(height: Self.thumbnailHeight)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(
                                index == selectedPage ? Color.accentColor : .secondary.opacity(0.3),
                                lineWidth: index == selectedPage ? 2 : 1
                            )
                    }
                Text("\(index + 1)")
                    .font(.caption2)
                    .foregroundStyle(index == selectedPage ? Color.accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
        .task {
            guard thumbnails[index] == nil,
                  let space = renderService.coordinateSpace(forPage: index),
                  space.displaySize.height > 0 else { return }
            let scale = (Self.thumbnailHeight * 2) / space.displaySize.height
            thumbnails[index] = await renderService.image(forPage: index, scale: scale)
        }
    }

    @ViewBuilder
    private func thumbnail(for index: Int) -> some View {
        if let image = thumbnails[index] {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary.opacity(0.4))
                .aspectRatio(0.77, contentMode: .fit)
        }
    }
}
