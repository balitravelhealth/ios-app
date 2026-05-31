import Foundation

/// Holds the user's active appointment for the Nursing Care screen.
@MainActor
@Observable
final class AppointmentService {
    static let shared = AppointmentService()

    private(set) var active: ActiveAppointment?
    private(set) var isLoading = false
    private(set) var lastError: AppointmentError?

    /// Re-fetch the active appointment from the server. Silently swallows
    /// `nil` so the UI just falls back to the nurse list.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await AppointmentAPIClient.shared.fetchActive()
            // Drop the appointment locally once it's past its 1-day grace
            // window so the screen reverts to the nurse list.
            if let appt = fetched, !appt.isStillVisible {
                if AppFlags.useDummyData {
                    DummyData.clearActiveAppointment()
                }
                active = nil
            } else {
                active = fetched
            }
            lastError = nil
        } catch let error as AppointmentError {
            lastError = error
            // Keep any previously fetched appointment on transient errors.
        } catch {
            lastError = AppointmentError(from: error)
        }
    }

    /// Clear the cache, e.g. after sign-out or after the user cancels a booking.
    func clear() {
        active = nil
        lastError = nil
    }
}
