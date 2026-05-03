import SwiftUI
import CoreLocation

struct NurseDetailView: View {
    let nurse: Nurse
    var onClose: (() -> Void)? = nil
    var onConfirmed: ((AppointmentConfirmation) -> Void)? = nil

    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.dismiss) private var dismiss

    // MARK: - Form state
    @State private var address: String = ""
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var scheduledAt: Date?
    @State private var description: String = ""

    @State private var showAddressSheet = false
    @State private var showSchedulePicker = false

    // MARK: - Submission state
    @State private var isSubmitting = false
    @State private var submissionError: AppointmentError?
    @State private var confirmation: AppointmentConfirmation?

    private let descriptionLimit = 255

    private var trimmedAddress: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFormValid: Bool {
        !trimmedAddress.isEmpty
            && coordinate != nil
            && scheduledAt != nil
            && !trimmedDescription.isEmpty
            && trimmedDescription.count <= descriptionLimit
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroAvatar
                    .frame(maxWidth: .infinity)
                identitySection
                fieldsSection
                descriptionSection
                bookButton
                Color.clear.frame(height: 16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .top)
        .scrollDismissesKeyboard(.interactively)
        .overlay(alignment: .topLeading) { closeButton }
        .sheet(isPresented: $showAddressSheet) {
            AddressPickerSheet(address: $address, coordinate: $coordinate)
        }
        .sheet(isPresented: $showSchedulePicker) {
            AppointmentSchedulePickerSheet(
                selection: $scheduledAt,
                travel: profileStore.travelInfo
            )
        }
        .fullScreenCover(item: $confirmation) { conf in
            AppointmentConfirmedView(confirmation: conf) {
                // After the 3-second display, close the cover AND the parent
                // nurse-detail overlay so the user lands back on the list.
                confirmation = nil
                if let onClose { onClose() } else { dismiss() }
            }
        }
        .alert(
            "Booking failed",
            isPresented: errorBinding,
            presenting: submissionError
        ) { _ in
            Button("Try Again") { submit() }
            Button("Cancel", role: .cancel) { submissionError = nil }
        } message: { error in
            Text(error.errorDescription ?? "Please try again.")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { submissionError != nil },
            set: { if !$0 { submissionError = nil } }
        )
    }

    // MARK: - Hero

    private var heroAvatar: some View {
        ZStack {
            Color(red: 0.91, green: 0.34, blue: 0.27)
                .frame(height: 380)

            if let url = nurse.avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        ProgressView().tint(.white)
                    case .failure:
                        fallbackGlyph
                    @unknown default:
                        fallbackGlyph
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 380)
                .clipped()
            } else {
                fallbackGlyph
            }
        }
        .frame(height: 380)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var fallbackGlyph: some View {
        Image(systemName: "stethoscope")
            .font(.system(size: 140))
            .foregroundStyle(.white)
    }

    private var closeButton: some View {
        Button {
            if let onClose { onClose() } else { dismiss() }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(.label))
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color(.separator).opacity(0.5), lineWidth: 0.5))
        }
        .padding(.leading, 16)
        .padding(.top, 16)
        .accessibilityLabel("Close")
    }

    // MARK: - Identity

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(nurse.name)
                .font(.system(size: 28, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Text(nurse.experience)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    // MARK: - Fields (Where + Schedule)

    private var fieldsSection: some View {
        VStack(spacing: 0) {
            fieldRow(symbol: "location.fill",
                     title: "Where to meet?",
                     value: address.isEmpty ? "Address" : address,
                     valueIsPlaceholder: address.isEmpty) {
                showAddressSheet = true
            }
            Divider().padding(.leading, 56)
            fieldRow(symbol: "calendar",
                     title: "Schedule",
                     value: scheduledAt.map(formatSchedule) ?? "DD/MM/YYYY  Time",
                     valueIsPlaceholder: scheduledAt == nil) {
                showSchedulePicker = true
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func fieldRow(symbol: String,
                          title: String,
                          value: String,
                          valueIsPlaceholder: Bool,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(.label))
                        .frame(width: 36, height: 36)
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(.systemBackground))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color(.label))
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(valueIsPlaceholder ? Color(.placeholderText) : .secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(valueIsPlaceholder ? "Not set" : value)
        .accessibilityAddTraits(.isButton)
    }

    private func formatSchedule(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy  HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 1)

                if description.isEmpty {
                    Text("Describe your condition…")
                        .font(.body)
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $description)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 160)
                    .onChange(of: description) { _, newValue in
                        if newValue.count > descriptionLimit {
                            description = String(newValue.prefix(descriptionLimit))
                        }
                    }
            }
            .frame(minHeight: 160)

            HStack {
                Spacer()
                Text("\(description.count) / \(descriptionLimit)")
                    .font(.caption)
                    .foregroundStyle(description.count >= descriptionLimit ? .red : .secondary)
                    .monospacedDigit()
                    .accessibilityLabel("Character count \(description.count) of \(descriptionLimit)")
            }
        }
    }

    // MARK: - Book button

    private var bookButton: some View {
        Button {
            submit()
        } label: {
            ZStack {
                if isSubmitting {
                    ProgressView().tint(Color(.systemBackground))
                } else {
                    Text("Book")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isFormValid ? Color(.systemBackground) : Color(.tertiaryLabel))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(isFormValid ? Color(.label) : Color(.systemGray5))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isFormValid || isSubmitting)
        .padding(.top, 12)
        .accessibilityHint(isFormValid ? "Submits the booking" : "Fill in every field to continue")
    }

    // MARK: - Submit

    private func submit() {
        guard isFormValid,
              let coordinate,
              let scheduledAt else { return }

        let payload = AppointmentRequest(
            nurseId: nurse.id,
            scheduledAt: scheduledAt,
            address: trimmedAddress,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            description: trimmedDescription
        )

        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                let result = try await AppointmentAPIClient.shared.submit(payload)
                confirmation = result
                onConfirmed?(result)
            } catch let error as AppointmentError {
                submissionError = error
            } catch {
                submissionError = AppointmentError(from: error)
            }
        }
    }
}

// MARK: - Confirmation placeholder

extension AppointmentConfirmation: Hashable, Identifiable {
    public var id: String { appointmentId }
    public func hash(into hasher: inout Hasher) { hasher.combine(appointmentId) }
    public static func == (lhs: AppointmentConfirmation, rhs: AppointmentConfirmation) -> Bool {
        lhs.appointmentId == rhs.appointmentId
    }
}

