import AppKit

// Menu-bar only: no Dock icon, no main menu, no window.
let app = NSApplication.shared
let controller = AppDelegate()
app.delegate = controller
app.setActivationPolicy(.accessory)
app.run()
