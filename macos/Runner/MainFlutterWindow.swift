import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var rfcommChannel: MacOSRfcommChannel?
  private var miAccountTwoFactorChannel: MacOSMiAccountTwoFactorChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    rfcommChannel = MacOSRfcommChannel(
      messenger: flutterViewController.engine.binaryMessenger
    )
    miAccountTwoFactorChannel = MacOSMiAccountTwoFactorChannel(
      messenger: flutterViewController.engine.binaryMessenger,
      parentWindow: self
    )

    super.awakeFromNib()
  }
}
