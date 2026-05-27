import SwiftUI

struct BannerFlight: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let accent: Color
    let duration: Double

    init(text: String, accent: Color = .yellow, duration: Double = 11.0) {
        self.text = text
        self.accent = accent
        self.duration = duration
    }
}

struct BannerView: View {
    let flight: BannerFlight
    let screenWidth: CGFloat
    var onFinished: () -> Void

    private let assemblyWidth: CGFloat = 560
    private let assemblyHeight: CGFloat = 110
    // The plane sits at the right end of the assembly; this offset is its center
    // measured from the assembly's leading (left) edge.
    private let planeCenterOffsetInAssembly: CGFloat = 481

    @State private var phase: CGFloat = -1.0

    var body: some View {
        let startX = -assemblyWidth - 40
        let endX = screenWidth + 40
        let currentX = startX + (endX - startX) * phase

        ZStack(alignment: .leading) {
            FlyingAssembly(text: flight.text, accent: flight.accent)
                .frame(width: assemblyWidth, height: assemblyHeight)
                .offset(x: currentX, y: 0)
        }
        .frame(width: screenWidth, height: assemblyHeight, alignment: .leading)
        .onAppear {
            phase = 0
            withAnimation(.linear(duration: flight.duration)) {
                phase = 1
            }
            scheduleWhoosh(startX: startX, endX: endX)
            DispatchQueue.main.asyncAfter(deadline: .now() + flight.duration + 0.1) {
                onFinished()
            }
        }
    }

    private func scheduleWhoosh(startX: CGFloat, endX: CGFloat) {
        // Phase at which the plane's center crosses 1/3 of the screen.
        let targetX = screenWidth / 3.0
        let travel = endX - startX
        guard travel > 0 else { return }
        let rawPhase = (targetX - planeCenterOffsetInAssembly - startX) / travel
        let phaseAtOneThird = max(0.0, min(0.95, rawPhase))
        let delay = Double(phaseAtOneThird) * flight.duration
        // Whoosh covers the middle two-thirds of the remaining flight.
        let remaining = max(0.6, flight.duration - delay)
        let whooshDuration = min(remaining, 2.4)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            WhooshPlayer.shared.playWhoosh(duration: whooshDuration)
        }
    }
}

private struct FlyingAssembly: View {
    let text: String
    let accent: Color

    var body: some View {
        HStack(spacing: 0) {
            BannerRibbon(text: text)
                .frame(width: 380, height: 70)
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            TowLines()
                .stroke(Color.black.opacity(0.55), lineWidth: 1.5)
                .frame(width: 36, height: 70)
            Plane(accent: accent)
                .frame(width: 130, height: 100)
                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
        }
    }
}

private struct BannerRibbon: View {
    let text: String

    var body: some View {
        ZStack {
            RibbonShape()
                .fill(LinearGradient(
                    colors: [Color.white, Color(white: 0.93)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            RibbonShape()
                .stroke(Color.black.opacity(0.15), lineWidth: 1)

            Text(text)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.18))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.leading, 38)
                .padding(.trailing, 22)
        }
    }
}

private struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let notch: CGFloat = 22
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + notch, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

private struct TowLines: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + 8))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY - 8))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

private struct Plane: View {
    let accent: Color

    var body: some View {
        Image(systemName: "airplane")
            .resizable()
            .scaledToFit()
            .foregroundStyle(
                LinearGradient(
                    colors: [accent, accent.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .rotationEffect(.degrees(0))
    }
}

#Preview {
    BannerView(
        flight: BannerFlight(text: "Standup with platform team in 5 min"),
        screenWidth: 1440,
        onFinished: {}
    )
    .frame(width: 1440, height: 200)
    .background(Color.black.opacity(0.0))
}
