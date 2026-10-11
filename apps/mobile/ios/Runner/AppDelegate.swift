import Flutter
import UIKit
import firebase_messaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {
  private var pendingPDFResult: FlutterResult?
  private var pendingPDFDirectory: URL?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "stackcard/document_links",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "open" || call.method == "share" || call.method == "savePdf" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self else {
        result(FlutterError(code: "unavailable", message: "The application is unavailable.", details: nil))
        return
      }
      if call.method == "savePdf" {
        self.savePDF(call.arguments, result: result)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
        let rawURL = arguments["url"] as? String,
        let url = self.validatedDocumentURL(rawURL, allowContacts: call.method == "open")
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

  private func savePDF(_ value: Any?, result: @escaping FlutterResult) {
    guard let arguments = value as? [String: Any],
      let typed = arguments["bytes"] as? FlutterStandardTypedData,
      typed.data.count >= 5, typed.data.count <= 20 * 1024 * 1024,
      typed.data.prefix(5) == Data("%PDF-".utf8),
      let filename = arguments["filename"] as? String,
      filename.range(of: "^[a-zA-Z0-9][a-zA-Z0-9._-]{0,99}\\.pdf$", options: .regularExpression) == (filename.startIndex..<filename.endIndex)
    else {
      result(FlutterError(code: "invalid_pdf", message: "A bounded PDF and safe filename are required.", details: nil))
      return
    }
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
      .flatMap { $0.windows }
    guard pendingPDFResult == nil,
      let root = windows.first(where: { $0.isKeyWindow })?.rootViewController,
      let presenter = visibleViewController(root),
      let sourceView = presenter.viewIfLoaded, sourceView.window != nil,
      !presenter.isBeingDismissed, !presenter.isBeingPresented,
      !(presenter is UIDocumentPickerViewController)
    else {
      result(FlutterError(code: "unavailable", message: "The file dialog is unavailable.", details: nil))
      return
    }
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("stackcard-pdf-\(UUID().uuidString)", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let file = directory.appendingPathComponent(filename)
      try typed.data.write(to: file, options: .atomic)
      let picker = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
      picker.delegate = self
      if let popover = picker.popoverPresentationController {
        popover.sourceView = sourceView
        popover.sourceRect = CGRect(x: sourceView.bounds.midX, y: sourceView.bounds.midY, width: 1, height: 1)
        popover.permittedArrowDirections = []
      }
      pendingPDFResult = result
      pendingPDFDirectory = directory
      presenter.present(picker, animated: true)
    } catch {
      try? FileManager.default.removeItem(at: directory)
      result(FlutterError(code: "action_failed", message: "The PDF could not be prepared for saving.", details: nil))
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    finishPDFSaving(!urls.isEmpty)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finishPDFSaving(false)
  }

  private func finishPDFSaving(_ saved: Bool) {
    let result = pendingPDFResult
    let directory = pendingPDFDirectory
    pendingPDFResult = nil
    pendingPDFDirectory = nil
    if let directory {
      try? FileManager.default.removeItem(at: directory)
    }
    result?(saved)
  }

  private func validatedDocumentURL(_ rawURL: String, allowContacts: Bool) -> URL? {
    guard !rawURL.isEmpty,
      rawURL.rangeOfCharacter(from: .whitespacesAndNewlines.union(.controlCharacters)) == nil,
      !rawURL.contains("\\")
    else { return nil }
    if allowContacts {
      let email = "^mailto:[a-zA-Z0-9.!$&'*+/=_^`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?)+$"
      let phone = "^tel:\\+[0-9]{7,15}$"
      if rawURL.range(of: email, options: .regularExpression) != nil ||
        rawURL.range(of: phone, options: .regularExpression) != nil {
        return URL(string: rawURL)
      }
    }
    guard let components = URLComponents(string: rawURL),
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
