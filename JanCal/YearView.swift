import SwiftUI

struct YearView: View {
    @ObservedObject var viewModel: CalendarViewModel

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    private let dayHeaders = ["S", "M", "T", "W", "T", "F", "S"]

    private var months: [Date] {
        let year = calendar.component(.year, from: viewModel.selectedDate)
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        return (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(months, id: \.timeIntervalSinceReferenceDate) { month in
                    MonthCardView(
                        month: month,
                        selectedDate: viewModel.selectedDate,
                        viewModel: viewModel
                    )
                }
            }
            .padding(12)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    if abs(value.translation.height) > abs(value.translation.width),
                       abs(value.translation.height) > 60 {
                        withAnimation(.spring(response: 0.4)) {
                            if value.translation.height < 0 {
                                viewModel.moveYear(forward: true)
                            } else {
                                viewModel.moveYear(forward: false)
                            }
                        }
                    }
                }
        )
    }
}

struct MonthCardView: View {
    let month: Date
    let selectedDate: Date
    @ObservedObject var viewModel: CalendarViewModel

    private let calendar = Calendar.current
    private let dayHeaders = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthName: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM"
        return fmt.string(from: month)
    }

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(monthName)
                .font(.system(size: 20, weight: .semibold))
                .padding(.leading, 4)

            HStack(spacing: 0) {
                ForEach(Array(dayHeaders.enumerated()), id: \.offset) { _, header in
                    Text(header)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(0..<(monthDays.count / 7), id: \.self) { weekIndex in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let i = weekIndex * 7 + dayIndex
                        if i < monthDays.count, let date = monthDays[i] {
                            let isToday = date.isToday()
                            let isSelected = date.isSameDay(as: selectedDate)
                            Text(date.dayNumber())
                                .font(.system(size: 12))
                                .foregroundColor(isToday ? .primary : (isSelected ? .white : .primary))
                                .fontWeight(isToday || isSelected ? .bold : .regular)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .frame(height: 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isToday ? Color.blue.opacity(1.0) : (isSelected ? Color.accentColor : Color.clear))
                                )
                                    .onTapGesture {
                                        viewModel.selectedDate = date
                                        viewModel.viewMode = viewModel.lastDetailViewMode
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
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
}
