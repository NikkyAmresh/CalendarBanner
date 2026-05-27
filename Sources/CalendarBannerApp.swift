import SwiftUI

@main
struct CalendarBannerApp: App {
    @StateObject private var service = CalendarService()
    @StateObject private var scheduler: ReminderScheduler

    init() {
        let svc = CalendarService()
        _service = StateObject(wrappedValue: svc)
        _scheduler = StateObject(wrappedValue: ReminderScheduler(service: svc))
    }

    var body: some Scene {
        MenuBarExtra("Calendar Banner", systemImage: "airplane") {
            MenuBarContent()
                .environmentObject(service)
                .environmentObject(scheduler)
                .task { await bootstrap() }
        }
        .menuBarExtraStyle(.window)
    }

    @MainActor
    private func bootstrap() async {
        service.refreshAccessStatus()
        if service.access == .unknown {
            await service.requestAccess()
        } else if service.access == .granted {
            await service.refresh()
        }
        scheduler.start()
    }
}
