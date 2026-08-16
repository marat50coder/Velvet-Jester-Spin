import Flutter
import UIKit
import UserNotifications

class SceneDelegate: FlutterSceneDelegate {
  static let launchRouteKey = "flutter.vjs_launch_route"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard
      let response = connectionOptions.notificationResponse,
      let destination = Self.destination(
        inside: response.notification.request.content.userInfo
      )
    else { return }

    let defaults = UserDefaults.standard
    defaults.set(destination, forKey: Self.launchRouteKey)
    defaults.synchronize()

    #if DEBUG
    NSLog("[SPIN.ROUTE] captured notification destination")
    #endif
  }

  // Order mirrors PulseRelay._urlKeys / _urlContainers on the Dart side —
  // keep both lists rotated in the same sweep per moderation §1.
  private static let routeKeys = [
    "target", "url", "deep_link", "link", "deeplink", "destination",
  ]
  private static let routeContainers = ["data", "payload"]

  private static func destination(
    inside payload: [AnyHashable: Any]
  ) -> String? {
    func firstValue(in dictionary: [AnyHashable: Any]) -> String? {
      for candidate in Self.routeKeys {
        guard let value = dictionary[candidate] as? String else { continue }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
      }
      return nil
    }

    if let direct = firstValue(in: payload) { return direct }

    for container in Self.routeContainers {
      if let nested = payload[container] as? [AnyHashable: Any],
         let value = firstValue(in: nested) {
        return value
      }
    }
    return nil
  }
}
