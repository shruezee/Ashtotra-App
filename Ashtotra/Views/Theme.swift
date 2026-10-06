import SwiftUI
import UIKit

enum Theme {
    /// Warm cream by day, deep plum at night.
    static let paper = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.11, green: 0.08, blue: 0.12, alpha: 1)
        : UIColor(red: 1.00, green: 0.97, blue: 0.91, alpha: 1) })
    static let paperDeep = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.17, green: 0.10, blue: 0.16, alpha: 1)
        : UIColor(red: 0.99, green: 0.90, blue: 0.80, alpha: 1) })
    static let card = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 1, alpha: 0.08)
        : UIColor(white: 1, alpha: 0.75) })
    static let saffron = Color(red: 0.89, green: 0.42, blue: 0.10)

    static let background = LinearGradient(colors: [paper, paperDeep], startPoint: .top, endPoint: .bottom)

    static func colors(for collection: NameCollection) -> [Color] { colors(forKey: collection.color) }
    static func colors(for prayer: Prayer) -> [Color] { colors(forKey: prayer.deity) }

    static func colors(forKey key: String) -> [Color] {
        switch key {
        case "orange": [Color(red: 0.98, green: 0.55, blue: 0.16), Color(red: 0.80, green: 0.25, blue: 0.10)]
        case "indigo": [Color(red: 0.36, green: 0.42, blue: 0.82), Color(red: 0.16, green: 0.17, blue: 0.46)]
        case "pink": [Color(red: 0.93, green: 0.40, blue: 0.55), Color(red: 0.68, green: 0.15, blue: 0.35)]
        case "teal": [Color(red: 0.18, green: 0.62, blue: 0.62), Color(red: 0.05, green: 0.35, blue: 0.44)]
        case "gold": [Color(red: 0.98, green: 0.72, blue: 0.20), Color(red: 0.78, green: 0.42, blue: 0.05)]
        case "blue": [Color(red: 0.25, green: 0.58, blue: 0.90), Color(red: 0.08, green: 0.28, blue: 0.60)]
        case "saffron": [Color(red: 0.99, green: 0.47, blue: 0.20), Color(red: 0.72, green: 0.18, blue: 0.12)]
        default: [.orange, .red]
        }
    }

    static func gradient(for collection: NameCollection) -> LinearGradient { gradient(forKey: collection.color) }
    static func gradient(for prayer: Prayer) -> LinearGradient { gradient(forKey: prayer.deity) }
    static func gradient(forKey key: String) -> LinearGradient {
        LinearGradient(colors: colors(forKey: key), startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Fills (buttons, cards) use the deep shade.
    static func tint(for collection: NameCollection) -> Color { colors(forKey: collection.color)[1] }
    static func tint(for prayer: Prayer) -> Color { colors(forKey: prayer.deity)[1] }

    /// Text on the page background: deep shade by day, light shade at night for contrast.
    static func textTint(for collection: NameCollection) -> Color { textTint(forKey: collection.color) }
    static func textTint(for prayer: Prayer) -> Color { textTint(forKey: prayer.deity) }
    static func textTint(forKey key: String) -> Color {
        let shades = colors(forKey: key).map(UIColor.init)
        return Color(UIColor { $0.userInterfaceStyle == .dark ? shades[0].lighter : shades[1] })
    }
}

private extension UIColor {
    var lighter: UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s * 0.6, brightness: min(1, b * 1.15), alpha: a)
    }
}

extension Text {
    /// Text in a given script, tagged so VoiceOver reads it with a matching voice.
    init(_ string: String, script: Script) {
        var attributed = AttributedString(string)
        if let language = script.speechLanguage {
            attributed.languageIdentifier = language
        }
        self.init(attributed)
    }
}
