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

/// Shared scale animation for our button styles, driven by
/// `ButtonStyle.Configuration.isPressed` — SwiftUI's own built-in press
/// state — rather than a custom touch-tracking gesture.
///
/// Two earlier versions of this attached an extra gesture
/// (`DragGesture(minimumDistance: 0)`, then `LongPressGesture`) via
/// `simultaneousGesture` to get more "instant" feedback inside a
/// `ScrollView` (SwiftUI otherwise waits to confirm a touch is a tap, not
/// the start of a scroll, before flipping `isPressed`). Both looked correct
/// in isolation but broke real tapping on device: the animation played, but
/// the button's own tap gesture never fired, so nothing after the animation
/// — opening a sheet, marking a workout done — ever happened. `isPressed`
/// can lag by a beat on a very fast tap inside a ScrollView, but unlike a
/// competing gesture, it can never block the tap itself.
private struct PressFeedback<Content: View>: View {
    var scale: CGFloat = 0.96
    var isPressed: Bool
    @ViewBuilder var content: (Bool) -> Content

    var body: some View {
        content(isPressed)
            .scaleEffect(isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.1), value: isPressed)
    }
}

/// "Done!" style — solid accent button.
struct HabitsPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    /// Overrides the default solid accent fill — e.g. red for a destructive
    /// primary action like Delete Account — while every existing call site
    /// (which passes the default) keeps its exact current look.
    var tint: Color = HabitsColor.accent

    private var pressedTint: Color {
        tint == HabitsColor.accent ? HabitsColor.accentDark : tint.opacity(0.8)
    }

    func makeBody(configuration: Configuration) -> some View {
        PressFeedback(isPressed: configuration.isPressed) { pressed in
            configuration.label
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(isEnabled ? .white : HabitsColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isEnabled ? (pressed ? pressedTint : tint) : HabitsColor.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isEnabled ? .clear : HabitsColor.border, lineWidth: 1)
                )
        }
    }
}

/// "Log activity" / "Undo" / "Edit" style — outlined ghost button.
/// Uses `borderActive` rather than the dim card-outline `border` color —
/// at `border`'s low contrast these read as barely-there against surface2.
struct HabitsGhostButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    /// `.large` matches `HabitsPrimaryButtonStyle`'s height — use it for a
    /// "Cancel" that sits next to a Save/primary button so the pair reads as
    /// one row, mirroring the web app's `.modal-cancel-btn`/`.modal-confirm-btn`
    /// (same padding on both; only weight differs).
    enum Size {
        case compact, large
    }

    var size: Size = .compact

    /// Overrides the default gray-text/purple-border look with a single
    /// color — e.g. red for a destructive ghost action like Sign Out —
    /// while leaving every existing call site (which passes nil) unchanged.
    var tint: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        PressFeedback(isPressed: configuration.isPressed) { pressed in
            configuration.label
                .font(.system(size: size == .large ? 17 : 14, weight: .semibold))
                .foregroundStyle(tint ?? HabitsColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, size == .large ? 18 : 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(pressed ? HabitsColor.surface : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke((tint ?? HabitsColor.borderActive).opacity(0.7), lineWidth: 1.25)
                )
                .opacity(isEnabled ? 1 : 0.35)
        }
    }
}

/// Recent-value chip style used in the skip / other-activity pickers.
struct HabitsChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressFeedback(scale: 0.94, isPressed: configuration.isPressed) { pressed in
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(pressed ? HabitsColor.accent : HabitsColor.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(HabitsColor.surface2)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(pressed ? HabitsColor.accent : HabitsColor.border, lineWidth: 1)
                )
        }
    }
}

/// Icon-only nav button (calendar month chevrons) — mirrors the web app's
/// `.cal-nav-btn`: a fixed 36x36 tap target with its own border, rather than
/// a bare glyph with no padding, which read as a finicky, tiny hit box.
struct HabitsIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressFeedback(scale: 0.92, isPressed: configuration.isPressed) { pressed in
            configuration.label
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(pressed ? HabitsColor.textPrimary : HabitsColor.textSecondary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(pressed ? HabitsColor.surface2 : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(HabitsColor.border, lineWidth: 1)
                )
        }
    }
}

/// Full-row selectable button (workout-option rows, "log activity" rows)
/// that otherwise use `.buttonStyle(.plain)` and so have no tap feedback at
/// all beyond whatever the row's own background already does.
struct HabitsRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressFeedback(scale: 0.98, isPressed: configuration.isPressed) { pressed in
            configuration.label
                .opacity(pressed ? 0.7 : 1)
        }
    }
}

/// Urgency tone for a "last done" pill, mirroring `lastDoneBadge` in the
/// web app's shared.js: 0 days is green, 1-3 green, 4-7 amber, 8+ or never red.
enum HabitsPillTone {
    case green, amber, red

    static func forDaysSince(_ days: Int?) -> HabitsPillTone {
        guard let days else { return .red }
        if days >= 8 { return .red }
        if days >= 4 { return .amber }
        return .green
    }

