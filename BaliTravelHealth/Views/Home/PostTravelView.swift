import SwiftUI

struct PostTravelView: View {
    @Environment(ProfileStore.self) private var profileStore
    @State private var adviceProvider = AdviceProvider()
    @State private var toolDestination: PostTravelTool?

    private var travel: TravelInfo? { profileStore.travelInfo }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                titleHeader
                adviceSection
                toolsSection
                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { EmptyView() }
        }
        .task {
            await adviceProvider.refresh(phase: .postTravel,
                                         profile: profileStore.profile,
                                         travel: travel)
        }
        .refreshable {
            await adviceProvider.refresh(phase: .postTravel,
                                         profile: profileStore.profile,
                                         travel: travel)
        }
        .navigationDestination(item: $toolDestination) { tool in
            PostTravelToolPlaceholder(tool: tool)
        }
    }

    // MARK: - Title

    private var titleHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Arriving Home")
                .font(.system(size: 34, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Text("Home sweet home. Last action. Stay robust.")
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
                Text("Once you're back, we'll surface follow-up health checks here.")
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
                    Text(advice.title)
                        .font(.headline)
                        .foregroundStyle(Color(.label))
                    Text(advice.body)
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

            // Mock matches the screenshot (single card). Add more `ToolCard`s
            // here when more post-travel tools come online.
            let columns = [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]
            LazyVGrid(columns: columns, spacing: 12) {
                ToolCard(title: "Health\nScreening", symbol: "list.clipboard.fill") {
                    toolDestination = .healthScreening
                }
                // Reserve the second column so the single card sits on the
                // leading edge as in the mock without stretching.
                Color.clear.aspectRatio(1.0, contentMode: .fit)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title2.weight(.bold))
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Tool destinations

enum PostTravelTool: String, Hashable, Identifiable {
    case healthScreening

    var id: String { rawValue }

    var title: String {
        switch self {
        case .healthScreening: return "Health Screening"
        }
    }

    var symbol: String {
        switch self {
        case .healthScreening: return "list.clipboard.fill"
        }
    }
}

private struct PostTravelToolPlaceholder: View {
    let tool: PostTravelTool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: tool.symbol)
                .font(.system(size: 56))
                .foregroundStyle(Color(red: 0.16, green: 0.45, blue: 0.92))
            Text(tool.title)
                .font(.title.weight(.bold))
            Text("Coming soon")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(tool.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PostTravelView()
            .environment(ProfileStore())
    }
}
