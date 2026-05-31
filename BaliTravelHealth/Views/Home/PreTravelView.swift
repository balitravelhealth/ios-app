import SwiftUI

struct PreTravelView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(NetworkMonitor.self) private var network
    @State private var adviceProvider = AdviceProvider()
    @State private var assessmentService = AssessmentService.shared
    @State private var showSchedulePicker = false
    @State private var pendingArrival: Date?
    @State private var pendingDeparture: Date?
    @State private var toolDestination: PreTravelTool?

    private var travel: TravelInfo? { profileStore.travelInfo }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !network.isConnected {
                    OfflineNoticeBanner()
                }

                VStack(alignment: .leading, spacing: 32) {
                    titleHeader
                    adviceSection
                    toolsSection
                    scheduleSection
                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, network.isConnected ? 0 : 12)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Keep the system back arrow but hide the duplicate inline title
            ToolbarItem(placement: .principal) { EmptyView() }
        }
        .task {
            await adviceProvider.refresh(phase: .preTravel, profile: profileStore.profile, travel: travel)
        }
        .onChange(of: assessmentService.latestResult?.id) { _, _ in
            // Re-fetch advice when the user submits a fresh assessment and returns
            Task { await adviceProvider.refresh(phase: .preTravel, profile: profileStore.profile, travel: travel) }
        }
        .refreshable {
            await adviceProvider.refresh(phase: .preTravel, profile: profileStore.profile, travel: travel)
        }
        .sheet(isPresented: $showSchedulePicker, onDismiss: commitScheduleIfReady) {
            DateRangePickerSheet(arrival: $pendingArrival, departure: $pendingDeparture)
        }
        .navigationDestination(item: $toolDestination) { tool in
            switch tool {
            case .riskAssessment:
                HealthRiskAssessmentView(kategori: .preTravel)
            case .vaccineRecord:
                VaccineRecordView()
            }
        }
    }

    // MARK: - Title

    private var titleHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Get Prepared")
                .font(.system(size: 34, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Text("Prevention is better than cure")
                .font(.title3.italic())
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Advice section

    private var adviceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Advice")

            if adviceProvider.isLoading && adviceProvider.advices.isEmpty {
                loadingAdviceCard
            } else if let error = adviceProvider.lastError {
                adviceErrorCard(error)
            } else if adviceProvider.advices.isEmpty {
                emptyAdviceCard
            } else {
                VStack(spacing: 10) {
                    ForEach(adviceProvider.advices) { advice in
                        adviceCard(advice)
                    }
                }
            }
        }
    }

    private var emptyAdviceCard: some View {
        AdviceContainer(tint: Color(red: 0.96, green: 0.92, blue: 0.55)) {
            VStack(spacing: 12) {
                Image(systemName: "lightbulb.max")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(Color(.label).opacity(0.55))
                Text("No advice for now")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                    .multilineTextAlignment(.center)
                Text("We'll surface health tips here once your travel details are known.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, 24)
        }
    }

    private var loadingAdviceCard: some View {
        AdviceContainer(tint: Color(red: 0.96, green: 0.92, blue: 0.55)) {
            ProgressView("Loading advice…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
        }
    }

    private func adviceErrorCard(_ message: String) -> some View {
        AdviceContainer(tint: Color(red: 1.0, green: 0.85, blue: 0.85)) {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.red)
                Text("Couldn't load advice")
                    .font(.headline)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .padding(.horizontal, 20)
        }
    }

    private func adviceCard(_ advice: Advice) -> some View {
        AdviceContainer(tint: tint(for: advice.severity)) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: advice.symbolName)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(Color(.label))
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    TranslatingText(advice.title)
                        .font(.headline)
                        .foregroundStyle(Color(.label))
                    TranslatingText(advice.body)
                        .font(.subheadline)
                        .foregroundStyle(Color(.label).opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(18)
        }
        .accessibilityElement(children: .combine)
    }

    private func tint(for severity: Advice.Severity) -> Color {
        switch severity {
        case .info:     return Color(red: 0.96, green: 0.92, blue: 0.55)
        case .warning:  return Color(red: 1.00, green: 0.78, blue: 0.42)
        case .critical: return Color(red: 1.00, green: 0.62, blue: 0.55)
        }
    }

    // MARK: - Tools section

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Tools")

            let columns = [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]
            LazyVGrid(columns: columns, spacing: 12) {
                ToolCard(
                    title: "Health Risk\nAssessment",
                    symbol: "list.clipboard.fill"
                ) { toolDestination = .riskAssessment }
                ToolCard(
                    title: "Vaccine\nRecord",
                    symbol: "syringe.fill"
                ) { toolDestination = .vaccineRecord }
            }
        }
    }

    // MARK: - Schedule section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Schedule")

            Button {
                pendingArrival = travel?.arrivalDate
                pendingDeparture = travel?.departureDate
                showSchedulePicker = true
            } label: {
                ZStack(alignment: .leading) {
                    // Subtle watermark
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 120))
                        .foregroundStyle(.white.opacity(0.18))
                        .offset(x: -16, y: 22)

                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(scheduleTitle)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                            if let subtitle = scheduleSubtitle {
                                Text(subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.92))
                            }
                        }
                        Spacer()
                        scheduleCalendarBadge
                    }
                    .padding(20)
                }
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
                .background(Color(red: 0.34, green: 0.62, blue: 0.36))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Schedule")
            .accessibilityValue(scheduleAccessibilityValue)
            .accessibilityHint(travel == nil ? "Add your travel dates" : "Change your travel dates")
        }
    }

    private var scheduleTitle: String {
        guard let travel else { return "Add travel dates" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        let start = formatter.string(from: travel.arrivalDate)
        let end = formatter.string(from: travel.departureDate)
        return "\(start) – \(end)"
    }

    private var scheduleSubtitle: String? {
        guard let travel else { return "Tap to set arrival & departure" }
        let nights = travel.nights
        return nights == 1 ? "1 night in Bali" : "\(nights) nights in Bali"
    }

    private var scheduleAccessibilityValue: String {
        guard let travel else { return "Not set" }
        return "\(travel.arrivalDate.formatted(date: .long, time: .omitted)) to \(travel.departureDate.formatted(date: .long, time: .omitted))"
    }

    private var scheduleCalendarBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white)
                .frame(width: 56, height: 56)
            Image(systemName: "calendar")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Color(.label))
        }
        .accessibilityHidden(true)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title2.weight(.bold))
            .accessibilityAddTraits(.isHeader)
    }

    private func commitScheduleIfReady() {
        guard let arrival = pendingArrival, let departure = pendingDeparture else { return }
        let info = TravelInfo(arrivalDate: arrival, departureDate: departure)
        profileStore.saveTravelInfo(info)
        Task {
            await profileStore.syncToServer()
            await adviceProvider.refresh(phase: .preTravel, profile: profileStore.profile, travel: info)
        }
    }
}

