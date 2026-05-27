import Foundation
import EventKit

struct UpcomingEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let start: Date
    let calendarTitle: String
    let calendarSource: String

    var minutesUntilStart: Int {
        Int(start.timeIntervalSinceNow / 60.0)
    }

    init(event: EKEvent) {
        self.id = event.eventIdentifier ?? UUID().uuidString
        self.title = (event.title?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled event"
        self.start = event.startDate
        self.calendarTitle = event.calendar?.title ?? "Calendar"
        self.calendarSource = event.calendar?.source?.title ?? ""
    }
}
