import SwiftUI
import UIKit

/// 共享设计系统：原生 App 质感、Apple Health 风格，自动适配浅色 / 深色模式。
/// 所有重构后的页面统一使用这套令牌（背景 / 卡片 / 深绿主色 / 文字层级 / 圆角 / 阴影）。
enum MKTheme {
    // 页面背景：浅色米白 / 深色近黑。
    static let background = Color(
        light: UIColor(red: 0.965, green: 0.969, blue: 0.957, alpha: 1),
        dark: UIColor(red: 0.035, green: 0.038, blue: 0.035, alpha: 1)
    )
    // 卡片：浅色纯白 / 深色抬升表面。
    static let card = Color(
        light: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
        dark: UIColor(red: 0.105, green: 0.111, blue: 0.101, alpha: 1)
    )
    static let primary = MKColor.green
    static let ink = MKColor.ink
    static let secondaryText = Color(
        light: UIColor(red: 0.420, green: 0.447, blue: 0.502, alpha: 1),
        dark: UIColor(red: 0.62, green: 0.64, blue: 0.66, alpha: 1)
    )
    static let divider = Color(
        light: UIColor(white: 0, alpha: 0.06),
        dark: UIColor(white: 1, alpha: 0.10)
    )
    static let shadow = Color(
        light: UIColor(white: 0, alpha: 0.055),
        dark: UIColor(white: 0, alpha: 0.40)
    )

    // 卡片内嵌的填充块（比卡片略深 / 略亮，浅深色都可见）。
    static let fill = Color(
        light: UIColor(red: 0.929, green: 0.937, blue: 0.918, alpha: 1),
        dark: UIColor(red: 0.16, green: 0.166, blue: 0.155, alpha: 1)
    )
    static let track = Color(
        light: UIColor(white: 0, alpha: 0.07),
        dark: UIColor(white: 1, alpha: 0.14)
    )

    // 间距 / 圆角规范
    static let pageMargin: CGFloat = 20
    static let cardPadding: CGFloat = 18
    static let cardSpacing: CGFloat = 16
    static let cardRadius: CGFloat = 24
}

/// 页面背景。
struct MKThemeBackground: View {
    var body: some View {
        MKTheme.background
            .ignoresSafeArea()
    }
}

/// 区块标题。
struct MKThemeSectionTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(MKTheme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(MKTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// 紧凑页面 Header：大标题 + 副标题，右侧可选轻量标签 / 操作。
struct MKThemeHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing

    init(title: String, subtitle: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(MKTheme.ink)
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MKTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension MKThemeHeader where Trailing == EmptyView {
    init(title: String, subtitle: String) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// 轻量胶囊标签（如「增肌期」「恢复中」）。
struct MKThemeTag: View {
    let text: String
    var tint: Color = MKTheme.primary

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

extension View {
    /// 标准白卡：圆角 + 非常轻的阴影。
    func mkThemeCard(cornerRadius: CGFloat = MKTheme.cardRadius) -> some View {
        self
            .background(MKTheme.card, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: MKTheme.shadow, radius: 18, x: 0, y: 8)
    }

    /// 卡片内的次级填充块（tile / 行）。
    func mkThemeInsetTile(cornerRadius: CGFloat = 18) -> some View {
        self.background(MKTheme.fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// 浅色主按钮标签（实色深绿）。
struct MKThemePrimaryButtonLabel: View {
    let symbol: String?
    let title: String

    init(symbol: String? = nil, title: String) {
        self.symbol = symbol
        self.title = title
    }

    var body: some View {
        Group {
            if let symbol {
                Label(title, systemImage: symbol)
            } else {
                Text(title)
            }
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(MKTheme.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// 浅色次级按钮标签（浅绿底）。
struct MKThemeSecondaryButtonLabel: View {
    let symbol: String?
    let title: String

    init(symbol: String? = nil, title: String) {
        self.symbol = symbol
        self.title = title
    }

    var body: some View {
        Group {
            if let symbol {
                Label(title, systemImage: symbol)
            } else {
                Text(title)
            }
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(MKTheme.primary)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(MKTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct MKCapsuleProgressBar: View {
    let progress: Double
    var tint: Color = MKTheme.primary
    var isOver: Bool = false
    var height: CGFloat = 8
    var animate: Bool = true
    var showsTrack: Bool = true
    var showsShadow: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedProgress = 0.0

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(animatedProgress, 0), 1)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(showsTrack ? trackColor : .clear)
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(showsTrack ? trackStroke : .clear, lineWidth: 1)
                    }

                Capsule(style: .continuous)
                    .fill(fillColor)
                    .frame(width: proxy.size.width * clamped)
                    .shadow(color: resolvedTint.opacity(showsShadow && clamped > 0 ? 0.14 : 0), radius: 3, x: 0, y: 1)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
        .onAppear { update(progress) }
        .onChange(of: progress) { _, newValue in update(newValue) }
    }

    private var resolvedTint: Color {
        isOver ? MKColor.coral : tint
    }

    private var fillColor: LinearGradient {
        LinearGradient(
            colors: [resolvedTint.opacity(0.92), resolvedTint],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var trackColor: Color {
        Color(
            light: UIColor.black.withAlphaComponent(0.055),
            dark: UIColor.white.withAlphaComponent(0.10)
        )
    }

    private var trackStroke: Color {
        Color(
            light: UIColor.black.withAlphaComponent(0.04),
            dark: UIColor.white.withAlphaComponent(0.14)
        )
    }

    private func update(_ value: Double) {
        guard animate, !reduceMotion else {
            animatedProgress = value
            return
        }
        withAnimation(.easeInOut(duration: 0.62)) {
            animatedProgress = value
        }
    }
}

struct MKCapsuleProgressColumn: View {
    let progress: Double
    var tint: Color
    var minFillHeight: CGFloat = 2
    var showsShadow: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(progress, 0), 1)
            let fillHeight = clamped > 0 ? max(proxy.size.height * clamped, minFillHeight) : 0

            ZStack(alignment: .bottom) {
                Capsule(style: .continuous)
                    .fill(trackColor)
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(trackStroke, lineWidth: 1)
                    }

                Capsule(style: .continuous)
                    .fill(fillColor)
                    .frame(height: fillHeight)
                    .clipShape(Capsule(style: .continuous))
                    .shadow(color: tint.opacity(showsShadow && clamped > 0 ? 0.18 : 0), radius: 3, x: 0, y: 1)
            }
        }
        .accessibilityHidden(true)
    }

    private var fillColor: LinearGradient {
        LinearGradient(
            colors: [tint.opacity(0.92), tint],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private var trackColor: Color {
        Color(
            light: UIColor.black.withAlphaComponent(0.055),
            dark: UIColor.white.withAlphaComponent(0.10)
        )
    }

    private var trackStroke: Color {
        Color(
            light: UIColor.black.withAlphaComponent(0.04),
            dark: UIColor.white.withAlphaComponent(0.14)
        )
    }
}

/// 浅色进度条。
struct MKThemeProgressBar: View {
    let progress: Double
    var tint: Color = MKTheme.primary
    var isOver: Bool = false
    var height: CGFloat = 10

    var body: some View {
        MKCapsuleProgressBar(progress: progress, tint: tint, isOver: isOver, height: height)
    }
}
