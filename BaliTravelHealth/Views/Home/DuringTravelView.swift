import SwiftUI
import SwiftData
import CoreLocation

struct DuringTravelView: View {
    @Query(sort: \HealthcareFacility.name) private var allFacilities: [HealthcareFacility]
    @Namespace private var morphNamespace
    @State private var blsSelection: BasicLifeSupportItem?
    @State private var presentedFacility: HealthcareFacility?
    @State private var showAllFacilities = false

    /// Reference point for "near you" sorting until CoreLocation is wired up.
    /// Default is Denpasar; swap with the live `CLLocationManager` location later.
    private let referenceLocation = CLLocation(latitude: -8.6705, longitude: 115.2126)

    private var nearestFacilities: [(HealthcareFacility, Double)] {
        allFacilities
            .map { ($0, $0.distance(from: referenceLocation)) }
            .sorted { $0.1 < $1.1 }
    }

    private var top4: [(HealthcareFacility, Double)] {
        Array(nearestFacilities.prefix(4))
    }

    var body: some View {
        ZStack {
            // Underlying screen — stays mounted, blurs while the card is open.
            mainContent
                .blur(radius: presentedFacility == nil ? 0 : 14)
                .allowsHitTesting(presentedFacility == nil)

            // Dimming layer
            if presentedFacility != nil {
                Rectangle()
                    .fill(.black.opacity(0.18))
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { closeFacility() }
                    .accessibilityLabel("Close facility details")
                    .accessibilityAddTraits(.isButton)
            }

            // Foreground card
            if let facility = presentedFacility {
                FacilityDetailView(facility: facility) { closeFacility() }
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.88).combined(with: .opacity),
                            removal: .scale(scale: 0.94).combined(with: .opacity)
                        )
                    )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: presentedFacility?.persistentModelID)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAllFacilities) {
            NavigationStack {
                AllFacilitiesPlaceholder(onDone: { showAllFacilities = false })
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .navigationDestination(item: $blsSelection) { item in
            BasicLifeSupportPlaceholder(item: item)
                .navigationTransition(.zoom(sourceID: item.id, in: morphNamespace))
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
    }

    private func closeFacility() {
        presentedFacility = nil
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

            Group {
                if allFacilities.isEmpty {
                    facilityEmptyState
                } else {
                    VStack(spacing: 10) {
                        ForEach(top4, id: \.0.persistentModelID) { facility, distance in
                            facilityRow(facility, distance: distance)
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

    private func facilityRow(_ facility: HealthcareFacility, distance: Double) -> some View {
        Button {
            presentedFacility = facility
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(.label).opacity(0.06))
                        .frame(width: 44, height: 44)
                    Image(systemName: facility.type.iconName)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Color(.label))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(facility.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                    Text(facility.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text(formattedDistance(km: distance))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(facility.name), \(facility.specialty)")
        .accessibilityValue(formattedDistance(km: distance))
        .accessibilityHint("Opens facility details")
    }

    private var facilityEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cross.case")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No facilities loaded yet")
                .font(.subheadline.weight(.medium))
            Text("Pull to refresh or relaunch the app to seed the directory.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func formattedDistance(km: Double) -> String {
        if km < 1 {
            return String(format: "%.0f m", km * 1000)
        }
        return String(format: "%.1f km", km)
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
                ForEach(BasicLifeSupportItem.all) { item in
                    Button {
                        blsSelection = item
                    } label: {
                        BLSCard(item: item)
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: item.id, in: morphNamespace)
                    .accessibilityLabel(item.title)
                    .accessibilityHint("Opens \(item.title) guide")
                }
            }
        }
    }
}

// MARK: - Basic Life Support model

struct BasicLifeSupportItem: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String

    // TODO: replace with the real BLS topics. Each routes to its own placeholder
    // destination today; swap the destination view when the real screens are built.
    static let all: [BasicLifeSupportItem] = [
        BasicLifeSupportItem(id: "cpr",       title: "CPR",                  symbol: "heart.fill"),
        BasicLifeSupportItem(id: "choking",   title: "Choking Relief",       symbol: "wind"),
        BasicLifeSupportItem(id: "bleeding",  title: "Bleeding Control",     symbol: "bandage.fill"),
        BasicLifeSupportItem(id: "burns",     title: "Burns",                symbol: "flame.fill"),
        BasicLifeSupportItem(id: "fracture",  title: "Fractures",            symbol: "figure.fall"),
        BasicLifeSupportItem(id: "shock",     title: "Shock",                symbol: "bolt.heart.fill")
    ]
}

private struct BLSCard: View {
    let item: BasicLifeSupportItem

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

// MARK: - Routes & placeholders

struct AllFacilitiesPlaceholder: View {
    var onDone: () -> Void = {}

    @Query(sort: \HealthcareFacility.name) private var facilities: [HealthcareFacility]
    @State private var presentedFacility: HealthcareFacility?

    var body: some View {
        ZStack {
            list
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
                FacilityDetailView(facility: facility) {
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
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: presentedFacility?.persistentModelID)
        .navigationTitle("All Facilities")
        .navigationBarTitleDisplayMode(.inline)
        // Hide the entire nav bar (Done button included) while the card is up,
        // leaving only the card's own X button visible.
        .toolbar(presentedFacility == nil ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            if presentedFacility == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }

    private var list: some View {
        List(facilities, id: \.persistentModelID) { facility in
            Button {
                presentedFacility = facility
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(.label).opacity(0.06))
                            .frame(width: 40, height: 40)
                        Image(systemName: facility.type.iconName)
                            .font(.system(size: 18))
                            .foregroundStyle(Color(.label))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(facility.name)
                            .font(.headline)
                            .foregroundStyle(Color(.label))
                        Text(facility.specialty)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(facility.address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }
}

struct BasicLifeSupportPlaceholder: View {
    let item: BasicLifeSupportItem

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: item.symbol)
                .font(.system(size: 56))
                .foregroundStyle(Color(red: 0.16, green: 0.45, blue: 0.92))
            Text(item.title)
                .font(.title.weight(.bold))
            Text("Step-by-step guidance coming soon.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DuringTravelView()
            .modelContainer(for: HealthcareFacility.self, inMemory: true)
    }
}
