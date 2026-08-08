//
//  SignatureDrawingView.swift
//  Form Filler
//
//  Sign with a finger or Apple Pencil. Strokes are rendered to a
//  transparent PNG so the signature overlays form artwork cleanly.
//

import SwiftUI
import UIKit

struct SignatureDrawingView: View {
    /// Receives the rendered PNG data on Save.
    let onSave: (Data) -> Void

    @State private var strokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []
    @State private var canvasSize: CGSize = .zero

    @Environment(\.dismiss) private var dismiss

    private static let lineWidth: CGFloat = 3

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                drawingCanvas
                Text("Sign above with your finger or Apple Pencil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Draw Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") {
                        strokes.removeAll()
                        currentStroke.removeAll()
                    }
                    .disabled(strokes.isEmpty && currentStroke.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let data = renderPNG() {
                            onSave(data)
                        }
                        dismiss()
                    }
                    .disabled(strokes.isEmpty)
                }
            }
        }
    }

    private var drawingCanvas: some View {
        GeometryReader { geometry in
            Canvas { context, _ in
                for stroke in strokes + [currentStroke] {
                    context.stroke(
                        path(for: stroke),
                        with: .color(.black),
                        style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.separator, lineWidth: 1)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in currentStroke.append(value.location) }
                    .onEnded { _ in
                        if !currentStroke.isEmpty {
                            strokes.append(currentStroke)
                            currentStroke.removeAll()
                        }
                    }
            )
            .onAppear { canvasSize = geometry.size }
            .onChange(of: geometry.size) { _, newSize in canvasSize = newSize }
        }
        .frame(maxHeight: 320)
    }

    private func path(for stroke: [CGPoint]) -> Path {
        var path = Path()
        guard let first = stroke.first else { return path }
        path.move(to: first)
        if stroke.count == 1 {
            path.addLine(to: first)   // a dot
        } else {
            for point in stroke.dropFirst() {
                path.addLine(to: point)
            }
        }
        return path
    }

    /// Renders the strokes cropped to their bounding box (plus padding)
    /// on a transparent background.
    private func renderPNG() -> Data? {
        let points = strokes.flatMap(\.self)
        guard !points.isEmpty else { return nil }
        let padding = Self.lineWidth * 2
        let minX = points.map(\.x).min()! - padding
        let minY = points.map(\.y).min()! - padding
        let maxX = points.map(\.x).max()! + padding
        let maxY = points.map(\.y).max()! + padding
        let bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
        let image = renderer.image { context in
            let ctx = context.cgContext
            ctx.translateBy(x: -bounds.minX, y: -bounds.minY)
            ctx.setStrokeColor(UIColor.black.cgColor)
            ctx.setLineWidth(Self.lineWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            for stroke in strokes {
                ctx.addPath(path(for: stroke).cgPath)
                ctx.strokePath()
            }
        }
        return image.pngData()
    }
}