// MARK: - Reusable advice container

struct AdviceContainer<Content: View>: View {
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Tool card

struct ToolCard: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Color.clear
                .aspectRatio(1.0, contentMode: .fit)
                .overlay {
                    GeometryReader { geo in
                        let side = min(geo.size.width, geo.size.height)
                        VStack(alignment: .leading, spacing: 0) {
                            Image(systemName: symbol)
                                .resizable()
                                .scaledToFit()
                                .frame(width: side * 0.30, height: side * 0.30)
                                .foregroundStyle(.white)
                            Spacer(minLength: 0)
                            Text(title)
                                .font(.system(size: side * 0.115, weight: .bold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(side * 0.10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .background(Color(red: 0.16, green: 0.45, blue: 0.92))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title.replacingOccurrences(of: "\n", with: " "))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Tool destinations

enum PreTravelTool: String, Hashable, Identifiable {
    case riskAssessment
    case vaccineRecord

    var id: String { rawValue }

    var title: String {
        switch self {
        case .riskAssessment: return "Health Risk Assessment"
        case .vaccineRecord:  return "Vaccine Record"
        }
    }

    var symbol: String {
        switch self {
        case .riskAssessment: return "list.clipboard.fill"
        case .vaccineRecord:  return "syringe.fill"
        }
    }
}

#Preview {
    NavigationStack {
        PreTravelView()
            .environment(ProfileStore())
            .environment(NetworkMonitor.shared)
    }
}
