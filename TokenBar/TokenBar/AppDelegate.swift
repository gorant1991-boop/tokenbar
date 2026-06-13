import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var vm = StatsViewModel()
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateButton(button)
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 440)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(vm: vm)
        )

        // Poll DB and refresh menu bar label
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            Task { @MainActor in self.tick() }
        }
    }

    private func tick() {
        vm.refresh()
        if let button = statusItem.button {
            updateButton(button)
        }
    }

    private func updateButton(_ button: NSStatusBarButton) {
        button.title = vm.menuBarLabel
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            tick()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
