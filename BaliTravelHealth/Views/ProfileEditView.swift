import SwiftUI

/// Edit screen for the user's profile. Saves locally first, then syncs to the
/// server in the background so the UI never blocks on the network.
struct ProfileEditView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var countryCode: String?
    @State private var dateOfBirth: Date?
    @State private var gender: Gender?

    @State private var showCountryPicker = false
    @State private var showDatePicker = false
    @State private var showGenderPicker = false
    @FocusState private var nameFocused: Bool

    private let nameMaxLength = 64

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && countryCode != nil
            && dateOfBirth != nil
            && gender != nil
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Your Name", text: $name)
                    .textContentType(.name)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onChange(of: name) { _, newValue in
                        if newValue.count > nameMaxLength {
                            name = String(newValue.prefix(nameMaxLength))
                        }
                    }
            }

            Section("Country of Residence") {
                Button {
                    nameFocused = false
                    showCountryPicker = true
                } label: {
                    LabeledContent {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } label: {
                        Text(countryCode.map { Locale.current.localizedString(forRegionCode: $0) ?? $0 } ?? "Select country")
                            .foregroundStyle(countryCode == nil ? Color(.placeholderText) : Color(.label))
                    }
                }
                .buttonStyle(.plain)
            }

            Section("Date of Birth") {
                Button {
                    nameFocused = false
                    showDatePicker = true
                } label: {
                    LabeledContent {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                    } label: {
                        Text(dateOfBirth.map { $0.formatted(date: .long, time: .omitted) } ?? "Select date")
                            .foregroundStyle(dateOfBirth == nil ? Color(.placeholderText) : Color(.label))
                    }
                }
                .buttonStyle(.plain)
            }

            Section("Gender") {
                Button {
                    nameFocused = false
                    showGenderPicker = true
                } label: {
                    LabeledContent {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } label: {
                        Text(gender?.displayName ?? "Select gender")
                            .foregroundStyle(gender == nil ? Color(.placeholderText) : Color(.label))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
            }
        }
        .onAppear(perform: prefillFromStore)
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerSheet(selection: $countryCode)
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selection: $dateOfBirth)
        }
        .sheet(isPresented: $showGenderPicker) {
            GenderPickerSheet(selection: $gender)
        }
    }

    // MARK: - Actions

    private func prefillFromStore() {
        guard let p = profileStore.profile else { return }
        name = p.name
        countryCode = p.countryCode
        dateOfBirth = p.dateOfBirth
        gender = p.gender
    }

    private func save() {
        guard let countryCode, let dateOfBirth, let gender else { return }
        let updated = UserProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            countryCode: countryCode,
            dateOfBirth: dateOfBirth,
            gender: gender
        )
        profileStore.saveProfile(updated)               // local-first
        Task { await profileStore.syncToServer() }      // server in background
        dismiss()
    }
}
