//
//  Theme.swift
//  Habits
//
//  Native mirror of the web app's dark palette and type scale (see
//  `style.css` in the `habits` repo, `:root` custom properties). The web
//  app is dark-only (no light-mode variant), so these are literal colors
//  rather than adaptive system colors — matched with `.preferredColorScheme(.dark)`
//  on screens that use them.

import SwiftUI

fileprivate extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }
}

enum HabitsColor {
    static let bg = Color(hex: 0x0d0d14)
    static let surface = Color(hex: 0x13131e)
    static let surface2 = Color(hex: 0x1a1a28)
    static let border = Color(hex: 0x222235)
    static let borderActive = Color(hex: 0x4040a0)
    static let accent = Color(hex: 0x6c63ff)
    static let accentDark = Color(hex: 0x4a42cc)
    static let textPrimary = Color(hex: 0xe4e4f4)
    static let textSecondary = Color(hex: 0x6a6a90)
    static let textDim = Color(hex: 0x3a3a58)
    static let red = Color(hex: 0xff5555)
    static let orange = Color(hex: 0xff9944)
    static let green = Color(hex: 0x3ecf8e)
    static let coral = Color(hex: 0xff6b6b)
    static let amber = Color(hex: 0xf59e0b)
    static let teal = Color(hex: 0x2dd4bf)
}

/// "Done!" style — solid accent button.
struct HabitsPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(isEnabled ? .white : HabitsColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isEnabled ? (configuration.isPressed ? HabitsColor.accentDark : HabitsColor.accent) : HabitsColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isEnabled ? .clear : HabitsColor.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// "Log activity" / "Undo" / "Edit" style — outlined ghost button.
struct HabitsGhostButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(HabitsColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(configuration.isPressed ? HabitsColor.surface : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(HabitsColor.border, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.35)
    }
}

/// Recent-value chip style used in the skip / other-activity pickers.
struct HabitsChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(configuration.isPressed ? HabitsColor.accent : HabitsColor.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(HabitsColor.surface2)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(configuration.isPressed ? HabitsColor.accent : HabitsColor.border, lineWidth: 1)
            )
    }
}

/// Small rounded status pill (e.g. "Last done 3d ago").
struct HabitsPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(HabitsColor.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(HabitsColor.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(HabitsColor.border, lineWidth: 1))
    }
}

/// The `.today-card` treatment — surface2 background, rounded 18pt corners.
struct HabitsCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(HabitsColor.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(HabitsColor.border, lineWidth: 1)
            )
    }
}

extension View {
    func habitsCard() -> some View {
        modifier(HabitsCardModifier())
    }
}
