import SwiftUI

struct WeekAgendaView: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(viewModel.weekDays, id: \.timeIntervalSinceReferenceDate) { date in
                        DayHeaderView(
                            date: date,
                            isSelected: date.isSameDay(as: viewModel.selectedDate),
                            eventCount: viewModel.events(for: date).count
                        )
                        .frame(width: 52)
                        .onTapGesture {
                            withAnimation { viewModel.selectedDate = date }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))

            Divider()

            eventList
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    if abs(value.translation.height) > abs(value.translation.width),
                       abs(value.translation.height) > 60 {
                        withAnimation(.spring(response: 0.4)) {
                            if value.translation.height < 0 {
                                viewModel.moveWeek(forward: true)
                            } else {
                                viewModel.moveWeek(forward: false)
                            }
                        }
                    }
                }
        )
    }

    private var eventList: some View {
        let dayEvents = viewModel.selectedDayEvents

        return Group {
            if dayEvents.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No events this day")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Tap + to add one")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(dayEvents) { event in
                        EventRowView(event: event)
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
                .listStyle(.plain)
            }
        }
    }
}

struct DayHeaderView: View {
    let date: Date
    let isSelected: Bool
    let eventCount: Int

    private var shortLabel: String {
        let idx = Calendar.current.component(.weekday, from: date)
        switch idx {
        case 2: return "M"
        case 3: return "T"
        case 4: return "W"
        case 5: return "T"
        case 6: return "F"
        case 7: return "S"
        default: return "Su"
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(shortLabel)
                .font(.caption2)
                .foregroundColor(date.isToday() ? .accentColor : .secondary)
            Text(date.dayNumber())
                .font(.callout)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
            if eventCount > 0 {
                Text("\(eventCount)")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct EventRowView: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(eventColor)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(event.startDate, style: .time)
                    Text("–")
                    Text(event.endDate, style: .time)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                if !event.notes.isEmpty {
                    Text(event.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
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
