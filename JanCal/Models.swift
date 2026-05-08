import Foundation
import SwiftUI

struct CalendarEvent: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var notes: String
    var color: String
    var ekEventId: String?
    var calendarIdentifier: String?
    var url: String?

    init(id: UUID = UUID(), title: String, startDate: Date, endDate: Date, notes: String = "", color: String = "blue", ekEventId: String? = nil, calendarIdentifier: String? = nil, url: String? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.color = color
        self.ekEventId = ekEventId
        self.calendarIdentifier = calendarIdentifier
        self.url = url
    }
}

let eventColors: [(name: String, color: Color)] = [
    ("blue", .blue),
    ("green", .green),
    ("orange", .orange),
    ("purple", .purple),
    ("red", .red),
]

func colorForName(_ name: String) -> Color {
    eventColors.first(where: { $0.name == name })?.color ?? .blue
}

extension Date {
    func startOfDay() -> Date {
        Calendar.current.startOfDay(for: self)
    }

    func startOfWeek() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components)!
    }

    func dayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self)
    }

    func dayNumber() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: self)
    }

    func isToday() -> Bool {
        Calendar.current.isDateInToday(self)
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    func isSameWeek(as other: Date) -> Bool {
        let calendar = Calendar.current
        let comp1 = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        let comp2 = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: other)
        return comp1.yearForWeekOfYear == comp2.yearForWeekOfYear && comp1.weekOfYear == comp2.weekOfYear
    }

    func dayOfWeekIndex() -> Int {
        (Calendar.current.component(.weekday, from: self) + 5) % 7
    }

    func weekBounds() -> (start: Date, end: Date) {
        let start = startOfWeek()
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start)!
        return (start, end)
    }
}
