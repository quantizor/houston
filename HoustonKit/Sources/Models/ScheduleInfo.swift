import Foundation

/// Computes next fire times and human-readable schedule descriptions for launchd jobs.
public struct ScheduleInfo: Sendable {

    /// Human-readable description of the schedule (e.g., "Every 5 minutes", "Daily at 3:30 AM").
    public static func description(startInterval: Int?, startCalendarInterval: [String: Int]?) -> String? {
        if let interval = startInterval, interval > 0 {
            return intervalDescription(interval)
        }
        if let cal = startCalendarInterval {
            return calendarDescription(cal)
        }
        return nil
    }

    /// Compute the next fire date from now.
    public static func nextFireDate(
        startInterval: Int?,
        startCalendarInterval: [String: Int]?,
        from now: Date = Date()
    ) -> Date? {
        if let interval = startInterval, interval > 0 {
            return now.addingTimeInterval(TimeInterval(interval))
        }
        if let cal = startCalendarInterval {
            return nextCalendarDate(cal, after: now)
        }
        return nil
    }

    /// Formatted next-run string for display (e.g., "next at 10:35 AM" or "next on Mon, Mar 31 at 3:30 AM").
    public static func nextRunString(
        startInterval: Int?,
        startCalendarInterval: [String: Int]?,
        from now: Date = Date()
    ) -> String? {
        guard let next = nextFireDate(startInterval: startInterval, startCalendarInterval: startCalendarInterval, from: now) else {
            return nil
        }

        let calendar = Calendar.current
        let formatter = DateFormatter()

        if calendar.isDate(next, inSameDayAs: now) {
            formatter.dateFormat = "h:mm a"
            return "next at \(formatter.string(from: next))"
        } else {
            formatter.dateFormat = "E, MMM d 'at' h:mm a"
            return "next on \(formatter.string(from: next))"
        }
    }

    // MARK: - Interval helpers

    private static func intervalDescription(_ seconds: Int) -> String {
        if seconds < 60 {
            return "Every \(seconds) second\(seconds == 1 ? "" : "s")"
        }
        let minutes = seconds / 60
        if seconds % 60 == 0 && minutes < 60 {
            return "Every \(minutes) minute\(minutes == 1 ? "" : "s")"
        }
        let hours = seconds / 3600
        if seconds % 3600 == 0 && hours < 24 {
            return "Every \(hours) hour\(hours == 1 ? "" : "s")"
        }
        if seconds % 86400 == 0 {
            let days = seconds / 86400
            return "Every \(days) day\(days == 1 ? "" : "s")"
        }
        // Fallback: show in most natural unit
        if minutes < 120 {
            return "Every \(minutes) minutes"
        }
        if hours < 48 {
            let remainingMin = (seconds % 3600) / 60
            return remainingMin > 0 ? "Every \(hours)h \(remainingMin)m" : "Every \(hours) hours"
        }
        let days = seconds / 86400
        return "Every \(days) days"
    }

    // MARK: - Calendar helpers

    private static func calendarDescription(_ cal: [String: Int]) -> String {
        let hour = cal["Hour"]
        let minute = cal["Minute"]
        let weekday = cal["Weekday"]
        let day = cal["Day"]
        let month = cal["Month"]

        let timeStr = formatTime(hour: hour, minute: minute)

        if let month = month, let day = day {
            let monthName = Calendar.current.monthSymbols[safe: month - 1] ?? "month \(month)"
            return "\(monthName) \(day) at \(timeStr)"
        }
        if let day = day {
            return "Monthly on day \(day) at \(timeStr)"
        }
        if let weekday = weekday {
            let dayName = Calendar.current.weekdaySymbols[safe: weekday == 0 ? 6 : weekday - 1] ?? "day \(weekday)"
            return "Every \(dayName) at \(timeStr)"
        }
        if hour != nil {
            return "Daily at \(timeStr)"
        }
        if minute != nil {
            return "Every hour at :\(String(format: "%02d", minute!))"
        }
        return "On schedule"
    }

    private static func formatTime(hour: Int?, minute: Int?) -> String {
        let h = hour ?? 0
        let m = minute ?? 0
        let period = h >= 12 ? "PM" : "AM"
        let displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return "\(displayHour):\(String(format: "%02d", m)) \(period)"
    }

    private static func nextCalendarDate(_ cal: [String: Int], after now: Date) -> Date? {
        let calendar = Calendar.current

        var components = DateComponents()
        if let hour = cal["Hour"] { components.hour = hour }
        if let minute = cal["Minute"] { components.minute = minute }
        if let weekday = cal["Weekday"] {
            // launchd uses 0=Sunday, DateComponents uses 1=Sunday
            components.weekday = weekday == 0 ? 1 : weekday
        }
        if let day = cal["Day"] { components.day = day }
        if let month = cal["Month"] { components.month = month }

        return calendar.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
