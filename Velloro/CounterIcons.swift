import SwiftUI

// Every glyph in the app is drawn from a Shape. No system imagery anywhere.

/// A two-pan balance. The counter.
struct BalanceGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let cx = rect.midX
        // Column
        path.addRect(CGRect(x: cx - w * 0.028, y: rect.minY + h * 0.14, width: w * 0.056, height: h * 0.66))
        // Foot
        path.addRect(CGRect(x: cx - w * 0.20, y: rect.minY + h * 0.80, width: w * 0.40, height: h * 0.07))
        path.addRect(CGRect(x: cx - w * 0.11, y: rect.minY + h * 0.72, width: w * 0.22, height: h * 0.08))
        // Beam
        path.addRect(CGRect(x: cx - w * 0.42, y: rect.minY + h * 0.17, width: w * 0.84, height: h * 0.055))
        // Left pan
        path.move(to: CGPoint(x: cx - w * 0.42, y: rect.minY + h * 0.225))
        path.addLine(to: CGPoint(x: cx - w * 0.42, y: rect.minY + h * 0.40))
        path.addLine(to: CGPoint(x: cx - w * 0.40, y: rect.minY + h * 0.40))
        path.addLine(to: CGPoint(x: cx - w * 0.40, y: rect.minY + h * 0.225))
        path.closeSubpath()
        path.move(to: CGPoint(x: cx - w * 0.62, y: rect.minY + h * 0.40))
        path.addLine(to: CGPoint(x: cx - w * 0.20, y: rect.minY + h * 0.40))
        path.addLine(to: CGPoint(x: cx - w * 0.32, y: rect.minY + h * 0.56))
        path.addLine(to: CGPoint(x: cx - w * 0.50, y: rect.minY + h * 0.56))
        path.closeSubpath()
        // Right pan
        path.move(to: CGPoint(x: cx + w * 0.40, y: rect.minY + h * 0.225))
        path.addLine(to: CGPoint(x: cx + w * 0.40, y: rect.minY + h * 0.40))
        path.addLine(to: CGPoint(x: cx + w * 0.42, y: rect.minY + h * 0.40))
        path.addLine(to: CGPoint(x: cx + w * 0.42, y: rect.minY + h * 0.225))
        path.closeSubpath()
        path.move(to: CGPoint(x: cx + w * 0.20, y: rect.minY + h * 0.40))
        path.addLine(to: CGPoint(x: cx + w * 0.62, y: rect.minY + h * 0.40))
        path.addLine(to: CGPoint(x: cx + w * 0.50, y: rect.minY + h * 0.56))
        path.addLine(to: CGPoint(x: cx + w * 0.32, y: rect.minY + h * 0.56))
        path.closeSubpath()
        return path
    }
}

/// An open ledger book.
struct LedgerGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let cx = rect.midX
        path.move(to: CGPoint(x: rect.minX + w * 0.06, y: rect.minY + h * 0.22))
        path.addLine(to: CGPoint(x: cx - w * 0.02, y: rect.minY + h * 0.30))
        path.addLine(to: CGPoint(x: cx - w * 0.02, y: rect.minY + h * 0.86))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.06, y: rect.minY + h * 0.78))
        path.closeSubpath()
        path.move(to: CGPoint(x: rect.maxX - w * 0.06, y: rect.minY + h * 0.22))
        path.addLine(to: CGPoint(x: cx + w * 0.02, y: rect.minY + h * 0.30))
        path.addLine(to: CGPoint(x: cx + w * 0.02, y: rect.minY + h * 0.86))
        path.addLine(to: CGPoint(x: rect.maxX - w * 0.06, y: rect.minY + h * 0.78))
        path.closeSubpath()
        for index in 0..<3 {
            let y = rect.minY + h * (0.44 + Double(index) * 0.13)
            path.addRect(CGRect(x: rect.minX + w * 0.14, y: y, width: w * 0.26, height: h * 0.035))
            path.addRect(CGRect(x: cx + w * 0.08, y: y, width: w * 0.26, height: h * 0.035))
        }
        return path
    }
}

/// An arcaded house front. The lending house itself.
struct HouseGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.10))
        path.addLine(to: CGPoint(x: rect.maxX - w * 0.06, y: rect.minY + h * 0.34))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.06, y: rect.minY + h * 0.34))
        path.closeSubpath()
        path.addRect(CGRect(x: rect.minX + w * 0.12, y: rect.minY + h * 0.36,
                            width: w * 0.76, height: h * 0.52))
        for index in 0..<3 {
            let x = rect.minX + w * (0.21 + Double(index) * 0.23)
            let archWidth = w * 0.15
            let top = rect.minY + h * 0.52
            path.addRect(CGRect(x: x, y: top, width: archWidth, height: h * 0.36))
            path.addEllipse(in: CGRect(x: x, y: top - archWidth / 2,
                                       width: archWidth, height: archWidth))
        }
        return path
    }
}

/// Three towers. The wider city.
struct CityGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.addRect(CGRect(x: rect.minX + w * 0.08, y: rect.minY + h * 0.42, width: w * 0.22, height: h * 0.46))
        path.addRect(CGRect(x: rect.minX + w * 0.39, y: rect.minY + h * 0.18, width: w * 0.22, height: h * 0.70))
        path.addRect(CGRect(x: rect.minX + w * 0.70, y: rect.minY + h * 0.50, width: w * 0.22, height: h * 0.38))
        // Crenellations on the tall tower
        path.addRect(CGRect(x: rect.minX + w * 0.36, y: rect.minY + h * 0.12, width: w * 0.06, height: h * 0.08))
        path.addRect(CGRect(x: rect.minX + w * 0.47, y: rect.minY + h * 0.12, width: w * 0.06, height: h * 0.08))
        path.addRect(CGRect(x: rect.minX + w * 0.58, y: rect.minY + h * 0.12, width: w * 0.06, height: h * 0.08))
        return path
    }
}

