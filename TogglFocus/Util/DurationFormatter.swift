import Foundation

enum DurationFormatter {
    static func relative(_ date: Date, now: Date = .now) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: now)
    }

    static func hms(seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}
