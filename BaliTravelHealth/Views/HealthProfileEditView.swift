import SwiftUI

struct HealthProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var service = HealthProfileService.shared

    @State private var heightCm: String = ""
    @State private var weightKg: String = ""
    @State private var bloodType: GolonganDarah? = nil
    @State private var allergies: String = ""

    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        Form {
            Section("Body Measurements") {
                LabeledContent("Height (cm)") {
                    TextField("e.g. 170", text: $heightCm)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Weight (kg)") {
                    TextField("e.g. 65", text: $weightKg)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Blood Type") {
                Picker("Blood Type", selection: $bloodType) {
                    Text("Not set").tag(Optional<GolonganDarah>.none)
                    ForEach(GolonganDarah.allCases) { type in
                        Text(type.rawValue).tag(Optional(type))
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Allergies") {
                TextField("e.g. Penicillin, peanuts", text: $allergies, axis: .vertical)
                    .lineLimit(3...5)
            }

            if let error = saveError {
                Section {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Health Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") { Task { await save() } }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear { prefill() }
        .onChange(of: service.profile) { _, _ in prefill() }
        .task { await service.fetch() }
    }

    private func prefill() {
        guard let p = service.profile else { return }
        heightCm   = p.tinggiCm.map { String($0) } ?? ""
        weightKg   = p.beratKg.map { String($0) } ?? ""
        bloodType  = p.golonganDarah
        allergies  = p.riwayatAlergi ?? ""
    }

    private func save() async {
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        let payload = HealthProfileRequest(
            tanggalLahir: SQLDateFormatter.normalizedString(from: service.profile?.tanggalLahir),
            jenisKelamin: service.profile?.jenisKelamin,
            tinggiCm:     Double(heightCm.trimmingCharacters(in: .whitespaces)),
            beratKg:      Double(weightKg.trimmingCharacters(in: .whitespaces)),
            golonganDarah: bloodType,
            riwayatAlergi: allergies.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        do {
            try await service.save(payload)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

#Preview {
    NavigationStack {
        HealthProfileEditView()
    }
}
