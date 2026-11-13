import Foundation

enum Format {
    private static let usLocale = Locale(identifier: "en_US")

    /// "$7.42", "$12.4", "$1,940"
    static func cost(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        let digits = value >= 100 ? 0 : value >= 10 ? 1 : 2
        return value.formatted(.currency(code: "USD").locale(usLocale).precision(.fractionLength(digits)))
    }

    /// "2.0B", "1.2M", "340k"; nil for zero so empty counts stay hidden.
    static func tokens(_ value: Int?) -> String? {
        guard let value, value > 0 else { return nil }
        let n = Double(value)
        if n >= 1e9 { return String(format: "%.1fB", n / 1e9) }
        if n >= 1e6 { return String(format: "%.1fM", n / 1e6) }
        if n >= 1e3 { return String(format: "%.0fk", n / 1e3) }
        return String(value)
    }

    /// "41.0%"; utilisation can exceed 100% while in overage.
    static func percent(_ fraction: Double) -> String {
        fraction.isFinite ? String(format: "%.1f%%", fraction * 100) : "—"
    }

    /// "Oct 19"
    static func shortDate(_ date: Date?) -> String? {
        date?.formatted(.dateTime.month(.abbreviated).day())
    }

    /// Time left until a window resets: "4d 16h", "2h 3m", "45m" or "now".
    static func countdown(to epoch: Double?, now: Date) -> String? {
        guard let epoch, epoch.isFinite else { return nil }
        let seconds = epoch - now.timeIntervalSince1970
        if seconds <= 0 { return "now" }
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        if hours >= 24 { return "\(hours / 24)d \(hours % 24)h" }
        if hours > 0 { return "\(hours)h \(minutes % 60)m" }
        return "\(minutes)m"
    }

    /// Time worked: "38h 20m", "45m", "<1m", and whole hours from 100h ("142h").
    static func duration(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        if hours >= 100 { return "\(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes % 60)m" }
        return minutes > 0 ? "\(minutes)m" : "<1m"
    }

    /// Calendar time between two dates: "26d", "5h", "40m".
    static func span(from start: Date, to end: Date) -> String {
        let seconds = max(0, end.timeIntervalSince(start))
        if seconds >= 24 * 3600 { return "\(Int(seconds / (24 * 3600)))d" }
        if seconds >= 3600 { return "\(Int(seconds / 3600))h" }
        return "\(max(1, Int(seconds / 60)))m"
    }

    /// "12s ago", "3m ago"
    static func ago(_ date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date).rounded()))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }

    /// "just now", "5m ago", "3h ago", then "Oct 19".
    static func lastActive(_ date: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "just now" }
        if seconds < 24 * 3600 { return ago(date, now: now) }
        return shortDate(date) ?? ""
    }

    /// "claude-opus-5-5" → "Opus 5.5", "claude-3-5-sonnet-20241022" → "Sonnet 3.5".
    static func modelName(_ id: String) -> String {
        var parts = id.split(separator: "-").map(String.init)
        if parts.first == "claude" { parts.removeFirst() }
        if let last = parts.last, last.count == 8, last.allSatisfy(\.isNumber) { parts.removeLast() }
        let words = parts.filter { !$0.allSatisfy(\.isNumber) }.map(\.capitalized)
        let version = parts.filter { $0.allSatisfy(\.isNumber) }.joined(separator: ".")
        return (words + (version.isEmpty ? [] : [version])).joined(separator: " ")
    }
}

/// Peak hours run 05:00–11:00 Pacific time.
enum PeakHours {
    private static let pacific: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    static func status(at now: Date) -> (isActive: Bool, text: String) {
        let parts = pacific.dateComponents([.hour, .minute], from: now)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let start = 5 * 60
        let end = 11 * 60
        if minutes >= start && minutes < end {
            return (true, "Peak hours end in \(span(end - minutes))")
        }
        let until = minutes < start ? start - minutes : 24 * 60 - minutes + start
        return (false, "\(span(until)) till peak hours")
    }

    private static func span(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
