import Cocoa
import FlutterMacOS
import IOBluetooth
import WebKit

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    if ProcessInfo.processInfo.arguments.contains("--nogui") {
      NSApp.setActivationPolicy(.prohibited)
      return
    }
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

final class MacOSZeppSettingsChannel: NSObject, WKScriptMessageHandler, NSWindowDelegate {
  private let channel: FlutterMethodChannel
  private weak var parentWindow: NSWindow?
  private var window: NSWindow?
  private var webView: WKWebView?
  private var appId: Int?

  init(messenger: FlutterBinaryMessenger, parentWindow: NSWindow?) {
    self.parentWindow = parentWindow
    channel = FlutterMethodChannel(name: "zerobox/zeppos_app_settings", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: nil, details: nil)); return
    }
    switch call.method {
    case "open":
      guard let id = args["appId"] as? Int, let html = args["html"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "appId and html are required", details: nil)); return
      }
      close(notify: true)
      let controller = WKUserContentController()
      controller.add(self, name: "ZeppSettingsBridge")
      let configuration = WKWebViewConfiguration()
      configuration.websiteDataStore = .nonPersistent()
      configuration.userContentController = controller
      let view = WKWebView(frame: .zero, configuration: configuration)
      let settingsWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
      settingsWindow.title = args["title"] as? String ?? "应用设置"
      settingsWindow.contentView = view
      settingsWindow.delegate = self
      settingsWindow.center()
      window = settingsWindow; webView = view; appId = id
      settingsWindow.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      view.loadHTMLString(html, baseURL: nil)
      result(nil)
    case "settingsChanged":
      if let id = args["appId"] as? Int, id == appId, let json = args["settingsJson"] as? String {
        webView?.evaluateJavaScript("globalThis.__zeroboxSettingsChanged(\(json))")
      }
      result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    guard let id = appId, let text = message.body as? String, let data = text.data(using: .utf8), var value = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let type = value.removeValue(forKey: "type") as? String else { return }
    value["appId"] = id
    channel.invokeMethod(type, arguments: value)
  }

  func windowWillClose(_ notification: Notification) { close(notify: true) }
  private func close(notify: Bool) {
    guard let id = appId else { return }
    appId = nil
    webView?.configuration.userContentController.removeScriptMessageHandler(forName: "ZeppSettingsBridge")
    webView?.stopLoading(); webView = nil
    window?.delegate = nil; window?.close(); window = nil
    if notify { channel.invokeMethod("closed", arguments: ["appId": id]) }
  }
}

final class MacOSMiAccountTwoFactorChannel: NSObject {
  private let methodChannel: FlutterMethodChannel
  private weak var parentWindow: NSWindow?
  private var session: MacOSMiAccountTwoFactorSession?

  init(messenger: FlutterBinaryMessenger, parentWindow: NSWindow?) {
    self.parentWindow = parentWindow
    methodChannel = FlutterMethodChannel(
      name: "zerobox/mi_account_2fa",
      binaryMessenger: messenger
    )
    super.init()
    methodChannel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "resolve":
      guard let args = call.arguments as? [String: Any],
        let urlValue = args["url"] as? String,
        let url = URL(string: urlValue)
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "url is required", details: nil))
        return
      }
      if session != nil {
        result(FlutterError(code: "ALREADY_RUNNING", message: "Xiaomi 2FA WebView is already open", details: nil))
        return
      }
      let nextSession = MacOSMiAccountTwoFactorSession(
        url: url,
        parentWindow: parentWindow
      ) { [weak self] outcome in
        self?.session = nil
        switch outcome {
        case .success(let cookieHeader):
          result(cookieHeader)
        case .failure(let error):
          result(FlutterError(code: error.code, message: error.message, details: nil))
        }
      }
      session = nextSession
      nextSession.start()
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private struct MacOSMiAccountTwoFactorError: Error {
  let code: String
  let message: String
}

private final class MacOSMiAccountTwoFactorSession: NSObject, NSWindowDelegate, WKNavigationDelegate {
  private let url: URL
  private weak var parentWindow: NSWindow?
  private let completion: (Result<String, MacOSMiAccountTwoFactorError>) -> Void
  private var window: NSWindow?
  private var webView: WKWebView?
  private weak var sheetParent: NSWindow?
  private var pollTimer: Timer?
  private var completed = false

  init(
    url: URL,
    parentWindow: NSWindow?,
    completion: @escaping (Result<String, MacOSMiAccountTwoFactorError>) -> Void
  ) {
    self.url = url
    self.parentWindow = parentWindow
    self.completion = completion
  }

