import Foundation

@MainActor
@Observable
final class NurseService {
    static let shared = NurseService()

    private(set) var nurses: [Nurse] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    // MARK: - Cache injection (called by AppLaunchCoordinator)

    func setNurses(_ list: [Nurse]) {
        nurses = list
    }

    // MARK: - Refresh

    func refresh() async {
        // Warm from cache immediately if empty
        if nurses.isEmpty, let cached = try? await LocalDataCache.shared.loadNurses() {
            nurses = cached
        }
        guard NetworkMonitor.shared.isConnected else { return }

        isLoading = true
        defer { isLoading = false }
        lastError = nil
        do {
            nurses = try await fetchAll()
            try? await LocalDataCache.shared.saveNurses(nurses)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Network fetch

    private func fetchAll() async throws -> [Nurse] {
        if AppFlags.useDummyData {
            try? await Task.sleep(nanoseconds: 250_000_000)
            return DummyData.nurses
        }

        let req = BaliAPI.authedRequest("nurses")
        let nurses = try await BaliAPI.performArray(req, of: APINurse.self)
        return nurses.map { n in
            Nurse(
                id: String(n.id),
                name: n.namaLengkap,
                experience: n.sertifikasi,
                baseRate: 0,
                currencyCode: "IDR",
                avatarURL: nil,
                bio: n.nomorLisensi.map { "License: \($0)" }
            )
        }
    }

    private struct APINurse: Decodable {
        let id: Int
        let namaLengkap: String
        let nomorLisensi: String?
        let sertifikasi: String
    }
}
