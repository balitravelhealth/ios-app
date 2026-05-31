import SwiftUI

/// Date + time picker constrained to the user's travel window.
///
/// If `travel` is nil, allows any date from today to one year out so the user
/// can still proceed before onboarding has set a travel range.
struct AppointmentSchedulePickerSheet: View {
    @Binding var selection: Date?
    let travel: TravelInfo?
    @Environment(\.dismiss) private var dismiss

    @State private var localSelection: Date

    init(selection: Binding<Date?>, travel: TravelInfo?) {
        self._selection = selection
        self.travel = travel
        let cal = Calendar.current
        let initial = selection.wrappedValue
            ?? travel?.arrivalDate
            ?? cal.startOfDay(for: Date())
        self._localSelection = State(initialValue: initial)
    }

    private var allowedRange: ClosedRange<Date> {
        let cal = Calendar.current
        if let travel {
            // Clamp the lower bound to "today" so past travel dates can't be picked.
            let lower = max(cal.startOfDay(for: Date()), travel.arrivalDate)
            let upper = max(lower, travel.departureDate)
            return lower...upper
        }
        let lower = cal.startOfDay(for: Date())
        let upper = cal.date(byAdding: .year, value: 1, to: lower) ?? lower
        return lower...upper
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if travel == nil {
                    Label("Add your travel dates first to see your booking window.",
                          systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 12)
                }

                DatePicker(
                    "Schedule",
                    selection: $localSelection,
                    in: allowedRange,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .navigationTitle("Schedule")
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