  func start() {
    DispatchQueue.main.async {
      let configuration = WKWebViewConfiguration()
      configuration.websiteDataStore = .nonPersistent()
      let webView = WKWebView(frame: .zero, configuration: configuration)
      webView.navigationDelegate = self

      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
      )
      window.title = "Xiaomi account verification"
      window.center()
      window.contentView = webView
      window.delegate = self

      self.window = window
      self.webView = webView
      if let parentWindow = self.parentWindow, parentWindow.isVisible {
        self.sheetParent = parentWindow
        parentWindow.beginSheet(window)
      } else {
        window.makeKeyAndOrderFront(nil)
      }
      NSApp.activate(ignoringOtherApps: true)
      webView.load(URLRequest(url: self.url))
      self.pollTimer = Timer.scheduledTimer(
        withTimeInterval: 0.75,
        repeats: true
      ) { [weak self] _ in
        self?.completeIfReady()
      }
    }
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    completeIfReady()
    webView.evaluateJavaScript("(document.body && document.body.innerText || '').trim()") { [weak self] value, _ in
      guard let text = value as? String else {
        return
      }
      let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      if normalized == "ok" || normalized.hasSuffix("\nok") {
        self?.completeIfReady()
      }
    }
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    failIfOpen(code: "WEBVIEW_FAILED", message: error.localizedDescription)
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    failIfOpen(code: "WEBVIEW_FAILED", message: error.localizedDescription)
  }

  func windowWillClose(_ notification: Notification) {
    failIfOpen(code: "CANCELLED", message: "Xiaomi 2FA WebView was closed")
  }

  private func completeIfReady() {
    guard !completed, let webView else {
      return
    }
    webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
      guard let self, !self.completed else {
        return
      }
      let header = self.cookieHeader(cookies)
      guard self.hasSessionCookie(header) else {
        return
      }
      self.finish(.success(header))
    }
  }

  private func cookieHeader(_ cookies: [HTTPCookie]) -> String {
    var values: [String: String] = [:]
    for cookie in cookies {
      guard !cookie.name.isEmpty, !cookie.value.isEmpty else {
        continue
      }
      values[cookie.name] = cookie.value
    }
    return values
      .map { "\($0.key)=\($0.value)" }
      .sorted()
      .joined(separator: "; ")
  }

  private func hasSessionCookie(_ header: String) -> Bool {
    let names = Set(
      header
        .split(separator: ";")
        .compactMap { pair -> String? in
          guard let index = pair.firstIndex(of: "=") else {
            return nil
          }
          return pair[..<index].trimmingCharacters(in: .whitespacesAndNewlines)
        }
    )
    return names.contains("passToken") ||
      names.contains("cUserId") ||
      names.contains("userId")
  }

  private func failIfOpen(code: String, message: String) {
    finish(.failure(MacOSMiAccountTwoFactorError(code: code, message: message)))
  }

  private func finish(_ outcome: Result<String, MacOSMiAccountTwoFactorError>) {
    guard !completed else {
      return
    }
    completed = true
    pollTimer?.invalidate()
    pollTimer = nil
    let closeWindow = window
    let parent = sheetParent
    window = nil
    webView = nil
    sheetParent = nil
    closeWindow?.delegate = nil
    if let parent, let closeWindow {
      parent.endSheet(closeWindow)
    } else {
      closeWindow?.close()
    }
    completion(outcome)
  }
}

final class MacOSRfcommChannel: NSObject, FlutterStreamHandler, IOBluetoothRFCOMMChannelDelegate, IOBluetoothDeviceInquiryDelegate {
  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private let scanEventChannel: FlutterEventChannel
  private var eventSink: FlutterEventSink?
  private var scanEventSink: FlutterEventSink?
  private var rfcommChannel: IOBluetoothRFCOMMChannel?
  private var inquiry: IOBluetoothDeviceInquiry?
  private var scanResults: [String: [String: Any]] = [:]
  private var connectGeneration: UInt64 = 0
  private let stateQueue = DispatchQueue(label: "org.zxor.zerobox.rfcomm.state")
  private var readClosed = false

