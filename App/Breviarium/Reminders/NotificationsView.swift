import SwiftUI

/// The *Notifications* page (1.6, `docs/1.6_plan.md`), opened from Settings as
/// *Romanus* opens its page: nine rows, the eight hours and the Martyrology, each with
/// its time (when on) and a switch. In English like *Theme* and *Font*; the hours keep
/// their Latin titles.
struct NotificationsView: View {
    @Environment(\.theme) private var theme
    @ObservedObject var settings: SettingsStore
    @ObservedObject private var center = ReminderCenter.shared

    var body: some View {
        List {
            Section {
                ForEach(Reminders.rows, id: \.key) { hour in
                    row(hour)
                }
            } footer: {
                if center.refused {
                    Text("Notifications are off for Breviarium. To allow them, open the Settings app, then Notifications, then Breviarium.")
                        .foregroundStyle(theme.chrome)
                        .accessibilityIdentifier("notificationsRefused")
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await center.refresh(settings) }
        #if DEBUG
        // What is scheduled, for the UI tests; one invisible point.
        .overlay(alignment: .bottomTrailing) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("remindersPending")
                .accessibilityValue(center.pendingSummary)
        }
        .overlay(alignment: .bottomLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("remindersDiagnostics")
                .accessibilityValue(center.diagnostics)
        }
        #endif
    }

    private func row(_ hour: OfficeHour) -> some View {
        let reminder = settings.reminders[hour.key]
        let isOn = reminder?.isOn == true
        return HStack {
            Text(hour.title)
                .foregroundStyle(theme.liturgicalText)
            Spacer()
            if isOn {
                DatePicker("", selection: time(of: hour), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .accessibilityLabel("\(hour.title), time")
                    .accessibilityIdentifier("reminderTime-\(hour.key)")
            }
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { on in
                    if on { center.turnOn(hour, in: settings) } else { center.turnOff(hour, in: settings) }
                }
            ))
            .labelsHidden()
            .accessibilityLabel(hour.title)
            .accessibilityIdentifier("reminder-\(hour.key)")
        }
    }

    /// The row's time as a `Date` today, for the picker; any time for any hour
    /// (decided 2026-11-14).
    private func time(of hour: OfficeHour) -> Binding<Date> {
        Binding(
            get: {
                let reminder = settings.reminders[hour.key] ?? Reminders.suggested(hour)
                return Calendar.current.date(bySettingHour: reminder.hour, minute: reminder.minute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                var reminder = settings.reminders[hour.key] ?? Reminders.suggested(hour)
                reminder.hour = parts.hour ?? reminder.hour
                reminder.minute = parts.minute ?? reminder.minute
                settings.reminders[hour.key] = reminder
            }
        )
    }
}
