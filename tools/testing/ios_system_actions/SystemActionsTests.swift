import XCTest

/// Управляет только opt-in fixture, уже запущенным отдельным Flutter driver.
final class SystemActionsTests: XCTestCase {
  private let app = XCUIApplication(bundleIdentifier: "com.example.appStackcard")

  override func setUpWithError() throws {
    continueAfterFailure = false
    try XCTSkipUnless(
      ProcessInfo.processInfo.environment["STACKCARD_IOS_SYSTEM_ACTIONS"] == "YES",
      "Set STACKCARD_IOS_SYSTEM_ACTIONS=YES only for a running synthetic acceptance harness."
    )
    if action == "cameraReset" { return }
    XCTAssertNotEqual(app.state, .notRunning, "Start the isolated Flutter harness first.")
    // activate не перезапускает приложение и не очищает его данные.
    if action != "linkOpen" { app.activate() }
  }

  override func tearDownWithError() throws {
    // XCTest assertion abort не гарантирует Swift defer; возвращаем живой harness.
    if (action == "linkShare" || action == "linkOpen") && app.state != .notRunning {
      app.activate()
    }
    try super.tearDownWithError()
  }

  func testPDFSaveAndCancel() throws {
    try XCTSkipUnless(action == "pdf", "PDF action was not selected.")
    waitHostStage(kind: "pdf", stage: "SAVE_READY", verifiedPDF: true)
    assertFilenameOrVerifiedSystemPicker("stackcard-native-acceptance.pdf")
    attach("pdf-save-picker")
    let save = button(["Save", "Сохранить"])
    XCTAssertTrue(save.waitForExistence(timeout: 20), app.debugDescription)
    XCTAssertTrue(save.isEnabled, app.debugDescription)
    save.tap()

    // Не перезаписываем существующий файл даже при synthetic fixture.
    let replace = button(["Replace", "Заменить"])
    if replace.exists {
      attach("pdf-existing-synthetic-file")
      XCTFail("Existing file replacement is not automated; inspect the exact host fixture first.")
    }
    // Native Save callback уже завершён; это новый этап, а не прежний picker.
    waitHostStage(kind: "pdf", stage: "CANCEL_READY", verifiedPDF: true)
    assertFilenameOrVerifiedSystemPicker("stackcard-native-cancel.pdf")
    attach("pdf-cancel-picker")
    var cancel = button(["Cancel", "Отмена"])
    if !cancel.waitForExistence(timeout: 3) {
      // Наблюдённый iOS27 BackButton «Обзор» ведёт к корню exporting picker.
      let browse = app.buttons["BackButton"]
      XCTAssertTrue(browse.waitForExistence(timeout: 10), app.debugDescription)
      browse.tap()
      cancel = button(["Cancel", "Отмена"])
    }
    XCTAssertTrue(cancel.waitForExistence(timeout: 20), app.debugDescription)
    cancel.tap()
    waitHostStage(kind: "pdf", stage: "ALL_PASS", verifiedPDF: true)
    attach("pdf-native-bridge-all-pass")
    print("STACKCARD_PDF_UI:BRIDGE_PASS_HOST_BYTE_COMPARISON_REQUIRED")
  }

  func testGalleryCancel() throws {
    try XCTSkipUnless(action == "galleryCancel", "Gallery action was not selected.")
    waitHostStage(kind: "media", stage: "READY", source: "gallery", outcome: "cancel")
    attach("gallery-picker")
    // Наблюдённый PHPicker: identifier Cancel, локализованный label «Отменить».
    var cancel = app.buttons["Cancel"]
    if !cancel.waitForExistence(timeout: 3) {
      cancel = button(["Cancel", "Отмена", "Отменить"])
    }
    XCTAssertTrue(cancel.waitForExistence(timeout: 20), app.debugDescription)
    XCTAssertTrue(cancel.isHittable, app.debugDescription)
    cancel.tap()
    waitHostStage(kind: "media", stage: "PASS", source: "gallery", outcome: "cancel")
    attach("gallery-native-cancel-pass")
  }

