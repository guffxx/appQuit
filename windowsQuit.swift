import Foundation

#if os(Windows)

// This is AI Slop

import WinSDK

struct WindowsProcess {
    let processID: DWORD
    let name: String
    let executablePath: String?
}

let protectedProcesses: Set<String> = [
    "winlogon.exe", "csrss.exe", "wininit.exe", "services.exe",
    "lsass.exe", "svchost.exe", "dwm.exe", "explorer.exe",
    "smss.exe", "conhost.exe", "audiodg.exe", "fontdrvhost.exe",
    "sihost.exe", "ctfmon.exe", "searchindexer.exe", "runtimebroker.exe",
    "taskhostw.exe", "spoolsv.exe", "system", "registry"
]

let optionalKeepProcesses: Set<String> = [
    "cmd.exe", "powershell.exe", "WindowsTerminal.exe",
    "taskmgr.exe", "procmon.exe", "procexp.exe",
    "windsurf.exe", "zed.exe", "code.exe", "devenv.exe",
    "steam.exe", "discord.exe"
]

func getRunningProcesses() -> [WindowsProcess] {
    var processes: [WindowsProcess] = []
    var processIDs = Array<DWORD>(repeating: 0, count: 1024)
    var bytesReturned: DWORD = 0
    
    guard EnumProcesses(&processIDs, DWORD(processIDs.count * MemoryLayout<DWORD>.size), &bytesReturned) != 0 else {
        print("Failed to enumerate processes")
        return processes
    }
    
    let processCount = Int(bytesReturned) / MemoryLayout<DWORD>.size
    
    for i in 0..<processCount {
        let processID = processIDs[i]
        if processID == 0 { continue }
        
        let processHandle = OpenProcess(DWORD(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ), 0, processID)
        guard processHandle != nil else { continue }
        
        defer { CloseHandle(processHandle) }
        
        var processName = Array<CHAR>(repeating: 0, count: MAX_PATH)
        var size = DWORD(MAX_PATH)
        
        if QueryFullProcessImageNameA(processHandle, 0, &processName, &size) != 0 {
            let fullPath = String(cString: processName)
            let name = URL(fileURLWithPath: fullPath).lastPathComponent
            
            processes.append(WindowsProcess(
                processID: processID,
                name: name,
                executablePath: fullPath
            ))
        }
    }
    
    return processes
}

func terminateProcess(processID: DWORD, force: Bool = false) -> Bool {
    let accessRights: DWORD = force ? DWORD(PROCESS_TERMINATE | PROCESS_QUERY_INFORMATION) : DWORD(PROCESS_TERMINATE)
    
    guard let processHandle = OpenProcess(accessRights, 0, processID) else {
        return false
    }
    
    defer { CloseHandle(processHandle) }
    
    if force {
        // Force terminate
        return TerminateProcess(processHandle, 1) != 0
    } else {
        // Graceful shutdown - send WM_CLOSE to all windows of this process
        var succeeded = false
        
        // Enumerate windows and send close messages
        let enumResult = EnumWindows({ (hWnd, lParam) -> BOOL in
            var windowProcessID: DWORD = 0
            GetWindowThreadProcessId(hWnd, &windowProcessID)
            
            if windowProcessID == lParam {
                // Send WM_CLOSE message for graceful shutdown
                PostMessage(hWnd, UINT(WM_CLOSE), 0, 0)
                let processIDPtr = UnsafeMutablePointer<Bool>(mutating: Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(bitPattern: Int(lParam))!).takeUnretainedValue() as! UnsafePointer<Bool>)
                processIDPtr.pointee = true
            }
            return 1 // Continue enumeration
        }, LPARAM(processID))
        
        // Wait a bit for graceful shutdown
        Thread.sleep(forTimeInterval: 0.5)
        
        // Check if process is still running, if so, force terminate
        var exitCode: DWORD = 0
        if GetExitCodeProcess(processHandle, &exitCode) != 0 && exitCode == STILL_ACTIVE {
            succeeded = TerminateProcess(processHandle, 1) != 0
        } else {
            succeeded = true // Process already terminated gracefully
        }
        
        return succeeded
    }
}

#else
// Fallback for non-Windows platforms
func getRunningProcesses() -> [Any] {
    print("This script is designed for Windows only")
    return []
}

func terminateProcess(processID: Any, force: Bool = false) -> Bool {
    return false
}
#endif

// Function to list running applications
func listRunningApps() {
    let processes = getRunningProcesses()
    
    print("💻 Currently Running Applications:")
    print("=" + String(repeating: "=", count: 49))
    
    var userApps: [String] = []
    var protectedCount = 0
    var optionalCount = 0
    
    for process in processes {
        #if os(Windows)
        let processName = process.name.lowercased()
        
        var status = ""
        if protectedProcesses.contains(processName) {
            status = " [PROTECTED]"
            protectedCount += 1
        } else if optionalKeepProcesses.contains(processName) {
            status = " [OPTIONAL KEEP]"
            optionalCount += 1
        } else {
            userApps.append(process.name)
        }
        
        print("• \(process.name) (PID: \(process.processID))\(status)")
        #endif
    }
    
    print("\n📊 Summary:")
    print("  User apps: \(userApps.count)")
    print("  Protected: \(protectedCount)")
    print("  Optional keep: \(optionalCount)")
    print()
}

// Function to quit applications using Windows APIs
func quitAllAppsWithWindowsAPI(forceQuit: Bool = false, keepOptional: Bool = true) {
    let processes = getRunningProcesses()
    
    var appsToQuit: [WindowsProcess] = []
    var skippedApps: [String] = []
    
    #if os(Windows)
    for process in processes {
        let processName = process.name.lowercased()
        
        // Skip protected system processes
        if protectedProcesses.contains(processName) {
            continue
        }
        
        // Skip optional apps if requested
        if keepOptional && optionalKeepProcesses.contains(processName) {
            skippedApps.append(process.name)
            continue
