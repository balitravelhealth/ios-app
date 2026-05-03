import SwiftUI

struct LoginView: View {
    @Environment(AuthenticationManager.self) private var auth

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Image("BthIcon")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundStyle(.white)
                        .accessibilityLabel("Bali Travel Health")
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()

                Image("JalakBali")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .accessibilityHidden(true)

                Spacer()

                VStack(spacing: 12) {
                    googleButton
                    passkeyButton
                    if AppFlags.useDummyData {
                        testUserButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            if auth.isLoading {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
        }
        .preferredColorScheme(.dark)
        .alert(
            "Sign-in failed",
            isPresented: errorBinding,
            presenting: auth.error
        ) { _ in
            Button("OK", role: .cancel) { auth.error = nil }
        } message: { error in
            Text(error.errorDescription ?? "Please try again.")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { auth.error?.errorDescription != nil },
            set: { if !$0 { auth.error = nil } }
        )
    }

    private var testUserButton: some View {
        Button {
            Task { await auth.signInAsTestUser() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.fill.checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Continue as Test User")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(auth.isLoading)
        .accessibilityIdentifier("continueAsTestUser")
    }

    private var googleButton: some View {
        Button {
            Task { await auth.signInWithGoogle() }
        } label: {
            HStack(spacing: 10) {
                Image("GoogleIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text("Continue With Google")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(auth.isLoading)
        .accessibilityIdentifier("continueWithGoogle")
    }

    private var passkeyButton: some View {
        Button {
            Task { await auth.signInWithPasskey() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)
                Text("Continue With Passkey")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white)
            )
        }
        .buttonStyle(.plain)
        .disabled(auth.isLoading)
        .accessibilityIdentifier("continueWithPasskey")
    }
}

#Preview {
    LoginView()
        .environment(AuthenticationManager())
}