  func testGallerySelectedSyntheticPhoto() throws {
    try XCTSkipUnless(action == "gallerySelected", "Gallery selection action was not selected.")
    waitHostStage(kind: "media", stage: "READY", source: "gallery", outcome: "selected")
    let label = ProcessInfo.processInfo.environment["PHOTO_LABEL"] ?? ""
    guard !label.isEmpty && label.utf8.count <= 1024 else {
      XCTFail("An exact observed synthetic PHOTO_LABEL is required; no photo was tapped.\n\(app.debugDescription)")
      return
    }
    let predicate = NSPredicate(format: "label == %@", label)
    let cells = app.cells.matching(predicate)
    let images = app.images.matching(predicate)
    let photo: XCUIElement
    if cells.firstMatch.waitForExistence(timeout: 5) {
      XCTAssertEqual(cells.count, 1, "Ambiguous synthetic photo label.\n\(app.debugDescription)")
      photo = cells.firstMatch
    } else {
      XCTAssertTrue(images.firstMatch.waitForExistence(timeout: 10), "Exact photo label missing; no photo was tapped.\n\(app.debugDescription)")
      XCTAssertEqual(images.count, 1, "Ambiguous synthetic image label.\n\(app.debugDescription)")
      photo = images.firstMatch
    }
    XCTAssertTrue(photo.isHittable, "The exact synthetic photo is not visible.\n\(app.debugDescription)")
    attach("gallery-exact-synthetic-photo")
    photo.tap()
    let confirm = button(["Done", "Add", "Готово", "Добавить"])
    if confirm.waitForExistence(timeout: 2) && confirm.isHittable { confirm.tap() }
    waitHostStage(kind: "media", stage: "PASS", source: "gallery", outcome: "selected")
    attach("gallery-native-selected-pass")
  }

