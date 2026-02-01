//
//  AppTheme.swift
//  Fyra
//

import SwiftUI

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
    static let background = Color.black
    static let surface = Color(red: 24 / 255, green: 24 / 255, blue: 27 / 255)
    static let surfaceAlt = Color(red: 39 / 255, green: 39 / 255, blue: 42 / 255)
    static let surfaceStrong = Color(red: 63 / 255, green: 63 / 255, blue: 70 / 255)
    static let border = Color(red: 39 / 255, green: 39 / 255, blue: 42 / 255)
    static let borderStrong = Color(red: 63 / 255, green: 63 / 255, blue: 70 / 255)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 161 / 255, green: 161 / 255, blue: 170 / 255)
    static let textTertiary = Color(red: 113 / 255, green: 113 / 255, blue: 122 / 255)
    static let accent = Color(red: 163 / 255, green: 230 / 255, blue: 53 / 255)
    static let accentSoft = Color(red: 190 / 255, green: 242 / 255, blue: 100 / 255)
    static let lime500 = Color(red: 132 / 255, green: 204 / 255, blue: 22 / 255)
    static let lime600 = Color(red: 101 / 255, green: 163 / 255, blue: 13 / 255)

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
