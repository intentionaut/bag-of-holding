import BagCore
import UserNotifications

/// The optional daily nudge. Off unless switched on; one repeating local notification.
enum Reminder {
    static let id = "daily-reach"

    static func schedule(on: Bool, minutes: Int, bag: Bag, denied: @escaping () -> Void) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard on else { return }

        let content = UNMutableNotificationContent()
        content.title = "Reach into the bag"
        // Notifications show on the lock screen, so the body never names what's in the bag.
        content.body = bag.items.isEmpty ? "It's empty for now. Drop something in."
                                         : "Something kind is waiting for you."
        let when = DateComponents(hour: minutes / 60, minute: minutes % 60)
        let request = UNNotificationRequest(
            identifier: id, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true))

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return DispatchQueue.main.async(execute: denied) }
            center.add(request)
        }
    }
}
