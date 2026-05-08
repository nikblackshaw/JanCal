import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $viewModel.isDarkMode)
                    ColorPicker("Today highlight", selection: $viewModel.todayColor, supportsOpacity: false)
                }

                if !viewModel.isDarkMode {
                    Section("Text Colors") {
                        ColorPicker("Weekday", selection: $viewModel.weekdayColorLight, supportsOpacity: false)
                        ColorPicker("Weekend", selection: $viewModel.weekendColorLight, supportsOpacity: false)
                    }
                    Section("Background Colors") {
                        ColorPicker("Weekday", selection: $viewModel.weekdayBgColorLight, supportsOpacity: false)
                        ColorPicker("Weekend", selection: $viewModel.weekendBgColorLight, supportsOpacity: false)
                    }
                }

                Section("Font Size") {
                    Stepper("\(Int(viewModel.fontScale * 100))%", value: $viewModel.fontScale, in: 0.6...2.0, step: 0.1)
                    HStack {
                        Text("Day name:")
                        Slider(value: $viewModel.dayNameFontSize, in: 10...30, step: 1)
                        Text("\(Int(viewModel.dayNameFontSize))pt")
                            .frame(width: 36)
                    }
                    Toggle("Bold day name", isOn: $viewModel.dayNameBold)
                    HStack {
                        Text("Day number:")
                        Slider(value: $viewModel.dayNumberFontSize, in: 14...50, step: 1)
                        Text("\(Int(viewModel.dayNumberFontSize))pt")
                            .frame(width: 36)
                    }
                }

                Section("Swipe Sensitivity") {
                    HStack {
                        Slider(value: $viewModel.swipeSensitivity, in: 10...100, step: 5)
                        Text("\(Int(viewModel.swipeSensitivity))pt")
                            .frame(width: 40)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { viewModel.showSettings = false }
                }
            }
        }
    }
}
