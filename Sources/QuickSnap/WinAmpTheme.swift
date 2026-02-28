import SwiftUI

// MARK: - WinAmp Classic Color Palette

enum WinAmp {

    /// Deepest background — toolbar, footer, scroll gutter
    static let panelBackground = Color(hex: "#1A1A1A")

    /// Slightly lighter surface variation
    static let surface         = Color(hex: "#232323")

    /// Button face fill (resting state)
    static let buttonFace      = Color(hex: "#2C2C2C")

    /// Button face fill (pressed state)
    static let buttonPressed   = Color(hex: "#181818")

    /// Iconic neon green — active icons, resolution text, slider fill
    static let accentGreen     = Color(hex: "#00FF41")

    /// Dimmer green — filename text, secondary green elements
    static let dimGreen        = Color(hex: "#00C132")

    /// Bevel top/left edge — raised highlight
    static let bevelLight      = Color(hex: "#5A5A5A")

    /// Bevel bottom/right edge — cast shadow
    static let bevelDark       = Color(hex: "#0A0A0A")

    /// 1px separator lines between panels
    static let separator       = Color(hex: "#111111")

    // MARK: - Typography

    static func lcdFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

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

// MARK: - WinAmpButtonStyle

struct WinAmpButtonStyle: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        configuration.label
            .foregroundColor(
                isActive ? WinAmp.accentGreen :
                pressed  ? WinAmp.dimGreen    :
                           Color(hex: "#B0B0B0")
            )
            .frame(minWidth: 28, minHeight: 28)
            .background(
                ZStack {
                    // Metallic gradient fill
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: pressed
                                    ? [WinAmp.buttonPressed, Color(hex: "#222222")]
                                    : [Color(hex: "#363636"), WinAmp.buttonFace],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Active green tint overlay
                    if isActive {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(WinAmp.accentGreen.opacity(0.12))
                    }
                }
            )
            .overlay(BevelBorder(cornerRadius: 3, pressed: pressed))
            .animation(.none, value: pressed)
    }
}

// MARK: - BevelBorder

/// Draws a two-tone directional bevel:
/// top + left edges = highlight (raised); bottom + right = shadow (recessed)
/// Inverted when pressed to simulate the button sinking in.
struct BevelBorder: View {
    let cornerRadius: CGFloat
    let pressed: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let r = cornerRadius

            Canvas { context, _ in
                let highlightColor: Color = pressed ? WinAmp.bevelDark : WinAmp.bevelLight
                let shadowColor: Color    = pressed ? WinAmp.bevelLight : WinAmp.bevelDark

                // Top edge
                var top = Path()
                top.move(to: CGPoint(x: r, y: 0.5))
                top.addLine(to: CGPoint(x: w - r, y: 0.5))
                context.stroke(top, with: .color(highlightColor), lineWidth: 1)

                // Left edge
                var left = Path()
                left.move(to: CGPoint(x: 0.5, y: r))
                left.addLine(to: CGPoint(x: 0.5, y: h - r))
                context.stroke(left, with: .color(highlightColor), lineWidth: 1)

                // Bottom edge
                var bottom = Path()
                bottom.move(to: CGPoint(x: r, y: h - 0.5))
                bottom.addLine(to: CGPoint(x: w - r, y: h - 0.5))
                context.stroke(bottom, with: .color(shadowColor), lineWidth: 1)

                // Right edge
                var right = Path()
                right.move(to: CGPoint(x: w - 0.5, y: r))
                right.addLine(to: CGPoint(x: w - 0.5, y: h - r))
                context.stroke(right, with: .color(shadowColor), lineWidth: 1)
            }
        }
    }
}

// MARK: - WinAmpSlider

/// Custom slider with dark track and green fill.
/// Replaces native Slider which ignores .tint on macOS.
struct WinAmpSlider: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>

    var body: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbX = fraction * (trackWidth - 10) + 5

            ZStack(alignment: .leading) {
                // Dark track (full width)
                RoundedRectangle(cornerRadius: 2)
                    .fill(WinAmp.buttonPressed)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(WinAmp.bevelDark, lineWidth: 1)
                    )
                    .frame(height: 4)

                // Green fill (left of thumb)
                RoundedRectangle(cornerRadius: 2)
                    .fill(WinAmp.accentGreen)
                    .frame(width: max(0, thumbX - 5), height: 4)

                // Thumb — beveled nub
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#4A4A4A"), WinAmp.buttonFace],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(WinAmp.bevelLight, lineWidth: 1)
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
