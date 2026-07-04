import Cocoa
import FlutterMacOS
import IOBluetooth

@main
class AppDelegate: FlutterAppDelegate {
  private var rfcommChannel: MacOSRfcommChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      rfcommChannel = MacOSRfcommChannel(messenger: controller.engine.binaryMessenger)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

final class MacOSRfcommChannel: NSObject, FlutterStreamHandler, IOBluetoothRFCOMMChannelDelegate {
  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private let scanEventChannel: FlutterEventChannel
  private var eventSink: FlutterEventSink?
  private var scanEventSink: FlutterEventSink?
  private var rfcommChannel: IOBluetoothRFCOMMChannel?
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
      result(pairedDevices())
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
    let devices = pairedDevices()
    for item in devices {
      scanEventSink?(item)
    }
    result(nil)
  }

  private func pairedDevices() -> [[String: Any]] {
    let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
    return devices.compactMap { device in
      guard let address = device.addressString, !address.isEmpty else {
        return nil
      }
      return [
        "addr": address,
        "name": device.nameOrAddress ?? "Unknown device",
        "connectType": "spp",
      ]
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

    DispatchQueue.global(qos: .userInitiated).async {
      self.disconnect()
      var lastError = "No RFCOMM channel available"
      for channelNumber in fallbackChannels where (1...30).contains(channelNumber) {
        var channel: IOBluetoothRFCOMMChannel?
        let status = device.openRFCOMMChannelSync(
          &channel,
          withChannelID: BluetoothRFCOMMChannelID(channelNumber),
          delegate: self
        )
        if status == kIOReturnSuccess, let channel {
          self.rfcommChannel = channel
          self.readClosed = false
          DispatchQueue.main.async {
            result(["channel": channelNumber])
          }
          return
        }
        lastError = "connect failed on channel \(channelNumber): \(status)"
      }

      DispatchQueue.main.async {
        result(FlutterError(code: "CONNECT_FAILED", message: lastError, details: nil))
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
    guard let channel = rfcommChannel else {
      result(FlutterError(code: "NOT_CONNECTED", message: "SPP socket is not connected", details: nil))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let bytes = [UInt8](data.data)
      let status = bytes.withUnsafeBytes { buffer -> IOReturn in
        guard let base = buffer.baseAddress else {
          return kIOReturnBadArgument
        }
        return channel.writeSync(
          UnsafeMutableRawPointer(mutating: base),
          length: UInt16(bytes.count)
        )
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

  private func disconnect() {
    rfcommChannel?.close()
    rfcommChannel = nil
    if !readClosed {
      readClosed = true
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
    readClosed = true
    self.rfcommChannel = nil
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
