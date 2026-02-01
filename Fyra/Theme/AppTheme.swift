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
