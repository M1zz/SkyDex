import Foundation
import UserNotifications

/// The evening heads-up: "tomorrow is clear, want to look up?"
///
/// This is the only notification the app sends, and the restraint is the
/// design. A reminder that fires because *you* did nothing teaches people to
/// turn notifications off; one that fires because the *sky* is doing something
/// is worth keeping on. So nothing here counts days, and a grey week is a
/// silent week.
enum ClearSkyNotifier {
    /// Late enough that tomorrow is a real plan, early enough to still be awake.
    static let eveningHour = 20
    /// A forecast five days out is not firm enough to promise anything.
    static let maximumScheduled = 3

    private static let identifierPrefix = "clear-sky."

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    /// Replaces every pending notice with what the current forecast supports.
    ///
    /// Rescheduling wholesale rather than patching is what keeps a promise from
    /// outliving the forecast that made it: if tomorrow clouds over, last
    /// night's "it will be clear" is withdrawn instead of firing anyway.
    static func reschedule(for days: [SkyForecast], enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        guard enabled, await isAuthorized() else { return }

        let calendar = Calendar.current
        var scheduled = 0

        for day in days.sorted(by: { $0.date < $1.date }) where day.isWorthTelling {
            guard scheduled < maximumScheduled else { break }
            guard let eve = calendar.date(byAdding: .day, value: -1, to: day.date),
                  let fireDate = calendar.date(
                      bySettingHour: eveningHour, minute: 0, second: 0, of: eve
                  ),
                  fireDate > .now
            else { continue }

            let content = UNMutableNotificationContent()
            content.title = "내일 하늘"
            content.body = day.invitation(for: .tomorrow)
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: fireDate
                ),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: identifierPrefix + ISO8601DateFormatter().string(from: day.date),
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
            scheduled += 1
        }
    }

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
    }
}
