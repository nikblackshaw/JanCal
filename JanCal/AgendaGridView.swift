import SwiftUI

struct AgendaGridView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @GestureState private var pinchScale: CGFloat = 1.0
    private let minZoom: CGFloat = 0.5
    private let maxZoom: CGFloat = 4.0

    var body: some View {
        GeometryReader { geo in
            let zoomLevel = viewModel.agendaZoomLevel * pinchScale

            weekView(weekStart: viewModel.selectedWeekStart, geo: geo, zoomLevel: zoomLevel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .simultaneousGesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            guard abs(value.translation.height) > 60 else { return }
                            if value.translation.height > 0 {
                                withAnimation(.spring(response: 0.4)) {
                                    viewModel.moveWeek(forward: false)
                                }
                            } else {
                                withAnimation(.spring(response: 0.4)) {
                                    viewModel.moveWeek(forward: true)
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .updating($pinchScale) { value, state, _ in
                            state = value
                        }
                        .onEnded { value in
                            let newZoom = viewModel.agendaZoomLevel * value
                            viewModel.agendaZoomLevel = min(max(newZoom, minZoom), maxZoom)
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.agendaZoomLevel = 1.0
                    }
                }
        }
        .clipped()
    }

    private func weekView(weekStart: Date, geo: GeometryProxy, zoomLevel: CGFloat) -> some View {
        let days = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
        let rowHeight = geo.size.height / 4

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                AgendaDayCell(date: days[0], events: viewModel.events(for: days[0]), viewModel: viewModel)
                    .frame(height: rowHeight)
                AgendaDayCell(date: days[1], events: viewModel.events(for: days[1]), viewModel: viewModel)
                    .frame(height: rowHeight)
            }
            HStack(spacing: 0) {
                AgendaDayCell(date: days[2], events: viewModel.events(for: days[2]), viewModel: viewModel)
                    .frame(height: rowHeight)
                AgendaDayCell(date: days[3], events: viewModel.events(for: days[3]), viewModel: viewModel)
                    .frame(height: rowHeight)
            }
            HStack(spacing: 0) {
                AgendaDayCell(date: days[4], events: viewModel.events(for: days[4]), viewModel: viewModel)
                    .frame(height: rowHeight)
                AgendaDayCell(date: days[5], events: viewModel.events(for: days[5]), viewModel: viewModel)
                    .frame(height: rowHeight)
            }
            HStack(spacing: 0) {
                AgendaDayCell(date: days[6], events: viewModel.events(for: days[6]), viewModel: viewModel)
                    .frame(height: rowHeight)
                MonthCalendarCell(selectedDate: days[6], viewModel: viewModel)
                    .frame(height: rowHeight)
            }
        }
        .frame(width: geo.size.width)
        .scaleEffect(zoomLevel, anchor: .topLeading)
    }
}

struct AgendaDayCell: View {
    let date: Date
    let events: [CalendarEvent]
    @ObservedObject var viewModel: CalendarViewModel

    private var dayTextColor: Color {
        if date.isToday() { return .accentColor }
        guard !viewModel.isDarkMode else { return .primary }
        let weekday = Calendar.current.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 {
            return viewModel.weekendColorLight
        }
        return viewModel.weekdayColorLight
    }

    private var backgroundColor: Color {
        if date.isToday() { return viewModel.todayColor }
        guard !viewModel.isDarkMode else { return Color.clear }
        let weekday = Calendar.current.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 {
            return viewModel.weekendBgColorLight
        }
        return viewModel.weekdayBgColorLight
    }

    private func scaledFont(_ baseSize: CGFloat) -> Font {
        .system(size: baseSize * viewModel.fontScale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4 * viewModel.fontScale) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(date.dayOfWeek())
                        .font(.system(size: viewModel.dayNameFontSize, weight: viewModel.dayNameBold ? .bold : .regular))
                        .foregroundColor(.secondary)
                    Text(date.dayNumber())
                        .font(.system(size: viewModel.dayNumberFontSize, weight: date.isToday() ? .bold : .regular))
                        .foregroundColor(dayTextColor)
                }
                Spacer()
            }

            Divider()

            if events.isEmpty {
                Spacer(minLength: 0)
            } else {
                let eventContent = VStack(alignment: .leading, spacing: 4 * viewModel.fontScale) {
                    ForEach(events) { event in
                        HStack(spacing: 4 * viewModel.fontScale) {
                            Circle()
                                .fill(colorForName(event.color))
                                .frame(width: 6 * viewModel.fontScale, height: 6 * viewModel.fontScale)
                            Text(event.title)
                                .font(scaledFont(12))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.presentEditEvent(event)
                        }
                    }
                }
                if events.count > 4 {
                    ScrollView(.vertical, showsIndicators: false) {
                        eventContent
                    }
                } else {
                    VStack(spacing: 4 * viewModel.fontScale) {
                        eventContent
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(8 * viewModel.fontScale)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 0).fill(backgroundColor)
        )
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedDate = date
        }
    }
}

struct MonthCalendarCell: View {
    let selectedDate: Date
    @ObservedObject var viewModel: CalendarViewModel

    private let calendar = Calendar.current
    private let dayHeaders = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
    }

    private var monthDays: [Date?] {
        let start = monthStart
        let range = calendar.range(of: .day, in: .month, for: start)!
        let firstWeekday = calendar.component(.weekday, from: start)
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: start) {
                days.append(date)
            }
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    private var monthName: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: selectedDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { viewModel.moveMonth(forward: false) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                Spacer()
                Text(monthName)
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button(action: { viewModel.moveMonth(forward: true) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(dayHeaders.enumerated()), id: \.offset) { _, header in
                        Text(header)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 2)
                    }
                }
                    ForEach(0..<(monthDays.count / 7), id: \.self) { weekIndex in
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { dayIndex in
                                let i = weekIndex * 7 + dayIndex
                                if i < monthDays.count, let date = monthDays[i] {
                                    let isToday = date.isToday()
                                    let isWeekend = dayIndex == 0 || dayIndex == 6
                                    Text(date.dayNumber())
                                        .font(.system(size: 14, weight: isToday ? .bold : .regular))
                                        .foregroundColor(isToday ? .primary : (isWeekend ? .accentColor.opacity(0.5) : .primary))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 20)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(isToday ? Color.blue.opacity(0.05) : Color.clear)
                                        )
                                        .onTapGesture {
                                            viewModel.selectedDate = date
                                        }
                                } else {
                                    Color.clear
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 20)
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 2)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
}
