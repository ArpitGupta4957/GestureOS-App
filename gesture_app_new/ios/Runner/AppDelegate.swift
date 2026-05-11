import Flutter
import UIKit
import AVFoundation
import Intents

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var torchOn = false
  private var deepLinkChannel: FlutterMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Setup Method Channels
    let controller = window?.rootViewController as! FlutterViewController
    
    // Action channel for native actions
    let actionChannel = FlutterMethodChannel(name: "action_channel",
                                              binaryMessenger: controller.binaryMessenger)
    
    actionChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      
      if call.method == "executeAction" {
        guard let args = call.arguments as? [String: Any],
              let actionType = args["type"] as? String,
              let actionValue = args["value"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
          return
        }
        
        self.handleAction(type: actionType, value: actionValue, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    // Deep link channel to send deep links to Flutter
    deepLinkChannel = FlutterMethodChannel(name: "deep_link_channel",
                                            binaryMessenger: controller.binaryMessenger)
    
    // Donate Siri Shortcuts on launch
    donateSiriShortcuts()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - Deep Link Handling (for mydail:// URLs)
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    handleDeepLink(url: url)
    return true
  }
  
  private func handleDeepLink(url: URL) {
    guard url.scheme == "mydail" else { return }
    
    let host = url.host ?? url.path.replacingOccurrences(of: "/", with: "")
    print("📱 [iOS] Deep link received: \(url.absoluteString), host: \(host)")
    
    // Send to Flutter
    deepLinkChannel?.invokeMethod("onDeepLink", arguments: [
      "scheme": url.scheme ?? "",
      "host": host,
      "path": url.path,
      "query": url.query ?? ""
    ])
  }
  
  // MARK: - Siri Shortcuts / User Activity
  override func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    
    if userActivity.activityType == "OpenDrawPadIntent" {
      print("📱 [iOS] Siri Shortcut: Open Draw Pad")
      deepLinkChannel?.invokeMethod("onDeepLink", arguments: [
        "scheme": "mydail",
        "host": "draw",
        "path": "",
        "query": ""
      ])
      return true
    }
    
    return false
  }
  
  private func donateSiriShortcuts() {
    // Create "Open Draw Pad" shortcut
    let activity = NSUserActivity(activityType: "OpenDrawPadIntent")
    activity.title = "Open MyDail Draw Pad"
    activity.suggestedInvocationPhrase = "Open gesture draw"
    activity.isEligibleForSearch = true
    activity.isEligibleForPrediction = true
    activity.persistentIdentifier = "com.mydail.opendrawpad"
    
    // Make it available to system
    self.userActivity = activity
    activity.becomeCurrent()
    
    print("📱 [iOS] Siri Shortcuts donated")
  }
  
  // MARK: - Action Handlers
  private func handleAction(type: String, value: String, result: @escaping FlutterResult) {
    switch type {
    case "flashlight":
      toggleFlashlight(result: result)
      
    case "call":
      makePhoneCall(number: value, result: result)
      
    case "app":
      launchApp(scheme: value, result: result)
      
    default:
      print("⚠️ [iOS] Action not implemented: \(type)")
      result(FlutterError(code: "NOT_IMPLEMENTED", message: "Action \(type) not available on iOS", details: nil))
    }
  }
  
  private func toggleFlashlight(result: @escaping FlutterResult) {
    guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
      result(FlutterError(code: "NO_TORCH", message: "Device has no flashlight", details: nil))
      return
    }
    
    do {
      try device.lockForConfiguration()
      torchOn = !torchOn
      device.torchMode = torchOn ? .on : .off
      device.unlockForConfiguration()
      result(true)
    } catch {
      result(FlutterError(code: "TORCH_ERROR", message: "Failed to toggle flashlight", details: error.localizedDescription))
    }
  }
  
  private func makePhoneCall(number: String, result: @escaping FlutterResult) {
    guard let url = URL(string: "tel://\(number)") else {
      result(FlutterError(code: "INVALID_NUMBER", message: "Invalid phone number", details: nil))
      return
    }
    
    if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url, options: [:]) { success in
        result(success)
      }
    } else {
      result(FlutterError(code: "CANNOT_CALL", message: "Cannot make phone call", details: nil))
    }
  }
  
  private func launchApp(scheme: String, result: @escaping FlutterResult) {
    // Map Android package names to iOS URL schemes
    let schemeMap: [String: String] = [
      "com.whatsapp": "whatsapp://",
      "com.instagram.android": "instagram://",
      "com.facebook.katana": "fb://",
      "com.twitter.android": "twitter://",
      "org.telegram.messenger": "telegram://",
      "com.google.android.youtube": "youtube://",
      "com.spotify.music": "spotify://",
      "com.linkedin.android": "linkedin://",
      "com.pinterest": "pinterest://",
      "com.reddit.frontpage": "reddit://",
      "com.zhiliaoapp.musically": "tiktok://",
      "com.snapchat.android": "snapchat://",
      "com.netflix.mediaclient": "netflix://",
      "com.discord": "discord://",
    ]
    
    let urlString = schemeMap[scheme] ?? "\(scheme)://"
    
    guard let url = URL(string: urlString) else {
      result(FlutterError(code: "INVALID_SCHEME", message: "Invalid URL scheme", details: nil))
      return
    }
    
    if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url, options: [:]) { success in
        result(success)
      }
    } else {
      result(FlutterError(code: "APP_NOT_FOUND", message: "App not installed", details: nil))
    }
  }
}
