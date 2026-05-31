import SwiftUI

struct SetupTravelView: View {
    @Environment(ProfileStore.self) private var profileStore

    @State private var arrival: Date?
    @State private var departure: Date?
    @State private var showRangePicker = false
    @State private var isSubmitting = false

    private var isFormValid: Bool {
        arrival != nil && departure != nil
    }

    /// Pick the seasonal video based on the chosen arrival date,
    /// or fall back to the current calendar month.
    private var season: BaliSeason {
        BaliSeason.season(for: arrival ?? Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    header
                    dateRangeRow
                    videoBackdrop
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }

            footer
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .navigationBarBackButtonHidden(false)
        .sheet(isPresented: $showRangePicker) {
            DateRangePickerSheet(arrival: $arrival, departure: $departure)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Ready to travel?")
                .font(.system(size: 34, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Spacer()
        }
    }

    // MARK: - Arrival ─── Departure

    private var dateRangeRow: some View {
        HStack(spacing: 12) {
            datePill(title: "Arrival Date", date: arrival)
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 28, height: 1.5)
            datePill(title: "Departure Date", date: departure)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Travel dates")
        .accessibilityValue(accessibilityValueText)
        .accessibilityAddTraits(.isButton)
        .onTapGesture { showRangePicker = true }
    }

    private var accessibilityValueText: String {
        switch (arrival, departure) {
        case let (a?, d?):
            return "\(a.formatted(date: .abbreviated, time: .omitted)) to \(d.formatted(date: .abbreviated, time: .omitted))"
        default:
            return "Not set"
        }
    }

    private func datePill(title: String, date: Date?) -> some View {
        Button {
            showRangePicker = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(date?.formatted(date: .abbreviated, time: .omitted) ?? " ")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(date == nil ? Color(.placeholderText) : Color(.label))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(height: 64)
            .modifier(GlassCapsuleBackground())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Looping seasonal video

    private var videoBackdrop: some View {
        LoopingVideoPlayer(
            resourceName: season.videoResourceName,
            placeholderEmoji: season == .rainy ? "🌧️" : "🌴"
        )
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .accessibilityHidden(true)
    }

    // MARK: - Footer (Skip + Next)

    private var footer: some View {
        VStack(spacing: 14) {
            Button {
                Task { await skip() }
            } label: {
                Text("Skip for now")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
            .accessibilityHint("Skip travel dates and continue")

            Button {
                Task { await submit() }
            } label: {
                ZStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(Color(.systemBackground))
                    } else {
                        Text("Next")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(isFormValid ? Color(.systemBackground) : Color(.tertiaryLabel))
                    }
                }
                .padding(.horizontal, 44)
                .padding(.vertical, 14)
                .background(nextButtonBackground)
            }
            .buttonStyle(.plain)
            .disabled(!isFormValid || isSubmitting)
            .animation(.easeInOut(duration: 0.2), value: isFormValid)
            .accessibilityHint(isFormValid ? "Saves and continues" : "Pick travel dates first")
        }
    }

    @ViewBuilder
    private var nextButtonBackground: some View {
        if #available(iOS 26, *), isFormValid {
            Capsule()
                .fill(Color(.label))
                .glassEffect(.regular.tint(Color(.label)), in: Capsule())
        } else {
            Capsule()
                .fill(isFormValid ? Color(.label) : Color(.systemGray5))
        }
    }

    // MARK: - Actions

    private func submit() async {
        guard let arrival, let departure else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        let info = TravelInfo(arrivalDate: arrival, departureDate: departure)
        profileStore.saveTravelInfo(info)
        await profileStore.completeOnboarding(skippingTravel: false)
    }

    private func skip() async {
        isSubmitting = true
        defer { isSubmitting = false }
        await profileStore.completeOnboarding(skippingTravel: true)
    }
}

// MARK: - Glass capsule background reused from setup screen

struct GlassCapsuleBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content.background(
                Capsule().stroke(Color(.separator), lineWidth: 1)
            )
        }
    }
}

#Preview {
    NavigationStack {
        SetupTravelView()
            .environment(ProfileStore())
    }
}
