import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "stackcard/document_links",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "open" || call.method == "share" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self else {
        result(FlutterError(code: "unavailable", message: "The application is unavailable.", details: nil))
        return
      }
      guard let arguments = call.arguments as? [String: Any],
        let rawURL = arguments["url"] as? String,
        let url = self.validatedDocumentURL(rawURL)
      else {
        result(FlutterError(code: "invalid_url", message: "A public HTTP(S) URL is required.", details: nil))
        return
      }
      if call.method == "open" {
        UIApplication.shared.open(url, options: [:]) { accepted in
          if accepted {
            result(true)
          } else {
            result(FlutterError(code: "unavailable", message: "The URL could not be opened.", details: nil))
          }
        }
      } else {
        self.shareDocumentURL(url, result: result)
      }
    }
  }

  private func validatedDocumentURL(_ rawURL: String) -> URL? {
    guard !rawURL.isEmpty,
      rawURL.rangeOfCharacter(from: .whitespacesAndNewlines.union(.controlCharacters)) == nil,
      !rawURL.contains("\\"),
      let components = URLComponents(string: rawURL),
      let scheme = components.scheme?.lowercased(),
      scheme == "http" || scheme == "https",
      let host = components.host, !host.isEmpty,
      components.user == nil, components.password == nil,
      components.port.map({ (0...65535).contains($0) }) ?? true,
      let url = components.url
    else {
      return nil
    }
    return url
  }

  private func shareDocumentURL(_ url: URL, result: @escaping FlutterResult) {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
      .flatMap { $0.windows }
    guard let root = windows.first(where: { $0.isKeyWindow })?.rootViewController,
      let presenter = visibleViewController(root),
      let sourceView = presenter.viewIfLoaded,
      sourceView.window != nil,
      !presenter.isBeingDismissed,
      !presenter.isBeingPresented,
      !(presenter is UIActivityViewController)
    else {
      result(FlutterError(code: "unavailable", message: "A share sheet cannot be presented now.", details: nil))
      return
    }
    let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    if let popover = activity.popoverPresentationController {
      popover.sourceView = sourceView
      popover.sourceRect = CGRect(x: sourceView.bounds.midX, y: sourceView.bounds.midY, width: 1, height: 1)
      popover.permittedArrowDirections = []
    }
    // Подтверждается показ системного интерфейса, а не отправка пользователем.
    presenter.present(activity, animated: true) {
      result(true)
    }
  }

  private func visibleViewController(_ controller: UIViewController) -> UIViewController? {
    if let presented = controller.presentedViewController {
      return visibleViewController(presented)
    }
    if let navigation = controller as? UINavigationController,
      let visible = navigation.visibleViewController {
      return visibleViewController(visible)
    }
    if let tabs = controller as? UITabBarController,
      let selected = tabs.selectedViewController {
      return visibleViewController(selected)
    }
    return controller
  }
}
