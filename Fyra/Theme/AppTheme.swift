//
//  AppTheme.swift
//  Fyra
//

import SwiftUI
import UIKit

/// Calm, minimal design system — quiet logbook feel, no loud colors.
/// Accessibility: minimum 44pt tap targets, Dynamic Type–friendly fonts.
enum AppTheme {
    static let cornerRadius: CGFloat = 16
    static let cornerRadiusSmall: CGFloat = 12
    static let sectionSpacing: CGFloat = 28
    static let itemSpacing: CGFloat = 16
    static let cardPadding: CGFloat = 20
    /// Minimum tap target size (44pt) for accessibility.
    static let minTapTarget: CGFloat = 44

    /// Soft card background (works in light and dark).
    static var cardBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.secondarySystemBackground))
    }

    /// Subtle grouped background for sections.
    static var sectionBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.tertiarySystemFill).opacity(0.5))
    }

    /// Section label — small, muted.
    static func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption)
            .fontWeight(.medium)
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }

    /// Primary input style (weight, text fields).
    static var inputBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadiusSmall)
            .fill(Color(.secondarySystemBackground))
    }

    /// Pill for tags and compact buttons.
    static func pillBackground(selected: Bool) -> some View {
        Capsule()
            .fill(selected ? Color.accentColor.opacity(0.15) : Color(.tertiarySystemFill))
    }
}

enum NeonTheme {
    private static func uiColor(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> UIColor {
        UIColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
    }

    private static func dynamic(_ light: UIColor, _ dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    static let background = dynamic(uiColor(248, 250, 252), uiColor(0, 0, 0))
    static let surface = dynamic(uiColor(241, 245, 249), uiColor(24, 24, 27))
    static let surfaceAlt = dynamic(uiColor(226, 232, 240), uiColor(39, 39, 42))
    static let surfaceStrong = dynamic(uiColor(203, 213, 225), uiColor(63, 63, 70))
    static let border = dynamic(uiColor(203, 213, 225), uiColor(39, 39, 42))
    static let borderStrong = dynamic(uiColor(148, 163, 184), uiColor(63, 63, 70))
    static let textPrimary = dynamic(uiColor(15, 23, 42), uiColor(255, 255, 255))
    static let textSecondary = dynamic(uiColor(51, 65, 85), uiColor(161, 161, 170))
    static let textTertiary = dynamic(uiColor(100, 116, 139), uiColor(113, 113, 122))
    static let accent = dynamic(uiColor(163, 230, 53), uiColor(163, 230, 53))
    static let accentSoft = dynamic(uiColor(190, 242, 100), uiColor(190, 242, 100))
    static let lime500 = dynamic(uiColor(132, 204, 22), uiColor(132, 204, 22))
    static let lime600 = dynamic(uiColor(101, 163, 13), uiColor(101, 163, 13))

    static let cornerXL: CGFloat = 28
    static let cornerLarge: CGFloat = 24
    static let cornerMedium: CGFloat = 20
    static let cornerSmall: CGFloat = 14
}

extension View {
    func neonCard(
        background: Color = NeonTheme.surface,
        border: Color = NeonTheme.border,
        radius: CGFloat = NeonTheme.cornerLarge,
        shadowColor: Color = Color.black.opacity(0.35),
        shadowRadius: CGFloat = 12,
        shadowY: CGFloat = 8
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
    }
}

struct NeonIconBadge: View {
    let systemName: String
    var size: CGFloat = 48
    var background: Color = NeonTheme.accent
    var foreground: Color = .black

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: NeonTheme.cornerSmall, style: .continuous)
                .fill(background)
                .shadow(color: background.opacity(0.45), radius: 10, x: 0, y: 6)
            Image(systemName: systemName)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(foreground)
        }
        .frame(width: size, height: size)
    }
}

struct NeonToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isOn ? NeonTheme.accent : NeonTheme.surfaceAlt)
                    .frame(width: 56, height: 32)
                Circle()
                    .fill(isOn ? Color.black : NeonTheme.borderStrong)
                    .frame(width: 24, height: 24)
                    .padding(4)
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
            }
        }
        .buttonStyle(.plain)
    }
}
