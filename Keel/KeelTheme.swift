import SwiftUI

enum KeelTheme {
    static let windowBackground = LinearGradient(
        colors: [
            Color(red: 0.035, green: 0.055, blue: 0.065),
            Color(red: 0.055, green: 0.075, blue: 0.085)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let railBackground = Color(red: 0.025, green: 0.045, blue: 0.055)
    static let panelBackground = Color(red: 0.055, green: 0.075, blue: 0.085)
    static let raisedBackground = Color(red: 0.075, green: 0.095, blue: 0.105)
    static let selectedBackground = Color(red: 0.00, green: 0.36, blue: 0.39).opacity(0.46)
    static let border = Color.white.opacity(0.09)
    static let subtleBorder = Color.white.opacity(0.06)
    static let textMuted = Color.white.opacity(0.58)
    static let textSubtle = Color.white.opacity(0.38)
    static let accent = Color(red: 0.00, green: 0.78, blue: 0.74)
    static let accentSoft = Color(red: 0.00, green: 0.78, blue: 0.74).opacity(0.16)
    static let healthy = Color(red: 0.20, green: 0.84, blue: 0.38)
    static let warning = Color(red: 0.98, green: 0.66, blue: 0.18)
    static let danger = Color(red: 1.00, green: 0.28, blue: 0.22)
    static let purple = Color(red: 0.58, green: 0.47, blue: 0.96)
    static let blue = Color(red: 0.25, green: 0.58, blue: 1.00)
}

struct KeelPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(KeelTheme.panelBackground.opacity(0.78))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(KeelTheme.border, lineWidth: 1)
                    )
            )
    }
}

struct KeelIconButton: View {
    let systemName: String
    let help: String
    var isActive = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isDisabled ? KeelTheme.textSubtle : (isActive ? .white : KeelTheme.textMuted))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? KeelTheme.selectedBackground : Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isActive ? KeelTheme.accent.opacity(0.42) : KeelTheme.subtleBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(help)
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(0.13))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
    }
}

struct MetricSparkline: View {
    let seed: String
    var color = KeelTheme.accent

    private var values: [Double] {
        var state = UInt64(bitPattern: Int64(seed.hashValue)) &+ 0x9E3779B97F4A7C15
        return (0..<18).map { index in
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let noise = Double((state >> 32) % 100) / 100
            let wave = (sin(Double(index) * 0.65) + 1) / 2
            return min(1, max(0.08, noise * 0.55 + wave * 0.45))
        }
    }

    var body: some View {
        SparklineShape(values: values)
            .stroke(color, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
            .frame(width: 58, height: 18)
    }
}

struct SparklineShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }

        for index in values.indices {
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(values.count - 1)
            let y = rect.maxY - rect.height * CGFloat(values[index])
            if index == values.startIndex {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}
