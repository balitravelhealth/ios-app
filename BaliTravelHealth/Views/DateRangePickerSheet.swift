import SwiftUI

/// Modal sheet that lets the user pick an arrival + departure date in a
/// single inline calendar. Returns both via the bindings only when "Done" is
/// tapped.
struct DateRangePickerSheet: View {
    @Binding var arrival: Date?
    @Binding var departure: Date?
    @Environment(\.dismiss) private var dismiss

    @State private var localArrival: Date?
    @State private var localDeparture: Date?

    init(arrival: Binding<Date?>, departure: Binding<Date?>) {
        self._arrival = arrival
        self._departure = departure
        self._localArrival = State(initialValue: arrival.wrappedValue)
        self._localDeparture = State(initialValue: departure.wrappedValue)
    }

    private var isValid: Bool {
        guard let a = localArrival, let d = localDeparture else { return false }
        return d >= a
    }

    private var nights: Int {
        guard let a = localArrival, let d = localDeparture else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: a, to: d).day ?? 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryBar
                    RangeCalendarView(
                        arrival: $localArrival,
                        departure: $localDeparture
                    )
                    .frame(minHeight: 360)
                    .padding(.horizontal, 8)

                    helperText
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Travel Dates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        arrival = localArrival
                        departure = localDeparture
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Summary bar

    private var summaryBar: some View {
        HStack(spacing: 0) {
            summaryColumn(label: "Arrival", date: localArrival, isSet: localArrival != nil)
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1, height: 36)
            summaryColumn(label: "Departure", date: localDeparture, isSet: localDeparture != nil)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func summaryColumn(label: String, date: Date?, isSet: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(date?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                .font(.headline)
                .foregroundStyle(isSet ? Color(.label) : Color(.placeholderText))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helper text

    @ViewBuilder
    private var helperText: some View {
        if isValid {
            Label(
                nights == 1 ? "1 night in Bali" : "\(nights) nights in Bali",
                systemImage: "moon.stars"
            )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
        } else if localArrival != nil && localDeparture == nil {
            Label("Tap your departure date", systemImage: "hand.tap")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            Label("Tap your arrival date to start", systemImage: "hand.tap")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
