import Foundation

/// In-memory + UserDefaults-backed fake backend used while
/// `AppFlags.useDummyData == true`. None of this code runs in production.
enum DummyData {

    // MARK: - Nurses (returned by NurseService)

    static let nurses: [Nurse] = [
        Nurse(id: "n_001",
              name: "Made Suparna",
              experience: "8 years experience",
              baseRate: 250000,
              currencyCode: "IDR",
              avatarURL: nil,
              bio: "Specialised in elderly home care and post-op recovery."),
        Nurse(id: "n_002",
              name: "Putu Sari",
              experience: "5 years experience",
              baseRate: 200000,
              currencyCode: "IDR",
              avatarURL: nil,
              bio: "Pediatric nurse, fluent in English and Indonesian."),
        Nurse(id: "n_003",
              name: "Wayan Adi",
              experience: "10 years experience",
              baseRate: 300000,
              currencyCode: "IDR",
              avatarURL: nil,
              bio: "Wound care, IV therapy, and travel-medicine triage."),
        Nurse(id: "n_004",
              name: "Komang Dewi",
              experience: "4 years experience",
              baseRate: 180000,
              currencyCode: "IDR",
              avatarURL: nil,
              bio: "General home visits, vaccinations, hotel call-outs."),
        Nurse(id: "n_005",
              name: "Nyoman Bagus",
              experience: "12 years experience",
              baseRate: 350000,
              currencyCode: "IDR",
              avatarURL: nil,
              bio: "ICU-trained, emergency response, dive medicine."),
        Nurse(id: "n_006",
              name: "Kadek Lestari",
              experience: "6 years experience",
              baseRate: 220000,
              currencyCode: "IDR",
              avatarURL: nil,
              bio: "Maternity & newborn care, lactation support.")
    ]

    // MARK: - Appointments (UserDefaults-backed)

    private static let activeKey = "com.balitravelhealth.dummy.activeAppointment"

    /// Save the booking and return a fake confirmation with a generated id.
    static func recordAppointment(_ request: AppointmentRequest) -> AppointmentConfirmation {
        let id = "appt_\(Int(Date().timeIntervalSince1970))"
        let nurse = nurses.first { $0.id == request.nurseId } ?? nurses[0]
        let active = ActiveAppointment(
            id: id,
            nurseId: request.nurseId,
            nurseName: nurse.name,
            nurseAvatarURL: nurse.avatarURL,
            nurseWhatsApp: "+6281234567890",
            address: request.address,
            scheduledAt: request.scheduledAt
        )
        if let data = try? JSONEncoder.iso.encode(active) {
            UserDefaults.standard.set(data, forKey: activeKey)
        }
        return AppointmentConfirmation(appointmentId: id)
    }

    static func loadActiveAppointment() -> ActiveAppointment? {
        guard let data = UserDefaults.standard.data(forKey: activeKey) else { return nil }
        return try? JSONDecoder.iso.decode(ActiveAppointment.self, from: data)
    }

    static func clearActiveAppointment() {
        UserDefaults.standard.removeObject(forKey: activeKey)
    }
}

private extension JSONEncoder {
    static let iso: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder {
    static let iso: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
