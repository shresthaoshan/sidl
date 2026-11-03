import SwiftUI

/// The trackpad surface, with a dot and an "x, y" label for each finger.
/// The size is fixed, so fingers coming and going never move the rest of the panel.
struct TrackpadView: View {
    let touches: [Touch]

    static let dotSize: CGFloat = 24
    static let labelSize = CGSize(width: 74, height: 16)

    var body: some View {
        GeometryReader { geo in
            let placed = Self.layout(touches, in: geo.size)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10).stroke(.secondary)
                ForEach(placed, id: \.touch.id) { p in
                    Circle()
                        .fill(p.touch.state == 4 ? Color.accentColor : .gray)
                        .frame(width: Self.dotSize, height: Self.dotSize)
                        .position(p.dot)
                }
                // Labels after all dots, so a label is never hidden under another finger's dot.
                ForEach(placed, id: \.touch.id) { p in
                    Text(String(format: "%.2f, %.2f", p.touch.x, p.touch.y))
                        .font(.caption2.monospacedDigit())
                        .frame(width: Self.labelSize.width, height: Self.labelSize.height)
                        .background(Capsule().fill(Color(nsColor: .textBackgroundColor)))
                        .overlay(Capsule().stroke(.secondary.opacity(0.5)))
                        .position(p.label)
                }
            }
        }
        .aspectRatio(1.6, contentMode: .fit)
    }

    struct Placement {
        let touch: Touch
        let dot: CGPoint
        let label: CGPoint
    }

    /// Dots stay inside the drawing. Fingers are taken from top to bottom, and labels alternate
    /// above and below their dots, so two fingers never get overlapping labels.
    static func layout(_ touches: [Touch], in size: CGSize) -> [Placement] {
        let inset = dotSize / 2
        let dots = touches.map { t in
            CGPoint(x: inset + CGFloat(min(max(t.x, 0), 1)) * (size.width - 2 * inset),
                    y: inset + CGFloat(1 - min(max(t.y, 0), 1)) * (size.height - 2 * inset))
        }
        let order = dots.indices.sorted { dots[$0].y < dots[$1].y }
        return order.enumerated().map { rank, i in
            Placement(touch: touches[i], dot: dots[i],
                      label: labelPosition(for: dots[i], in: size, above: rank.isMultiple(of: 2)))
        }
    }

    /// On the preferred side of the dot, or the other side when there is no room. Always fully inside the drawing.
    static func labelPosition(for dot: CGPoint, in size: CGSize, above: Bool) -> CGPoint {
        let offset = dotSize / 2 + labelSize.height / 2 + 2
        let halfW = labelSize.width / 2, halfH = labelSize.height / 2
        let up = dot.y - offset, down = dot.y + offset
        let y: CGFloat
        if above { y = up >= halfH ? up : down } else { y = down <= size.height - halfH ? down : up }
        return CGPoint(x: min(max(dot.x, halfW), size.width - halfW),
                       y: min(max(y, halfH), size.height - halfH))
    }
}
