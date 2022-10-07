import Cocoa

@objc class SquirrelSettingsWindow: NSWindowController {
  @IBOutlet var basicKeyboardLayoutButton: NSPopUpButton!
  @IBOutlet var theWindow: NSWindow!

  @objc static var shared: SquirrelSettingsWindow?

  override func windowDidLoad() {
    super.windowDidLoad()
    window = theWindow
    initiateKeyLayoutDropdownButton()
  }

  @objc static func show() {
    if shared == nil {
      shared = .init(windowNibName: "SquirrelSettingsWindow")
    }
    guard let shared = shared else { return }
    shared.window?.center()
    shared.window?.orderFrontRegardless() // 逼著屬性視窗往最前方顯示
    shared.window?.level = .statusBar
    if #available(macOS 10.10, *) {
      shared.window?.titlebarAppearsTransparent = true
    }
    NSApp.setActivationPolicy(.accessory)
    NSApp.activate(ignoringOtherApps: true)
  }
}

extension SquirrelSettingsWindow {
  func initiateKeyLayoutDropdownButton() {
    var usKeyboardLayoutItem: NSMenuItem?
    var chosenBaseKeyboardLayoutItem: NSMenuItem?
    basicKeyboardLayoutButton.menu?.removeAllItems()
    let basicKeyboardLayoutID = Properties.shared.basicKeyboardLayout

    for source in IMKHelper.allowedBasicLayoutsAsTISInputSources {
      guard let source = source else {
        basicKeyboardLayoutButton.menu?.addItem(NSMenuItem.separator())
        continue
      }
      let menuItem = NSMenuItem()
      menuItem.title = source.vChewingLocalizedName
      menuItem.representedObject = source.identifier
      if source.identifier == "com.apple.keylayout.US" { usKeyboardLayoutItem = menuItem }
      if basicKeyboardLayoutID == source.identifier { chosenBaseKeyboardLayoutItem = menuItem }
      basicKeyboardLayoutButton.menu?.addItem(menuItem)
    }

    basicKeyboardLayoutButton.select(chosenBaseKeyboardLayoutItem ?? usKeyboardLayoutItem)
  }

  @IBAction func updateBasicKeyboardLayoutAction(_: Any) {
    if let sourceID = basicKeyboardLayoutButton.selectedItem?.representedObject as? String {
      Properties.shared.basicKeyboardLayout = sourceID
      sessionControllers.forEach {
        $0.overrideKeyboard()
      }
    }
  }
}
