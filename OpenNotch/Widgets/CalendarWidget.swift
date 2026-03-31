import SwiftUI
import EventKit

// MARK: – Calendar Service

@Observable
final class CalendarService {

    static let shared = CalendarService()

    private let store = EKEventStore()
    private(set) var upcomingEvents: [CalendarEvent] = []
    private(set) var accessGranted = false
    private var timer: Timer?

    struct CalendarEvent: Identifiable, Equatable {
        let id: String
        let title: String
        let startDate: Date
        let endDate: Date
        let calendarColor: CGColor
        let calendarName: String
        let isAllDay: Bool
    }

    private init() {
        requestAccess()
    }

    func requestAccess() {
        if #available(macOS 14.0, *) {
            NSLog("[CalendarService] Requesting full access (macOS 14+)...")
            store.requestFullAccessToEvents { [weak self] granted, error in
                if let error = error {
                    NSLog("[CalendarService] Permission error: \(error.localizedDescription)")
                }
                NSLog("[CalendarService] Permission granted: \(granted)")
                DispatchQueue.main.async {
                    self?.accessGranted = granted
                    if granted {
                        self?.fetchEvents()
                        self?.startAutoRefresh()
                    }
                }
            }
        } else {
            NSLog("[CalendarService] Requesting access (legacy)...")
            store.requestAccess(to: .event) { [weak self] granted, error in
                if let error = error {
                    NSLog("[CalendarService] Permission error: \(error.localizedDescription)")
                }
                NSLog("[CalendarService] Permission granted: \(granted)")
                DispatchQueue.main.async {
                    self?.accessGranted = granted
                    if granted {
                        self?.fetchEvents()
                        self?.startAutoRefresh()
                    }
                }
            }
        }
    }

    func fetchEvents() {
        guard accessGranted else { 
            NSLog("[CalendarService] Fetch ignored: permission not granted yet.")
            return 
        }

        NSLog("[CalendarService] Fetching events...")
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? now.addingTimeInterval(86400)

        let predicate = store.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        let ekEvents = store.events(matching: predicate)
        NSLog("[CalendarService] Found \(ekEvents.count) events.")

        let mapped: [CalendarEvent] = ekEvents
            .sorted { $0.startDate < $1.startDate }
            .prefix(5)
            .map { event in
                CalendarEvent(
                    id: event.eventIdentifier,
                    title: event.title ?? "Untitled",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    calendarColor: event.calendar.cgColor,
                    calendarName: event.calendar.title,
                    isAllDay: event.isAllDay
                )
            }

        DispatchQueue.main.async { [weak self] in
            self?.upcomingEvents = mapped
        }
    }

    private func startAutoRefresh() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.fetchEvents()
        }
        timer?.tolerance = 10
    }
}

// MARK: – Widget View

struct CalendarWidget: View {
    @Environment(\.appearance) private var appearance
    @State private var service = CalendarService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .font(appearance.font(size: 14))
                    .foregroundStyle(appearance.color)
                Text("Upcoming")
                    .font(appearance.font(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            }

            if !service.accessGranted {
                Text("Calendar access not granted. Please allow in System Settings → Privacy → Calendars.")
                    .font(appearance.font(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.leading)
            } else if service.upcomingEvents.isEmpty {
                Text("No upcoming events today")
                    .font(appearance.font(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                ForEach(service.upcomingEvents) { event in
                    EventRow(event: event)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            service.fetchEvents()
        }
    }
}

// MARK: – Event Row

private struct EventRow: View {
    @Environment(\.appearance) private var appearance
    let event: CalendarService.CalendarEvent

    var body: some View {
        HStack(spacing: 10) {
            // Calendar color dot
            Circle()
                .fill(Color(cgColor: event.calendarColor) ?? .blue)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(appearance.font(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if event.isAllDay {
                    Text("All day")
                        .font(appearance.font(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                } else {
                    Text(timeRange)
                        .font(appearance.font(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))"
    }
}

// MARK: – Color extension for optional CGColor

extension Color {
    init?(cgColor: CGColor) {
        guard let nsColor = NSColor(cgColor: cgColor) else { return nil }
        self.init(nsColor: nsColor)
    }
}
