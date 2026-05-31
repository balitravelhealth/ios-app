import Foundation

struct AppointmentAPIClient: Sendable {
    static let shared = AppointmentAPIClient()

    // POST /nursing/appointments
    func submit(_ payload: AppointmentRequest) async throws -> AppointmentConfirmation {
        if AppFlags.useDummyData {
            try? await Task.sleep(nanoseconds: 700_000_000)
            return DummyData.recordAppointment(payload)
        }

        let nurseIdInt = Int(payload.nurseId) ?? 0
        let nursingPayload = NursingAppointmentRequest(
            nurseId: nurseIdInt,
            tanggalKunjungan: payload.scheduledAt
        )

        var req = BaliAPI.authedRequest("nursing/appointments", method: "POST")
        req.httpBody = try BaliAPI.encoder.encode(nursingPayload)

        do {
            let (data, status) = try await BaliAPI.perform(req)
            guard (200..<300).contains(status) else {
                throw AppointmentError.server(status)
            }
            let record = try BaliAPI.decode(NursingRecord.self, from: data)
            return AppointmentConfirmation(appointmentId: String(record.id))
        } catch let error as AppointmentError {
            throw error
        } catch {
            throw AppointmentError(from: error)
        }
    }

    /// Fetches the user's nursing records and returns the most recent future visit,
    /// or nil if there are none.
    func fetchActive() async throws -> ActiveAppointment? {
        if AppFlags.useDummyData {
            return DummyData.loadActiveAppointment()
        }

        do {
            let req = BaliAPI.authedRequest("nursing/my-records")
            let (data, status) = try await BaliAPI.perform(req)
            if status == 204 || status == 404 { return nil }
            guard (200..<300).contains(status) else {
                throw AppointmentError.server(status)
            }
            if data.isEmpty { return nil }

            let records = try BaliAPI.decodeArray(NursingRecord.self, from: data)
            guard let record = records.first else { return nil }

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let scheduledDate = iso.date(from: record.tanggalKunjungan)
                ?? ISO8601DateFormatter().date(from: record.tanggalKunjungan)
                ?? Date()

            let nurseId = record.nurseId ?? 0
            let nurseName: String
            if let cached = NurseService.shared.nurses.first(where: { $0.id == String(nurseId) }) {
                nurseName = cached.name
            } else {
                nurseName = "Nurse #\(nurseId)"
            }

            return ActiveAppointment(
                id: String(record.id),
                nurseId: String(nurseId),
                nurseName: nurseName,
                nurseAvatarURL: nil,
                nurseWhatsApp: "",
                address: "",
                scheduledAt: scheduledDate
            )
        } catch let error as AppointmentError {
            throw error
        } catch {
            throw AppointmentError(from: error)
        }
    }

    /// Fetches the full list of nursing records for the current user.
    func fetchMyRecords() async throws -> [NursingRecord] {
        let req = BaliAPI.authedRequest("nursing/my-records")
        let (data, status) = try await BaliAPI.perform(req)
        guard (200..<300).contains(status) else {
            throw AppointmentError.server(status)
        }
        return try BaliAPI.decodeArray(NursingRecord.self, from: data)
    }
}
