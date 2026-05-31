import SwiftUI
import UIKit

/// A single inline calendar that lets the user tap two dates to define a
/// closed range (arrival → departure). The days between the two taps are
/// highlighted with a coloured pill so the range is visible at a glance.
///
/// Tap behaviour:
/// - 1st tap  → arrival
/// - 2nd tap (≥ arrival) → departure
/// - 2nd tap (< arrival) → becomes new arrival, departure cleared
/// - 3rd tap (when both set) → resets and starts a new range
struct RangeCalendarView: UIViewRepresentable {
    @Binding var arrival: Date?
    @Binding var departure: Date?
    var minimumDate: Date = Calendar.current.startOfDay(for: Date())
    var maximumDate: Date = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
    var tint: UIColor = UIColor(red: 0.34, green: 0.62, blue: 0.36, alpha: 1)

    func makeCoordinator() -> Coordinator {
        Coordinator(arrival: $arrival, departure: $departure, tint: tint)
    }

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = Calendar(identifier: .gregorian)
        view.locale = .current
        view.tintColor = tint
        view.fontDesign = .default
        view.availableDateRange = DateInterval(start: minimumDate, end: maximumDate)

        let selection = UICalendarSelectionMultiDate(delegate: context.coordinator)
        view.selectionBehavior = selection
        view.delegate = context.coordinator

        context.coordinator.calendarView = view
        context.coordinator.pushSelectionIntoCalendar()
        return view
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        // Keep the calendar in sync if the bindings change from the outside.
        context.coordinator.pushSelectionIntoCalendar()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionMultiDateDelegate {
        @Binding var arrival: Date?
        @Binding var departure: Date?
        let tint: UIColor
        weak var calendarView: UICalendarView?
        private var isApplyingProgrammaticUpdate = false

        init(arrival: Binding<Date?>, departure: Binding<Date?>, tint: UIColor) {
            self._arrival = arrival
            self._departure = departure
            self.tint = tint
        }

        // MARK: User taps

        func multiDateSelection(_ selection: UICalendarSelectionMultiDate,
                                didSelectDate dateComponents: DateComponents) {
            guard !isApplyingProgrammaticUpdate,
                  let tapped = Calendar.current.date(from: dateComponents) else { return }
            handleTap(on: tapped)
        }

        func multiDateSelection(_ selection: UICalendarSelectionMultiDate,
                                didDeselectDate dateComponents: DateComponents) {
            guard !isApplyingProgrammaticUpdate,
                  let tapped = Calendar.current.date(from: dateComponents) else { return }
            // The system tries to deselect a previously-selected date — treat
            // this as another tap so our state machine stays in control.
            handleTap(on: tapped)
        }

        private func handleTap(on date: Date) {
            let day = Calendar.current.startOfDay(for: date)

            switch (arrival, departure) {
            case (nil, _):
                arrival = day
                departure = nil
            case (let a?, nil):
                if day < a {
                    arrival = day
                } else if day == a {
                    // Tapping the arrival again clears the range.
                    arrival = nil
                } else {
                    departure = day
                }
            case (_?, _?):
                // Both already set → start a fresh range.
                arrival = day
                departure = nil
            }

            pushSelectionIntoCalendar()
        }

        // MARK: Decorations

        func calendarView(_ calendarView: UICalendarView,
                          decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let arrival, let departure,
                  let date = Calendar.current.date(from: dateComponents) else { return nil }
            let day = Calendar.current.startOfDay(for: date)
            // Highlight in-between days (exclusive of arrival/departure since
            // those already get the system's selection circle).
            guard day > arrival && day < departure else { return nil }

            return .customView {
                let dot = UIView()
                dot.backgroundColor = self.tint.withAlphaComponent(0.22)
                dot.layer.cornerRadius = 4
                dot.translatesAutoresizingMaskIntoConstraints = false
                let container = UIView()
                container.addSubview(dot)
                NSLayoutConstraint.activate([
                    dot.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    dot.widthAnchor.constraint(equalToConstant: 28),
                    dot.heightAnchor.constraint(equalToConstant: 8)
                ])
                return container
            }
        }

        // MARK: Sync bindings → UICalendarView

        func pushSelectionIntoCalendar() {
            guard let calendarView,
                  let selection = calendarView.selectionBehavior as? UICalendarSelectionMultiDate else { return }

            isApplyingProgrammaticUpdate = true
            defer { isApplyingProgrammaticUpdate = false }

            let cal = Calendar.current
            var components: [DateComponents] = []
            if let arrival { components.append(cal.dateComponents([.year, .month, .day], from: arrival)) }
            if let departure { components.append(cal.dateComponents([.year, .month, .day], from: departure)) }
            selection.setSelectedDates(components, animated: true)

            calendarView.reloadDecorations(forDateComponents: allRangeComponents(), animated: true)
        }

        private func allRangeComponents() -> [DateComponents] {
            guard let arrival, let departure, departure > arrival else { return [] }
            let cal = Calendar.current
            var dates: [DateComponents] = []
            var d = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: arrival)) ?? arrival
            let end = cal.startOfDay(for: departure)
            while d < end {
                dates.append(cal.dateComponents([.year, .month, .day], from: d))
                d = cal.date(byAdding: .day, value: 1, to: d) ?? end
            }
            return dates
        }
    }
}
