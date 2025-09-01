import sys
import subprocess
import platform
import time
import os

def get_platform():
    system = platform.system().lower()
    if system not in ['darwin', 'linux', 'windows']:
        print(f"Unsupported operating system: {system}")
        sys.exit(1)
    return system

def install_dependencies(system):
    def pip_install(package):
        try:
            # Try installing with --user flag first
            subprocess.check_call([sys.executable, '-m', 'pip', 'install', '--user', package])
            print(f"Successfully installed {package}")
        except subprocess.CalledProcessError:
            try:
                # If that fails, try without --user flag
                subprocess.check_call([sys.executable, '-m', 'pip', 'install', package])
                print(f"Successfully installed {package}")
            except subprocess.CalledProcessError:
                print(f"Error installing {package}.")
                print(f"Try running manually: pip3 install --user {package}")
                sys.exit(1)

    # Only install platform-specific dependencies
    if system == 'darwin':
        try:
            import AppKit
        except ImportError:
            print("Installing macOS dependencies...")
            pip_install('pyobjc-framework-Cocoa')
    elif system == 'linux':
        try:
            import psutil
        except ImportError:
            print("Installing Linux dependencies...")
            pip_install('psutil')
    elif system == 'windows':
        try:
            import psutil
            import win32gui
        except ImportError:
            print("Installing Windows dependencies...")
            pip_install('psutil')
            pip_install('pywin32')

# System-specific protected apps
PROTECTED_APPS = {
    'darwin': [
        "Finder", "Dock", "SystemUIServer", "ControlCenter",
        "NotificationCenter", "WindowServer", "loginwindow"
    ],
    'linux': [
        "systemd", "init", "Xorg", "gdm", "gdm3", "lightdm",
        "sddm", "gnome-shell", "plasma-desktop"
    ],
    'windows': [
        "explorer.exe", "System", "Registry", "csrss.exe",
        "svchost.exe", "lsass.exe", "winlogon.exe"
    ]
}

OPTIONAL_KEEP_APPS = {
    'darwin': ["Terminal", "Activity Monitor", "Console"],
    'linux': ["gnome-terminal", "konsole", "xterm", "top"],
    'windows': ["cmd.exe", "powershell.exe", "taskmgr.exe"]
}

class AppQuitter:
    def __init__(self):
        self.system = get_platform()
        install_dependencies(self.system)
        
        # Import platform-specific modules
        if self.system == 'darwin':
            from AppKit import NSWorkspace
            self.workspace = NSWorkspace.sharedWorkspace()
        else:
            import psutil
            self.psutil = psutil
            if self.system == 'windows':
                # Only import Windows modules if we're on Windows
                try:
                    import win32gui
                    import win32con
                    import win32process
                    self.win32gui = win32gui
                    self.win32con = win32con
                    self.win32process = win32process
                except ImportError:
                    print("Error: Windows dependencies not available")
                    sys.exit(1)

    def get_running_apps(self):
        if self.system == 'darwin':
            return [(app, app.localizedName()) for app in self.workspace.runningApplications()
                    if app.activationPolicy() == 0]
        elif self.system == 'linux':
            return [(proc, proc.name()) for proc in self.psutil.process_iter(['name'])
                    if proc.info['name'] not in PROTECTED_APPS['linux']]
        else:  # windows
            apps = []
            def enum_windows_callback(hwnd, results):
                if self.win32gui.IsWindowVisible(hwnd):
                    _, pid = self.win32process.GetWindowThreadProcessId(hwnd)
                    try:
                        proc = self.psutil.Process(pid)
                        apps.append((proc, proc.name()))
                    except (self.psutil.NoSuchProcess, self.psutil.AccessDenied):
                        pass
            self.win32gui.EnumWindows(enum_windows_callback, [])
            return list(set(apps))

    def quit_app(self, app, force_quit):
        try:
            if self.system == 'darwin':
                if force_quit:
                    app.forceTerminate()
                else:
                    app.terminate()
            else:
                if force_quit:
                    app.kill()
                else:
                    app.terminate()
            return True
        except Exception as e:
            print(f"Error quitting app: {e}")
            return False

    def quit_all_apps(self, force_quit=False, keep_optional=True):
        running_apps = self.get_running_apps()
        protected = PROTECTED_APPS[self.system]
        optional = OPTIONAL_KEEP_APPS[self.system]
        
        apps_to_quit = []
        skipped_apps = []

        for app, app_name in running_apps:
            if app_name in protected:
                continue
            if keep_optional and app_name in optional:
                skipped_apps.append(app_name)
                continue
            apps_to_quit.append((app, app_name))

        print(f"Apps to quit: {len(apps_to_quit)}")
        print(f"Apps to skip: {len(skipped_apps)} - {', '.join(skipped_apps)}")
        print()

        for app, app_name in apps_to_quit:
            print(f"Quitting: {app_name}")
            self.quit_app(app, force_quit)
            time.sleep(0.1)

    def list_running_apps(self):
        running_apps = self.get_running_apps()
        protected = PROTECTED_APPS[self.system]
        optional = OPTIONAL_KEEP_APPS[self.system]

        print("📱 Currently Running Applications:")
        print("=================================")

        for _, app_name in running_apps:
            status = ""
            if app_name in protected:
                status = " [PROTECTED]"
            elif app_name in optional:
                status = " [OPTIONAL KEEP]"
            print(f"• {app_name}{status}")
        print()

def main():
    try:
        quitter = AppQuitter()
        
        print(f"🚪 Python App Quitter ({platform.system()})")
        print("==========================================")
        print()

        quitter.list_running_apps()

        print("Choose quit method:")
        print("1. Graceful quit (allows apps to save)")
        print("2. Force quit (immediate, no saving)")
        print("3. Graceful quit (keep Terminal/Activity Monitor)")
        print("4. Force quit (keep Terminal/Activity Monitor)")
        print("5. List apps only")

        try:
            choice = int(input().strip())
            if choice == 1:
                print("🔄 Gracefully quitting all applications...")
                quitter.quit_all_apps(force_quit=False, keep_optional=False)
            elif choice == 2:
                print("⚡ Force quitting all applications...")
                quitter.quit_all_apps(force_quit=True, keep_optional=False)
            elif choice == 3:
                print("🔄 Gracefully quitting apps (keeping optional apps)...")
                quitter.quit_all_apps(force_quit=False, keep_optional=True)
            elif choice == 4:
                print("⚡ Force quitting apps (keeping optional apps)...")
                quitter.quit_all_apps(force_quit=True, keep_optional=True)
            elif choice == 5:
                print("App list displayed above.")
            else:
                print("Invalid choice. Using default (graceful quit with optional keeps)...")
                quitter.quit_all_apps(force_quit=False, keep_optional=True)
        except ValueError:
            print("No input provided. Using default method...")
            quitter.quit_all_apps(force_quit=False, keep_optional=True)

    except Exception as e:
        print(f"An error occurred: {e}")
        sys.exit(1)

    print()
    print("Done! All specified applications have been quit.")
    print("Tip: Use 'graceful quit' to let apps save their work first!")

if __name__ == "__main__":
    main()