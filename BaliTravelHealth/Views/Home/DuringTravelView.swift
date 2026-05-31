import SwiftUI

struct DuringTravelView: View {
    @State private var facilityStore = HealthFacilityStore.shared
    @Namespace private var morphNamespace
    @State private var blsDestination: BLSDestination?
    @State private var presentedFacility: NearbyHealthFacility?
    @State private var showAllFacilities = false

    var body: some View {
        ZStack {
            mainContent
                .blur(radius: presentedFacility == nil ? 0 : 14)
                .allowsHitTesting(presentedFacility == nil)

            if presentedFacility != nil {
                Rectangle()
                    .fill(.black.opacity(0.18))
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { presentedFacility = nil }
                    .accessibilityLabel("Close facility details")
                    .accessibilityAddTraits(.isButton)
            }

            if let facility = presentedFacility {
                APIFacilityDetailView(facility: facility) { presentedFacility = nil }
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.88).combined(with: .opacity),
                            removal: .scale(scale: 0.94).combined(with: .opacity)
                        )
                    )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: presentedFacility?.id)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $blsDestination) { destination in
            switch destination {
            case .flow(let id, let title):
                EmergencyGuideFlowView(flowId: id, flowTitle: title)
            case .steps(let kategori, let title):
                EmergencyGuideStepsView(kategori: kategori, title: title)
            }
        }
        .sheet(isPresented: $showAllFacilities) {
            NavigationStack {
                AllFacilitiesView(store: facilityStore, onDone: { showAllFacilities = false })
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task {
            await facilityStore.refresh()
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                titleHeader
                healthFacilitySection
                basicLifeSupportSection
                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .toolbar {
            ToolbarItem(placement: .principal) { EmptyView() }
        }
        .refreshable {
            await facilityStore.refresh()
        }
    }

    // MARK: - Title

    private var titleHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Traveling")
                .font(.system(size: 34, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Text("Everything can happen. Don't worry")
                .font(.title3.italic())
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Health Facility

    private var healthFacilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Health Facility")
                    .font(.title2.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if !facilityStore.facilities.isEmpty {
                    Button {
                        showAllFacilities = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Show all")
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show all facilities")
                }
            }

            Group {
                if facilityStore.isLoading && facilityStore.facilities.isEmpty {
                    facilityLoadingState
                } else if let error = facilityStore.lastError, facilityStore.facilities.isEmpty {
                    facilityErrorState(message: error)
                } else if facilityStore.facilities.isEmpty {
                    facilityEmptyState
                } else {
                    VStack(spacing: 10) {
                        ForEach(facilityStore.facilities.prefix(4)) { facility in
                            facilityRow(facility)
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private func facilityRow(_ facility: NearbyHealthFacility) -> some View {
        Button {
            presentedFacility = facility
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(.label).opacity(0.06))
                        .frame(width: 44, height: 44)
                    Image(systemName: facilitySymbol(for: facility.jenis))
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Color(.label))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(facility.nama)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                    Text(facility.jenis)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(facilityStore.distanceString(for: facility))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Capsule(style: .continuous).fill(Color(.systemBackground)))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(facility.nama), \(facility.jenis)")
        .accessibilityValue(facilityStore.distanceString(for: facility))
        .accessibilityHint("Opens facility details")
    }

    private var facilityLoadingState: some View {
        HStack {
            ProgressView()
            Text("Finding nearby facilities…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func facilityErrorState(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "location.slash")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await facilityStore.refresh() }
            }
            .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var facilityEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cross.case")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No facilities found nearby")
                .font(.subheadline.weight(.medium))
            Text("Pull down to refresh or check your location settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Basic Life Support

    private var basicLifeSupportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basic Life Support")
                .font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            let columns = [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(BLSItem.all) { item in
                    Button {
                        blsDestination = item.destination
                    } label: {
                        BLSCard(item: item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title.replacingOccurrences(of: "\n", with: " "))
                    .accessibilityHint("Opens \(item.title.replacingOccurrences(of: "\n", with: " ")) guide")
                }
            }
        }
    }

    // MARK: - Helpers

    private func facilitySymbol(for jenis: String) -> String {
        let j = jenis.lowercased()
        if j.contains("klinik") || j.contains("puskesmas") { return "stethoscope" }
        if j.contains("mata") { return "eye.fill" }
        if j.contains("swasta") { return "cross.case.fill" }
        return "building.columns.fill"
    }
}

// MARK: - BLS model

enum BLSDestination: Hashable {
    case flow(Int, String)
    case steps(String, String)
}

struct BLSItem: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let destination: BLSDestination

    static let all: [BLSItem] = [
        BLSItem(id: "bls",        title: "Basic Life\nSupport",    symbol: "heart.fill",                  destination: .flow(1, "Basic Life Support")),
        BLSItem(id: "choking",    title: "Choking\nRelief",        symbol: "wind",                        destination: .flow(2, "Choking Relief")),
        BLSItem(id: "cpr_child",  title: "CPR Child\n& Baby",      symbol: "figure.2.and.child.holdinghands", destination: .flow(3, "CPR Child & Baby")),
        BLSItem(id: "wounds",     title: "Wounds\n& Bleeding",     symbol: "bandage.fill",                destination: .steps("LUKA", "Wound Care")),
        BLSItem(id: "allergy",    title: "Allergy &\nAnaphylaxis", symbol: "allergens",                   destination: .steps("ALERGI", "Allergy & Anaphylaxis")),
        BLSItem(id: "emergency",  title: "Emergency\nNumbers",     symbol: "phone.fill",                  destination: .steps("DARURAT", "Emergency Numbers")),
    ]
}

// MARK: - BLS card

private struct BLSCard: View {
    let item: BLSItem

    var body: some View {
        Color.clear
            .aspectRatio(1.05, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    VStack(alignment: .leading, spacing: 0) {
                        Image(systemName: item.symbol)
                            .resizable()
                            .scaledToFit()
                            .frame(width: side * 0.24, height: side * 0.24)
                            .foregroundStyle(.white)
                        Spacer(minLength: 0)
                        Text(item.title)
                            .font(.system(size: side * 0.115, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(side * 0.10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .background(Color(red: 0.16, green: 0.45, blue: 0.92))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - All facilities view

struct AllFacilitiesView: View {
    let store: HealthFacilityStore
    var onDone: () -> Void = {}

    @State private var presentedFacility: NearbyHealthFacility?

    var body: some View {
        ZStack {
            facilityList
                .blur(radius: presentedFacility == nil ? 0 : 14)
                .allowsHitTesting(presentedFacility == nil)

            if presentedFacility != nil {
                Rectangle()
                    .fill(.black.opacity(0.18))
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { presentedFacility = nil }
                    .accessibilityLabel("Close facility details")
                    .accessibilityAddTraits(.isButton)
            }

            if let facility = presentedFacility {
                APIFacilityDetailView(facility: facility) {
                    presentedFacility = nil
                }
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.88).combined(with: .opacity),
                        removal: .scale(scale: 0.94).combined(with: .opacity)
                    )
                )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: presentedFacility?.id)
        .navigationTitle("All Facilities")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(presentedFacility == nil ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            if presentedFacility == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }

    private var facilityList: some View {
        List(store.facilities) { facility in
            Button {
                presentedFacility = facility
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(.label).opacity(0.06))
                            .frame(width: 40, height: 40)
                        Image(systemName: facilitySymbol(for: facility.jenis))
                            .font(.system(size: 18))
                            .foregroundStyle(Color(.label))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(facility.nama)
                            .font(.headline)
                            .foregroundStyle(Color(.label))
                        Text(facility.jenis)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let alamat = facility.alamat {
                            Text(alamat)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                    if !store.distanceString(for: facility).isEmpty {
                        Text(store.distanceString(for: facility))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }

    private func facilitySymbol(for jenis: String) -> String {
        let j = jenis.lowercased()
        if j.contains("klinik") || j.contains("puskesmas") { return "stethoscope" }
        if j.contains("mata") { return "eye.fill" }
        if j.contains("swasta") { return "cross.case.fill" }
        return "building.columns.fill"
    }
}

#Preview {
    NavigationStack {
        DuringTravelView()
    }
}
