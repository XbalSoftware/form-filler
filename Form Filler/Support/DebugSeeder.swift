//
//  DebugSeeder.swift
//  Form Filler
//

#if DEBUG
import UIKit

/// DEBUG-only: on first launch with an empty library, generates a sample
/// referral-form PDF and seeds one template with pre-placed fields so every
/// stage of the app has something to work with. Never compiled into
/// release builds.
enum DebugSeeder {
    private static let pageSize = CGSize(width: 612, height: 792)   // US Letter, points

    static func seedIfNeeded(using store: TemplateStore) {
        guard let existing = try? store.loadAll(), existing.isEmpty else { return }
        do {
            try store.create(makeSeedTemplate(), pdfData: makeSamplePDF())
        } catch {
            assertionFailure("Debug seeding failed: \(error)")
        }
    }

    // MARK: - Layout

    // One shared layout drives both the drawn PDF and the seeded field
    // rects, so the fields land exactly on the form's boxes. Boxes are
    // specified in top-left (UIKit) coordinates for drawing and converted
    // to PDF space (bottom-left origin) for the FieldDefinitions.

    private struct Box {
        var label: String
        var fieldName: String
        var type: FieldType
        var frame: CGRect               // top-left origin, drawing space
    }

    private static let boxes: [Box] = [
        Box(label: "Patient name", fieldName: "Patient Name", type: .singleLineText,
            frame: CGRect(x: 170, y: 130, width: 300, height: 24)),
        Box(label: "Date of birth", fieldName: "Date of Birth", type: .date,
            frame: CGRect(x: 170, y: 170, width: 160, height: 24)),
        Box(label: "Referral date", fieldName: "Referral Date", type: .date,
            frame: CGRect(x: 170, y: 210, width: 160, height: 24)),
        Box(label: "Urgent", fieldName: "Urgent", type: .checkbox,
            frame: CGRect(x: 170, y: 252, width: 18, height: 18)),
        Box(label: "Reason for referral", fieldName: "Reason for Referral", type: .multiLineText,
            frame: CGRect(x: 40, y: 320, width: 532, height: 140)),
    ]

    /// Converts a top-left-origin drawing rect to PDF page point space
    /// (bottom-left origin). Local to the seeder; real conversion helpers
    /// arrive with Stage 3's CoordinateConversion.swift.
    private static func pdfRect(for frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX,
            y: pageSize.height - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    // MARK: - Seed content

    private static func makeSeedTemplate() -> Template {
        Template(
            name: "Sample Referral (Debug)",
            category: "Samples",
            fields: boxes.enumerated().map { index, box in
                FieldDefinition(
                    name: box.fieldName,
                    type: box.type,
                    pageIndex: 0,
                    rect: pdfRect(for: box.frame),
                    style: .default,
                    sortOrder: index
                )
            }
        )
    }

    private static func makeSamplePDF() -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { context in
            context.beginPage()

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Helvetica-Bold", size: 22) ?? .boldSystemFont(ofSize: 22),
                .foregroundColor: UIColor.black,
            ]
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Helvetica", size: 12) ?? .systemFont(ofSize: 12),
                .foregroundColor: UIColor.black,
            ]

            "Anytown Eye Clinic — Referral Form".draw(at: CGPoint(x: 40, y: 48), withAttributes: titleAttributes)
            "Sample form generated for DEBUG builds. Not a real document.".draw(
                at: CGPoint(x: 40, y: 82), withAttributes: labelAttributes
            )

            let stroke = context.cgContext
            stroke.setStrokeColor(UIColor.black.cgColor)
            stroke.setLineWidth(1)

            for box in boxes {
                let labelPoint: CGPoint
                if box.frame.minX > 60 {
                    // Label sits to the left of the box, vertically centered.
                    labelPoint = CGPoint(x: 40, y: box.frame.midY - 7)
                } else {
                    // Full-width box: label sits above it.
                    labelPoint = CGPoint(x: box.frame.minX, y: box.frame.minY - 20)
                }
                box.label.draw(at: labelPoint, withAttributes: labelAttributes)
                stroke.stroke(box.frame)
            }
        }
    }
}
#endif
