import SwiftUI

extension View {
    /// 已重塑为浅色系统的标准白卡（圆角 + 非常轻的阴影）。
    /// 保留原签名以兼容现有调用点；`tint` / `isInteractive` 不再影响外观。
    @ViewBuilder
    func mkGlassSurface(
        cornerRadius: CGFloat = 28,
        tint: Color = .white.opacity(0.12),
        isInteractive: Bool = false
    ) -> some View {
        self
            .background(MKTheme.card, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: MKTheme.shadow, radius: 18, x: 0, y: 8)
    }
}

struct MKBackdrop: View {
    var body: some View {
        MKTheme.background
            .ignoresSafeArea()
    }
}

extension View {
    /// 顶部 / 底部导航条的透明液态玻璃背景。
    /// iOS 26+ 使用真正的 Liquid Glass（`glassEffect`），低版本回退到 `.ultraThinMaterial`。
    /// 玻璃通过 `ignoresSafeArea` 延伸到状态栏 / Home 指示条下方，而不会带动其上的文字内容。
    func mkBarGlass(edges: Edge.Set) -> some View {
        background {
            MKGlassBarLayer(edges: edges)
        }
    }

    func mkGlassNavigation<Trailing: View>(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) -> some View {
        self
            .background(MKThemeBackground())
            .safeAreaInset(edge: .top, spacing: 0) {
                MKTopNavigationBar(title: title, subtitle: subtitle, trailing: trailing)
                    .padding(.horizontal, 20)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity)
                    .mkBarGlass(edges: .top)
            }
            .navigationBarHidden(true)
    }

    func mkGlassNavigation(title: String, subtitle: String) -> some View {
        mkGlassNavigation(title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

private struct MKGlassBarLayer: View {
    let edges: Edge.Set

    var body: some View {
        ZStack {
            if #available(iOS 26.0, *) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.18)
                    .glassEffect(.regular, in: .rect)
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.32)
            }

            Rectangle()
                .fill(
                    Color(
                        light: UIColor.white.withAlphaComponent(0.03),
                        dark: UIColor.black.withAlphaComponent(0.04)
                    )
                )

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        .white.opacity(0.06),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 22)

                Spacer(minLength: 0)

                Rectangle()
                    .fill(
                        Color(
                            light: UIColor.black.withAlphaComponent(0.035),
                            dark: UIColor.white.withAlphaComponent(0.055)
                        )
                    )
                    .frame(height: 0.5)
            }
        }
        .ignoresSafeArea(edges: edges)
    }
}

struct MKPageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(MKColor.ink)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct MKTopNavigationBar<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing

    init(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(MKColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)

            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .mkLiquidGlassBar(cornerRadius: 28)
    }
}

extension MKTopNavigationBar where Trailing == EmptyView {
    init(title: String, subtitle: String) {
        self.init(title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

private extension View {
    // 重塑为干净页眉：透明背景，与浅色页面融为一体。
    @ViewBuilder
    func mkLiquidGlassBar(cornerRadius: CGFloat) -> some View {
        self
    }
}

struct MKIconBadge: View {
    let symbol: String
    var tint: Color = MKColor.green
    var fill: Color = MKColor.subtleGreen.opacity(0.55)
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.12), in: Circle())
    }
}

struct MKPrimaryActionStyle: ButtonStyle {
    var tint: Color = MKTheme.primary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                tint,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: tint.opacity(configuration.isPressed ? 0.10 : 0.18), radius: 12, x: 0, y: 6)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.985 : 1))
            .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: configuration.isPressed)
    }
}
