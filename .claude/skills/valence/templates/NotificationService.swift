import UserNotifications
import FirebaseMessaging

// Add to a Notification Service Extension target linked with Firebase Messaging.
// Experimental and untested: requires Xcode, APNs provisioning and a real device.
final class NotificationService: UNNotificationServiceExtension {
    private var handler: ((UNNotificationContent) -> Void)?
    private var content: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        handler = contentHandler
        guard let mutable = request.content.mutableCopy() as? UNMutableNotificationContent else {
            finish(request.content)
            return
        }
        content = mutable
        Messaging.serviceExtension().populateNotificationContent(mutable) { [weak self] result in
            self?.finish(result)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let content = content { finish(content) }
    }

    private func finish(_ result: UNNotificationContent) {
        let callback = handler
        handler = nil
        callback?(result)
    }
}
