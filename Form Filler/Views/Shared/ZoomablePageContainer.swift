//
//  ZoomablePageContainer.swift
//  Form Filler
//
//  Our own pinch-zoom/pan container (CLAUDE.md invariant #4 — no PDFView).
//  A UIScrollView hosts SwiftUI content (page image + overlays) laid out at
//  `contentSize`; the scroll view's zoom transform scales everything
//  together, so overlays stay glued to the page.
//

import SwiftUI
import UIKit

struct ZoomablePageContainer<Content: View>: UIViewRepresentable {
    /// Base (zoom = 1) size of the hosted content, in view points.
    let contentSize: CGSize
    var maximumZoom: CGFloat = 6
    /// Called when a zoom gesture settles — the cue to re-render the page
    /// image at a sharper scale.
    var onStableZoomChange: ((CGFloat) -> Void)?
    @ViewBuilder let content: () -> Content

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = maximumZoom
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear

        let hosting = UIHostingController(rootView: AnyView(content()))
        hosting.view.backgroundColor = .clear
        hosting.view.frame = CGRect(origin: .zero, size: contentSize)
        scrollView.addSubview(hosting.view)
        scrollView.contentSize = contentSize

        context.coordinator.hostingController = hosting
        context.coordinator.onStableZoomChange = onStableZoomChange
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let hosting = context.coordinator.hostingController else { return }
        hosting.rootView = AnyView(content())
        context.coordinator.onStableZoomChange = onStableZoomChange
        scrollView.maximumZoomScale = maximumZoom

        // Page switch or rotation/layout change: reset zoom and relayout.
        if hosting.view.bounds.size != contentSize {
            scrollView.zoomScale = 1
            hosting.view.frame = CGRect(origin: .zero, size: contentSize)
            scrollView.contentSize = contentSize
        }
        DispatchQueue.main.async {
            context.coordinator.centerContent(in: scrollView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<AnyView>?
        var onStableZoomChange: ((CGFloat) -> Void)?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController?.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent(in: scrollView)
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            onStableZoomChange?(scale)
        }

        /// Keeps content centered when it's smaller than the viewport.
        func centerContent(in scrollView: UIScrollView) {
            guard let contentView = hostingController?.view else { return }
            let bounds = scrollView.bounds.size
            let frame = contentView.frame
            let insetX = max((bounds.width - frame.width) / 2, 0)
            let insetY = max((bounds.height - frame.height) / 2, 0)
            scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
        }
    }
}
