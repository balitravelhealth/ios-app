import SwiftUI

struct ProfileView: View {
    @Environment(AuthenticationManager.self) private var auth
    @Environment(ProfileStore.self) private var profileStore
    @State private var showEdit = false
    @State private var showSignOutConfirmation = false

    private var profile: UserProfile? { profileStore.profile }
    private var travel: TravelInfo? { profileStore.travelInfo }

    private var email: String? {
        if case let .signedIn(user) = auth.status { return user.email }
        return nil
    }

    private var age: Int? {
        guard let dob = profile?.dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                heroRow
                accountSection
                healthPassCard(travel: profileStore.travelInfo)
                signOutButton
                Color.clear.frame(height: 100) // tab bar breathing room
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEdit) {
            NavigationStack { ProfileEditView() }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Sign out of your account?",
                            isPresented: $showSignOutConfirmation,
                            titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                auth.signOut()
                profileStore.clear()
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Hero (avatar + name + edit)

    private var heroRow: some View {
        HStack(alignment: .top, spacing: 16) {
            avatar
                .frame(width: 90, height: 90)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile?.name ?? "—")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color(.label))
                    .lineLimit(2)
                if let age {
                    Text("\(age) years old")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let country = profile?.localizedCountryName {
                    Text(country)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)

            Spacer(minLength: 8)

            Button {
                showEdit = true
            } label: {
                Text("Edit")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.label))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color(.systemGray5))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit profile")
        }
    }

    private var avatar: some View {
        ZStack {
            // 3D-style emoji avatar; replace with a real avatar later if added.
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.65, green: 0.85, blue: 1.00),
                                 Color(red: 0.40, green: 0.65, blue: 0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            if let initials = initialsFromName, !initials.isEmpty {
                Text(initials)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.white)
            }
        }
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initialsFromName: String? {
        guard let name = profile?.name else { return nil }
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    // MARK: - Account section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Account")
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            HStack {
                Text("Email")
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
                Spacer()
                if let email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemGray5))
            )
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Health Pass

    private func healthPassCard(travel: TravelInfo?) -> some View {
        let cleared = profileStore.hasCompletedHealthRiskAssessment

        return VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Image("BthIcon")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.white)
                Text("Bali Travel Health")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
            }

            HStack(spacing: 14) {
                Image(systemName: cleared ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile?.name ?? "—")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(cleared ? "Cleared for Bali!" : "Please take Health Risk Assessment first")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }

            HStack(spacing: 12) {
                datePill(label: "Arrival", date: travel?.arrivalDate)
                datePill(label: "Departure", date: travel?.departureDate)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.70, green: 0.05, blue: 0.10),
                    Color(red: 0.42, green: 0.02, blue: 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cleared
            ? "Health pass: \(profile?.name ?? "") cleared for Bali"
            : "Health pass for \(profile?.name ?? ""): assessment pending")
    }

    private func datePill(label: String, date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color(.label).opacity(0.7))
            Text(date.map { $0.formatted(date: .long, time: .omitted) } ?? "—")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(date == nil ? Color(.label).opacity(0.5) : Color(.label))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemGray5))
        )
    }

    // MARK: - Sign out

    private var signOutButton: some View {
        Button(role: .destructive) {
            showSignOutConfirmation = true
        } label: {
            Text("Sign Out")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemGray6))
                )
        }
        .foregroundStyle(.red)
        .padding(.top, 4)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environment(AuthenticationManager())
            .environment(ProfileStore())
    }
}
