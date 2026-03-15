import AppKit
import SwiftUI

// MARK: - Color Hex Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8)  & 0xFF) / 255.0
        let b = Double(int         & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255.0
        let g = CGFloat((int >> 8)  & 0xFF) / 255.0
        let b = CGFloat(int         & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

// MARK: - AppSkin

struct AppSkin: Identifiable, Equatable {
    let id: String
    let name: String
    let colorScheme: ColorScheme
    let isModern: Bool
    let isGlass: Bool

    // Panel & layout
    let panelBg: Color
    let toolbarGradientTop: Color
    let separator: Color

    // Buttons
    let buttonFace: Color
    let buttonPressed: Color
    let buttonGradTop: Color
    let buttonGradBottom: Color
    let buttonPressedGradTop: Color
    let buttonPressedGradBottom: Color
    let thumbGradTop: Color

    // Accents
    let accent: Color       // active icons, resolution text, slider fill
    let accentDim: Color    // filename text, secondary
    let accentOverlay: Color // active button tint

    // Icons
    let iconIdle: Color

    // Bevel (WinAmp themes only)
    let bevelHi: Color
    let bevelShadow: Color

    // Canvas frame gradient (WinAmp themes only)
    let canvasFrameStart: Color
    let canvasFrameEnd: Color

    // Modern properties
    let surface: Color          // toolbar/footer bg
    let surfaceHover: Color     // button hover
    let border: Color           // subtle universal border
    let textSecondary: Color    // secondary text

    // NSView colors for DragExportNotch
    let notchResting: NSColor
    let notchHover: NSColor
    let notchPressed: NSColor
    let notchIcon: NSColor
    let notchIconDisabled: NSColor
    let notchBevelHi: NSColor
    let notchBevelShadow: NSColor

    func lcdFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    func primaryFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    func monoFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    static func == (lhs: AppSkin, rhs: AppSkin) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - WinAmp Skin Definitions

extension AppSkin {

    /// WinAmp Classic — charcoal panels, neon green accents
    static let classic = AppSkin(
        id: "classic",
        name: "WinAmp Classic",
        colorScheme: .dark,
        isModern: false,
        isGlass: false,
        panelBg:               Color(hex: "#1A1A1A"),
        toolbarGradientTop:    Color(hex: "#282828"),
        separator:             Color(hex: "#111111"),
        buttonFace:            Color(hex: "#2C2C2C"),
        buttonPressed:         Color(hex: "#181818"),
        buttonGradTop:         Color(hex: "#363636"),
        buttonGradBottom:      Color(hex: "#2C2C2C"),
        buttonPressedGradTop:  Color(hex: "#181818"),
        buttonPressedGradBottom: Color(hex: "#222222"),
        thumbGradTop:          Color(hex: "#4A4A4A"),
        accent:                Color(hex: "#00FF41"),
        accentDim:             Color(hex: "#00C132"),
        accentOverlay:         Color(hex: "#00FF41").opacity(0.12),
        iconIdle:              Color(hex: "#B0B0B0"),
        bevelHi:               Color(hex: "#5A5A5A"),
        bevelShadow:           Color(hex: "#0A0A0A"),
        canvasFrameStart:      Color(hex: "#0A0A0A"),
        canvasFrameEnd:        Color(hex: "#333333"),
        surface:               Color(hex: "#282828"),
        surfaceHover:          Color(hex: "#3A3A3A"),
        border:                Color(hex: "#111111"),
        textSecondary:         Color(hex: "#B0B0B0"),
        notchResting:          NSColor(hex: "#2C2C2C"),
        notchHover:            NSColor(red: 0.10, green: 0.22, blue: 0.11, alpha: 1.0),
        notchPressed:          NSColor(red: 0.07, green: 0.17, blue: 0.09, alpha: 1.0),
        notchIcon:             NSColor(red: 0.0,  green: 1.0,  blue: 0.255, alpha: 0.88),
        notchIconDisabled:     NSColor(red: 0.0,  green: 1.0,  blue: 0.255, alpha: 0.30),
        notchBevelHi:          NSColor(white: 0.35, alpha: 0.9),
        notchBevelShadow:      NSColor(white: 0.04, alpha: 0.9)
    )

    /// WinAmp Modern — dark navy, orange accents (WinAmp 5 era)
    static let modern = AppSkin(
        id: "modern",
        name: "WinAmp Modern",
        colorScheme: .dark,
        isModern: false,
        isGlass: false,
        panelBg:               Color(hex: "#1C2333"),
        toolbarGradientTop:    Color(hex: "#24304A"),
        separator:             Color(hex: "#141B2D"),
        buttonFace:            Color(hex: "#2A3447"),
        buttonPressed:         Color(hex: "#141C2E"),
        buttonGradTop:         Color(hex: "#324055"),
        buttonGradBottom:      Color(hex: "#2A3447"),
        buttonPressedGradTop:  Color(hex: "#141C2E"),
        buttonPressedGradBottom: Color(hex: "#1A2438"),
        thumbGradTop:          Color(hex: "#3A4A60"),
        accent:                Color(hex: "#FF8C00"),
        accentDim:             Color(hex: "#CC7000"),
        accentOverlay:         Color(hex: "#FF8C00").opacity(0.15),
        iconIdle:              Color(hex: "#9AAABB"),
        bevelHi:               Color(hex: "#4A5A7A"),
        bevelShadow:           Color(hex: "#0A0D15"),
        canvasFrameStart:      Color(hex: "#0A0D15"),
        canvasFrameEnd:        Color(hex: "#2A3447"),
        surface:               Color(hex: "#24304A"),
        surfaceHover:          Color(hex: "#324055"),
        border:                Color(hex: "#141B2D"),
        textSecondary:         Color(hex: "#9AAABB"),
        notchResting:          NSColor(hex: "#2A3447"),
        notchHover:            NSColor(red: 0.22, green: 0.28, blue: 0.18, alpha: 1.0),
        notchPressed:          NSColor(red: 0.15, green: 0.17, blue: 0.10, alpha: 1.0),
        notchIcon:             NSColor(red: 1.0,  green: 0.55, blue: 0.0,  alpha: 0.88),
        notchIconDisabled:     NSColor(red: 1.0,  green: 0.55, blue: 0.0,  alpha: 0.30),
        notchBevelHi:          NSColor(white: 0.29, alpha: 0.9),
        notchBevelShadow:      NSColor(white: 0.04, alpha: 0.9)
    )

    /// Midnight — deep indigo, cyan accents (Milkdrop visualizer era)
    static let midnight = AppSkin(
        id: "midnight",
        name: "Midnight",
        colorScheme: .dark,
        isModern: false,
        isGlass: false,
        panelBg:               Color(hex: "#0D0D1A"),
        toolbarGradientTop:    Color(hex: "#161628"),
        separator:             Color(hex: "#0A0A1A"),
        buttonFace:            Color(hex: "#1A1A33"),
        buttonPressed:         Color(hex: "#0A0A18"),
        buttonGradTop:         Color(hex: "#222244"),
        buttonGradBottom:      Color(hex: "#1A1A33"),
        buttonPressedGradTop:  Color(hex: "#0A0A18"),
        buttonPressedGradBottom: Color(hex: "#141425"),
        thumbGradTop:          Color(hex: "#2A2A55"),
        accent:                Color(hex: "#00D4FF"),
        accentDim:             Color(hex: "#00A0CC"),
        accentOverlay:         Color(hex: "#00D4FF").opacity(0.12),
        iconIdle:              Color(hex: "#8888BB"),
        bevelHi:               Color(hex: "#3A3A6A"),
        bevelShadow:           Color(hex: "#050510"),
        canvasFrameStart:      Color(hex: "#050510"),
        canvasFrameEnd:        Color(hex: "#1A1A33"),
        surface:               Color(hex: "#161628"),
        surfaceHover:          Color(hex: "#222244"),
        border:                Color(hex: "#0A0A1A"),
        textSecondary:         Color(hex: "#8888BB"),
        notchResting:          NSColor(hex: "#1A1A33"),
        notchHover:            NSColor(red: 0.08, green: 0.16, blue: 0.22, alpha: 1.0),
        notchPressed:          NSColor(red: 0.05, green: 0.10, blue: 0.15, alpha: 1.0),
        notchIcon:             NSColor(red: 0.0,  green: 0.83, blue: 1.0,  alpha: 0.88),
        notchIconDisabled:     NSColor(red: 0.0,  green: 0.83, blue: 1.0,  alpha: 0.30),
        notchBevelHi:          NSColor(white: 0.23, alpha: 0.9),
        notchBevelShadow:      NSColor(white: 0.02, alpha: 0.9)
    )
}

// MARK: - Modern Skin Definitions

extension AppSkin {

    /// Obsidian — cool blue-undertone dark, indigo accent
    static let obsidian = AppSkin(
        id: "obsidian",
        name: "Obsidian",
        colorScheme: .dark,
        isModern: true,
        isGlass: false,
        panelBg:               Color(hex: "#15151E"),
        toolbarGradientTop:    Color(hex: "#1E1E2E"),
        separator:             Color.white.opacity(0.08),
        buttonFace:            Color(hex: "#1E1E2E"),
        buttonPressed:         Color(hex: "#151520"),
        buttonGradTop:         Color(hex: "#1E1E2E"),
        buttonGradBottom:      Color(hex: "#1E1E2E"),
        buttonPressedGradTop:  Color(hex: "#151520"),
        buttonPressedGradBottom: Color(hex: "#151520"),
        thumbGradTop:          Color(hex: "#2E2E42"),
        accent:                Color(hex: "#818CF8"),
        accentDim:             Color(hex: "#6366F1"),
        accentOverlay:         Color(hex: "#818CF8").opacity(0.15),
        iconIdle:              Color(hex: "#9898B0"),
        bevelHi:               Color.clear,
        bevelShadow:           Color.clear,
        canvasFrameStart:      Color.white.opacity(0.08),
        canvasFrameEnd:        Color.white.opacity(0.08),
        surface:               Color(hex: "#1E1E2E"),
        surfaceHover:          Color(hex: "#2E2E42"),
        border:                Color.white.opacity(0.08),
        textSecondary:         Color(hex: "#9898B0"),
        notchResting:          NSColor(hex: "#1E1E2E"),
        notchHover:            NSColor(hex: "#818CF8").withAlphaComponent(0.2),
        notchPressed:          NSColor(hex: "#818CF8").withAlphaComponent(0.3),
        notchIcon:             NSColor(hex: "#818CF8").withAlphaComponent(0.88),
        notchIconDisabled:     NSColor(hex: "#818CF8").withAlphaComponent(0.30),
        notchBevelHi:          NSColor.clear,
        notchBevelShadow:      NSColor.clear
    )

    /// Aurora — slate base, teal accent
    static let aurora = AppSkin(
        id: "aurora",
        name: "Aurora",
        colorScheme: .dark,
        isModern: true,
        isGlass: false,
        panelBg:               Color(hex: "#0F172A"),
        toolbarGradientTop:    Color(hex: "#1E293B"),
        separator:             Color.white.opacity(0.08),
        buttonFace:            Color(hex: "#1E293B"),
        buttonPressed:         Color(hex: "#0F172A"),
        buttonGradTop:         Color(hex: "#1E293B"),
        buttonGradBottom:      Color(hex: "#1E293B"),
        buttonPressedGradTop:  Color(hex: "#0F172A"),
        buttonPressedGradBottom: Color(hex: "#0F172A"),
        thumbGradTop:          Color(hex: "#334155"),
        accent:                Color(hex: "#2DD4BF"),
        accentDim:             Color(hex: "#14B8A6"),
        accentOverlay:         Color(hex: "#2DD4BF").opacity(0.15),
        iconIdle:              Color(hex: "#94A3B8"),
        bevelHi:               Color.clear,
        bevelShadow:           Color.clear,
        canvasFrameStart:      Color.white.opacity(0.08),
        canvasFrameEnd:        Color.white.opacity(0.08),
        surface:               Color(hex: "#1E293B"),
        surfaceHover:          Color(hex: "#334155"),
        border:                Color.white.opacity(0.08),
        textSecondary:         Color(hex: "#94A3B8"),
        notchResting:          NSColor(hex: "#1E293B"),
        notchHover:            NSColor(hex: "#2DD4BF").withAlphaComponent(0.2),
        notchPressed:          NSColor(hex: "#2DD4BF").withAlphaComponent(0.3),
        notchIcon:             NSColor(hex: "#2DD4BF").withAlphaComponent(0.88),
        notchIconDisabled:     NSColor(hex: "#2DD4BF").withAlphaComponent(0.30),
        notchBevelHi:          NSColor.clear,
        notchBevelShadow:      NSColor.clear
    )

    /// Ember — warm brown-undertone dark, orange accent
    static let ember = AppSkin(
        id: "ember",
        name: "Ember",
        colorScheme: .dark,
        isModern: true,
        isGlass: false,
        panelBg:               Color(hex: "#1C1917"),
        toolbarGradientTop:    Color(hex: "#292524"),
        separator:             Color.white.opacity(0.08),
        buttonFace:            Color(hex: "#292524"),
        buttonPressed:         Color(hex: "#1C1917"),
        buttonGradTop:         Color(hex: "#292524"),
        buttonGradBottom:      Color(hex: "#292524"),
        buttonPressedGradTop:  Color(hex: "#1C1917"),
        buttonPressedGradBottom: Color(hex: "#1C1917"),
        thumbGradTop:          Color(hex: "#44403C"),
        accent:                Color(hex: "#FB923C"),
        accentDim:             Color(hex: "#F97316"),
        accentOverlay:         Color(hex: "#FB923C").opacity(0.15),
        iconIdle:              Color(hex: "#A8A29E"),
        bevelHi:               Color.clear,
        bevelShadow:           Color.clear,
        canvasFrameStart:      Color.white.opacity(0.08),
        canvasFrameEnd:        Color.white.opacity(0.08),
        surface:               Color(hex: "#292524"),
        surfaceHover:          Color(hex: "#44403C"),
        border:                Color.white.opacity(0.08),
        textSecondary:         Color(hex: "#A8A29E"),
        notchResting:          NSColor(hex: "#292524"),
        notchHover:            NSColor(hex: "#FB923C").withAlphaComponent(0.2),
        notchPressed:          NSColor(hex: "#FB923C").withAlphaComponent(0.3),
        notchIcon:             NSColor(hex: "#FB923C").withAlphaComponent(0.88),
        notchIconDisabled:     NSColor(hex: "#FB923C").withAlphaComponent(0.30),
        notchBevelHi:          NSColor.clear,
        notchBevelShadow:      NSColor.clear
    )

    /// Glass — translucent macOS Tahoe-style with vibrancy
    static let glass = AppSkin(
        id: "glass",
        name: "Glass",
        colorScheme: .dark,
        isModern: true,
        isGlass: true,
        panelBg:               Color.white.opacity(0.001),
        toolbarGradientTop:    Color.white.opacity(0.001),
        separator:             Color.white.opacity(0.12),
        buttonFace:            Color.white.opacity(0.08),
        buttonPressed:         Color.white.opacity(0.04),
        buttonGradTop:         Color.white.opacity(0.08),
        buttonGradBottom:      Color.white.opacity(0.08),
        buttonPressedGradTop:  Color.white.opacity(0.04),
        buttonPressedGradBottom: Color.white.opacity(0.04),
        thumbGradTop:          Color.white.opacity(0.15),
        accent:                Color(hex: "#60A5FA"),
        accentDim:             Color(hex: "#3B82F6"),
        accentOverlay:         Color(hex: "#60A5FA").opacity(0.18),
        iconIdle:              Color.white.opacity(0.7),
        bevelHi:               Color.clear,
        bevelShadow:           Color.clear,
        canvasFrameStart:      Color.white.opacity(0.12),
        canvasFrameEnd:        Color.white.opacity(0.12),
        surface:               Color.white.opacity(0.001),
        surfaceHover:          Color.white.opacity(0.12),
        border:                Color.white.opacity(0.12),
        textSecondary:         Color.white.opacity(0.6),
        notchResting:          NSColor.white.withAlphaComponent(0.08),
        notchHover:            NSColor(hex: "#60A5FA").withAlphaComponent(0.25),
        notchPressed:          NSColor(hex: "#60A5FA").withAlphaComponent(0.35),
        notchIcon:             NSColor(hex: "#60A5FA").withAlphaComponent(0.88),
        notchIconDisabled:     NSColor(hex: "#60A5FA").withAlphaComponent(0.30),
        notchBevelHi:          NSColor.clear,
        notchBevelShadow:      NSColor.clear
    )
}

// MARK: - SkinManager

final class SkinManager: ObservableObject {
    static let all: [AppSkin] = [.obsidian, .aurora, .ember, .glass, .classic, .modern, .midnight]

    @AppStorage("quicksnap.activeSkin") private var savedId: String = "obsidian"
    @Published var current: AppSkin = .obsidian

    init() {
        current = SkinManager.all.first { $0.id == savedId } ?? .obsidian
    }

    func select(_ skin: AppSkin) {
        current = skin
        savedId = skin.id
    }
}

// MARK: - WinAmpButtonStyle

struct WinAmpButtonStyle: ButtonStyle {
    let skin: AppSkin
    var isActive: Bool = false
    private var toolbarIconColor: Color { Color.white.opacity(skin.isGlass ? 0.82 : 0.9) }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        configuration.label
            .foregroundColor(toolbarIconColor)
            .opacity(pressed ? 0.75 : 1)
            .frame(minWidth: 28, minHeight: 28)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: pressed
                                    ? [skin.buttonPressedGradTop, skin.buttonPressedGradBottom]
                                    : [skin.buttonGradTop, skin.buttonGradBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    if isActive {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(skin.accentOverlay)
                    }
                }
            )
            .overlay(BevelBorder(hi: skin.bevelHi, shadow: skin.bevelShadow, cornerRadius: 3, pressed: pressed))
            .animation(.none, value: pressed)
    }
}

// MARK: - ModernButtonStyle

struct ModernButtonStyle: ButtonStyle {
    let skin: AppSkin
    var isActive: Bool = false
    private var toolbarIconColor: Color { Color.white.opacity(skin.isGlass ? 0.82 : 0.9) }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        configuration.label
            .foregroundColor(toolbarIconColor)
            .opacity(pressed ? 0.75 : 1)
            .frame(minWidth: 32, minHeight: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        pressed  ? skin.buttonPressed :
                        isActive ? skin.accentOverlay :
                                   skin.buttonFace
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: pressed)
            .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

// MARK: - BevelBorder

struct BevelBorder: View {
    let hi: Color
    let shadow: Color
    let cornerRadius: CGFloat
    let pressed: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let r = cornerRadius

            Canvas { context, _ in
                let highlightColor: Color = pressed ? shadow : hi
                let shadowColor: Color    = pressed ? hi : shadow

                var top = Path()
                top.move(to: CGPoint(x: r, y: 0.5))
                top.addLine(to: CGPoint(x: w - r, y: 0.5))
                context.stroke(top, with: .color(highlightColor), lineWidth: 1)

                var left = Path()
                left.move(to: CGPoint(x: 0.5, y: r))
                left.addLine(to: CGPoint(x: 0.5, y: h - r))
                context.stroke(left, with: .color(highlightColor), lineWidth: 1)

                var bottom = Path()
                bottom.move(to: CGPoint(x: r, y: h - 0.5))
                bottom.addLine(to: CGPoint(x: w - r, y: h - 0.5))
                context.stroke(bottom, with: .color(shadowColor), lineWidth: 1)

                var right = Path()
                right.move(to: CGPoint(x: w - 0.5, y: r))
                right.addLine(to: CGPoint(x: w - 0.5, y: h - r))
                context.stroke(right, with: .color(shadowColor), lineWidth: 1)
            }
        }
    }
}

