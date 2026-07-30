
import Cocoa
import Foundation

let protectedApps = [
    "Finder",
    "Dock",
    "SystemUIServer",
    "ControlCenter",
    "NotificationCenter",
    "WindowServer",
    "loginwindow"
]

let optionalKeepApps = [
    "Terminal",
    "Activity Monitor",
    "Console"
]

func quitAllAppsWithWorkspace(forceQuit: Bool = false, keepOptional: Bool = true, recheckDelay: UInt32 = 5_000_000) {
    let workspace = NSWorkspace.shared
    let runningApps = workspace.runningApplications

    var appsToQuit: [NSRunningApplication] = []
    var skippedApps: [String] = []

    for app in runningApps {
        guard let appName = app.localizedName else { continue }

        if protectedApps.contains(appName) {
            continue
        }

        if keepOptional && optionalKeepApps.contains(appName) {
            skippedApps.append(appName)
            continue
        }

        if app.activationPolicy == .regular {
            appsToQuit.append(app)
        }
    }

    print("Apps to quit: \(appsToQuit.count)")
    print("Apps to skip: \(skippedApps.count) - \(skippedApps.joined(separator: ", "))")
    print()

    for app in appsToQuit {
        let appName = app.localizedName ?? "Unknown"
        print("Quitting: \(appName)")

        if forceQuit {
            app.forceTerminate()
        } else {
            app.terminate()
        }

        usleep(100000)
    }

    // Recheck pass — catches launchers that respawn after their game quits
    usleep(recheckDelay)

    let stillRunning = appsToQuit.filter { !$0.isTerminated }
    if !stillRunning.isEmpty {
        print()
        print("Still running after \(recheckDelay / 1_000_000)s, force quitting: \(stillRunning.map { $0.localizedName ?? "Unknown" }.joined(separator: ", "))")
        for app in stillRunning {
            app.forceTerminate()
            usleep(100000)
        }
    }
}

func listRunningApps() {
    let workspace = NSWorkspace.shared
    let runningApps = workspace.runningApplications

    print("📱 Currently Running Applications:")
    print("=================================")

    for app in runningApps {
        if app.activationPolicy == .regular {
            let appName = app.localizedName ?? "Unknown"
            let isProtected = protectedApps.contains(appName)
            let isOptional = optionalKeepApps.contains(appName)

            var status = ""
            if isProtected {
                status = " [PROTECTED]"
            } else if isOptional {
                status = " [OPTIONAL KEEP]"
            }

            print("• \(appName)\(status)")
        }
    }
    print()
}

// Main GUI
print("🚪 Swift App Quitter")
print("====================")
print()

listRunningApps()

print("Choose quit method:")
print("1. Graceful quit (allows apps to save)")
print("2. Force quit (immediate, no saving)")
print("3. Graceful quit (keep Terminal/Activity Monitor)")
print("4. Force quit (keep Terminal/Activity Monitor)")
print("5. List apps only")

if let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), let choice = Int(input) {
    switch choice {
    case 1:
        print("🔄 Gracefully quitting all applications...")
        quitAllAppsWithWorkspace(forceQuit: false, keepOptional: false)
    case 2:
        print("⚡ Force quitting all applications...")
        quitAllAppsWithWorkspace(forceQuit: true, keepOptional: false)
    case 3:
        print("🔄 Gracefully quitting apps (keeping optional apps)...")
        quitAllAppsWithWorkspace(forceQuit: false, keepOptional: true)
    case 4:
        print("⚡ Force quitting apps (keeping optional apps)...")
        quitAllAppsWithWorkspace(forceQuit: true, keepOptional: true)
    case 5:
        print("App list displayed above.")
    default:
        print("Invalid choice. Using default (graceful quit with optional keeps)...")
        quitAllAppsWithWorkspace(forceQuit: false, keepOptional: true)
    }
} else {
    print("No input provided. Using default method...")
    quitAllAppsWithWorkspace(forceQuit: false, keepOptional: true)
}

print()
print("Done! All specified applications have been quit.")
print("Tip: Use 'graceful quit' to let apps save their work first!")
