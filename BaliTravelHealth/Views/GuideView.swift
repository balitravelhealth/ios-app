import SwiftUI

struct GuideView: View {
    @State private var service = EmergencyGuideAPIService.shared
    @State private var selection: GuideListItem?

    private var flowItems: [GuideListItem] {
        service.flows.map { .flow($0) }
    }

    private var stepItems: [GuideListItem] {
        let covered = Set(service.flows.map { $0.kategori.uppercased() })
        let grouped = Dictionary(grouping: service.steps, by: \.kategori)
        return grouped.keys
            .filter { !Self.isFlowCovered(kategori: $0, covered: covered) }
            .sorted()
            .compactMap { kategori -> GuideListItem? in
                guard let info = Self.stepInfo[kategori] else { return nil }
                return .steps(kategori: kategori, title: info.title, summary: info.summary, symbol: info.symbol)
            }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                if service.isLoading && service.flows.isEmpty && service.steps.isEmpty {
                    loadingState
                } else if let error = service.lastError, service.flows.isEmpty {
                    errorState(message: error)
                } else {
                    guideList
                }
                Color.clear.frame(height: 100)
            }
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .top)
        .navigationDestination(item: $selection) { item in
            switch item {
            case .flow(let summary):
                let dict = TranslationDictionaryService.shared
                let title = dict.lookup(summary.title) ?? summary.title
                EmergencyGuideFlowView(flowId: summary.id, flowTitle: title)
            case .steps(let kategori, let title, _, _):
                EmergencyGuideStepsView(kategori: kategori, title: title)
            }
        }
        .task {
            async let flows: Void = service.fetchFlows()
            async let steps: Void = service.fetchSteps()
            _ = await (flows, steps)
        }
        .refreshable {
            async let flows: Void = service.fetchFlows()
            async let steps: Void = service.fetchSteps()
            _ = await (flows, steps)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.96, blue: 0.13),
                    Color(red: 1.00, green: 0.96, blue: 0.13),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer(minLength: 60)
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 130, weight: .regular))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .red)
                    .accessibilityHidden(true)
                    .padding(.bottom, 16)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            Text("Emergency guide")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color(.label))
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(height: 380)
    }

    // MARK: - Guide list

    private var guideList: some View {
        VStack(spacing: 0) {
            if !flowItems.isEmpty {
                sectionHeader("Interactive Guides")
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                ForEach(Array(flowItems.enumerated()), id: \.element.id) { index, item in
                    guideRow(item: item)
                    if index < flowItems.count - 1 {
                        Divider().padding(.leading, 116)
                    }
                }
            }

            if !stepItems.isEmpty {
                sectionHeader("First Aid Reference")
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 4)
                ForEach(Array(stepItems.enumerated()), id: \.element.id) { index, item in
                    guideRow(item: item)
                    if index < stepItems.count - 1 {
                        Divider().padding(.leading, 116)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private func guideRow(item: GuideListItem) -> some View {
        let dict = TranslationDictionaryService.shared
        let displayTitle   = dict.lookup(item.title)   ?? item.title
        let displaySummary = dict.lookup(item.summary) ?? item.summary

        return Button {
            selection = item
        } label: {
            HStack(spacing: 16) {
                thumbnail(symbol: item.symbol, isFlow: item.isFlow)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(displayTitle)
                            .font(.headline)
                            .foregroundStyle(Color(.label))
                            .lineLimit(1)
                        if item.isFlow {
                            Text("GUIDE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(red: 0.16, green: 0.45, blue: 0.92))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(Color(red: 0.16, green: 0.45, blue: 0.92).opacity(0.12))
                                )
                        }
                    }
                    Text(displaySummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayTitle)
        .accessibilityHint(displaySummary)
        .accessibilityAddTraits(.isButton)
    }

    private func thumbnail(symbol: String, isFlow: Bool) -> some View {
        ZStack {
            Color(isFlow ? .systemBlue : .systemGray5)
                .opacity(isFlow ? 0.15 : 1)
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(isFlow ? Color(red: 0.16, green: 0.45, blue: 0.92) : .secondary)
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityHidden(true)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading guides…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Couldn't load guides")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task {
                    async let flows: Void = service.fetchFlows()
                    async let steps: Void = service.fetchSteps()
                    _ = await (flows, steps)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 60)
    }

    // MARK: - Category metadata

    static func isFlowCovered(kategori: String, covered: Set<String>) -> Bool {
        let k = kategori.uppercased()
        if covered.contains(k) { return true }
        if k.hasPrefix("TERSEDAK") && covered.contains("TERSEDAK") { return true }
        if (k == "CEK_NAPAS" || k == "CPR_DEWASA" || k == "AED") && covered.contains("BLS") { return true }
        return false
    }

    static let stepInfo: [String: (title: String, summary: String, symbol: String)] = [
        "CEK_NAPAS": (
            "Check Breathing",
            "Look, listen, and feel — assess whether the casualty is breathing.",
            "lungs.fill"
        ),
        "CPR_DEWASA": (
            "CPR — Adult",
            "Step-by-step chest compressions and rescue breaths for adults.",
            "heart.text.square.fill"
        ),
        "CPR_ANAK": (
            "CPR — Child & Baby",
            "Adapted technique for children aged 1–8 and infants under 1 year.",
            "figure.2.and.child.holdinghands"
        ),
        "AED": (
            "AED Usage Guide",
            "How to set up and use an Automated External Defibrillator.",
            "bolt.heart.fill"
        ),
        "TERSEDAK_DEWASA": (
            "Choking — Adult",
            "Back blows and abdominal thrusts (Heimlich manoeuvre) for adults.",
            "wind"
        ),
        "TERSEDAK_ANAK": (
            "Choking — Child & Baby",
            "Adapted technique for children and infants who are choking.",
            "figure.child"
        ),
        "LUKA": (
            "Wound Care",
            "Stop bleeding, clean the wound, and dress it properly.",
            "bandage.fill"
        ),
        "ALERGI": (
            "Allergy & Anaphylaxis",
            "Recognise signs of anaphylaxis and use an EpiPen if available.",
            "allergens"
        ),
        "ACCIDENTAL_INGESTION": (
            "Accidental Ingestion",
            "Steps to take when a hazardous substance has been swallowed.",
            "pills.fill"
        ),
        "DARURAT": (
            "Emergency Numbers",
            "Key emergency contacts for Bali: ambulance, police, hospitals.",
            "phone.fill"
        ),
    ]
}

// MARK: - List item model

enum GuideListItem: Identifiable, Hashable {
    case flow(EmergencyGuideFlowSummary)
    case steps(kategori: String, title: String, summary: String, symbol: String)

    var id: String {
        switch self {
        case .flow(let s): return "flow-\(s.id)"
        case .steps(let k, _, _, _): return "steps-\(k)"
        }
    }

    var title: String {
        switch self {
        case .flow(let s): return s.title
        case .steps(_, let t, _, _): return t
        }
    }

    var summary: String {
        switch self {
        case .flow(let s): return s.deskripsi ?? ""
        case .steps(_, _, let s, _): return s
        }
    }

    var symbol: String {
        switch self {
        case .flow(let s):
            switch s.kategori.uppercased() {
            case "BLS":     return "heart.fill"
            case "TERSEDAK":return "wind"
            case "CPR_ANAK":return "figure.2.and.child.holdinghands"
            default:        return "cross.case.fill"
            }
        case .steps(_, _, _, let sym): return sym
        }
    }

    var isFlow: Bool {
        if case .flow = self { return true }
        return false
    }
}

#Preview {
    NavigationStack { GuideView() }
}
