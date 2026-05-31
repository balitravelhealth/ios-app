import SwiftUI
import MapKit
import CoreLocation

/// Sheet that lets the user pick an address by:
/// 1. Auto-locating + reverse-geocoding to a starting address.
/// 2. Panning a mini map to pinpoint the exact spot.
/// 3. Manually editing the address text.
struct AddressPickerSheet: View {
    @Binding var address: String
    @Binding var coordinate: CLLocationCoordinate2D?
    @Environment(\.dismiss) private var dismiss

    @State private var localAddress: String
    @State private var localCoordinate: CLLocationCoordinate2D
    @State private var camera: MapCameraPosition
    @State private var isLocating = false
    @State private var locationError: String?
    @State private var fetcher = LocationFetcher()

    private let baliFallback = CLLocationCoordinate2D(latitude: -8.6705, longitude: 115.2126)

    init(address: Binding<String>, coordinate: Binding<CLLocationCoordinate2D?>) {
        self._address = address
        self._coordinate = coordinate
        let initial = coordinate.wrappedValue ?? CLLocationCoordinate2D(latitude: -8.6705, longitude: 115.2126)
        self._localAddress = State(initialValue: address.wrappedValue)
        self._localCoordinate = State(initialValue: initial)
        self._camera = State(initialValue: .region(
            MKCoordinateRegion(
                center: initial,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    mapView
                    useCurrentLocationButton
                    addressEditor
                    if let locationError {
                        Text(locationError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Where to meet?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        address = localAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                        coordinate = localCoordinate
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(localAddress.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task {
                if address.isEmpty {
                    await fetchCurrentLocation()
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Map

    private var mapView: some View {
        ZStack {
            Map(position: $camera, interactionModes: [.pan, .zoom])
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .onMapCameraChange(frequency: .onEnd) { context in
                    localCoordinate = context.region.center
                    Task { await reverseGeocode(localCoordinate) }
                }

            // Fixed pin overlay — the map pans under it.
            Image(systemName: "mappin")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.red)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                .offset(y: -12)
                .accessibilityHidden(true)
        }
        .accessibilityLabel("Map")
        .accessibilityHint("Drag the map to move the pin to your meeting point")
    }

    private var useCurrentLocationButton: some View {
        Button {
            Task { await fetchCurrentLocation() }
        } label: {
            HStack {
                if isLocating {
                    ProgressView()
                } else {
                    Image(systemName: "location.fill")
                }
                Text(isLocating ? "Locating…" : "Use my current location")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
        .disabled(isLocating)
    }

    private var addressEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Address")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("Street, building, or landmark",
                      text: $localAddress,
                      axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...5)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
        }
    }

    // MARK: - Geocoding

    private func fetchCurrentLocation() async {
        isLocating = true
        defer { isLocating = false }
        do {
            let location = try await fetcher.currentLocation()
            localCoordinate = location.coordinate
            camera = .region(
                MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )
            )
            await reverseGeocode(location.coordinate)
            locationError = nil
        } catch let error as LocationFetcher.LocationError {
            locationError = error.errorDescription
        } catch {
            locationError = "We couldn't get your location. Try entering your address manually."
        }
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) async {
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                localAddress = formatAddress(placemark)
            }
        } catch {
            // Silent — manual entry is always available.
        }
    }

    private func formatAddress(_ placemark: CLPlacemark) -> String {
        var parts: [String] = []
        if let name = placemark.name { parts.append(name) }
        if let locality = placemark.locality, !parts.contains(locality) { parts.append(locality) }
        if let admin = placemark.administrativeArea, !parts.contains(admin) { parts.append(admin) }
        if let postal = placemark.postalCode { parts.append(postal) }
        return parts.joined(separator: ", ")
    }
}
