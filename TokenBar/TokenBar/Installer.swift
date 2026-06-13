import Foundation
import AppKit

/// Handles first-launch self-install: copies .app to ~/Applications and registers LaunchAgent.
enum Installer {

    static let appName      = "TokenBar.app"
    static let bundleID     = "com.tokenbar.app"
    static let launchAgent  = "\(bundleID).plist"

    // MARK: – Public

    static func runIfNeeded() {
        guard isFirstLaunch else { return }
        do {
            let dest = try installApp()
            try writeLaunchAgent(appPath: dest)
            try loadLaunchAgent()
            markInstalled()
            showWelcome()
        } catch {
            // Non-fatal — app still works, just won't autostart
            NSLog("[TokenBar] Installer error: \(error)")
        }
    }

    // MARK: – Steps

    private static func installApp() throws -> String {
        let appsDir = (NSHomeDirectory() as NSString).appendingPathComponent("Applications")
        try FileManager.default.createDirectory(atPath: appsDir,
                                                withIntermediateDirectories: true)
        let src  = Bundle.main.bundlePath
        let dest = (appsDir as NSString).appendingPathComponent(appName)

        if FileManager.default.fileExists(atPath: dest) {
            try FileManager.default.removeItem(atPath: dest)
        }
        try FileManager.default.copyItem(atPath: src, toPath: dest)
        return dest
    }

    private static func writeLaunchAgent(appPath: String) throws {
        let binaryPath = (appPath as NSString)
            .appendingPathComponent("Contents/MacOS/TokenBar")

        let plist: [String: Any] = [
            "Label":           bundleID,
            "ProgramArguments": [binaryPath],
            "RunAtLoad":        true,
            "KeepAlive":        false,
            "StandardOutPath":  NSHomeDirectory() + "/Library/Logs/TokenBar.log",
            "StandardErrorPath": NSHomeDirectory() + "/Library/Logs/TokenBar.log"
        ]

        let dir = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/LaunchAgents")
        try FileManager.default.createDirectory(atPath: dir,
                                                withIntermediateDirectories: true)
        let plistPath = (dir as NSString).appendingPathComponent(launchAgent)
        let data = try PropertyListSerialization.data(fromPropertyList: plist,
                                                      format: .xml,
                                                      options: 0)
        try data.write(to: URL(fileURLWithPath: plistPath))
    }

    private static func loadLaunchAgent() throws {
        let plistPath = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/LaunchAgents/\(launchAgent)")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = ["load", "-w", plistPath]
        try proc.run(); proc.waitUntilExit()
    }

    // MARK: – State

    private static var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: "tokenbar.installed")
    }

    private static func markInstalled() {
        UserDefaults.standard.set(true, forKey: "tokenbar.installed")
    }

    // MARK: – Welcome

    private static func showWelcome() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alert = NSAlert()
            alert.messageText = "TokenBar installed"
            alert.informativeText = "Now in your menu bar. Starts automatically at login."
            alert.addButton(withTitle: "Got it")
            alert.alertStyle = .informational
            alert.runModal()
        }
    }
}
