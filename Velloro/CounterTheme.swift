import SwiftUI

/// Fixed palette. Nothing here reads the device colour scheme, so the house looks the
/// same whatever the phone is set to.
enum Ink {
    static let parchment = Color(red: 0.949, green: 0.906, blue: 0.816)
    static let parchmentDim = Color(red: 0.898, green: 0.839, blue: 0.722)
    static let card = Color(red: 0.984, green: 0.957, blue: 0.886)
    static let cardEdge = Color(red: 0.816, green: 0.745, blue: 0.596)

    static let text = Color(red: 0.141, green: 0.102, blue: 0.071)
    static let textSoft = Color(red: 0.361, green: 0.290, blue: 0.220)
    static let textFaint = Color(red: 0.545, green: 0.478, blue: 0.396)

    static let burgundy = Color(red: 0.361, green: 0.102, blue: 0.165)
    static let burgundyDeep = Color(red: 0.231, green: 0.059, blue: 0.110)
    static let burgundyLight = Color(red: 0.514, green: 0.180, blue: 0.243)

    static let gold = Color(red: 0.725, green: 0.545, blue: 0.133)
    static let goldBright = Color(red: 0.878, green: 0.733, blue: 0.341)
    static let goldPale = Color(red: 0.945, green: 0.878, blue: 0.702)

    static let good = Color(red: 0.184, green: 0.412, blue: 0.271)
    static let bad = Color(red: 0.576, green: 0.133, blue: 0.122)
    static let caution = Color(red: 0.647, green: 0.412, blue: 0.102)
    static let rule = Color(red: 0.824, green: 0.761, blue: 0.627)
}

enum Quill {
    static func title(_ size: CGFloat = 22) -> Font { .system(size: size, weight: .bold, design: .serif) }
    static func heading(_ size: CGFloat = 17) -> Font { .system(size: size, weight: .semibold, design: .serif) }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static func label(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .semibold, design: .serif) }
    static func numeral(_ size: CGFloat = 20) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func smallNumeral(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
}

enum Measure {
    /// Widest a reading column ever gets. Keeps iPad and landscape from stretching text.
    static let column: CGFloat = 620
}

// MARK: - Container size passed down from the root

private struct CounterSizeKey: EnvironmentKey {
    static let defaultValue = CGSize(width: 390, height: 844)
}

extension EnvironmentValues {
    var counterSize: CGSize {
        get { self[CounterSizeKey.self] }
        set { self[CounterSizeKey.self] = newValue }
    }
}

// MARK: - Shared chrome

/// A page: a light header band that fills the top safe area (so scrolled content can
/// never reach the clock), then the scrolling body.
struct CounterPage<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            CounterHeader(title: title, subtitle: subtitle, trailing: trailing)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    content()
                    Color.clear.frame(height: 18)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .frame(maxWidth: Measure.column)
                .frame(maxWidth: .infinity)
            }
            .background(Ink.parchment)
        }
        .background(Ink.parchment)
    }
}

struct CounterHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil

    @Environment(\.counterSize) private var container

    /// Landscape on a phone leaves very little height. Shrink the band and drop the
    /// subtitle rather than eating the reading area.
    private var compact: Bool { container.height < 500 }

    // The band is deliberately LIGHT. The app runs in the light scheme, so the clock and
    // battery are drawn dark; a burgundy band here would swallow them.
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Quill.title(compact ? 17 : 21))
                    .foregroundColor(Ink.burgundy)
                if let subtitle = subtitle, !compact {
                    Text(subtitle)
                        .font(Quill.body(12))
                        .foregroundColor(Ink.textSoft)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let trailing = trailing { trailing }
        }
        .padding(.horizontal, 16)
        .padding(.top, compact ? 5 : 10)
        .padding(.bottom, compact ? 6 : 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Ink.parchmentDim
                .overlay(
                    VStack(spacing: 2) {
                        Rectangle().fill(Ink.burgundy.opacity(0.85)).frame(height: 2)
                        Rectangle().fill(Ink.gold.opacity(0.75)).frame(height: 1)
                    },
                    alignment: .bottom
                )
                .edgesIgnoringSafeArea([.top, .horizontal])
        )
    }
}

/// A framed slab of parchment. Used for every block of content in the app.
struct CounterCard<Content: View>: View {
    var tint: Color = Ink.card
    var edge: Color = Ink.cardEdge
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(edge, lineWidth: 1.2)
                    )
            )
    }
}

struct CounterSectionTitle: View {
    let text: String
    var note: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(text.uppercased())
                .font(Quill.label(11))
                .tracking(1.4)
                .foregroundColor(Ink.textFaint)
            Rectangle().fill(Ink.rule).frame(height: 1)
            if let note = note {
                Text(note)
                    .font(Quill.label(11))
                    .foregroundColor(Ink.textFaint)
            }
        }
    }
}

/// Row of a label on the left and a value on the right.
struct CounterStatRow: View {
    let label: String
    let value: String
    var valueColor: Color = Ink.text
    var emphasis: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(Quill.body(14))
                .foregroundColor(Ink.textSoft)
            Spacer(minLength: 10)
            Text(value)
                .font(emphasis ? Quill.numeral(17) : Quill.smallNumeral(15))
                .foregroundColor(valueColor)
        }
    }
}

/// A pill used for cues, filters and tags. Not a button on its own.
struct CounterTag: View {
    let text: String
    var fill: Color = Ink.parchmentDim
    var stroke: Color = Ink.cardEdge
    var textColor: Color = Ink.textSoft

    var body: some View {
        Text(text)
            .font(Quill.label(11))
            .foregroundColor(textColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(fill).overlay(Capsule().stroke(stroke, lineWidth: 1))
            )
    }
}

/// The app's only button style. Always carries a real, tappable rectangle.
struct CounterButton: View {
    enum Weight { case solid, outline, quiet, danger }

    let title: String
    var weight: Weight = .solid
    var enabled: Bool = true
    var action: () -> Void

    private var background: Color {
        switch weight {
        case .solid: return enabled ? Ink.burgundy : Ink.cardEdge
        case .outline: return Ink.card
        case .quiet: return Color.clear
        case .danger: return enabled ? Ink.bad : Ink.cardEdge
        }
    }

    private var foreground: Color {
        switch weight {
        case .solid, .danger: return Ink.goldPale
        case .outline: return Ink.burgundy
        case .quiet: return Ink.textSoft
        }
    }

    var body: some View {
        Button(action: { if enabled { action() } }) {
            Text(title)
                .font(Quill.heading(15))
                .foregroundColor(enabled ? foreground : Ink.textFaint)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(background)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(weight == .quiet ? Ink.cardEdge : Ink.burgundyDeep.opacity(0.4),
                                        lineWidth: 1)
                        )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(FlatPressStyle())
    }
}

struct FlatPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1.0)
    }
}

/// Horizontal bar used for exposure, coverage and study readings.
struct CounterBar: View {
    let fraction: Double
    var fill: Color = Ink.burgundy
    var track: Color = Ink.parchmentDim
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(fill)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}
