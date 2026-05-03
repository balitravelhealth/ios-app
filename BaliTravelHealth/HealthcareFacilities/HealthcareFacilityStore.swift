import Foundation
import SwiftData
import CoreLocation

/// Repository-style store for querying healthcare facilities from SwiftData.
///
/// All query methods are designed to be called from `@MainActor` (SwiftUI) context.
/// For background work, use `ModelActor` instead.
@MainActor
final class HealthcareFacilityStore {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Fetch All

    func allFacilities(sortedBy sort: SortOption = .name) -> [HealthcareFacility] {
        var descriptor = FetchDescriptor<HealthcareFacility>()
        switch sort {
        case .name:
            descriptor.sortBy = [SortDescriptor(\.name)]
        case .type:
            descriptor.sortBy = [SortDescriptor(\.typeRawValue), SortDescriptor(\.name)]
        }
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Fetch by Type

    func facilities(ofType type: FacilityType) -> [HealthcareFacility] {
        let rawValue = type.rawValue
        let predicate = #Predicate<HealthcareFacility> { $0.typeRawValue == rawValue }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.name)]
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Search

    func search(query: String) -> [HealthcareFacility] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return allFacilities()
        }

        let q = query.lowercased()
        let predicate = #Predicate<HealthcareFacility> {
            $0.name.localizedStandardContains(q) ||
            $0.specialty.localizedStandardContains(q) ||
            $0.address.localizedStandardContains(q) ||
            $0.officialName.localizedStandardContains(q)
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.name)]
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Specialty Filter

    func facilities(withSpecialtyContaining keyword: String) -> [HealthcareFacility] {
        let predicate = #Predicate<HealthcareFacility> {
            $0.specialty.localizedStandardContains(keyword)
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.name)]
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - 24 Hour Facilities

    func twentyFourHourFacilities() -> [HealthcareFacility] {
        let predicate = #Predicate<HealthcareFacility> { $0.isOpen24Hours == true }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.name)]
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Nearest Facilities (sorted by distance)

    func nearestFacilities(
        from location: CLLocation,
        maxDistanceKm: Double = .greatestFiniteMagnitude,
        type: FacilityType? = nil
    ) -> [(facility: HealthcareFacility, distanceKm: Double)] {

        let all: [HealthcareFacility]
        if let type {
            all = facilities(ofType: type)
        } else {
            all = allFacilities()
        }

        return all
            .map { facility in
                let dist = facility.distance(from: location)
                return (facility: facility, distanceKm: dist)
            }
            .filter { $0.distanceKm <= maxDistanceKm }
            .sorted { $0.distanceKm < $1.distanceKm }
    }

    // MARK: - Count

    func count() -> Int {
        let descriptor = FetchDescriptor<HealthcareFacility>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    // MARK: - CRUD

    func insert(_ facility: HealthcareFacility) {
        modelContext.insert(facility)
        try? modelContext.save()
    }

    func delete(_ facility: HealthcareFacility) {
        modelContext.delete(facility)
        try? modelContext.save()
    }

    func deleteAll() {
        try? modelContext.delete(model: HealthcareFacility.self)
        try? modelContext.save()
    }

    // MARK: - Re-seed

    /// Delete all data and re-insert from seeder.
    func reseed() {
        deleteAll()
        DatabaseSeeder.seedIfNeeded(modelContext: modelContext)
    }

    // MARK: - Sort Options

    enum SortOption {
        case name
        case type
    }
}
