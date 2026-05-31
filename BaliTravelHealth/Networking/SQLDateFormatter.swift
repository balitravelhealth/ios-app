import Foundation

enum SQLDateFormatter {
    static func string(from date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return ""
        }

        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func date(from sqlDate: String, timeZone: TimeZone = .current) -> Date? {
        let value = sqlDate.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = value.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = timeZone
        components.year = year
        components.month = month
        components.day = day

        guard let date = calendar.date(from: components) else {
            return nil
        }

        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == year,
              resolved.month == month,
              resolved.day == day else {
            return nil
        }

        return date
    }

    static func normalizedString(from rawValue: String?, timeZone: TimeZone = .current) -> String? {
        guard let rawValue else { return nil }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let date = date(from: value, timeZone: timeZone) {
            return string(from: date, timeZone: timeZone)
        }

        if value.count >= 10 {
            let prefix = String(value.prefix(10))
            if let date = date(from: prefix, timeZone: timeZone) {
                return string(from: date, timeZone: timeZone)
            }
        }

        if let date = ISO8601DateFormatter().date(from: value) {
            return string(from: date, timeZone: timeZone)
        }

        return nil
    }
}
