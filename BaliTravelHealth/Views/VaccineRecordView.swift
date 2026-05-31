import SwiftUI

struct VaccineRecordView: View {
    @State private var service = VaccinationService.shared
    @State private var showAddSheet = false
    @State private var deleteError: String?

    var body: some View {
        Group {
            if service.isLoading && service.vaccinations.isEmpty {
                loadingView
            } else if let error = service.lastError, service.vaccinations.isEmpty {
                errorView(message: error)
            } else if service.vaccinations.isEmpty {
                emptyView
            } else {
                vaccineList
            }
        }
        .navigationTitle("Vaccine Records")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add vaccination")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                AddVaccineView { payload in
                    try await service.add(payload)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Delete Failed", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        .task {
            await service.fetch()
        }
        .refreshable {
            await service.fetch()
        }
    }

    private var vaccineList: some View {
        List {
            ForEach(service.vaccinations) { vaccine in
                VaccineRow(vaccine: vaccine)
            }
            .onDelete { indexSet in
                Task { await delete(at: indexSet) }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func delete(at offsets: IndexSet) async {
        for index in offsets {
            let id = service.vaccinations[index].id
            do {
                try await service.delete(id: id)
            } catch {
                deleteError = error.localizedDescription
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading records…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Couldn't load records")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await service.fetch() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "syringe")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(Color(red: 0.16, green: 0.45, blue: 0.92).opacity(0.7))
            Text("No vaccination records")
                .font(.title3.weight(.bold))
            Text("Tap + to add your first vaccination record.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Vaccination") {
                showAddSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.16, green: 0.45, blue: 0.92))
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Vaccine row

private struct VaccineRow: View {
    let vaccine: Vaccination

    private var formattedDate: String {
        let iso = DateFormatter()
        iso.dateFormat = "yyyy-MM-dd"
        iso.timeZone = TimeZone(secondsFromGMT: 0)
        let display = DateFormatter()
        display.dateStyle = .medium
        if let date = iso.date(from: vaccine.tanggal) {
            return display.string(from: date)
        }
        return vaccine.tanggal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(vaccine.jenisVaksin)
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                Spacer()
                if let dosis = vaccine.dosis, !dosis.isEmpty {
                    Text(dosis)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.16, green: 0.45, blue: 0.92))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color(red: 0.16, green: 0.45, blue: 0.92).opacity(0.12))
                        )
                }
            }
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let catatan = vaccine.catatan, !catatan.isEmpty {
                Text(catatan)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(vaccine.jenisVaksin), \(vaccine.dosis ?? ""), \(formattedDate)")
    }
}

// MARK: - Add vaccine sheet

private struct AddVaccineView: View {
    /// Async throwing closure — called with the payload; throws on failure.
    let onSave: (VaccinationRequest) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var jenisVaksin = ""
    @State private var tanggal = Date()
    @State private var dosis = ""
    @State private var catatan = ""
    @State private var isSaving = false
    @State private var saveError: String?

    private var isValid: Bool {
        !jenisVaksin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("Vaccine") {
                TextField("Vaccine name (e.g. Hepatitis A)", text: $jenisVaksin)
                    .textContentType(.none)
            }

            Section("Date") {
                DatePicker("Date given", selection: $tanggal, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }

            Section("Dose (optional)") {
                TextField("e.g. Dose 1, Booster", text: $dosis)
            }

            Section("Notes (optional)") {
                TextField("Any notes…", text: $catatan, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }

            if let error = saveError {
                Section {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Add Vaccination")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") { Task { await save() } }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private func save() async {
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let payload = VaccinationRequest(
            jenisVaksin: jenisVaksin.trimmingCharacters(in: .whitespacesAndNewlines),
            tanggal: formatter.string(from: tanggal),
            dosis: dosis.isEmpty ? nil : dosis,
            catatan: catatan.isEmpty ? nil : catatan
        )
        do {
            try await onSave(payload)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { VaccineRecordView() }
}
