import Foundation
import SwiftData
import CoreLocation

// MARK: - Facility Type Enum

enum FacilityType: String, Codable, CaseIterable, Identifiable {
    case government = "GOVERNMENT"
    case privateHospital = "PRIVATE"
    case clinic = "CLINIC"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .government: return "RS Pemerintah"
        case .privateHospital: return "RS Swasta"
        case .clinic: return "Klinik"
        }
    }

    var displayNameEN: String {
        switch self {
        case .government: return "Government Hospital"
        case .privateHospital: return "Private Hospital"
        case .clinic: return "Clinic"
        }
    }

    /// SF Symbol name for map annotation / list icon
    var iconName: String {
        switch self {
        case .government: return "building.columns.fill"
        case .privateHospital: return "cross.case.fill"
        case .clinic: return "stethoscope"
        }
    }
}

// MARK: - SwiftData Model

/// Represents a BMTA-listed healthcare facility in Bali.
///
/// Data sources: official hospital websites, Australian Embassy Bali Medical List,
/// US Embassy Medical Assistance Indonesia, SIRS Kemkes, and verified third-party directories.
///
/// - Note: Coordinates are approximate (~100–200 m accuracy).
///   Verify with MapKit geocoding or Google Maps Places API before production use.
///
/// Schema version: 2 — includes operating hours fields.
@Model
final class HealthcareFacility {

    // MARK: - Core Fields

    /// Short display name (e.g. "BIMC Hospital Kuta")
    var name: String

    /// Full official name in Indonesian
    var officialName: String

    /// Primary specialty / reason listed in BMTA
    var specialty: String

    /// Facility category: GOVERNMENT / PRIVATE / CLINIC
    var typeRawValue: String

    var address: String

    /// Primary phone number (international format +62 XXX XXXXXXX)
    var phone: String

    /// Secondary / emergency / WhatsApp number
    var phoneAlt: String?

    var website: String?
    var email: String?

    var latitude: Double
    var longitude: Double

    // MARK: - Operating Hours

    /// True if emergency / IGD unit operates 24 hours, 7 days a week.
    /// Even if true, outpatient clinics may have separate limited hours.
    var isOpen24Hours: Bool

    /// Outpatient / polyclinic hours in human-readable format.
    /// Multiple lines separated by `\n`.
    ///
    /// Example:
    /// ```
    /// Senin–Kamis: 07.30–16.00 WITA
    /// Jumat: 07.30–13.00 WITA
    /// IGD: 24 jam
    /// ```
    ///
    /// Prefix with "⚠️ " if hours are estimated / not officially confirmed.
    var outpatientHours: String?

    /// Emergency / IGD hours string.
    /// Typically "24 jam / 7 hari" for hospitals; nil for clinics without IGD.
    var emergencyHours: String?

    /// Brief one-line summary of hours for display in list cards.
    /// Example: "IGD 24 jam | Poli: Sen–Jum 07.30–16.00"
    var hoursSummary: String?

    /// Brief notes on services relevant to tourists
    var notes: String?

    // MARK: - Computed Properties

    /// Typed enum accessor (stored as rawValue String for SwiftData compatibility)
    var type: FacilityType {
        get { FacilityType(rawValue: typeRawValue) ?? .privateHospital }
        set { typeRawValue = newValue.rawValue }
    }

    /// CoreLocation coordinate
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// CLLocation for distance calculations
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    /// Phone number formatted for `tel:` URL scheme
    var phoneURL: URL? {
        let cleaned = phone.replacingOccurrences(of: " ", with: "")
        return URL(string: "tel:\(cleaned)")
    }

    /// WhatsApp deep link for phoneAlt (if available)
    var whatsAppURL: URL? {
        guard let alt = phoneAlt else { return nil }
        let cleaned = alt
            .replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        return URL(string: "https://wa.me/\(cleaned)")
    }

    /// Website URL object
    var websiteURL: URL? {
        guard let urlString = website else { return nil }
        return URL(string: urlString)
    }

    /// Apple Maps URL for "Open in Maps" action
    var appleMapsURL: URL? {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        return URL(string: "http://maps.apple.com/?q=\(encodedName)&ll=\(latitude),\(longitude)&z=17")
    }

    /// Google Maps URL for "Open in Google Maps" action
    var googleMapsURL: URL? {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        return URL(string: "https://www.google.com/maps/search/?api=1&query=\(latitude),\(longitude)&query_place_id=\(encodedName)")
    }

    // MARK: - Initializer

    init(
        name: String,
        officialName: String,
        specialty: String,
        type: FacilityType,
        address: String,
        phone: String,
        phoneAlt: String? = nil,
        website: String? = nil,
        email: String? = nil,
        latitude: Double,
        longitude: Double,
        isOpen24Hours: Bool = false,
        outpatientHours: String? = nil,
        emergencyHours: String? = nil,
        hoursSummary: String? = nil,
        notes: String? = nil
    ) {
        self.name = name
        self.officialName = officialName
        self.specialty = specialty
        self.typeRawValue = type.rawValue
        self.address = address
        self.phone = phone
        self.phoneAlt = phoneAlt
        self.website = website
        self.email = email
        self.latitude = latitude
        self.longitude = longitude
        self.isOpen24Hours = isOpen24Hours
        self.outpatientHours = outpatientHours
        self.emergencyHours = emergencyHours
        self.hoursSummary = hoursSummary
        self.notes = notes
    }
}

// MARK: - Distance Helper

extension HealthcareFacility {

    /// Calculate distance from a given location in kilometers.
    func distance(from userLocation: CLLocation) -> Double {
        let facilityLocation = CLLocation(latitude: latitude, longitude: longitude)
        return facilityLocation.distance(from: userLocation) / 1000.0 // meters → km
    }

    /// Formatted distance string (e.g. "2.3 km" or "850 m")
    func formattedDistance(from userLocation: CLLocation) -> String {
        let distKm = distance(from: userLocation)
        if distKm < 1.0 {
            return String(format: "%.0f m", distKm * 1000)
        } else {
            return String(format: "%.1f km", distKm)
        }
    }
}
