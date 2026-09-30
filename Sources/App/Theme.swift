import AppKit
import SwiftUI

extension NSColor {
    /// Color that switches between light and dark appearance.
    static func adaptive(light: UInt32, dark: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        }
    }

    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Editor palette, modelled on Xcode's default light/dark themes.
enum CodeTheme {
    static let background = NSColor.adaptive(light: 0xFFFFFF, dark: 0x1F1F24)
    static let gutter = NSColor.adaptive(light: 0xF7F7F9, dark: 0x1A1A1E)
    static let lineNumber = NSColor.adaptive(light: 0xB0B0B8, dark: 0x5C5C66)
    static let text = NSColor.adaptive(light: 0x1D1D1F, dark: 0xE6E6E9)
    static let keyword = NSColor.adaptive(light: 0x9B2393, dark: 0xFF7AB2)
    static let string = NSColor.adaptive(light: 0xC41A16, dark: 0xFF8170)
    static let number = NSColor.adaptive(light: 0x1C00CF, dark: 0xD9C97C)
    static let type = NSColor.adaptive(light: 0x0F68A0, dark: 0x5DD8FF)
    static let comment = NSColor.adaptive(light: 0x707F8C, dark: 0x7F8C98)
    static let flag = NSColor.adaptive(light: 0x326D74, dark: 0x78C2B3)
    static let url = NSColor.adaptive(light: 0x0E4FC9, dark: 0x6BA4FF)

    static let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    static let paragraph: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.18
        return style
    }()
}

extension Language {
    /// Brand color used for the language chip and accents.
    var color: Color {
        switch self {
        case .python: return Color(nsColor: NSColor(hex: 0x3776AB))
        case .javascript: return Color(nsColor: NSColor(hex: 0xF0D722))
        case .csharp: return Color(nsColor: NSColor(hex: 0x7B3FB8))
        case .ruby: return Color(nsColor: NSColor(hex: 0xCC342D))
        case .java: return Color(nsColor: NSColor(hex: 0xE76F00))
        case .rust: return Color(nsColor: NSColor(hex: 0xB7410E))
        case .go: return Color(nsColor: NSColor(hex: 0x00ADD8))
        case .php: return Color(nsColor: NSColor(hex: 0x777BB4))
        case .swift: return Color(nsColor: NSColor(hex: 0xF05138))
        }
    }

    /// Text color that reads on top of `color`.
    var onColor: Color { self == .javascript ? .black.opacity(0.85) : .white }
}

/// Rounded, softly shadowed container used for the two editor panes.
struct Card<Header: View, Content: View>: View {
    @ViewBuilder var header: Header
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Color(nsColor: CodeTheme.gutter))
            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 1)
            content
        }
        .background(Color(nsColor: CodeTheme.background))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
    }
}

/// Small square icon badge used in card headers.
struct IconBadge: View {
    var systemImage: String
    var color: Color
    var foreground: Color = .white

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(foreground)
            .frame(width: 26, height: 26)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
