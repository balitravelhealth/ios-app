import SwiftUI

struct NursingCareView: View {
    @State private var service = NurseService.shared
    @State private var appointmentService = AppointmentService.shared
    @State private var presentedNurse: Nurse?
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            mainContent
                .blur(radius: presentedNurse == nil ? 0 : 14)
                .allowsHitTesting(presentedNurse == nil)

            if presentedNurse != nil {
                Rectangle()
                    .fill(.black.opacity(0.18))
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { presentedNurse = nil }
                    .accessibilityLabel("Close nurse details")
                    .accessibilityAddTraits(.isButton)
            }

            if let nurse = presentedNurse {
                NurseDetailView(nurse: nurse) { presentedNurse = nil }
                    .frame(maxWidth: 540)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(Color(.systemBackground))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 24)
                    )
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.88).combined(with: .opacity),
                            removal: .scale(scale: 0.94).combined(with: .opacity)
                        )
                    )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: presentedNurse?.id)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: presentedNurse) { old, new in
            // After the booking sheet closes, re-fetch in case the user just
            // submitted an appointment — the server will now return it as active.
            if old != nil && new == nil {
                Task { await appointmentService.refresh() }
            }
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                titleHeader
                content
                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .toolbar {
            ToolbarItem(placement: .principal) { EmptyView() }
        }
        .task {
            await appointmentService.refresh()
            if service.nurses.isEmpty {
                await service.refresh()
            }
        }
        .refreshable {
            await appointmentService.refresh()
            await service.refresh()
        }
    }

    // MARK: - Title

    private var titleHeader: some View {
        Text("Nursing Care Service")
            .font(.system(size: 34, weight: .bold))
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - State machine

    @ViewBuilder
    private var content: some View {
        if let active = appointmentService.active, active.isStillVisible {
            appointmentSection(active: active)
        } else if service.isLoading && service.nurses.isEmpty {
            loadingState
        } else if let error = service.lastError, service.nurses.isEmpty {
            errorState(message: error)
        } else if service.nurses.isEmpty {
            emptyState
        } else {
            nurseGrid
        }
    }

    // MARK: - Active appointment section

    private func appointmentSection(active: ActiveAppointment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Appointment")
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            AppointmentCard(active: active) {
                if let url = active.whatsAppURL {
                    openURL(url)
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading nurses…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Couldn't load nurses")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await service.refresh() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "stethoscope")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No nurses available")
                .font(.headline)
            Text("Pull down to refresh, or check back soon.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private var nurseGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]
        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(service.nurses) { nurse in
                Button {
                    presentedNurse = nurse
                } label: {
                    NurseCard(nurse: nurse)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(nurse.name), \(nurse.experience)")
                .accessibilityValue(nurse.formattedFromRate())
                .accessibilityHint("Opens nurse details")
            }
        }
    }
}

// MARK: - Card

private struct NurseCard: View {
    let nurse: Nurse

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            avatar
                .frame(maxWidth: .infinity)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(nurse.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(nurse.experience)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 14)

            Spacer(minLength: 4)

            Text(nurse.formattedFromRate())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.label))
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(.separator).opacity(0.4), lineWidth: 0.6)
        )
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = nurse.avatarURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty:
                    ProgressView()
                case .failure:
                    avatarFallback
                @unknown default:
                    avatarFallback
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())
        } else {
            avatarFallback
                .frame(width: 96, height: 96)
                .clipShape(Circle())
        }
    }

    private var avatarFallback: some View {
        ZStack {
            Circle().fill(Color(red: 0.91, green: 0.34, blue: 0.27)) // warm red
            Image(systemName: "stethoscope")
                .font(.system(size: 36))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Active appointment card

private struct AppointmentCard: View {
    let active: ActiveAppointment
    let onWhatsApp: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            nurseRow
            Divider()
            addressRow
            Divider()
            scheduleRow
            Divider()
            whatsAppButton
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private var nurseRow: some View {
        HStack(spacing: 16) {
            avatar
                .frame(width: 60, height: 60)
            Text(active.nurseName)
                .font(.headline)
                .foregroundStyle(Color(.label))
                .lineLimit(2)
            Spacer()
        }
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(Color(red: 0.91, green: 0.34, blue: 0.27))
            if let url = active.nurseAvatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        ProgressView().tint(.white)
                    case .failure:
                        glyph
                    @unknown default:
                        glyph
                    }
                }
                .clipShape(Circle())
            } else {
                glyph
            }
        }
    }

    private var glyph: some View {
        Image(systemName: "stethoscope")
            .font(.system(size: 24))
            .foregroundStyle(.white)
    }

    private var addressRow: some View {
        HStack(alignment: .top, spacing: 14) {
            iconBadge("location.fill")
            VStack(alignment: .leading, spacing: 2) {
                Text("Address")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(active.address)
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
    }

    private var scheduleRow: some View {
        HStack(spacing: 14) {
            iconBadge("calendar")
            Text(formattedSchedule)
                .font(.subheadline)
                .foregroundStyle(Color(.label))
            Spacer(minLength: 0)
        }
    }

    private var formattedSchedule: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy  HH:mm"
        return formatter.string(from: active.scheduledAt)
    }

    private func iconBadge(_ symbol: String) -> some View {
        ZStack {
            Circle()
                .fill(Color(.label))
                .frame(width: 36, height: 36)
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(.systemBackground))
        }
        .accessibilityHidden(true)
    }

    private var whatsAppButton: some View {
        Button(action: onWhatsApp) {
            HStack {
                Text("Contact Nurse")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color(red: 0.15, green: 0.83, blue: 0.45))
                        .frame(width: 36, height: 36)
                    Image(systemName: "message.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Contact \(active.nurseName) on WhatsApp")
        .accessibilityHint("Opens WhatsApp")
    }
}

#Preview {
    NavigationStack { NursingCareView() }
}
