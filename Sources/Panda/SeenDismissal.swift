import SwiftUI

/// Acknowledgements settle the remaining cards while the departing card stretches out.
enum SeenDismissal {
    static func animation(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.14) : .spring(response: 0.55, dampingFraction: 0.76)
    }
    static func transition(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        let exit = AnyTransition.modifier(active: RubberBandExit(progress: 1), identity: RubberBandExit(progress: 0))
            .animation(.linear(duration: 0.6))
        return .asymmetric(insertion: .opacity, removal: exit)
    }
}

private func smoothExit(_ value: CGFloat) -> CGFloat {
    let t = min(1, max(0, value)); return t * t * (3 - 2 * t)
}

private struct RubberBandExit: AnimatableModifier {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        content.modifier(RubberBandGeometry(progress: progress))
            .opacity(Double(1 - smoothExit((progress - 0.3) / 0.7)))
            .zIndex(progress > 0 ? 2 : 1)
            .allowsHitTesting(progress == 0)
    }
}

private struct RubberBandGeometry: GeometryEffect {
    let progress: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = min(1, max(0, progress))
        let pull = smoothExit(t / 0.2)
        let release = min(1, max(0, (t - 0.2) / 0.8))
        let snap = 1 - pow(1 - release, 3)
        // Briefly compress/pull left, stretch on release, then relax as the card exits right.
        let displacement = size.width * (-0.045 * pull + 1.25 * snap)
        let stretch = -0.06 * pull * (1 - smoothExit(release / 0.35)) + 0.10 * sin(.pi * release)
        let transform = CGAffineTransform(translationX: size.width / 2 + displacement, y: size.height / 2)
            .scaledBy(x: 1 + stretch, y: 1 - stretch * 0.35)
            .translatedBy(x: -size.width / 2, y: -size.height / 2)
        return ProjectionTransform(transform)
    }
}
