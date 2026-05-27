import SwiftUI

struct MenuBarContent: View {
    @EnvironmentObject private var service: CalendarService
    @EnvironmentObject private var scheduler: ReminderScheduler

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            accessSection
            Divider()
            upcomingSection
            Divider()
            settingsSection
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 360)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "airplane")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.tint)
            Text("Calendar Banner")
                .font(.headline)
            Spacer()
            Toggle("On", isOn: $scheduler.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    @ViewBuilder
    private var accessSection: some View {
        switch service.access {
        case .granted:
            Label("Calendar access granted", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.subheadline)
        case .denied:
            VStack(alignment: .leading, spacing: 6) {
                Label("Calendar access denied", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline)
                Button("Open Privacy Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.small)
            }
        case .unknown:
            Button("Grant Calendar Access") {
                Task { await service.requestAccess() }
            }
            .controlSize(.small)
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Next 24 hours")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    Task { await service.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }

            if service.upcoming.isEmpty {
                Text("No upcoming events.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(service.upcoming.prefix(5)) { event in
                    EventRow(event: event)
                }
                if service.upcoming.count > 5 {
                    Text("(+\(service.upcoming.count - 5) more)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reminder window")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                Stepper(value: $scheduler.leadWindowMinutes, in: 1...30) {
                    Text("Start \(scheduler.leadWindowMinutes) min before, fire every minute")
                        .font(.caption)
                }
            }
            Text("(\(reminderSequenceText))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button("Test banner now") {
                scheduler.testBanner()
            }
            .controlSize(.small)
        }
    }

    private var reminderSequenceText: String {
        let leads = Array((1...scheduler.leadWindowMinutes).reversed()) + [0]
        let formatted = leads.map { $0 == 0 ? "now" : "\($0)m" }
        if formatted.count <= 7 { return formatted.joined(separator: " > ") }
        return "\(formatted.first ?? "")m > ... > 1m > now"
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .controlSize(.small)
        }
    }
}

private struct EventRow: View {
    let event: UpcomingEvent

    private var subtitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeString = formatter.string(from: event.start)
        let mins = event.minutesUntilStart
        let relative: String
        if mins < 0 { relative = "started" }
        else if mins == 0 { relative = "now" }
        else if mins < 60 { relative = "in \(mins) min" }
        else { relative = "in \(mins / 60)h \(mins % 60)m" }
        return "\(timeString) (\(relative)) (\(event.calendarTitle))"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(.tint)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.callout)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}
