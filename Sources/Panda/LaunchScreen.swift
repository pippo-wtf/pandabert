import SwiftUI
import AppKit

/// Lives for the lifetime of the panel, so showing/hiding the window never replays the intro.
struct LaunchContainer: View {
    @ObservedObject var store: PandaStore
    @State private var finished = false
    var body: some View {
        Group {
            if finished { PanelView(store: store) }
            else { LaunchScreen { finished = true } }
        }
    }
}

struct LaunchScreen: View {
    static let duration: TimeInterval = 2.7
    let onFinished: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = ProcessInfo.processInfo.systemUptime

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { _ in
            LaunchArtwork(elapsed: ProcessInfo.processInfo.systemUptime - startedAt, reduceMotion: reduceMotion)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 23))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PandaBert. Keeps you on track. Opening.")
        .task {
            // Monotonic deadline, independent of collection and animation frames.
            let remaining = max(0, Self.duration - (ProcessInfo.processInfo.systemUptime - startedAt))
            do { try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000)) }
            catch { return }
            guard !Task.isCancelled else { return }
            onFinished()
        }
    }
}

/// Elapsed-time rendering also lets the exact production frames be inspected without slowing launch.
struct LaunchArtwork: View {
    let elapsed: TimeInterval
    var reduceMotion = false
    private func smooth(_ value: Double) -> Double {
        let t = min(1, max(0, value)); return t * t * (3 - 2 * t)
    }
    var body: some View {
        let drop = pow(smooth((elapsed - 0.25) / 1.15), 1.6)
        let pull = smooth((elapsed - 1.6) / 0.4)
        let sniff = sin(min(1, max(0, (elapsed - 1.6) / 0.55)) * .pi)
        let length = (0.115 + 0.25 * drop) * (1 - pull)
        let sway = sin(drop * .pi) * 0.018 * (1 - pull)
        let fade = smooth(elapsed / 0.18) * (1 - smooth((elapsed - 2.38) / 0.32))
        VStack(spacing: 9) {
            ZStack(alignment: .topLeading) {
                if reduceMotion {
                    Image(nsImage: PandaBrand.mark).resizable().renderingMode(.template)
                        .interpolation(.high).frame(width: 180, height: 180)
                } else {
                    // Keep the original ears and eye patches. The nose/drip are drawn separately
                    // for animation; the shared transparent icon asset is never changed.
                    Image(nsImage: PandaBrand.mark).resizable().renderingMode(.template)
                        .interpolation(.high).frame(width: 180, height: 180)
                        .mask(LaunchFaceMask().fill(style: FillStyle(eoFill: true)))
                    Canvas { context, _ in
                        let unit = 180.0
                        var drip = Path()
                        let x = 0.441, y = 0.727, tip = y + length
                        if length > 0.002 {
                            let bulb = min(0.026, length * 0.35)
                            drip.move(to: CGPoint(x: (x - 0.014) * unit, y: y * unit))
                            drip.addCurve(to: CGPoint(x: (x + sway - bulb) * unit, y: (tip - bulb) * unit),
                                          control1: CGPoint(x: (x + 0.010) * unit, y: (y + length * 0.4) * unit),
                                          control2: CGPoint(x: (x + sway - bulb) * unit, y: (tip - bulb * 2) * unit))
                            drip.addCurve(to: CGPoint(x: (x + sway + bulb) * unit, y: (tip - bulb) * unit),
                                          control1: CGPoint(x: (x + sway - bulb * 1.4) * unit, y: (tip + bulb * 0.7) * unit),
                                          control2: CGPoint(x: (x + sway + bulb * 1.4) * unit, y: (tip + bulb * 0.7) * unit))
                            drip.addCurve(to: CGPoint(x: (x + 0.012) * unit, y: y * unit),
                                          control1: CGPoint(x: (x + sway + bulb) * unit, y: (tip - bulb * 2) * unit),
                                          control2: CGPoint(x: (x - 0.012) * unit, y: (y + length * 0.4) * unit))
                            drip.closeSubpath()
                            context.fill(drip, with: .color(ink))
                        }
                        // The rounded, slightly asymmetric nose follows the approved mark.
                        var nose = Path()
                        nose.move(to: CGPoint(x: 0.399 * unit, y: 0.711 * unit))
                        nose.addCurve(to: CGPoint(x: 0.5 * unit, y: 0.681 * unit), control1: CGPoint(x: 0.391 * unit, y: 0.689 * unit), control2: CGPoint(x: 0.45 * unit, y: 0.681 * unit))
                        nose.addCurve(to: CGPoint(x: 0.601 * unit, y: 0.713 * unit), control1: CGPoint(x: 0.56 * unit, y: 0.68 * unit), control2: CGPoint(x: 0.61 * unit, y: 0.686 * unit))
                        nose.addCurve(to: CGPoint(x: 0.512 * unit, y: 0.774 * unit), control1: CGPoint(x: 0.598 * unit, y: 0.732 * unit), control2: CGPoint(x: 0.538 * unit, y: 0.773 * unit))
                        nose.addCurve(to: CGPoint(x: 0.435 * unit, y: 0.739 * unit), control1: CGPoint(x: 0.491 * unit, y: 0.779 * unit), control2: CGPoint(x: 0.458 * unit, y: 0.751 * unit))
                        nose.addCurve(to: CGPoint(x: 0.399 * unit, y: 0.711 * unit), control1: CGPoint(x: 0.409 * unit, y: 0.731 * unit), control2: CGPoint(x: 0.399 * unit, y: 0.725 * unit))
                        nose.closeSubpath()
                        context.fill(nose, with: .color(ink))
                    }.frame(width: 180, height: 220)
                }
            }
            .frame(width: 180, height: 220, alignment: .top)
            .scaleEffect(x: 1 + (reduceMotion ? 0 : sniff * 0.015), y: 1 - (reduceMotion ? 0 : sniff * 0.025))
            .offset(y: reduceMotion ? 0 : -sniff * 4)
            .accessibilityHidden(true)
            Text("PandaBert").font(.system(size: 26, weight: .semibold, design: .rounded))
            Text("Keeps you on track").font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .foregroundStyle(ink)
        .opacity(fade)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LaunchFaceMask: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRect(CGRect(x: rect.width * 0.38, y: rect.height * 0.67, width: rect.width * 0.24, height: rect.height * 0.33))
        return path
    }
}
