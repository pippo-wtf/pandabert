import SwiftUI

/// Acknowledgements settle the remaining cards while the departing card stretches out.
enum SeenDismissal {
    static func animation(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.14) : .spring(response: 0.3, dampingFraction: 0.76).delay(0.08)
    }
    static let duration: TimeInterval = 0.3

    static func emptyStateTransition(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        let entrance = AnyTransition.modifier(active: EmptyStateEntrance(progress: 0), identity: EmptyStateEntrance(progress: 1))
            .animation(.linear(duration: duration))
        return .asymmetric(insertion: entrance, removal: .opacity)
    }

    static func transition(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        let exit = AnyTransition.modifier(active: RubberBandExit(progress: 1), identity: RubberBandExit(progress: 0))
            .animation(.linear(duration: duration))
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

/// Shared geometry keeps the empty-state reveal synchronized with the outgoing card.
private struct RubberBandMotion {
    let displacement: CGFloat
    let stretch: CGFloat
    init(progress: CGFloat) {
        let t = min(1, max(0, progress))
        let pull = smoothExit(t / 0.3)
        let release = min(1, max(0, (t - 0.3) / 0.7))
        let snap = 1 - pow(1 - release, 3)
        // Pull left for 90 ms, then stretch and snap right out of the panel over 210 ms.
        displacement = -0.045 * pull + 1.25 * snap
        stretch = -0.06 * pull * (1 - smoothExit(release / 0.35)) + 0.10 * sin(.pi * release)
    }
    // Account for the stretched trailing edge, rather than using elapsed time as distance.
    var fractionOutside: CGFloat { displacement - stretch / 2 }
}

private struct EmptyStateEntrance: AnimatableModifier {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        let outside = RubberBandMotion(progress: progress).fractionOutside
        content.opacity(Double(smoothExit((outside - 0.8) / 0.4)))
    }
}

private struct RubberBandGeometry: GeometryEffect {
    let progress: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        let motion = RubberBandMotion(progress: progress)
        let transform = CGAffineTransform(translationX: size.width / 2 + size.width * motion.displacement, y: size.height / 2)
            .scaledBy(x: 1 + motion.stretch, y: 1 - motion.stretch * 0.35)
            .translatedBy(x: -size.width / 2, y: -size.height / 2)
        return ProjectionTransform(transform)
    }
}
