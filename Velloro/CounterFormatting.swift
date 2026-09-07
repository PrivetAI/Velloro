import Foundation

enum Tally {
    private static let grouped: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()

    static func coin(_ value: Int) -> String {
        grouped.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func florins(_ value: Int) -> String {
        "\(coin(value)) fl"
    }

    static func signedCoin(_ value: Int) -> String {
        value >= 0 ? "+\(coin(value)) fl" : "-\(coin(-value)) fl"
    }

    static func percent(_ fraction: Double, places: Int = 0) -> String {
        let scaled = fraction * 100
        if places == 0 { return "\(Int(scaled.rounded()))%" }
        return String(format: "%.\(places)f%%", scaled)
    }

    /// Rates are quoted the way a counter would quote them: per hundred, per quarter.
    static func rate(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    static func weeks(_ count: Int) -> String {
        count == 1 ? "1 week" : "\(count) weeks"
    }

    static func ordinalWeek(_ week: Int) -> String {
        let quarter = (week - 1) / 13 + 1
        let inQuarter = (week - 1) % 13 + 1
        return "Week \(inQuarter) of quarter \(quarter)"
    }
}
