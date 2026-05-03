import SwiftUI
import MapKit
import Contacts

struct FacilityDetailView: View {
    let facility: HealthcareFacility
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showDirectionsDialog = false
    @State private var showCallDialog = false
    @State private var showWebsiteDialog = false

    var body: some View {
        cardContent
            .frame(maxWidth: 540)
            .padding(.horizontal, 12)
            .padding(.vertical, 24)
    }

    private var cardContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroImage
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
            Button("Open in Apple Maps")  { openAppleMapsDirections() }
            Button("Open in Google Maps") { openGoogleMapsDirections() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(facility.name)
        }
        .confirmationDialog(
            "Call \(facility.name)?",
            isPresented: $showCallDialog,
            titleVisibility: .visible
        ) {
            Button("Call \(facility.phone)") { call(number: facility.phone) }
            if let alt = facility.phoneAlt, !alt.isEmpty {
                Button("Call \(alt)") { call(number: alt) }
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog(
            "Open Website",
            isPresented: $showWebsiteDialog,
            titleVisibility: .visible
        ) {
            if let url = facility.websiteURL {
                Button("Open in Browser") { openURL(url) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let urlString = facility.website {
                Text(urlString)
            }
        }
    }

    // MARK: - Hero image (picture placeholder)
    //
    // Photos will be added later. To wire a real photo per facility, drop an
    // asset into the catalog whose name matches `facility.name` (or set a
    // dedicated `photoAssetName` property on the model and use it here).
    // Until then, a clean placeholder is shown.

    private var heroImage: some View {
        ZStack {
            if UIImage(named: facility.name) != nil {
                Image(facility.name)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color(.systemGray5), Color(.systemGray4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 38, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text("Photo coming soon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 260)
        .frame(maxWidth: .infinity)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 32, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 32,
                style: .continuous
            )
        )
        .accessibilityLabel("\(facility.name) photo")
        .accessibilityAddTraits(.isImage)
    }

    // MARK: - Close button

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

    // MARK: - Info card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            facilityHeader
                .padding(.top, 16)   // sit below the hero's bottom edge, not on it

            VStack(spacing: 0) {
                infoRow(symbol: "phone.fill", text: facility.phone) {
                    showCallDialog = true
                }
                Divider().padding(.leading, 56)

                infoRow(symbol: "mappin.circle.fill", text: facility.address) {
                    showDirectionsDialog = true
                }

                if facility.website != nil {
                    Divider().padding(.leading, 56)
                    infoRow(symbol: "globe", text: facility.website ?? "") {
                        showWebsiteDialog = true
                    }
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
                Image(systemName: facility.type.iconName)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color(.label))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(facility.type.displayNameEN)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(facility.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(.label))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Speciality: \(facility.specialty)")
                        .font(.subheadline)
                        .foregroundStyle(Color(.label))
                    Text("Open 24 hours: \(facility.isOpen24Hours ? "Yes" : "No")")
                        .font(.subheadline)
                        .foregroundStyle(Color(.label))
                    if let summary = facility.hoursSummary {
                        Text(summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
    }

    private func infoRow(symbol: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            primaryButton(
                title: "Get Directions",
                symbol: "location.fill",
                tint: Color(red: 0.55, green: 0.46, blue: 0.85)
            ) {
                showDirectionsDialog = true
            }

            primaryButton(
                title: "Call Facility",
                symbol: "phone.fill",
                tint: Color(red: 0.45, green: 0.45, blue: 0.50)
            ) {
                showCallDialog = true
            }
        }
    }

    private func primaryButton(title: String, symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
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
            .background(
                Capsule(style: .continuous).fill(tint)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // MARK: - Actions

    private func call(number: String) {
        let cleaned = number
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        if let url = URL(string: "tel:\(cleaned)"), UIApplication.shared.canOpenURL(url) {
            openURL(url)
        }
    }

    /// Open Apple Maps with directions to the facility's exact coordinates.
    ///
    /// We use `MKMapItem` rather than the `maps.apple.com` URL scheme because
    /// the URL scheme treats `q=` as a search — when our seeded Indonesian
    /// addresses don't match Apple's POI database, Apple Maps silently routes
    /// to whatever it found instead of our coordinates. `MKMapItem` pins the
    /// destination at the exact lat/lng we pass and labels it with our name.
    private func openAppleMapsDirections() {
        let coordinate = CLLocationCoordinate2D(
            latitude: facility.latitude,
            longitude: facility.longitude
        )
        let addressDictionary: [String: Any] = [
            CNPostalAddressStreetKey: facility.address
        ]
        let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: addressDictionary)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = facility.name

        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    /// Open Google Maps directions to the facility's exact coordinates.
    /// Coordinates only (no name/address text) so Google can't substitute a
    /// nearby search match for the destination.
    private func openGoogleMapsDirections() {
        let urlString =
            "https://www.google.com/maps/dir/?api=1" +
            "&destination=\(facility.latitude),\(facility.longitude)" +
            "&travelmode=driving"
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }
}
