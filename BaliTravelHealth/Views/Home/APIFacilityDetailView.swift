import SwiftUI
import MapKit
import Contacts

struct APIFacilityDetailView: View {
    let facility: NearbyHealthFacility
    var onClose: (() -> Void)? = nil

    @Environment(\.openURL) private var openURL
    @State private var showDirectionsDialog = false
    @State private var showCallDialog = false

    var body: some View {
        cardContent
            .frame(maxWidth: 540)
            .padding(.horizontal, 12)
            .padding(.vertical, 24)
    }

    private var cardContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroPlaceholder
                infoCard
                    .padding(.top, -28)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(alignment: .topLeading) { closeButton }
        .confirmationDialog(
            "Get Directions",
            isPresented: $showDirectionsDialog,
            titleVisibility: .visible
        ) {
            Button("Open in Apple Maps") { openAppleMapsDirections() }
            Button("Open in Google Maps") { openGoogleMapsDirections() }
            Button("Cancel", role: .cancel) { }
        } message: { Text(facility.nama) }
        .confirmationDialog(
            "Call \(facility.nama)?",
            isPresented: $showCallDialog,
            titleVisibility: .visible
        ) {
            if let phone = facility.telepon, !phone.isEmpty {
                Button("Call \(phone)") { call(number: phone) }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var heroPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemGray5), Color(.systemGray4)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(spacing: 8) {
                Image(systemName: facilitySymbol)
                    .font(.system(size: 48, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 32, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 32,
                style: .continuous
            )
        )
        .accessibilityLabel("\(facility.nama) facility icon")
        .accessibilityAddTraits(.isImage)
    }

    private var closeButton: some View {
        Button {
            onClose?()
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

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            facilityHeader
                .padding(.top, 16)

            VStack(spacing: 0) {
                if let phone = facility.telepon, !phone.isEmpty {
                    infoRow(symbol: "phone.fill", text: phone) {
                        showCallDialog = true
                    }
                    Divider().padding(.leading, 56)
                }

                if let alamat = facility.alamat, !alamat.isEmpty {
                    infoRow(symbol: "mappin.circle.fill", text: alamat) {
                        showDirectionsDialog = true
                    }
                }

                if let hours = facility.jamOperasional, !hours.isEmpty {
                    Divider().padding(.leading, 56)
                    infoRow(symbol: "clock.fill", text: hours, action: nil)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemBackground))
            )

            actionButtons
        }
        .padding(20)
    }

    private var facilityHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.label).opacity(0.06))
                    .frame(width: 48, height: 48)
                Image(systemName: facilitySymbol)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color(.label))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(facility.jenis)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(facility.nama)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(.label))
                    .fixedSize(horizontal: false, vertical: true)
                if let km = facility.jarakKm {
                    Text(km < 1
                         ? String(format: "%.0f m away", km * 1000)
                         : String(format: "%.1f km away", km))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func infoRow(symbol: String, text: String, action: (() -> Void)?) -> some View {
        Group {
            if let action {
                Button(action: action) { rowContent(symbol: symbol, text: text) }
                    .buttonStyle(.plain)
            } else {
                rowContent(symbol: symbol, text: text)
            }
        }
    }

    private func rowContent(symbol: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color(.label))
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color(.label))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
                .opacity(symbol == "clock.fill" ? 0 : 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            actionButton(
                title: "Get Directions",
                symbol: "location.fill",
                tint: Color(red: 0.55, green: 0.46, blue: 0.85)
            ) { showDirectionsDialog = true }

            if let phone = facility.telepon, !phone.isEmpty {
                actionButton(
                    title: "Call Facility",
                    symbol: "phone.fill",
                    tint: Color(red: 0.45, green: 0.45, blue: 0.50)
                ) { showCallDialog = true }
            }
        }
    }

    private func actionButton(title: String, symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 28, height: 28)
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Capsule(style: .continuous).fill(tint))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var facilitySymbol: String {
        let jenis = facility.jenis.lowercased()
        if jenis.contains("klinik") || jenis.contains("puskesmas") { return "stethoscope" }
        if jenis.contains("mata") { return "eye.fill" }
        if jenis.contains("swasta") { return "cross.case.fill" }
        return "building.columns.fill"
    }

    private func call(number: String) {
        let cleaned = number
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        if let url = URL(string: "tel:\(cleaned)") {
            openURL(url)
        }
    }

    private func openAppleMapsDirections() {
        let coordinate = CLLocationCoordinate2D(latitude: facility.lat, longitude: facility.lng)
        let placemark = MKPlacemark(
            coordinate: coordinate,
            addressDictionary: [CNPostalAddressStreetKey: facility.alamat ?? ""]
        )
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = facility.nama
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func openGoogleMapsDirections() {
        let urlString = "https://www.google.com/maps/dir/?api=1&destination=\(facility.lat),\(facility.lng)&travelmode=driving"
        if let url = URL(string: urlString) { openURL(url) }
    }
}