/// A quill nib. The rest of the house's papers.
struct QuillGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: rect.maxX - w * 0.10, y: rect.minY + h * 0.10))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.34, y: rect.minY + h * 0.62))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.20, y: rect.minY + h * 0.88))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.46, y: rect.minY + h * 0.74))
        path.closeSubpath()
        path.addRect(CGRect(x: rect.minX + w * 0.10, y: rect.minY + h * 0.84,
                            width: w * 0.30, height: h * 0.06))
        return path
    }
}

/// A struck coin.
struct CoinGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let side = min(rect.width, rect.height)
        let box = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        path.addEllipse(in: box)
        path.addEllipse(in: box.insetBy(dx: side * 0.17, dy: side * 0.17))
        return path
    }
}

/// A wax seal on a folded paper. The pledge.
struct SealGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let side = min(rect.width, rect.height)
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let outer = side * 0.44
        let inner = side * 0.32
        let points = 12
        for index in 0..<(points * 2) {
            let radius = index % 2 == 0 ? outer : inner
            let angle = Double(index) * Double.pi / Double(points) - Double.pi / 2
            let point = CGPoint(x: centre.x + CGFloat(cos(angle)) * radius,
                                y: centre.y + CGFloat(sin(angle)) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        path.addEllipse(in: CGRect(x: centre.x - side * 0.13, y: centre.y - side * 0.13,
                                   width: side * 0.26, height: side * 0.26))
        return path
    }
}

/// A small chevron used for disclosure and for the stepper arrows.
struct ChevronGlyph: Shape {
    enum Direction { case left, right, up, down }
    var direction: Direction = .right

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = min(rect.width, rect.height) * 0.24
        let box = rect.insetBy(dx: inset, dy: inset)
        switch direction {
        case .right:
            path.move(to: CGPoint(x: box.minX, y: box.minY))
            path.addLine(to: CGPoint(x: box.maxX, y: box.midY))
            path.addLine(to: CGPoint(x: box.minX, y: box.maxY))
        case .left:
            path.move(to: CGPoint(x: box.maxX, y: box.minY))
            path.addLine(to: CGPoint(x: box.minX, y: box.midY))
            path.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
        case .up:
            path.move(to: CGPoint(x: box.minX, y: box.maxY))
            path.addLine(to: CGPoint(x: box.midX, y: box.minY))
            path.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
        case .down:
            path.move(to: CGPoint(x: box.minX, y: box.minY))
            path.addLine(to: CGPoint(x: box.midX, y: box.maxY))
            path.addLine(to: CGPoint(x: box.maxX, y: box.minY))
        }
        return path
    }
}

struct TickGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let box = rect.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.22)
        path.move(to: CGPoint(x: box.minX, y: box.midY))
        path.addLine(to: CGPoint(x: box.minX + box.width * 0.34, y: box.maxY))
        path.addLine(to: CGPoint(x: box.maxX, y: box.minY))
        return path
    }
}

struct CrossGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let box = rect.insetBy(dx: rect.width * 0.24, dy: rect.height * 0.24)
        path.move(to: CGPoint(x: box.minX, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
        path.move(to: CGPoint(x: box.maxX, y: box.minY))
        path.addLine(to: CGPoint(x: box.minX, y: box.maxY))
        return path
    }
}

struct PlusGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bar = min(rect.width, rect.height) * 0.16
        path.addRect(CGRect(x: rect.midX - bar / 2, y: rect.minY + rect.height * 0.22,
                            width: bar, height: rect.height * 0.56))
        path.addRect(CGRect(x: rect.minX + rect.width * 0.22, y: rect.midY - bar / 2,
                            width: rect.width * 0.56, height: bar))
        return path
    }
}

struct MinusGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bar = min(rect.width, rect.height) * 0.16
        path.addRect(CGRect(x: rect.minX + rect.width * 0.22, y: rect.midY - bar / 2,
                            width: rect.width * 0.56, height: bar))
        return path
    }
}

/// A warning lozenge for events and concentration.
struct AlertGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.08))
        path.addLine(to: CGPoint(x: rect.maxX - w * 0.05, y: rect.maxY - h * 0.12))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.05, y: rect.maxY - h * 0.12))
        path.closeSubpath()
        return path
    }
}

/// A five-part rosette used as the standing mark.
struct StandingGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let side = min(rect.width, rect.height)
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        for index in 0..<5 {
            let angle = Double(index) * 2 * Double.pi / 5 - Double.pi / 2
            let petal = CGRect(x: centre.x + CGFloat(cos(angle)) * side * 0.22 - side * 0.17,
                               y: centre.y + CGFloat(sin(angle)) * side * 0.22 - side * 0.17,
                               width: side * 0.34, height: side * 0.34)
            path.addEllipse(in: petal)
        }
        return path
    }
}

// MARK: - Convenience wrappers

/// Filled glyph at a fixed size.
struct Glyph<S: Shape>: View {
    let shape: S
    var size: CGFloat = 22
    var color: Color = Ink.text

    var body: some View {
        shape
            .fill(color)
            .frame(width: size, height: size)
    }
}

/// Stroked glyph at a fixed size, for chevrons and ticks.
struct StrokedGlyph<S: Shape>: View {
    let shape: S
    var size: CGFloat = 14
    var color: Color = Ink.text
    var lineWidth: CGFloat = 2

    var body: some View {
        shape
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}
