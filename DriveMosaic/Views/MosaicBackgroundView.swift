import SwiftUI

/// Animated mosaic background for the empty state.
/// Floating colored blocks drift with opacity increasing toward the bottom.
struct MosaicBackgroundView: View {
    @State private var blocks: [MosaicBlock] = MosaicBlock.generate(count: 80)
    @State private var startTime: Date = .now

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(startTime)

                for block in blocks {
                    let x = block.x(at: elapsed, containerWidth: size.width)
                    let y = block.y(at: elapsed, containerHeight: size.height)

                    // Opacity: stronger at bottom, with breathing
                    let normalizedY = max(0, min(1, y / size.height))
                    let breathe = 0.7 + 0.3 * sin(elapsed * block.breatheSpeed + block.phase)
                    let opacity = normalizedY * 0.35 * breathe

                    let rect = CGRect(x: x, y: y, width: block.width, height: block.height)
                    let path = Path(roundedRect: rect, cornerRadius: 3)

                    context.fill(path, with: .color(block.color.opacity(opacity)))
                }
            }
        }
    }
}

// MARK: - Block Model

private struct MosaicBlock: Identifiable {
    let id = UUID()
    let width: CGFloat
    let height: CGFloat
    let yFraction: CGFloat     // 0…1 base vertical position
    let xFraction: CGFloat     // 0…1 base horizontal position
    let color: Color
    let phase: Double          // offset so blocks don't move in sync
    let xDriftSpeed: Double    // radians per second for horizontal oscillation
    let yDriftSpeed: Double    // radians per second for vertical oscillation
    let breatheSpeed: Double   // radians per second for opacity pulse
    let xAmplitude: CGFloat    // pixels of horizontal drift
    let yAmplitude: CGFloat    // pixels of vertical drift

    func x(at time: Double, containerWidth: CGFloat) -> CGFloat {
        let base = xFraction * (containerWidth - width)
        let drift = sin(time * xDriftSpeed + phase) * xAmplitude
        return base + drift
    }

    func y(at time: Double, containerHeight: CGFloat) -> CGFloat {
        let base = yFraction * (containerHeight - height)
        let drift = cos(time * yDriftSpeed + phase * 1.3) * yAmplitude
        return base + drift
    }

    static let palette: [Color] = [
        Color(red: 99/255, green: 102/255, blue: 241/255),   // indigo
        Color(red: 168/255, green: 85/255, blue: 247/255),   // purple
        Color(red: 59/255, green: 130/255, blue: 246/255),   // blue
        Color(red: 236/255, green: 72/255, blue: 153/255),   // pink
        Color(red: 34/255, green: 197/255, blue: 94/255),    // green
        Color(red: 249/255, green: 115/255, blue: 22/255),   // orange
        Color(red: 14/255, green: 165/255, blue: 233/255),   // sky
        Color(red: 244/255, green: 63/255, blue: 94/255),    // rose
        Color(red: 234/255, green: 179/255, blue: 8/255),    // amber
        Color(red: 20/255, green: 184/255, blue: 166/255),   // teal
    ]

    static func generate(count: Int) -> [MosaicBlock] {
        var blocks = (0..<count).map { _ in
            MosaicBlock(
                width: CGFloat.random(in: 30...120),
                height: CGFloat.random(in: 20...70),
                yFraction: CGFloat.random(in: 0...1),
                xFraction: CGFloat.random(in: 0...1),
                color: palette.randomElement()!,
                phase: Double.random(in: 0...(Double.pi * 2)),
                xDriftSpeed: Double.random(in: 0.15...0.5),   // ~6-20 sec per cycle
                yDriftSpeed: Double.random(in: 0.1...0.35),   // ~9-30 sec per cycle
                breatheSpeed: Double.random(in: 0.5...1.2),   // ~5-12 sec per breathe
                xAmplitude: CGFloat.random(in: 20...50),
                yAmplitude: CGFloat.random(in: 10...25)
            )
        }

        // One hero block — larger, sits in the lower third
        blocks.append(MosaicBlock(
            width: 180,
            height: 110,
            yFraction: CGFloat.random(in: 0.65...0.85),
            xFraction: CGFloat.random(in: 0.15...0.6),
            color: palette.randomElement()!,
            phase: Double.random(in: 0...(Double.pi * 2)),
            xDriftSpeed: 0.1,
            yDriftSpeed: 0.08,
            breatheSpeed: 0.4,
            xAmplitude: 30,
            yAmplitude: 15
        ))

        return blocks
    }
}
