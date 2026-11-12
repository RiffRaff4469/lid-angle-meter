import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    // Polling / smoothing constants.
    private let pollInterval = 1.0 / 25.0      // 25 Hz
    private let emaAlpha = 0.15                // light smoothing, kills jitter
    private let redrawInterval = 1.0 / 10.0    // cap redraws at ~10 Hz
    private let redrawThreshold = 0.3          // degrees
    private let failureLimit = 15              // ~0.6 s of dead reads

    private let sensor = LidAngleSensor()
    private var timer: Timer?

    private var statusItem: NSStatusItem!
    private var graphicItem: NSMenuItem!
    private var angleItem: NSMenuItem!
    private var statusLineItem: NSMenuItem!

    private var rawAngle: Double = 0
    private var smoothedAngle: Double?
    private var renderedAngle: Double = -1000
    private var lastRenderTime: TimeInterval = 0
    private var failureCount = 0
    private var menuIsOpen = false
    private var sensorMissing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = LaptopIcon.image(size: LaptopIcon.statusItemSize, angle: 0)
        statusItem.menu = buildMenu()

        if sensor == nil {
            markSensorMissing()
            return
        }

        let timer = Timer(timeInterval: pollInterval,
                          target: self,
                          selector: #selector(poll),
                          userInfo: nil,
                          repeats: true)
        // .common so the menu keeps updating while it is open (event tracking).
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        poll()
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        graphicItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        graphicItem.image = LaptopIcon.image(size: LaptopIcon.menuSize, angle: 0)
        menu.addItem(graphicItem)

        angleItem = NSMenuItem(title: "--", action: nil, keyEquivalent: "")
        menu.addItem(angleItem)

        statusLineItem = NSMenuItem(title: "Lid sensor: ok", action: nil, keyEquivalent: "")
        statusLineItem.isEnabled = false
        menu.addItem(statusLineItem)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Quit LidAngleMeter",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        menuIsOpen = true
        guard !sensorMissing else { return }
        render(angle: smoothedAngle ?? rawAngle, force: true)
    }

    func menuDidClose(_ menu: NSMenu) {
        menuIsOpen = false
    }

    // MARK: - Polling

    @objc private func poll() {
        guard let sensor = sensor, let value = sensor.readAngle() else {
            failureCount += 1
            if failureCount >= failureLimit { markSensorMissing() }
            return
        }
        failureCount = 0
        rawAngle = value

        let smoothed: Double
        if let previous = smoothedAngle {
            smoothed = previous + emaAlpha * (value - previous)
        } else {
            smoothed = value
        }
        smoothedAngle = smoothed
        render(angle: smoothed, force: false)
    }

    private func render(angle: Double, force: Bool) {
        let now = ProcessInfo.processInfo.systemUptime
        if !force {
            guard abs(angle - renderedAngle) > redrawThreshold,
                  now - lastRenderTime >= redrawInterval else { return }
        }
        renderedAngle = angle
        lastRenderTime = now

        statusItem.button?.image = LaptopIcon.image(size: LaptopIcon.statusItemSize, angle: angle)
        statusItem.button?.toolTip = String(format: "Lid angle: %.1f\u{00B0} (raw %.0f\u{00B0})", angle, rawAngle)
        angleItem.title = String(format: "%.0f\u{00B0}  \u{2014}  %@", angle, AppDelegate.describe(angle))

        // The large graphic is only worth redrawing while the menu is on screen.
        if menuIsOpen {
            graphicItem.image = LaptopIcon.image(size: LaptopIcon.menuSize, angle: angle)
        }
    }

    private static func describe(_ angle: Double) -> String {
        if angle < 2.0 { return "Lid closed" }
        if angle < 25.0 { return "Barely open" }
        if angle < 70.0 { return "Partially open" }
        if angle < 115.0 { return "Lid open" }
        if angle < 170.0 { return "Wide open" }
        return "Folded flat"
    }

    private func markSensorMissing() {
        sensorMissing = true
        timer?.invalidate()
        timer = nil
        statusItem.button?.image = LaptopIcon.image(size: LaptopIcon.statusItemSize, angle: 0)
        statusItem.button?.toolTip = "Lid sensor: not found"
        statusItem.button?.appearsDisabled = true
        graphicItem.image = LaptopIcon.image(size: LaptopIcon.menuSize, angle: 0)
        angleItem.title = "--"
        statusLineItem.title = "Lid sensor: not found"
    }
}
