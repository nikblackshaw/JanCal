import SwiftUI
import EventKit

struct EventEditorView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600)
    @State private var notes: String = ""
    @State private var url: String = ""
    @State private var selectedColor: String = "blue"
    @State private var selectedCalendarID: String = ""
    @State private var showDeleteAlert = false
    @State private var showingFilePicker = false
    @State private var attachedFileName: String?

    private var calendars: [EKCalendar] {
        viewModel.calendarStore.availableCalendars
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                }

                Section("Date & Time") {
                    DatePicker("Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("Start", selection: $startDate, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Calendar") {
                    if calendars.isEmpty {
                        Text("No calendars available")
                            .foregroundColor(.secondary)
                    } else if viewModel.editorMode == .add {
                        Picker("Save to", selection: $selectedCalendarID) {
                            ForEach(calendars, id: \.calendarIdentifier) { cal in
                                HStack {
                                    Circle()
                                        .fill(Color(cgColor: cal.cgColor ?? CGColor(gray: 0.5, alpha: 1)))
                                        .frame(width: 10, height: 10)
                                    Text(cal.title)
                                }
                                .tag(cal.calendarIdentifier)
                            }
                        }
                    } else {
                        HStack {
                            Text("Calendar")
                            Spacer()
                            if let cal = calendars.first(where: { $0.calendarIdentifier == selectedCalendarID }) {
                                HStack {
                                    Circle()
                                        .fill(Color(cgColor: cal.cgColor ?? CGColor(gray: 0.5, alpha: 1)))
                                        .frame(width: 10, height: 10)
                                    Text(cal.title)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Color") {
                    HStack(spacing: 16) {
                        Spacer()
                        ForEach(eventColors, id: \.name) { item in
                            Circle()
                                .fill(item.color)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == item.name ? Color.primary : Color.clear, lineWidth: 3)
                                )
                                .overlay(
                                    selectedColor == item.name
                                        ? Image(systemName: "checkmark").font(.caption).foregroundColor(.white)
                                        : nil
                                )
                                .onTapGesture {
                                    selectedColor = item.name
                                }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                Section("Attachment") {
                    HStack {
                        if let name = attachedFileName {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.accentColor)
                                Text(name)
                                    .lineLimit(1)
                                    .font(.subheadline)
                                Button { clearAttachment() } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                        } else {
                            TextField("URL or tap Browse", text: $url)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                        Spacer()
                        Button("Browse") { showingFilePicker = true }
                            .font(.subheadline)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                if viewModel.editorMode == .edit {
                    Section {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Delete Event", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(viewModel.editorMode == .add ? "New Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.dismissEditor() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let selected = urls.first else { return }
                    importFile(from: selected)
                case .failure(let error):
                    print("File picker error: \(error)")
                }
            }
            .alert("Delete Event", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let event = viewModel.editingEvent {
                        viewModel.deleteEvent(event)
                        viewModel.dismissEditor()
                    }
                }
            } message: {
                Text("Are you sure you want to delete this event?")
            }
        }
        .onAppear {
            populateFromEditingEvent()
        }
    }

    private func populateFromEditingEvent() {
        guard let event = viewModel.editingEvent else { return }
        title = event.title
        startDate = event.startDate
        endDate = event.endDate
        notes = event.notes
        url = event.url ?? ""
        if let urlStr = event.url, let fileURL = URL(string: urlStr), fileURL.isFileURL {
            attachedFileName = fileURL.lastPathComponent
        }
        selectedColor = event.color
        selectedCalendarID = event.calendarIdentifier ?? calendars.first?.calendarIdentifier ?? ""
    }

    private func importFile(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url)
            let fileName = url.lastPathComponent
            let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_" + fileName)
            try data.write(to: localURL)
            self.url = localURL.absoluteString
            attachedFileName = fileName
        } catch {
            print("Failed to import file: \(error)")
        }
    }

    private func clearAttachment() {
        if !url.isEmpty, let existingURL = URL(string: url), existingURL.isFileURL {
            try? FileManager.default.removeItem(at: existingURL)
        }
        url = ""
        attachedFileName = nil
    }

    private func save() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let event = CalendarEvent(
            id: viewModel.editingEvent?.id ?? UUID(),
            title: title,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            color: selectedColor,
            ekEventId: viewModel.editorMode == .edit ? viewModel.editingEvent?.ekEventId : nil,
            calendarIdentifier: viewModel.editorMode == .add ? selectedCalendarID : viewModel.editingEvent?.calendarIdentifier,
            url: url.trimmingCharacters(in: .whitespaces).isEmpty ? nil : url
        )
        switch viewModel.editorMode {
        case .add:
            viewModel.addEvent(event)
        case .edit:
            viewModel.updateEvent(event)
        }
        viewModel.dismissEditor()
    }
}