    var foreground: Color {
        switch self {
        case .green: return HabitsColor.green
        case .amber: return HabitsColor.amber
        case .red: return HabitsColor.red
        }
    }

    var background: Color {
        switch self {
        case .green: return HabitsColor.green.opacity(0.14)
        case .amber: return HabitsColor.amber.opacity(0.14)
        case .red: return HabitsColor.red.opacity(0.16)
        }
    }

    var border: Color {
        foreground.opacity(0.32)
    }
}

/// Small rounded status pill (e.g. "Last done 3d ago"), color-coded by urgency.
struct HabitsPill: View {
    let text: String
    var tone: HabitsPillTone = .green
    var showsCheck: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Text(text)
            if showsCheck {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
            }
        }
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tone.background)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(tone.border, lineWidth: 1))
    }
}

/// `HabitsTextField`'s secure counterpart, same `.modal-input` treatment —
/// for a password field inside a themed sheet.
struct HabitsSecureField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        SecureField(placeholder, text: $text)
            .foregroundStyle(HabitsColor.textPrimary)
            .tint(HabitsColor.accent)
            .padding(14)
            .background(HabitsColor.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(HabitsColor.border, lineWidth: 1)
            )
    }
}

/// The `.modal-input` treatment — single-line text field on a surface2 box.
struct HabitsTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
            .foregroundStyle(HabitsColor.textPrimary)
            .tint(HabitsColor.accent)
            .padding(14)
            .background(HabitsColor.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(HabitsColor.border, lineWidth: 1)
            )
    }
}

/// The `.journal-textarea` treatment — multi-line box, starts at ~3 lines tall.
struct HabitsTextArea: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .lineLimit(3...6)
            .foregroundStyle(HabitsColor.textPrimary)
            .tint(HabitsColor.accent)
            .padding(14)
            .background(HabitsColor.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(HabitsColor.border, lineWidth: 1)
            )
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

/// The `.modal-sheet` treatment — a bottom half-sheet sized to its content
/// (surface background, rounded top corners) rather than a full-screen sheet
/// with empty space below, matching the web app's modal pattern.
///
/// Also mirrors `.modal-sheet`'s brighter `border-top` (vs. the dim `border`
/// used on the rest of the sheet) — a bit of extra "chrome" along the top
/// edge that separates the sheet from the page underneath it.
struct HabitsSheetModifier: ViewModifier {
    var detents: Set<PresentationDetent>

    func body(content: Content) -> some View {
        content
            .presentationDetents(detents)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
            .presentationBackground {
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    topTrailingRadius: 24,
                    style: .continuous
                )
                .fill(HabitsColor.surface)
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 24,
                        topTrailingRadius: 24,
                        style: .continuous
                    )
                    .strokeBorder(HabitsColor.borderActive.opacity(0.6), lineWidth: 1.5)
                )
            }
    }
}

extension View {
    func habitsSheet(detents: Set<PresentationDetent> = [.medium]) -> some View {
        modifier(HabitsSheetModifier(detents: detents))
    }
}

/// The `.history-tabs`/`.htab` treatment — a rounded-square segmented
/// track (14pt outer / 10pt inner radius) rather than the system segmented
/// picker's much rounder, capsule-leaning control.
struct HabitsSegmentedControl<Item: Identifiable & Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Button {
                    selection = item
                } label: {
                    Text(title(item))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(item == selection ? HabitsColor.accent : HabitsColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(item == selection ? HabitsColor.surface2 : .clear)
                        )
                }
                // Plain, not HabitsRowButtonStyle: this control sits above the
                // ScrollView, not inside it, so it never had the scroll-vs-tap
                // recognition delay that motivated PressFeedback elsewhere —
                // and tab switching is critical enough that we don't want to
                // risk an extra gesture competing with the tap here.
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(HabitsColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HabitsColor.border, lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.15), value: selection)
    }
}

/// Small dim version readout shown at the bottom of every screen, mirroring
/// the web app's footer version tag. Reads `MARKETING_VERSION` and the build
/// number (`CURRENT_PROJECT_VERSION`) straight out of Info.plist — see
/// CLAUDE.md's Versioning section for the `v{MARKETING_VERSION}.{BUILD}`
/// convention — so it's always a live readout of the two Xcode fields rather
/// than a separately maintained string that can drift out of sync.
struct HabitsVersionFooter: View {
    /// Defaults to the same quiet-but-legible color as other secondary
    /// labels (e.g. the JOURNAL/WEIGHT section headers) — `textDim` reads as
    /// basically invisible at this text size. Pass `.secondary` (or similar)
    /// on a screen like Settings that hasn't opted into the app's dark theme
    /// and still uses adaptive system colors.
    var color: Color = HabitsColor.textSecondary

    private var versionString: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "v\(shortVersion).\(build)"
    }

    var body: some View {
        Text(versionString)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
}