  init(messenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(
      name: "zerobox/classic_spp",
      binaryMessenger: messenger
    )
    eventChannel = FlutterEventChannel(
      name: "zerobox/classic_spp/events",
      binaryMessenger: messenger
    )
    scanEventChannel = FlutterEventChannel(
      name: "zerobox/classic_spp/scan_events",
      binaryMessenger: messenger
    )
    super.init()

    methodChannel.setMethodCallHandler(handle)
    eventChannel.setStreamHandler(self)
    scanEventChannel.setStreamHandler(MacOSScanStreamHandler(owner: self))
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  fileprivate func onScanListen(_ events: @escaping FlutterEventSink) {
    scanEventSink = events
  }

  fileprivate func onScanCancel() {
    scanEventSink = nil
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestPermissions":
      result(nil)
    case "startScan":
      startScan(result: result)
    case "stopScan":
      stopScan(result: result)
    case "connect":
      connect(call, result: result)
    case "send":
      send(call, result: result)
    case "disconnect":
      disconnect()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startScan(result: @escaping FlutterResult) {
    stopInquiry()
    scanResults.removeAll()

    for item in pairedDevices() {
      rememberScanDevice(item)
    }

    let inquiry = IOBluetoothDeviceInquiry(delegate: self)
    inquiry?.updateNewDeviceNames = true
    self.inquiry = inquiry
    let status = inquiry?.start() ?? kIOReturnError
    if status == kIOReturnSuccess {
      result(nil)
    } else {
      self.inquiry = nil
      result(FlutterError(code: "SCAN_FAILED", message: "Bluetooth inquiry failed: \(status)", details: nil))
    }
  }

  private func stopScan(result: @escaping FlutterResult) {
    stopInquiry()
    result(Array(scanResults.values))
  }

  private func stopInquiry() {
    inquiry?.stop()
    inquiry = nil
  }

  private func pairedDevices() -> [[String: Any]] {
    let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
    return devices.compactMap(scanDeviceMap)
  }

  private func scanDeviceMap(_ device: IOBluetoothDevice) -> [String: Any]? {
    guard let address = device.addressString, !address.isEmpty else {
      return nil
    }
    return [
      "addr": address,
      "name": device.nameOrAddress ?? "Unknown device",
      "connectType": "spp",
    ]
  }

  private func rememberScanDevice(_ item: [String: Any]) {
    guard let address = item["addr"] as? String, !address.isEmpty else {
      return
    }
    scanResults[address] = item
    DispatchQueue.main.async {
      self.scanEventSink?(item)
    }
  }

  private func connect(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let address = args["addr"] as? String,
      !address.isEmpty
    else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "addr is required", details: nil))
      return
    }
    let fallbackChannels = (args["fallbackChannels"] as? [Int]) ?? [5, 1]
    guard let device = IOBluetoothDevice(addressString: address) else {
      result(FlutterError(code: "CONNECT_FAILED", message: "Bluetooth device not found", details: nil))
      return
    }

    let generation = stateQueue.sync { () -> UInt64 in
      connectGeneration += 1
      return connectGeneration
    }
    disconnect(cancelConnect: false, emitEvent: false)