  func testCameraPermissionDenied() throws {
    try XCTSkipUnless(action == "cameraDeny", "Camera denial action was not selected.")
    waitHostStage(kind: "media", stage: "READY", source: "camera", outcome: "permissionDenied")
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let appAlert = app.alerts.firstMatch
    let alert = appAlert.waitForExistence(timeout: 5) ? appAlert : springboard.alerts.firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 20), app.debugDescription + springboard.debugDescription)
    let tree = alert.debugDescription
    XCTAssertTrue(tree.localizedCaseInsensitiveContains("StackCard"), tree)
    XCTAssertTrue(
      tree.localizedCaseInsensitiveContains("camera") || tree.localizedCaseInsensitiveContains("камер"),
      tree
    )
    XCTContext.runActivity(named: "camera-system-permission-prompt") { activity in
      let description = XCTAttachment(string: tree)
      description.lifetime = .keepAlways
      activity.add(description)
    }
    attach("camera-permission-prompt")
    let deny = alert.buttons.matching(
      NSPredicate(format: "label IN %@", ["Don't Allow", "Don’t Allow", "Не разрешать"])
    ).firstMatch
    XCTAssertTrue(deny.waitForExistence(timeout: 10), tree)
    deny.tap()
    waitHostStage(kind: "media", stage: "PASS", source: "camera", outcome: "permissionDenied")
    attach("camera-native-denial-pass")
  }

  func testNativeLinkShare() throws {
    try XCTSkipUnless(action == "linkShare", "Link share action was not selected.")
    let url = requiredLinkURL()
    // Наблюдённый iOS27 remote UIKit share sheet; Copy не выбирает получателя.
    let remote = app.otherElements["ShareSheet.RemoteContainerView"]
    let copy: XCUIElement
    if remote.waitForExistence(timeout: 5) {
      let collection = remote.collectionViews["activityCollectionView"]
      XCTAssertTrue(collection.waitForExistence(timeout: 5), app.debugDescription)
      let cells = collection.cells.matching(
        NSPredicate(format: "identifier == %@ AND label IN %@", "actionGroupCell",
                    ["Copy", "Скопировать", "Копировать"])
      )
      XCTAssertTrue(cells.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
      XCTAssertEqual(cells.count, 1, "Ambiguous UIKit Copy action.\n\(app.debugDescription)")
      copy = cells.firstMatch
    } else {
      // Прежняя UIKit ветка допустима только внутри известного native контейнера.
      let activities = app.otherElements["ActivityListView"]
      XCTAssertTrue(activities.waitForExistence(timeout: 10), app.debugDescription)
      let buttons = activities.buttons.matching(
        NSPredicate(format: "label IN %@", ["Copy", "Скопировать", "Копировать"])
      )
      XCTAssertTrue(buttons.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
      XCTAssertEqual(buttons.count, 1, "Ambiguous UIKit Copy button.\n\(app.debugDescription)")
      copy = buttons.firstMatch
    }
    XCTAssertTrue(copy.isHittable, app.debugDescription)
    attach("native-link-share-sheet")
    copy.tap()
    let dismissal = Date().addingTimeInterval(5)
    while (remote.exists || app.otherElements["ActivityListView"].exists) && Date() < dismissal {
      Thread.sleep(forTimeInterval: 0.1)
    }
    XCTAssertFalse(remote.exists || app.otherElements["ActivityListView"].exists,
                   "The known UIKit share sheet did not dismiss after Copy.")
    assertSecureSafariPaste(url)
    print("STACKCARD_IOS_LINK:SHARE_PAYLOAD_URL_PASS")
    print("STACKCARD_IOS_LINK:SHARE_PASS")
  }

  func testNativeLinkOpen() throws {
    try XCTSkipUnless(action == "linkOpen", "Link open action was not selected.")
    let url = requiredLinkURL()
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    defer { app.activate() }
    let deadline = Date().addingTimeInterval(15)
    while safari.state != .runningForeground && Date() < deadline {
      Thread.sleep(forTimeInterval: 0.1)
    }
    XCTAssertEqual(safari.state, .runningForeground, safari.debugDescription)
    let author = safari.staticTexts["Native saved author"]
    XCTAssertTrue(author.waitForExistence(timeout: 15), safari.debugDescription)
    let tree = safari.debugDescription
    XCTAssertFalse(tree.contains("PRIVATE_EDITOR_BUFFER"), tree)
    XCTAssertFalse(tree.contains("PRIVATE_SAVED_NOTE"), tree)
    // Проверяем значение native Safari address field, а не текст ссылки на странице.
    let address = safariAddressField(safari)
    let value = address.value as? String ?? ""
    // Наблюдённое Safari URL field скрывает только HTTP scheme.
    XCTAssertTrue(value == url || value == String(url.dropFirst("http://".count)),
                  safari.debugDescription)
    XCTContext.runActivity(named: "native-safari-exact-public-reader") { activity in
      let tree = XCTAttachment(string: safari.debugDescription)
      tree.lifetime = .keepAlways
      activity.add(tree)
      let screen = XCTAttachment(screenshot: safari.screenshot())
      screen.lifetime = .keepAlways
      activity.add(screen)
    }
    print("STACKCARD_IOS_LINK:OPEN_PASS")
  }

  private func safariAddressField(_ safari: XCUIApplication) -> XCUIElement {
    // Наблюдённый iOS27 collapsed native address field.
    let collapsed = safari.textFields["TabBarItemTitle"]
    if collapsed.waitForExistence(timeout: 5) {
      dismissOnlyKnownKeyboardIntro(safari)
      XCTAssertTrue(collapsed.isHittable, safari.debugDescription)
      collapsed.tap()
    }
    let address = safari.textFields["URL"]
    XCTAssertTrue(address.waitForExistence(timeout: 5), safari.debugDescription)
    dismissOnlyKnownKeyboardIntro(safari)
    XCTAssertTrue(address.isHittable, safari.debugDescription)
    return address
  }

  private func dismissOnlyKnownKeyboardIntro(_ safari: XCUIApplication) {
    // Только наблюдённая подсказка первого запуска slide-to-type, не общие dialogs.
    let intro = safari.otherElements["UIContinuousPathIntroductionView"]
    guard intro.waitForExistence(timeout: 1) else { return }
    let proceed = intro.buttons.matching(
      NSPredicate(format: "label IN %@", ["Continue", "Продолжить"])
    )
    XCTAssertEqual(proceed.count, 1, safari.debugDescription)
    XCTAssertTrue(proceed.firstMatch.isHittable, safari.debugDescription)
    proceed.firstMatch.tap()
    let dismissed = Date().addingTimeInterval(3)
    while intro.exists && Date() < dismissed { Thread.sleep(forTimeInterval: 0.1) }
    XCTAssertFalse(intro.exists, safari.debugDescription)
  }

  private func assertSecureSafariPaste(_ url: String) {
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    safari.activate()
    defer { app.activate() }
    let address = safariAddressField(safari)
    let current = address.value as? String ?? ""
    if !current.isEmpty && current != address.placeholderValue {
      // Наблюдённый ClearTextButton — sibling URL field, не его child.
      let clears = safari.buttons.matching(identifier: "ClearTextButton")
      XCTAssertTrue(clears.firstMatch.waitForExistence(timeout: 2), safari.debugDescription)
      XCTAssertEqual(clears.count, 1, safari.debugDescription)
      XCTAssertTrue(clears.firstMatch.isHittable, safari.debugDescription)
      clears.firstMatch.tap()
    }
    let cleared = address.value as? String ?? ""
    XCTAssertTrue(cleared.isEmpty || cleared == address.placeholderValue,
                  "Safari URL field was not cleared by its native control.")
    address.press(forDuration: 1)
    let labels = ["Paste", "Вставить"]
    var paste = safari.menuItems.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
    if !paste.waitForExistence(timeout: 2) {
      paste = safari.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
    }
    XCTAssertTrue(paste.waitForExistence(timeout: 5), safari.debugDescription)
    XCTAssertTrue(paste.isHittable, safari.debugDescription)
    paste.tap()
    let deadline = Date().addingTimeInterval(5)
    var exact = false
    while Date() < deadline {
      if (address.value as? String) == url { exact = true; break }
      Thread.sleep(forTimeInterval: 0.1)
    }
    // Чужой clipboard не попадает в assertion/attachments при несовпадении.
    XCTAssertTrue(exact, "Secure Safari Paste did not produce the exact synthetic LINK_URL.")
    // Закрываем address edit без Go/navigation перед возвратом к StackCard.
    let close = safari.buttons["CancelBarItemButton"]
    XCTAssertTrue(close.waitForExistence(timeout: 3), safari.debugDescription)
    XCTAssertTrue(close.isHittable, safari.debugDescription)
    close.tap()
    XCTAssertTrue(safari.textFields["TabBarItemTitle"].waitForExistence(timeout: 5), safari.debugDescription)
  }

  func testNotificationPermissionDenied() throws {
    try XCTSkipUnless(action == "notificationDeny", "Notification denial action was not selected.")
    waitHostStage(kind: "notification", stage: "READY", permission: "denied")
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let appAlert = app.alerts.firstMatch
    let alert = appAlert.waitForExistence(timeout: 3) ? appAlert : springboard.alerts.firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 15), app.debugDescription + springboard.debugDescription)
    let tree = alert.debugDescription
    XCTAssertTrue(tree.localizedCaseInsensitiveContains("StackCard"), tree)
    XCTAssertTrue(tree.localizedCaseInsensitiveContains("notification")
                  || tree.localizedCaseInsensitiveContains("уведомлен"), tree)
    let deny = alert.buttons.matching(
      NSPredicate(format: "label IN %@", ["Don't Allow", "Don’t Allow", "Не разрешать"])
    ).firstMatch
    XCTAssertTrue(deny.waitForExistence(timeout: 5), tree)
    attach("notification-system-permission-prompt")
    deny.tap()
    waitHostStage(kind: "notification", stage: "PASS", permission: "denied")
    attach("notification-native-denial-pass")
  }

  func testNotificationPermissionAuthorized() throws {
    try XCTSkipUnless(action == "notificationAllow", "Notification authorization action was not selected.")
    waitHostStage(kind: "notification", stage: "READY", permission: "authorized")
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let appAlert = app.alerts.firstMatch
    let alert = appAlert.waitForExistence(timeout: 3) ? appAlert : springboard.alerts.firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 15), app.debugDescription + springboard.debugDescription)
    let tree = alert.debugDescription
    XCTAssertTrue(tree.localizedCaseInsensitiveContains("StackCard"), tree)
    XCTAssertTrue(tree.localizedCaseInsensitiveContains("notification")
                  || tree.localizedCaseInsensitiveContains("уведомлен"), tree)
    let allow = alert.buttons.matching(
      NSPredicate(format: "label IN %@", ["Allow", "Разрешить"])
    ).firstMatch
    XCTAssertTrue(allow.waitForExistence(timeout: 5), tree)
    attach("notification-system-allow-prompt")
    allow.tap()
    waitHostStage(kind: "notification", stage: "PASS", permission: "authorized")
    attach("notification-native-authorization-pass")
  }

  private func requiredLinkURL() -> String {
    let url = ProcessInfo.processInfo.environment["LINK_URL"] ?? ""
    XCTAssertNotNil(url.range(of: "^http://127[.]0[.]0[.]1:3800/d/[0-9a-f]{32}$", options: .regularExpression),
                    "LINK_URL must identify the exact synthetic local public document.")
    return url
  }

  func testResetCameraAuthorizationToOriginalUndeterminedState() throws {
    try XCTSkipUnless(action == "cameraReset", "Camera reset action was not selected.")
    try XCTSkipUnless(
      ProcessInfo.processInfo.environment["STACKCARD_IOS_CAMERA_INITIAL_STATE"] == "notDetermined",
      "Reset is allowed only after confirming the original camera state was notDetermined."
    )
    // Официальный XCTest API; запускать отдельно ПОСЛЕ exit0 Flutter driver.
    // Сброс может завершить приложение, но не затрагивает данные/другие permissions.
    app.resetAuthorizationStatus(for: .camera)
    print("STACKCARD_CAMERA_RESET:REQUESTED")
  }

  private var action: String {
    ProcessInfo.processInfo.environment["STACKCARD_IOS_ACTION"] ?? ""
  }

  private struct HostStatus: Decodable {
    let kind: String
    let stage: String
    let source: String?
    let outcome: String?
    let sourceVerified: Bool?
    let permission: String?
  }

  private final class LoopbackSessionDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
      completionHandler(nil)
    }
  }

  private func waitHostStage(kind: String, stage: String, source: String? = nil,
                             outcome: String? = nil, verifiedPDF: Bool = false, permission: String? = nil) {
    let config = URLSessionConfiguration.ephemeral
    config.httpShouldSetCookies = false
    config.httpCookieStorage = nil
    config.urlCache = nil
    config.timeoutIntervalForRequest = 2
    config.timeoutIntervalForResource = 3
    let session = URLSession(configuration: config, delegate: LoopbackSessionDelegate(), delegateQueue: nil)
    defer { session.invalidateAndCancel() }
    let deadline = Date().addingTimeInterval(30)
    var last = "no host response"
    while Date() < deadline {
      let done = DispatchSemaphore(value: 0)
      let lock = NSLock()
      var result: HostStatus?
      var diagnostic = "request pending"
      let task = session.dataTask(with: URL(string: "http://127.0.0.1:3812/status")!) { data, response, error in
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        lock.lock()
        if code == 200, let data, data.count <= 2048 {
          result = try? JSONDecoder().decode(HostStatus.self, from: data)
        }
        diagnostic = "http=\(code), transport=\((error as? URLError)?.code.rawValue ?? 0)"
        lock.unlock()
        done.signal()
      }
      task.resume()
      if done.wait(timeout: .now() + 3) == .timedOut { task.cancel() }
      lock.lock()
      let snapshot = result
      last = diagnostic
      lock.unlock()
      if let snapshot {
        last = "\(snapshot.kind):\(snapshot.stage)"
        if snapshot.kind == kind && snapshot.stage == stage
          && (source == nil || snapshot.source == source)
          && (outcome == nil || snapshot.outcome == outcome)
          && (permission == nil || snapshot.permission == permission)
          && (!verifiedPDF || snapshot.sourceVerified == true) {
          return
        }
      }
      Thread.sleep(forTimeInterval: 0.1)
    }
    XCTFail("Host phase deadline: expected \(kind):\(stage), last \(last)")
  }

  private func button(_ labels: [String]) -> XCUIElement {
    app.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
  }

  private func assertFilenameOrVerifiedSystemPicker(_ filename: String) {
    let stem = String(filename.dropLast(4))
    let exact = app.descendants(matching: .any).matching(
      NSPredicate(format: "label IN %@ OR value IN %@", [filename, stem], [filename, stem])
    ).firstMatch
    let hostVerified = ProcessInfo.processInfo.environment["STACKCARD_IOS_PDF_SOURCE_VERIFIED"] == "YES"
    if exact.waitForExistence(timeout: hostVerified ? 2 : 15) { return }
    // iOS27 exporting picker не раскрывает filename в accessibility.
    // Host обязан заранее проверить expected.pdf и после UI сравнить экспорт byte-for-byte.
    XCTAssertTrue(hostVerified, "Exact filename is unavailable; host fixture verification is required.\n\(app.debugDescription)")
    XCTAssertTrue(app.buttons["DOCPicker.actionButton"].waitForExistence(timeout: 20), app.debugDescription)
  }

  private func attach(_ name: String) {
    XCTContext.runActivity(named: name) { activity in
      let tree = XCTAttachment(string: app.debugDescription)
      tree.name = "\(name)-accessibility"
      tree.lifetime = .keepAlways
      activity.add(tree)
      let screenshot = XCTAttachment(screenshot: app.screenshot())
      screenshot.name = name
      screenshot.lifetime = .keepAlways
      activity.add(screenshot)
    }
  }
}
