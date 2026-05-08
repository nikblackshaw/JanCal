import SwiftUI

struct DayView: View {
    @ObservedObject var viewModel: CalendarViewModel

    private let startHour = 6
    private let endHour = 22

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(startHour..<endHour, id: \.self) { hour in
                    let hourEvents = viewModel.selectedDayEvents.filter {
                        Calendar.current.component(.hour, from: $0.startDate) == hour
                    }

                    HourSectionView(hour: hour, events: hourEvents, viewModel: viewModel)
                        .id(hour)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
            .listStyle(.plain)
            .onAppear {
                let currentHour = Calendar.current.component(.hour, from: Date())
                let scrollHour = max(startHour, min(currentHour, endHour - 1))
                if Calendar.current.isDateInToday(viewModel.selectedDate) {
                    proxy.scrollTo(scrollHour, anchor: .top)
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    if abs(value.translation.height) > abs(value.translation.width),
                       abs(value.translation.height) > 60 {
                        withAnimation(.spring(response: 0.4)) {
                            if value.translation.height < 0 {
                                viewModel.moveDay(forward: true)
                            } else {
                                viewModel.moveDay(forward: false)
                            }
                        }
                    }
                }
        )
    }
}

struct HourSectionView: View {
    let hour: Int
    let events: [CalendarEvent]
    @ObservedObject var viewModel: CalendarViewModel

    private var isCurrentHour: Bool {
        Calendar.current.component(.hour, from: Date()) == hour && Calendar.current.isDateInToday(Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Text(timeString)
                    .font(.caption)
                    .foregroundColor(isCurrentHour ? .accentColor : .secondary)
                    .fontWeight(isCurrentHour ? .bold : .regular)
                    .frame(width: 52, alignment: .trailing)
                    .padding(.trailing, 8)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 4) {
                    if events.isEmpty {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 40)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: viewModel.selectedDate) ?? viewModel.selectedDate
                                viewModel.presentAddEvent(on: date)
                            }
                    } else {
                        ForEach(events) { event in
                            EventCardView(event: event)
                                .onTapGesture {
                                    viewModel.presentEditEvent(event)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        viewModel.deleteEvent(event)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
                .padding(.leading, 68)
        }
        .background(
            isCurrentHour
                ? Color.accentColor.opacity(0.05)
                : Color.clear
        )
    }

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return fmt.string(from: date)
    }
}

struct EventCardView: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(eventColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text("\(event.startDate, style: .time) – \(event.endDate, style: .time)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .background(eventColor.opacity(0.1))
        .cornerRadius(8)
    }

    private var eventColor: Color {
        switch event.color {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        default: return .blue
        }
    }
}
