import SwiftUI
import Lottie

/// Shown for ~3 seconds after a successful appointment booking, then auto-dismisses.
///
/// Background uses an animated 3-color `MeshGradient` (iOS 18+) that eases in
/// from white. The checkmark is a `LottieCheckmarkPlaceholder` — drop your
/// real Lottie JSON file in and follow the comments on that view to swap it
/// for the actual `LottieView` once the Lottie SPM package is added.
struct AppointmentConfirmedView: View {
    let confirmation: AppointmentConfirmation
    let onComplete: () -> Void

    /// How long the screen stays up before returning to the nursing list.
    var displayDuration: Duration = .seconds(3)

    @State private var colorAmount: CGFloat = 0       // 0 → 1: ease-in of the 3 colors
    @State private var didDismiss = false

    // The 3 colors that bleed in from white.
    private let colorA = Color(red: 0.85, green: 0.30, blue: 0.25)   // red
    private let colorB = Color(red: 0.42, green: 0.62, blue: 0.32)   // green
    private let colorC = Color(red: 0.45, green: 0.30, blue: 0.78)   // purple

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            VStack(spacing: 28) {
                LottieCheckmarkPlaceholder()
                    .frame(width: 220, height: 220)
                    .accessibilityHidden(true)

                Text("Appointment\nConfirmed")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.15), radius: 12)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 1.6)) { colorAmount = 1 }

            Task {
                try? await Task.sleep(for: displayDuration)
                guard !didDismiss else { return }
                didDismiss = true
                onComplete()
            }
        }
    }

    // MARK: - Animated 3-colour background

    @ViewBuilder
    private var background: some View {
        if #available(iOS 18.0, *) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: animatedPoints(t: t),
                    colors: animatedColors()
                )
            }
        } else {
            // Fallback for OSes without MeshGradient.
            LinearGradient(
                colors: [
                    blend(.white, with: colorA, amount: colorAmount),
                    blend(.white, with: colorB, amount: colorAmount),
                    blend(.white, with: colorC, amount: colorAmount)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    /// Slightly drifting control points for a soft "breathing" motion.
    private func animatedPoints(t: TimeInterval) -> [SIMD2<Float>] {
        let drift = CGFloat(0.04)
        let dx1 = CGFloat(sin(t * 0.6))  * drift
        let dy1 = CGFloat(cos(t * 0.5))  * drift
        let dx2 = CGFloat(sin(t * 0.45)) * drift
        let dy2 = CGFloat(cos(t * 0.7))  * drift

        let p: [(CGFloat, CGFloat)] = [
            (0, 0), (0.5, 0),               (1, 0),
            (0, 0.5 + dy1), (0.5 + dx1, 0.5 + dy2), (1, 0.5 - dy2),
            (0, 1), (0.5 + dx2, 1),         (1, 1)
        ]
        return p.map { SIMD2<Float>(Float($0.0), Float($0.1)) }
    }

    /// Corners stay white, the inner ring eases into the 3 brand colours.
    private func animatedColors() -> [Color] {
        [
            .white,
            blend(.white, with: colorB, amount: colorAmount * 0.6),
            .white,

            blend(.white, with: colorA, amount: colorAmount),
            blend(.white, with: colorB, amount: colorAmount),
            blend(.white, with: colorC, amount: colorAmount),

            blend(.white, with: colorA, amount: colorAmount * 0.6),
            blend(.white, with: colorC, amount: colorAmount),
            .white
        ]
    }

    private func blend(_ from: Color, with to: Color, amount: CGFloat) -> Color {
        let t = max(0, min(1, amount))
        let lhs = UIColor(from).rgba
        let rhs = UIColor(to).rgba
        return Color(
            red:   Double(lhs.r + (rhs.r - lhs.r) * t),
            green: Double(lhs.g + (rhs.g - lhs.g) * t),
            blue:  Double(lhs.b + (rhs.b - lhs.b) * t),
            opacity: Double(lhs.a + (rhs.a - lhs.a) * t)
        )
    }
}

// MARK: - Lottie placeholder

/// White rounded square with a black SF-Symbol checkmark.
///
/// **To use a real Lottie animation:**
/// 1. Add `lottie-ios` via SPM: https://github.com/airbnb/lottie-ios
/// 2. Drop your JSON (e.g. `appointment_confirmed.json`) into the app bundle.
/// 3. Replace this view's body with:
/// ```swift
/// import Lottie
/// LottieView(animation: .named("appointment_confirmed"))
///     .playing(loopMode: .playOnce)
/// ```
struct LottieCheckmarkPlaceholder: View {
    var body: some View {
        LottieView(animation: .named("appointment_confirmed")).playing()
    }
}

// MARK: - UIColor → RGBA helper

private extension UIColor {
    var rgba: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
}

#Preview {
    AppointmentConfirmedView(
        confirmation: AppointmentConfirmation(appointmentId: "preview"),
        onComplete: {}
    )
}
