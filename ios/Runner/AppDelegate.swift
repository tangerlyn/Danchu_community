import Flutter
import UIKit
import UserNotifications

import NMapsMap
import NidThirdPartyLogin
import NidCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    NMFAuthManager.shared().clientId = "4erd0jhvuv"

    // Local notification setup
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    if NidOAuth.shared.handleURL(url) == true {
      return true
    }
    return super.application(application, open: url, options: options)
  }
}
