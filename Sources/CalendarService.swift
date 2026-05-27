import Foundation
import EventKit
import Combine

@MainActor
final class CalendarService: ObservableObject {
    enum Access: Equatable {
        case unknown, denied, granted
    }

    @Published private(set) var access: Access = .unknown
    @Published private(set) var upcoming: [UpcomingEvent] = []
    @Published private(set) var lastError: String?

    private let store = EKEventStore()
    private var refreshTask: Task<Void, Never>?

    init() {
        refreshAccessStatus()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: .EKEventStoreChanged,
            object: store
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func storeChanged() {
        Task { @MainActor in await self.refresh() }
    }

    func refreshAccessStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .authorized, .writeOnly:
            access = .granted
        case .denied, .restricted:
            access = .denied
        case .notDetermined:
            access = .unknown
        @unknown default:
            access = .unknown
        }
    }

    func requestAccess() async {
        do {
            if #available(macOS 14.0, *) {
                let granted = try await store.requestFullAccessToEvents()
                access = granted ? .granted : .denied
            } else {
                let granted = try await store.requestAccess(to: .event)
                access = granted ? .granted : .denied
            }
            if access == .granted { await refresh() }
        } catch {
            lastError = error.localizedDescription
            access = .denied
        }
    }

    func refresh() async {
        guard access == .granted else { return }
        let calendars = store.calendars(for: .event)
        let now = Date()
        let horizon = Calendar.current.date(byAdding: .hour, value: 24, to: now) ?? now.addingTimeInterval(86_400)
        let predicate = store.predicateForEvents(withStart: now, end: horizon, calendars: calendars)
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .filter { $0.startDate >= now.addingTimeInterval(-60) }
            .sorted { $0.startDate < $1.startDate }
        self.upcoming = events.prefix(25).map(UpcomingEvent.init(event:))
    }
}
