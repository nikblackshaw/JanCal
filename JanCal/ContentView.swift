import SwiftUI
import EventKit

struct ContentView: View {
    @StateObject private var viewModel = CalendarViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $viewModel.viewMode) {
                    ForEach(CalendarViewModel.ViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode == .month ? "calendar" : mode == .agenda ? "square.grid.2x2" : mode == .week ? "list.bullet" : mode == .day ? "rectangle.grid.1x2" : "square.grid.3x3")
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))

                if let error = viewModel.calendarStore.lastSyncError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08))
                }

                switch viewModel.viewMode {
                case .month:
                    MonthView(viewModel: viewModel)
                case .agenda:
                    AgendaGridView(viewModel: viewModel)
                case .week:
                    WeekAgendaView(viewModel: viewModel)
                case .day:
                    DayView(viewModel: viewModel)
                case .year:
                    YearView(viewModel: viewModel)
                }
            }
            .navigationTitle(headerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .preferredColorScheme(viewModel.isDarkMode ? .dark : .light)
            .sheet(isPresented: $viewModel.showSettings) {
                SettingsView(viewModel: viewModel)
            }
            .onAppear {
                let status = EKEventStore.authorizationStatus(for: .event)
                let hasAccess: Bool
                if #available(iOS 17.0, *) {
                    hasAccess = status == .fullAccess || status == .authorized
                } else {
                    hasAccess = status == .authorized
                }
                if hasAccess {
                    viewModel.calendarStore.isAuthorized = true
                    viewModel.calendarStore.loadCalendars()
                    Task { await viewModel.syncFromSystemCalendars() }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingEditor) {
            EventEditorView(viewModel: viewModel)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: { viewModel.goToToday() }) {
                Image(systemName: "arrow.uturn.backward")
            }
            .font(.subheadline)
        }

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button(action: { viewModel.presentAddEvent(on: viewModel.selectedDate) }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }

            if viewModel.calendarStore.isAuthorized {
                Button(action: { Task { await viewModel.syncFromSystemCalendars() } }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .disabled(viewModel.calendarStore.isSyncing)
            } else {
                Button(action: { Task { await viewModel.connectSystemCalendars() } }) {
                    Image(systemName: "calendar.badge.plus")
                }
            }

            Button(action: { viewModel.showSettings = true }) {
                Image(systemName: "gearshape")
            }
            .id("gear-\(viewModel.showSettings)")
        }
    }

    private var headerTitle: String {
        switch viewModel.viewMode {
        case .month:
            let fmt = DateFormatter()
            fmt.dateFormat = "MMMM yyyy"
            return fmt.string(from: viewModel.selectedDate)
        case .year:
            return "\(Calendar.current.component(.year, from: viewModel.selectedDate))"
        case .agenda:
            let start = viewModel.selectedWeekStart
            let end = Calendar.current.date(byAdding: .day, value: 6, to: start)!
            let fmt = DateFormatter()
            fmt.dateFormat = "MMMM yyyy"
            if Calendar.current.component(.month, from: start) == Calendar.current.component(.month, from: end) {
                return fmt.string(from: start)
            }
            let sm = DateFormatter().shortMonthSymbols[Calendar.current.component(.month, from: start) - 1]
            let em = DateFormatter().shortMonthSymbols[Calendar.current.component(.month, from: end) - 1]
            return "\(sm) – \(em) \(Calendar.current.component(.year, from: start))"
        case .week:
            let start = viewModel.selectedWeekStart
            let end = Calendar.current.date(byAdding: .day, value: 6, to: start)!
            let fmt = DateFormatter()
            fmt.dateFormat = "MMMM yyyy"
            if Calendar.current.component(.month, from: start) == Calendar.current.component(.month, from: end) {
                return fmt.string(from: start)
            }
            let sm = DateFormatter().shortMonthSymbols[Calendar.current.component(.month, from: start) - 1]
            let em = DateFormatter().shortMonthSymbols[Calendar.current.component(.month, from: end) - 1]
            return "\(sm) – \(em) \(Calendar.current.component(.year, from: start))"
        case .day:
            let fmt = DateFormatter()
            fmt.dateFormat = "EEEE, MMM d"
            return fmt.string(from: viewModel.selectedDate)
        }
    }
}
