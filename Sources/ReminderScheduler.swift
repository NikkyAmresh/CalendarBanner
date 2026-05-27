import Foundation
import Combine

@MainActor
final class ReminderScheduler: ObservableObject {
    /// How many minutes before the event the banner starts firing.
    /// A value of 5 fires at T-5, T-4, T-3, T-2, T-1 and T-0 ("starting now").
    @Published var leadWindowMinutes: Int {
        didSet {
            let clamped = max(1, min(30, leadWindowMinutes))
            if clamped != leadWindowMinutes {
                leadWindowMinutes = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: "leadWindowMinutes")
        }
    }

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "isEnabled") }
    }

    private let service: CalendarService
    private var timer: Timer?
    private var firedKeys: Set<String> = []

    init(service: CalendarService) {
        self.service = service
        let storedWindow = UserDefaults.standard.object(forKey: "leadWindowMinutes") as? Int
        self.leadWindowMinutes = storedWindow.map { max(1, min(30, $0)) } ?? 5
        if UserDefaults.standard.object(forKey: "isEnabled") == nil {
            self.isEnabled = true
        } else {
            self.isEnabled = UserDefaults.standard.bool(forKey: "isEnabled")
        }
    }

    func start() {
        timer?.invalidate()
        // Tick frequently so a per-minute schedule fires within ~10s of the exact minute.
        let t = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        Task { @MainActor in await self.tick() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() async {
        await service.refresh()
        guard isEnabled else { return }
        let now = Date()
        // Leads: window..1, then 0 (starting now). Largest first so we fire 5 before 4 etc.
        let leads: [Int] = Array((1...leadWindowMinutes).reversed()) + [0]

        for event in service.upcoming {
            let secondsUntil = event.start.timeIntervalSince(now)
            for lead in leads {
                let leadSeconds = TimeInterval(lead * 60)
                let key = "\(event.id)#\(lead)"
                if firedKeys.contains(key) { continue }
                // Fire when within +/- 15s of the target lead boundary.
                let lower = leadSeconds - 15
                let upper = leadSeconds + 15
                if secondsUntil <= upper && secondsUntil >= lower {
                    firedKeys.insert(key)
                    BannerController.shared.enqueue(makeFlight(for: event, leadMinutes: lead))
                }
            }
        }
        pruneFiredKeys()
    }

    private func pruneFiredKeys() {
        let liveIds = Set(service.upcoming.map { $0.id })
        firedKeys = firedKeys.filter { key in
            guard let id = key.split(separator: "#").first else { return false }
            return liveIds.contains(String(id))
        }
    }

    func testBanner() {
        let mock = BannerFlight(text: "Test flight: standup in 5 min")
        BannerController.shared.enqueue(mock)
    }

    private func makeFlight(for event: UpcomingEvent, leadMinutes lead: Int) -> BannerFlight {
        let suffix: String
        switch lead {
        case 0: suffix = "starting now"
        case 1: suffix = "in 1 min"
        default: suffix = "in \(lead) min"
        }
        return BannerFlight(text: "\(event.title) \(suffix)")
    }
}
