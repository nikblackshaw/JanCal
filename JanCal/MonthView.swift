import SwiftUI

struct MonthView: View {
    @ObservedObject var viewModel: CalendarViewModel

    private let calendar = Calendar.current
    private let dayHeaders = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: viewModel.selectedDate))!
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

    private var numWeeks: Int {
        monthDays.count / 7
    }

    private func isWeekend(_ dayIndex: Int) -> Bool {
        dayIndex == 0 || dayIndex == 6
    }

    var body: some View {
        GeometryReader { geo in
            let cellHeight = max(50, (geo.size.height - 80) / CGFloat(max(numWeeks, 1)))
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                dayHeaderRow
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                grid(cellHeight: cellHeight)
                    .padding(.horizontal, 4)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    if abs(value.translation.height) > abs(value.translation.width),
                       abs(value.translation.height) > 60 {
                        withAnimation(.spring(response: 0.4)) {
                            if value.translation.height < 0 {
                                viewModel.moveMonth(forward: true)
                            } else {
                                viewModel.moveMonth(forward: false)
                            }
                        }
                    }
                }
        )
    }

    private var header: some View {
        HStack {
            Button(action: { viewModel.moveMonth(forward: false) }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            Spacer()
            Text(monthName)
                .font(.title2.weight(.semibold))
            Spacer()
            Button(action: { viewModel.moveMonth(forward: true) }) {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
        }
    }

    private var monthName: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: viewModel.selectedDate)
    }

    private var dayHeaderRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(dayHeaders.enumerated()), id: \.offset) { i, header in
                Text(header)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
        }
    }

    private func grid(cellHeight: CGFloat) -> some View {
        VStack(spacing: 1) {
            ForEach(0..<numWeeks, id: \.self) { weekIndex in
                HStack(spacing: 1) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let i = weekIndex * 7 + dayIndex
                        if i < monthDays.count, let date = monthDays[i] {
                            cell(for: date, dayIndex: dayIndex, cellHeight: cellHeight)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: cellHeight)
                        }
                    }
                }
            }
        }
    }

    private func cell(for date: Date, dayIndex: Int, cellHeight: CGFloat) -> some View {
        let dayEvents = viewModel.events(for: date)
        let isToday = date.isToday()
        let isWeekend = isWeekend(dayIndex)

        return VStack(alignment: .leading, spacing: 1) {
            Text(date.dayNumber())
                .font(.system(size: 16, weight: isToday ? .bold : .regular))
                .foregroundColor(dayTextColor(isToday: isToday, isWeekend: isWeekend))
                .padding(.top, 2)
                .padding(.leading, 4)

            if !dayEvents.isEmpty {
                ForEach(dayEvents.prefix(3)) { event in
                    HStack(spacing: 2) {
                        Circle()
                            .fill(colorForName(event.color))
                            .frame(width: 5, height: 5)
                        Text(event.title)
                            .font(.system(size: 15))
                            .lineLimit(1)
                    }
                    .padding(.leading, 4)
                }
                if dayEvents.count > 3 {
                    Text("+\(dayEvents.count - 3) more")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: cellHeight)
        .background(cellBackground(isToday: isToday, isWeekend: isWeekend))
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedDate = date
            viewModel.viewMode = viewModel.lastDetailViewMode
        }
    }

    private func dayTextColor(isToday: Bool, isWeekend: Bool) -> Color {
        if isToday { return .primary }
        guard !viewModel.isDarkMode else { return .primary }
        return isWeekend ? viewModel.weekendColorLight : viewModel.weekdayColorLight
    }

    private func cellBackground(isToday: Bool, isWeekend: Bool) -> Color {
        if isToday { return viewModel.todayColor }
        guard !viewModel.isDarkMode else { return Color.clear }
        return isWeekend ? viewModel.weekendBgColorLight : viewModel.weekdayBgColorLight
    }
}
