import SwiftUI
import UIKit

enum MKColor {
    static let green = Color(light: UIColor(red: 0.25, green: 0.55, blue: 0.34, alpha: 1), dark: UIColor(red: 0.49, green: 0.86, blue: 0.60, alpha: 1))
    static let mint = Color(light: UIColor(red: 0.33, green: 0.62, blue: 0.48, alpha: 1), dark: UIColor(red: 0.56, green: 0.92, blue: 0.74, alpha: 1))
    static let deepGreen = Color(light: UIColor(red: 0.18, green: 0.35, blue: 0.24, alpha: 1), dark: UIColor(red: 0.17, green: 0.33, blue: 0.22, alpha: 1))
    static let citrus = Color(light: UIColor(red: 0.68, green: 0.46, blue: 0.18, alpha: 1), dark: UIColor(red: 0.94, green: 0.72, blue: 0.34, alpha: 1))
    static let coral = Color(light: UIColor(red: 0.72, green: 0.28, blue: 0.22, alpha: 1), dark: UIColor(red: 0.94, green: 0.42, blue: 0.34, alpha: 1))
    static let sky = Color(light: UIColor(red: 0.32, green: 0.49, blue: 0.68, alpha: 1), dark: UIColor(red: 0.54, green: 0.72, blue: 0.92, alpha: 1))
    static let ink = Color(light: UIColor(red: 0.10, green: 0.12, blue: 0.10, alpha: 1), dark: UIColor(red: 0.94, green: 0.96, blue: 0.93, alpha: 1))
    static let background = Color(light: UIColor(red: 0.96, green: 0.97, blue: 0.95, alpha: 1), dark: UIColor(red: 0.035, green: 0.038, blue: 0.035, alpha: 1))
    static let surface = Color(light: UIColor(red: 1.00, green: 1.00, blue: 0.98, alpha: 1), dark: UIColor(red: 0.075, green: 0.079, blue: 0.072, alpha: 1))
    static let elevatedSurface = Color(light: UIColor(red: 1.00, green: 1.00, blue: 0.985, alpha: 1), dark: UIColor(red: 0.105, green: 0.111, blue: 0.101, alpha: 1))
    static let subtleGreen = Color(light: UIColor(red: 0.84, green: 0.91, blue: 0.86, alpha: 1), dark: UIColor(red: 0.12, green: 0.20, blue: 0.15, alpha: 1))
    static let subtleCitrus = Color(light: UIColor(red: 0.95, green: 0.88, blue: 0.73, alpha: 1), dark: UIColor(red: 0.24, green: 0.18, blue: 0.10, alpha: 1))
    static let subtleSky = Color(light: UIColor(red: 0.85, green: 0.90, blue: 0.95, alpha: 1), dark: UIColor(red: 0.10, green: 0.15, blue: 0.21, alpha: 1))

    /// 饮食负荷配色（交通拥堵思路）：摄入/建议 比值越低越浅绿，达标为绿；超标转黄→橙→红，超得越多越深红。
    static func mealLoad(ratio: Double) -> Color {
        let r = max(ratio, 0)
        // 关键色（RGB 0...1）
        let lightGreen = (0.62, 0.84, 0.58)
        let green = (0.30, 0.66, 0.40)
        let orange = (0.95, 0.62, 0.20)
        let deepRed = (0.74, 0.12, 0.12)

        func lerp(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: Double) -> Color {
            let k = min(max(t, 0), 1)
            return Color(
                red: a.0 + (b.0 - a.0) * k,
                green: a.1 + (b.1 - a.1) * k,
                blue: a.2 + (b.2 - a.2) * k
            )
        }

        if r <= 1 {
            return lerp(lightGreen, green, r) // 越少越浅绿，达标为绿
        }
        let over = (r - 1) / 0.6 // 比值 1.6 时达到最深红
        if over < 0.5 {
            return lerp(green, orange, over / 0.5)
        }
        return lerp(orange, deepRed, (over - 0.5) / 0.5)
    }
}

extension Color {
    init(light: UIColor, dark: UIColor) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}