// MARK: - WinAmpSlider

struct WinAmpSlider: View {
    let skin: AppSkin
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>

    var body: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbX = fraction * (trackWidth - 10) + 5

            ZStack(alignment: .leading) {
                // Dark track
                RoundedRectangle(cornerRadius: 2)
                    .fill(skin.buttonPressed)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(skin.bevelShadow, lineWidth: 1)
                    )
                    .frame(height: 4)

                // Accent fill (left of thumb)
                RoundedRectangle(cornerRadius: 2)
                    .fill(skin.accent)
                    .frame(width: max(0, thumbX - 5), height: 4)

                // Thumb nub
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [skin.thumbGradTop, skin.buttonFace],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(skin.bevelHi, lineWidth: 1)
                }
                .frame(width: 10, height: 18)
                .offset(x: thumbX - 5)
            }
            .frame(height: 18)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let newFraction = max(0, min(1, drag.location.x / trackWidth))
                        value = range.lowerBound + CGFloat(newFraction) * (range.upperBound - range.lowerBound)
                    }
            )
        }
        .frame(height: 18)
    }
}

// MARK: - ModernSlider

struct ModernSlider: View {
    let skin: AppSkin
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>

    var body: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbX = fraction * (trackWidth - 14) + 7

            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(skin.surfaceHover)
                    .frame(height: 3)

                // Accent fill (left of thumb)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(skin.accent)
                    .frame(width: max(0, thumbX), height: 3)

                // Thumb circle
                Circle()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
                    .frame(width: 14, height: 14)
                    .offset(x: thumbX - 7)
            }
            .frame(height: 14)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let newFraction = max(0, min(1, drag.location.x / trackWidth))
                        value = range.lowerBound + CGFloat(newFraction) * (range.upperBound - range.lowerBound)
                    }
            )
        }
        .frame(height: 14)
    }
}
