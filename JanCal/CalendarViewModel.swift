import Foundation
import SwiftUI
import UIKit

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var selectedDate: Date
    @Published var events: [CalendarEvent]
    @Published var viewMode: ViewMode = .agenda {
        willSet {
            if viewMode != .year {
                lastDetailViewMode = viewMode
            }
        }
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: "lastViewMode") }
    }
    var lastDetailViewMode: ViewMode = .agenda
    @Published var editingEvent: CalendarEvent?
    @Published var showingEditor = false
    @Published var editorMode: EditorMode = .add
    @Published var agendaZoomLevel: CGFloat = 1.0 {
        didSet { UserDefaults.standard.set(Double(agendaZoomLevel), forKey: "agendaZoomLevel") }
    }

    let calendarStore = CalendarStoreService()
    @Published var ekEventMap: [String: String] = [:]

    @Published var isDarkMode: Bool = true {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode") }
    }
    @Published var weekdayColorLight: Color = .primary {
        didSet { saveColor(weekdayColorLight, forKey: "weekdayColorLight") }
    }
    @Published var weekendColorLight: Color = .secondary {
        didSet { saveColor(weekendColorLight, forKey: "weekendColorLight") }
    }
    @Published var weekdayBgColorLight: Color = Color(.systemGroupedBackground) {
        didSet { saveColor(weekdayBgColorLight, forKey: "weekdayBgColorLight") }
    }
    @Published var weekendBgColorLight: Color = Color(.systemGroupedBackground) {
        didSet { saveColor(weekendBgColorLight, forKey: "weekendBgColorLight") }
    }
    @Published var fontScale: CGFloat = 1.0 {
        didSet { UserDefaults.standard.set(Double(fontScale), forKey: "fontScale") }
    }
    @Published var dayNameFontSize: CGFloat = 20 {
        didSet { UserDefaults.standard.set(Double(dayNameFontSize), forKey: "dayNameFontSize") }
    }
    @Published var dayNumberFontSize: CGFloat = 25 {
        didSet { UserDefaults.standard.set(Double(dayNumberFontSize), forKey: "dayNumberFontSize") }
    }
    @Published var dayNameBold: Bool = false {
        didSet { UserDefaults.standard.set(dayNameBold, forKey: "dayNameBold") }
    }
    @Published var showSettings = false
    @Published var swipeSensitivity: CGFloat = 30 {
        didSet { UserDefaults.standard.set(Double(swipeSensitivity), forKey: "swipeSensitivity") }
    }
    @Published var todayColor: Color = .accentColor {
        didSet { saveColor(todayColor, forKey: "todayColor") }
    }

    enum ViewMode: String, CaseIterable {
        case year = "Year"
        case agenda = "Agenda"
        case week = "Week"
        case day = "Day"
    }

    enum EditorMode {
        case add
        case edit
    }

    var selectedWeekStart: Date {
        selectedDate.startOfWeek()
    }

    var weekDays: [Date] {
        let start = selectedWeekStart
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    var agendaWeekdays: [Date] {
        let start = selectedWeekStart
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    var selectedDayEvents: [CalendarEvent] {
        events.filter { event in
            let dayStart = selectedDate.startOfDay()
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
            return event.startDate < dayEnd && event.endDate > dayStart
        }
        .sorted { $0.startDate < $1.startDate }
    }

    func events(for date: Date) -> [CalendarEvent] {
        events.filter { event in
            let dayStart = date.startOfDay()
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
            return event.startDate < dayEnd && event.endDate > dayStart
        }
        .sorted { $0.startDate < $1.startDate }
    }

    func moveWeek(forward: Bool) {
        selectedDate = Calendar.current.date(byAdding: .day, value: forward ? 7 : -7, to: selectedDate)!
    }

    func moveDay(forward: Bool) {
        selectedDate = Calendar.current.date(byAdding: .day, value: forward ? 1 : -1, to: selectedDate)!
    }

    func moveMonth(forward: Bool) {
        selectedDate = Calendar.current.date(byAdding: .month, value: forward ? 1 : -1, to: selectedDate)!
    }

    func moveYear(forward: Bool) {
        selectedDate = Calendar.current.date(byAdding: .year, value: forward ? 1 : -1, to: selectedDate)!
    }

    func goToToday() {
        selectedDate = Date()
    }

    func addEvent(_ event: CalendarEvent) {
        events.append(event)
        saveEvents()
        pushEventToStore(event)
    }

    func updateEvent(_ event: CalendarEvent) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[index] = event
        saveEvents()
        pushEventToStore(event)
    }

    func deleteEvent(_ event: CalendarEvent) {
        events.removeAll { $0.id == event.id }
        saveEvents()
        deleteEventFromStore(event)
    }

    func presentAddEvent(on date: Date) {
        let proposedDate = date.startOfDay()
        let startHour = Calendar.current.component(.hour, from: Date())
        let start = Calendar.current.date(bySettingHour: startHour, minute: 0, second: 0, of: proposedDate)!
        let end = Calendar.current.date(byAdding: .hour, value: 1, to: start)!
        let defaultCalID = calendarStore.store.defaultCalendarForNewEvents?.calendarIdentifier
        editingEvent = CalendarEvent(title: "", startDate: start, endDate: end, notes: "", color: "blue", calendarIdentifier: defaultCalID)
        editorMode = .add
        showingEditor = true
    }

    func presentEditEvent(_ event: CalendarEvent) {
        editingEvent = event
        editorMode = .edit
        showingEditor = true
    }

    func dismissEditor() {
        showingEditor = false
        editingEvent = nil
    }

    private lazy var ekMapURL: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("ek_map.json")
    }()

    // MARK: - Calendar Store Sync (Google / iCloud / Exchange via EventKit)

    private func pushEventToStore(_ event: CalendarEvent) {
        guard calendarStore.isAuthorized else { return }
        if let ekId = ekEventMap[event.id.uuidString] {
            _ = calendarStore.updateEvent(event, ekEventId: ekId)
        } else {
            if let ekId = calendarStore.addEvent(event) {
                ekEventMap[event.id.uuidString] = ekId
                saveEKMap()
                if let index = events.firstIndex(where: { $0.id == event.id }) {
                    events[index].ekEventId = ekId
                    saveEvents()
                }
            }
        }
    }

    private func deleteEventFromStore(_ event: CalendarEvent) {
        guard calendarStore.isAuthorized,
              let ekId = ekEventMap[event.id.uuidString] else { return }
        if calendarStore.deleteEvent(ekEventId: ekId) {
            ekEventMap.removeValue(forKey: event.id.uuidString)
            saveEKMap()
        }
    }

    func syncFromSystemCalendars() async {
        guard calendarStore.isAuthorized else { return }
        calendarStore.isSyncing = true
        defer { calendarStore.isSyncing = false }

        let start = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let end = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        let systemEvents = calendarStore.fetchEvents(from: start, to: end)

        let knownEkIds = Set(ekEventMap.values)
        let trulyNew = systemEvents.filter { !knownEkIds.contains($0.ekEventId ?? "") }

        for event in trulyNew {
            if let ekId = event.ekEventId {
                ekEventMap[event.id.uuidString] = ekId
            }
        }
        saveEKMap()

        events = (events + trulyNew).sorted { $0.startDate < $1.startDate }
        saveEvents()
        calendarStore.lastSyncError = nil
    }

    func connectSystemCalendars() async {
        await calendarStore.requestAccess()
        if calendarStore.isAuthorized {
            await syncFromSystemCalendars()
        }
    }

    private func saveEKMap() {
        guard let data = try? JSONEncoder().encode(ekEventMap) else { return }
        try? data.write(to: ekMapURL)
    }

    private func loadEKMap() {
        guard let data = try? Data(contentsOf: ekMapURL),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        ekEventMap = map
    }

    private lazy var eventsURL: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("events.json")
    }()

    private func saveEvents() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        try? data.write(to: eventsURL)
    }

    private func loadEvents() -> [CalendarEvent]? {
        guard let data = try? Data(contentsOf: eventsURL),
              let events = try? JSONDecoder().decode([CalendarEvent].self, from: data) else {
            return nil
        }
        return events
    }

    init() {
        self.selectedDate = Date()
        self.events = CalendarViewModel.loadPersistedEvents() ?? []
        if let saved = UserDefaults.standard.string(forKey: "lastViewMode"),
           let mode = ViewMode(rawValue: saved) {
            self.viewMode = mode
            if mode != .year && mode != .agenda {
                self.lastDetailViewMode = mode
            }
        }
        let savedZoom = UserDefaults.standard.double(forKey: "agendaZoomLevel")
        if savedZoom > 0 { self.agendaZoomLevel = CGFloat(savedZoom) }
        if UserDefaults.standard.object(forKey: "isDarkMode") != nil {
            self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        }
        self.weekdayColorLight = loadColor(forKey: "weekdayColorLight", default: .primary)
        self.weekendColorLight = loadColor(forKey: "weekendColorLight", default: .secondary)
        self.weekdayBgColorLight = loadColor(forKey: "weekdayBgColorLight", default: Color(.systemGroupedBackground))
        self.weekendBgColorLight = loadColor(forKey: "weekendBgColorLight", default: Color(.systemGroupedBackground))
        let savedFontScale = UserDefaults.standard.double(forKey: "fontScale")
        if savedFontScale > 0 { self.fontScale = CGFloat(savedFontScale) }
        let savedDayName = UserDefaults.standard.double(forKey: "dayNameFontSize")
        if savedDayName > 0 { self.dayNameFontSize = CGFloat(savedDayName) }
        let savedDayNumber = UserDefaults.standard.double(forKey: "dayNumberFontSize")
        if savedDayNumber > 0 { self.dayNumberFontSize = CGFloat(savedDayNumber) }
        if UserDefaults.standard.object(forKey: "dayNameBold") != nil {
            self.dayNameBold = UserDefaults.standard.bool(forKey: "dayNameBold")
        }
        let savedSensitivity = UserDefaults.standard.double(forKey: "swipeSensitivity")
        if savedSensitivity > 0 { self.swipeSensitivity = CGFloat(savedSensitivity) }
        self.todayColor = loadColor(forKey: "todayColor", default: .accentColor)
        loadEKMap()
    }

    // MARK: - Theme persistence

    private func saveColor(_ color: Color, forKey key: String) {
        let uiColor = UIColor(color)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: uiColor, requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadColor(forKey key: String, default color: Color) -> Color {
        guard let data = UserDefaults.standard.data(forKey: key),
              let uiColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) else {
            return color
        }
        return Color(uiColor)
    }

    private static func loadPersistedEvents() -> [CalendarEvent] {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let url = paths[0].appendingPathComponent("events.json")
        guard let data = try? Data(contentsOf: url),
              let events = try? JSONDecoder().decode([CalendarEvent].self, from: data) else {
            return []
        }
        return events
    }
}