    DispatchQueue.global(qos: .userInitiated).async {
      var errors: [String] = []
      for channelNumber in fallbackChannels where (1...30).contains(channelNumber) {
        if !self.isCurrentGeneration(generation) {
          DispatchQueue.main.async {
            result(FlutterError(code: "CONNECT_CANCELLED", message: "SPP connect was cancelled", details: nil))
          }
          return
        }

        var channel: IOBluetoothRFCOMMChannel?
        let status = self.openRfcommChannel(
          device: device,
          channelNumber: channelNumber,
          generation: generation,
          channel: &channel
        )
        if status == kIOReturnSuccess, let channel {
          let accepted = self.stateQueue.sync { () -> Bool in
            guard self.connectGeneration == generation else {
              return false
            }
            self.rfcommChannel = channel
            self.readClosed = false
            return true
          }
          if !accepted {
            channel.close()
            DispatchQueue.main.async {
              result(FlutterError(code: "CONNECT_CANCELLED", message: "SPP connect was cancelled", details: nil))
            }
            return
          }
          DispatchQueue.main.async {
            result(["channel": channelNumber])
          }
          return
        }
        errors.append("channel \(channelNumber): \(status)")
      }

      DispatchQueue.main.async {
        let details = errors.isEmpty ? "No RFCOMM channel available" : errors.joined(separator: ", ")
        result(FlutterError(code: "CONNECT_FAILED", message: "connect failed: \(details)", details: nil))
      }
    }
  }

  private func send(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let data = args["data"] as? FlutterStandardTypedData
    else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "data is required", details: nil))
      return
    }
    guard let channel = stateQueue.sync(execute: { rfcommChannel }) else {
      result(FlutterError(code: "NOT_CONNECTED", message: "SPP socket is not connected", details: nil))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let bytes = [UInt8](data.data)
      let mtu = Int(channel.getMTU())
      let chunkSize = min(max(mtu, 1), 1024)
      var status: IOReturn = kIOReturnSuccess
      var offset = 0

      while offset < bytes.count {
        let length = min(chunkSize, bytes.count - offset)
        status = bytes.withUnsafeBytes { buffer -> IOReturn in
          guard let base = buffer.baseAddress else {
            return kIOReturnBadArgument
          }
          let chunkBase = base.advanced(by: offset)
          return channel.writeSync(
            UnsafeMutableRawPointer(mutating: chunkBase),
            length: UInt16(length)
          )
        }
        if status != kIOReturnSuccess {
          break
        }
        offset += length
      }

      DispatchQueue.main.async {
        if status == kIOReturnSuccess {
          result(nil)
        } else {
          result(FlutterError(code: "SEND_FAILED", message: "RFCOMM write failed: \(status)", details: nil))
        }
      }
    }
  }

  private func disconnect(cancelConnect: Bool = true, emitEvent: Bool = true) {
    let channel = stateQueue.sync { () -> IOBluetoothRFCOMMChannel? in
      if cancelConnect {
        connectGeneration += 1
      }
      let channel = rfcommChannel
      rfcommChannel = nil
      readClosed = true
      return channel
    }
    channel?.close()
    if emitEvent {
      emitDisconnected()
    }
  }

  private func isCurrentGeneration(_ generation: UInt64) -> Bool {
    stateQueue.sync { connectGeneration == generation }
  }

  private func openRfcommChannel(
    device: IOBluetoothDevice,
    channelNumber: Int,
    generation: UInt64,
    channel: inout IOBluetoothRFCOMMChannel?
  ) -> IOReturn {
    let semaphore = DispatchSemaphore(value: 0)
    let state = RfcommOpenState()
    let deadline = Date().addingTimeInterval(4)

    DispatchQueue.global(qos: .userInitiated).async {
      var localChannel: IOBluetoothRFCOMMChannel?
      let status = device.openRFCOMMChannelSync(
        &localChannel,
        withChannelID: BluetoothRFCOMMChannelID(channelNumber),
        delegate: self
      )
      state.finish(status: status, channel: localChannel)
      semaphore.signal()
    }

    while semaphore.wait(timeout: .now() + 0.25) == .timedOut {
      if !isCurrentGeneration(generation) {
        state.cancel()?.close()
        return kIOReturnAborted
      }
      if Date() >= deadline {
        state.cancel()?.close()
        return kIOReturnTimeout
      }
    }

    let snapshot = state.snapshot()
    if !isCurrentGeneration(generation) {
      snapshot.channel?.close()
      return kIOReturnAborted
    }
    channel = snapshot.channel
    return snapshot.status
  }

  private func emitDisconnected() {
    DispatchQueue.main.async {
      self.eventSink?(["event": "disconnected"])
    }
  }

  func rfcommChannelData(
    _ rfcommChannel: IOBluetoothRFCOMMChannel!,
    data dataPointer: UnsafeMutableRawPointer!,
    length dataLength: Int
  ) {
    guard dataLength > 0, let dataPointer else {
      return
    }
    let data = Data(bytes: dataPointer, count: dataLength)
    DispatchQueue.main.async {
      self.eventSink?(FlutterStandardTypedData(bytes: data))
    }
  }

  func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
    let shouldEmit = stateQueue.sync { () -> Bool in
      guard self.rfcommChannel === rfcommChannel else {
        return false
      }
      readClosed = true
      self.rfcommChannel = nil
      return true
    }
    if shouldEmit {
      emitDisconnected()
    }
  }

  func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!) {
    guard sender === inquiry, let item = scanDeviceMap(device) else {
      return
    }
    rememberScanDevice(item)
  }

  func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry!, error: IOReturn, aborted: Bool) {
    guard sender === inquiry else {
      return
    }
    inquiry = nil
  }
}

private final class RfcommOpenState {
  private let lock = NSLock()
  private var status: IOReturn = kIOReturnTimeout
  private var channel: IOBluetoothRFCOMMChannel?
  private var cancelled = false

  func finish(status: IOReturn, channel: IOBluetoothRFCOMMChannel?) {
    lock.lock()
    defer { lock.unlock() }
    if cancelled {
      channel?.close()
      return
    }
    self.status = status
    self.channel = channel
  }

  func cancel() -> IOBluetoothRFCOMMChannel? {
    lock.lock()
    defer { lock.unlock() }
    cancelled = true
    let channel = self.channel
    self.channel = nil
    return channel
  }

  func snapshot() -> (status: IOReturn, channel: IOBluetoothRFCOMMChannel?) {
    lock.lock()
    defer { lock.unlock() }
    return (status, channel)
  }
}

private final class MacOSScanStreamHandler: NSObject, FlutterStreamHandler {
  private weak var owner: MacOSRfcommChannel?

  init(owner: MacOSRfcommChannel) {
    self.owner = owner
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    owner?.onScanListen(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    owner?.onScanCancel()
    return nil
  }
}
