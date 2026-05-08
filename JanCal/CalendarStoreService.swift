import Foundation
import EventKit

@MainActor
class CalendarStoreService: ObservableObject {
    @Published var isAuthorized = false
    @Published var isSyncing = false
    @Published var lastSyncError: String?
    @Published var availableCalendars: [EKCalendar] = []
    @Published var selectedCalendarIDs: Set<String> = []

    let store = EKEventStore()

    func requestAccess() async {
        do {
            if #available(iOS 17.0, *) {
                try await store.requestFullAccessToEvents()
            } else {
                try await store.requestAccess(to: .event)
            }
            isAuthorized = true
            loadCalendars()
        } catch {
            lastSyncError = "Calendar access denied: \(error.localizedDescription)"
        }
    }

    func loadCalendars() {
        let cals = store.calendars(for: .event)
        availableCalendars = cals
        print("Found \(cals.count) calendars:")
        for cal in cals {
            print("  - \(cal.title) (source: \(cal.source.title), type: \(cal.source.sourceType.rawValue))")
        }
        if selectedCalendarIDs.isEmpty {
            selectedCalendarIDs = Set(cals.map { $0.calendarIdentifier })
        }
    }

    func fetchEvents(from start: Date, to end: Date) -> [CalendarEvent] {
        guard isAuthorized else { return [] }
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            guard status == .fullAccess || status == .authorized else {
                lastSyncError = "Calendar access not granted (status: \(status.rawValue))"
                return []
            }
        } else {
            guard status == .authorized else {
                lastSyncError = "Calendar access not granted"
                return []
            }
        }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: selectedCalendars)
        let ekEvents = store.events(matching: predicate)
        print("fetchEvents: found \(ekEvents.count) events from \(start) to \(end)")
        for ek in ekEvents.prefix(5) {
            print("  - \(ek.title ?? "(no title)") on \(ek.startDate) calendar: \(ek.calendar.title)")
        }
        if ekEvents.count > 5 { print("  ... and \(ekEvents.count - 5) more") }
        return ekEvents.map { $0.toCalendarEvent() }
    }

    func addEvent(_ event: CalendarEvent, calendarIdentifier: String? = nil) -> String? {
        guard isAuthorized else { return nil }
        let ekEvent = EKEvent(eventStore: store)
        ekEvent.title = event.title
        ekEvent.startDate = event.startDate
        ekEvent.endDate = event.endDate
        ekEvent.notes = event.notes
        if let urlString = event.url, let url = URL(string: urlString), url.scheme == "http" || url.scheme == "https" {
            ekEvent.url = url
        }
        if let calID = calendarIdentifier ?? event.calendarIdentifier,
           let calendar = store.calendar(withIdentifier: calID) {
            ekEvent.calendar = calendar
        } else {
            ekEvent.calendar = defaultCalendar ?? availableCalendars.first
        }
        guard let targetCalendar = ekEvent.calendar else {
            lastSyncError = "No calendar available to save event"
            return nil
        }
        print("Saving event '\(event.title)' to calendar: \(targetCalendar.title) (\(targetCalendar.source.title))")
        do {
            try store.save(ekEvent, span: .thisEvent)
            return ekEvent.eventIdentifier
        } catch {
            lastSyncError = "Failed to save event: \(error.localizedDescription)"
            return nil
        }
    }

    func updateEvent(_ event: CalendarEvent, ekEventId: String) -> Bool {
        guard isAuthorized else { return false }
        guard let ekEvent = store.event(withIdentifier: ekEventId) else { return false }
        ekEvent.title = event.title
        ekEvent.startDate = event.startDate
        ekEvent.endDate = event.endDate
        ekEvent.notes = event.notes
        if let urlString = event.url, let url = URL(string: urlString), url.scheme == "http" || url.scheme == "https" {
            ekEvent.url = url
        } else {
            ekEvent.url = nil
        }
        do {
            try store.save(ekEvent, span: .thisEvent)
            return true
        } catch {
            lastSyncError = "Failed to update event: \(error.localizedDescription)"
            return false
        }
    }

    func deleteEvent(ekEventId: String) -> Bool {
        guard isAuthorized else { return false }
        guard let ekEvent = store.event(withIdentifier: ekEventId) else { return false }
        do {
            try store.remove(ekEvent, span: .thisEvent)
            return true
        } catch {
            lastSyncError = "Failed to delete event: \(error.localizedDescription)"
            return false
        }
    }

    private var selectedCalendars: [EKCalendar]? {
        let cals = availableCalendars.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
        return cals.isEmpty ? nil : cals
    }

    private var defaultCalendar: EKCalendar? {
        store.defaultCalendarForNewEvents
    }
}

extension EKEvent {
    func toCalendarEvent() -> CalendarEvent {
        CalendarEvent(
            id: UUID(),
            title: title ?? "(no title)",
            startDate: startDate,
            endDate: endDate,
            notes: notes ?? "",
            color: calendarColor,
            ekEventId: eventIdentifier,
            calendarIdentifier: calendar.calendarIdentifier,
            url: url?.absoluteString
        )
    }

    var calendarColor: String {
        colorForCGColor(calendar.cgColor)
    }
}

func colorForCGColor(_ cgColor: CGColor?) -> String {
    guard let comps = cgColor?.components, comps.count >= 3 else { return "blue" }
    let r = comps[0], g = comps[1], b = comps[2]
    if r > 0.8 && g < 0.3 && b < 0.3 { return "red" }
    if r > 0.8 && g > 0.5 && b < 0.2 { return "orange" }
    if r < 0.3 && g > 0.7 && b < 0.3 { return "green" }
    if r < 0.3 && g < 0.5 && b > 0.7 { return "blue" }
    if r > 0.5 && g < 0.3 && b > 0.5 { return "purple" }
    return "blue"
}
