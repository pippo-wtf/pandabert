import SwiftUI
import PulseCore

struct AttentionGlow: View {
    let arrival: AttentionArrival
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let elapsed = context.date.timeIntervalSince(arrival.startedAt)
            let envelope = smooth(elapsed / 3) * smooth((AttentionArrival.duration - elapsed) / 5)
            let breath = reduceMotion ? 0.65 : 0.55 + 0.45 * (1 - cos(elapsed * .pi / 4)) / 2
            RoundedRectangle(cornerRadius: 17)
                .stroke(lavender.opacity(0.65), lineWidth: 1.5)
                .shadow(color: lavender.opacity(0.5), radius: 8)
                .overlay {
                    RoundedRectangle(cornerRadius: 17)
                        .stroke(lavender.opacity(0.3), lineWidth: 5)
                        .blur(radius: 5)
                }
                .opacity(elapsed >= 0 && elapsed < AttentionArrival.duration ? envelope * breath : 0)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func smooth(_ value: Double) -> Double {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }
}
