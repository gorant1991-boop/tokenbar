import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var vm = StatsViewModel()

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

        // Refresh menu bar label when VM updates
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TokenBarRefresh"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, let button = self.statusItem.button else { return }
            self.updateButton(button)
        }

        // Poll to update button label
        Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let button = self.statusItem.button else { return }
                self.vm.refresh()
                self.updateButton(button)
            }
        }
    }

    private func updateButton(_ button: NSStatusBarButton) {
        button.title = vm.menuBarLabel
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            vm.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
