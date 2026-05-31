import SwiftUI

/// Shown in place of the main app while `AppLaunchCoordinator` is fetching
/// and caching initial data. Replicates the visual feel of the system launch
/// screen so the transition into the app feels seamless.
struct LaunchLoadingView: View {
    let statusMessage: String

    var body: some View {
        ZStack {
            // Gradient background matching the app's brand
            LinearGradient(
                colors: [
                    Color(red: 0.72, green: 0.05, blue: 0.10),
                    Color(red: 0.40, green: 0.02, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App icon / branding
                VStack(spacing: 14) {
                    Image("BthIcon")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.white)

                    Text("Bali Travel Health")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                // Progress indicator + status
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)

                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.8))
                            .animation(.easeInOut, value: statusMessage)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .transition(.opacity)
    }
}

#Preview {
    LaunchLoadingView(statusMessage: "Updating guides…")
}
