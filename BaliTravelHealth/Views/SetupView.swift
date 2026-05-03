import SwiftUI

struct SetupView: View {
    var onContinue: () -> Void = {}

    @Environment(ProfileStore.self) private var profileStore

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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(spacing: 14) {
                    nameField
                    countryField
                    dateField
                    genderField
                }

                nextButton
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
        .scrollDismissesKeyboard(.interactively)
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

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Let's Get Started")
                .font(.system(size: 34, weight: .bold))
                .accessibilityAddTraits(.isHeader)

            Text("Before that, we need to know some of your information. This information will be used to maximize your personal experience.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Fields

    private var nameField: some View {
        CapsuleFieldContainer {
            TextField("Your Name", text: $name)
                .textContentType(.name)
                .autocorrectionDisabled()
                .focused($nameFocused)
                .submitLabel(.done)
                .onChange(of: name) { _, newValue in
                    if newValue.count > nameMaxLength {
                        name = String(newValue.prefix(nameMaxLength))
                    }
                }
                .accessibilityLabel("Your name")
                .accessibilityHint("Up to \(nameMaxLength) characters")
        }
    }

    private var countryField: some View {
        SelectableCapsuleField(
            placeholder: "Country of Residence",
            value: countryCode.map { Locale.current.localizedString(forRegionCode: $0) ?? $0 },
            systemImage: "chevron.down"
        ) {
            nameFocused = false
            showCountryPicker = true
        }
    }

    private var dateField: some View {
        SelectableCapsuleField(
            placeholder: "Date of Birth",
            value: dateOfBirth.map { $0.formatted(date: .long, time: .omitted) },
            systemImage: "calendar"
        ) {
            nameFocused = false
            showDatePicker = true
        }
    }

    private var genderField: some View {
        SelectableCapsuleField(
            placeholder: "Gender",
            value: gender?.displayName,
            systemImage: "chevron.down"
        ) {
            nameFocused = false
            showGenderPicker = true
        }
    }

    // MARK: - Next button

    private var nextButton: some View {
        Button {
            submit()
        } label: {
            Text("Next")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isFormValid ? Color(.systemBackground) : Color(.tertiaryLabel))
                .padding(.horizontal, 44)
                .padding(.vertical, 14)
                .background(nextButtonBackground)
        }
        .buttonStyle(.plain)
        .disabled(!isFormValid)
        .animation(.easeInOut(duration: 0.2), value: isFormValid)
        .accessibilityHint(isFormValid ? "Saves your information" : "Fill in all fields to continue")
    }

    @ViewBuilder
    private var nextButtonBackground: some View {
        if #available(iOS 26, *), isFormValid {
            Capsule()
                .fill(Color(.label))
                .glassEffect(.regular.tint(Color(.label)), in: Capsule())
        } else {
            Capsule()
                .fill(isFormValid ? Color(.label) : Color(.systemGray5))
        }
    }

    private func submit() {
        guard let countryCode, let dateOfBirth, let gender else { return }
        let profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            countryCode: countryCode,
            dateOfBirth: dateOfBirth,
            gender: gender
        )
        profileStore.saveProfile(profile)
        onContinue()
    }
}

// MARK: - Field Containers

/// Pill-shaped container. Uses Liquid Glass on iOS 26+, stroke fallback on earlier OS.
struct CapsuleFieldContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 26, *) {
            content
                .padding(.horizontal, 20)
                .frame(height: 56)
                .glassEffect(.regular, in: Capsule())
        } else {
            content
                .padding(.horizontal, 20)
                .frame(height: 56)
                .background(
                    Capsule()
                        .stroke(Color(.separator), lineWidth: 1)
                )
        }
    }
}

struct SelectableCapsuleField: View {
    let placeholder: String
    let value: String?
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(value ?? placeholder)
                    .font(.body)
                    .foregroundStyle(value == nil ? Color(.placeholderText) : Color(.label))
                    .lineLimit(1)
                Spacer()
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(CapsuleFieldStyleModifier())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(placeholder)
        .accessibilityValue(value ?? "Not set")
        .accessibilityAddTraits(.isButton)
    }
}

private struct CapsuleFieldStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .padding(.horizontal, 20)
                .frame(height: 56)
                .glassEffect(.regular, in: Capsule())
        } else {
            content
                .padding(.horizontal, 20)
                .frame(height: 56)
                .background(
                    Capsule()
                        .stroke(Color(.separator), lineWidth: 1)
                )
        }
    }
}

// MARK: - Country Picker

struct CountryPickerSheet: View {
    @Binding var selection: String?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private let countries: [Country] = {
        Locale.Region.isoRegions
            .filter { $0.subRegions.isEmpty } // exclude continents/groupings
            .compactMap { region -> Country? in
                guard let name = Locale.current.localizedString(forRegionCode: region.identifier) else {
                    return nil
                }
                return Country(code: region.identifier, name: name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }()

    private var filtered: [Country] {
        guard !query.isEmpty else { return countries }
        return countries.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { country in
                Button {
                    selection = country.code
                    dismiss()
                } label: {
                    HStack {
                        Text(country.flag)
                        Text(country.name)
                            .foregroundStyle(Color(.label))
                        Spacer()
                        if selection == country.code {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search country")
            .navigationTitle("Country of Residence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    struct Country: Identifiable, Hashable {
        let code: String
        let name: String
        var id: String { code }
        var flag: String {
            code.uppercased().unicodeScalars.compactMap {
                UnicodeScalar(127397 + $0.value)
            }.map(String.init).joined()
        }
    }
}

// MARK: - Date Picker

struct DatePickerSheet: View {
    @Binding var selection: Date?
    @Environment(\.dismiss) private var dismiss
    @State private var localSelection: Date

    init(selection: Binding<Date?>) {
        self._selection = selection
        let initial = selection.wrappedValue ?? Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
        self._localSelection = State(initialValue: initial)
    }

    private var range: ClosedRange<Date> {
        let cal = Calendar.current
        let now = Date()
        let lower = cal.date(byAdding: .year, value: -120, to: now) ?? now
        return lower...now
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Date of Birth",
                    selection: $localSelection,
                    in: range,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()

                Spacer()
            }
            .navigationTitle("Date of Birth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selection = localSelection
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Gender Picker

struct GenderPickerSheet: View {
    @Binding var selection: Gender?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Gender.allCases) { option in
                    Button {
                        selection = option
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: selection == option ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(selection == option ? Color.accentColor : Color(.tertiaryLabel))
                            Text(option.displayName)
                                .foregroundStyle(Color(.label))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Gender")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    SetupView()
        .environment(ProfileStore())
}
