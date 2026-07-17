//
//  EdgeSnapping.swift
//  Form Filler
//

import CoreGraphics

/// Light edge-snapping for the editor: nudges a dragged rect so its edges
/// align with nearby edges of other fields. Pure geometry, view-space.
nonisolated enum EdgeSnapping {
    /// Returns `rect` offset by at most `tolerance` on each axis so that
    /// one of its vertical edges meets another rect's vertical edge (and
    /// likewise horizontally). The nearest qualifying edge wins; axes snap
    /// independently.
    static func snapped(_ rect: CGRect, toEdgesOf others: [CGRect], tolerance: CGFloat = 6) -> CGRect {
        var bestDX: CGFloat?
        var bestDY: CGFloat?

        for other in others {
            for candidate in [rect.minX, rect.maxX] {
                for target in [other.minX, other.maxX] {
                    let delta = target - candidate
                    if abs(delta) <= tolerance, abs(delta) < abs(bestDX ?? .greatestFiniteMagnitude) {
                        bestDX = delta
                    }
                }
            }
            for candidate in [rect.minY, rect.maxY] {
                for target in [other.minY, other.maxY] {
                    let delta = target - candidate
                    if abs(delta) <= tolerance, abs(delta) < abs(bestDY ?? .greatestFiniteMagnitude) {
                        bestDY = delta
                    }
                }
            }
        }
        return rect.offsetBy(dx: bestDX ?? 0, dy: bestDY ?? 0)
    }
}
