//
//  PageCanvasView.swift
//  Form Filler
//
//  Displays one PDF page, zoomable, with a SwiftUI overlay layer. The
//  overlay closure receives the page's coordinate space and the base
//  (zoom = 1) displayed size — everything it needs to position field
//  overlays via PageCoordinateSpace. Foundation for the editor (Stage 4)
//  and fill preview (Stage 5).
//

import SwiftUI

struct PageCanvasView<Overlay: View>: View {
    let renderService: PDFRenderService
    let pageIndex: Int
    var panRequiresTwoTouches: Bool = false
    @ViewBuilder var overlay: (_ space: PageCoordinateSpace, _ pageSize: CGSize) -> Overlay

    @Environment(\.displayScale) private var displayScale
    @State private var pageImage: UIImage?
    @State private var stableZoom: CGFloat = 1

    private struct RenderRequest: Hashable {
        let pageIndex: Int
        let fittedWidth: CGFloat
        let zoom: CGFloat
    }

    var body: some View {
        GeometryReader { geometry in
            if let space = renderService.coordinateSpace(forPage: pageIndex) {
                let fitted = fittedSize(for: space.displaySize, in: geometry.size)
                ZoomablePageContainer(
                    contentSize: fitted,
                    panRequiresTwoTouches: panRequiresTwoTouches,
                    onStableZoomChange: { stableZoom = $0 }
                ) {
                    ZStack(alignment: .topLeading) {
                        pageImageView
                        overlay(space, fitted)
                    }
                    .frame(width: fitted.width, height: fitted.height)
                }
                .task(id: RenderRequest(pageIndex: pageIndex, fittedWidth: fitted.width, zoom: stableZoom)) {
                    guard space.displaySize.width > 0, fitted.width > 0 else { return }
                    let scale = fitted.width / space.displaySize.width * displayScale * stableZoom
                    if let image = await renderService.image(forPage: pageIndex, scale: scale) {
                        pageImage = image
                    }
                }
            } else {
                ContentUnavailableView("Couldn't Load Page", systemImage: "exclamationmark.triangle")
            }
        }
        .onChange(of: pageIndex) {
            pageImage = nil
            stableZoom = 1
        }
    }

    @ViewBuilder
    private var pageImageView: some View {
        if let pageImage {
            Image(uiImage: pageImage)
                .resizable()
                .background(.white)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 1)
        } else {
            Rectangle()
                .fill(.quaternary.opacity(0.4))
                .overlay(ProgressView())
        }
    }

    private func fittedSize(for pageSize: CGSize, in available: CGSize) -> CGSize {
        guard pageSize.width > 0, pageSize.height > 0,
              available.width > 0, available.height > 0 else { return .zero }
        let scale = min(available.width / pageSize.width, available.height / pageSize.height)
        return CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
    }
}

extension PageCanvasView where Overlay == EmptyView {
    init(renderService: PDFRenderService, pageIndex: Int) {
        self.init(renderService: renderService, pageIndex: pageIndex) { _, _ in EmptyView() }
    }
}
