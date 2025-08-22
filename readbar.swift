import Cocoa
import Foundation
import CoreServices

// Check for debug flag
let isDebugMode = CommandLine.arguments.contains("--debug")

func debugPrint(_ message: String) {
    if isDebugMode {
        print(message)
    }
}

struct RecentFile {
    let path: String
    let name: String
    let lastModified: Date
    let lastAccessed: Date
    let sortDate: Date // The date to use for sorting (accessed for reading dir, modified for others)
}

class FileMonitor {
    private var eventStream: FSEventStreamRef?
    private let readBar: ReadBar
    private let monitoredPaths: [String]
    
    init(readBar: ReadBar) {
        self.readBar = readBar
        self.monitoredPaths = [
            NSString(string: "~/Downloads").expandingTildeInPath,
            NSString(string: "~/Desktop").expandingTildeInPath,
            NSString(string: "~/Library/Mobile Documents/com~apple~CloudDocs/reading").expandingTildeInPath
        ]
    }
    
    func startMonitoring() {
        debugPrint("🔍 Starting file monitoring for paths: \(monitoredPaths)")
        let callback: FSEventStreamCallback = { streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds in
            debugPrint("📁 FSEvent callback triggered with \(numEvents) events")
            guard let info = clientCallBackInfo else { 
                debugPrint("❌ No client callback info")
                return 
            }
            let monitor = Unmanaged<FileMonitor>.fromOpaque(info).takeUnretainedValue()
            monitor.handleEvents(numEvents: numEvents, eventPaths: eventPaths, eventFlags: eventFlags)
        }
        
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        
        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            monitoredPaths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
        )
        
        guard let stream = eventStream else { 
            debugPrint("❌ Failed to create FSEventStream")
            return 
        }
        
        debugPrint("✅ FSEventStream created successfully")
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
        debugPrint("🚀 FSEventStream started")
    }
    
    private func handleEvents(numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>) {
        debugPrint("LOG-FSEVENT-001: handleEvents called with \(numEvents) events")
        
        // Add safety checks to prevent crashes
        guard numEvents > 0 && numEvents < 1000 else {
            debugPrint("LOG-FSEVENT-002: Invalid numEvents: \(numEvents) - RETURNING")
            return
        }
        
        debugPrint("LOG-FSEVENT-003: About to extract paths from eventPaths pointer")
        
        // Correct way to handle FSEvents callback - eventPaths is a C array of C strings
        debugPrint("LOG-FSEVENT-004: Converting C array to Swift strings")
        let pathsPointer = eventPaths.bindMemory(to: UnsafePointer<Int8>.self, capacity: numEvents)
        var paths: [String] = []
        
        for i in 0..<numEvents {
            let cString = pathsPointer[i]
            if let swiftString = String(cString: cString, encoding: .utf8) {
                paths.append(swiftString)
                debugPrint("LOG-FSEVENT-005-\(i): Got path: \(swiftString)")
            } else {
                debugPrint("LOG-FSEVENT-005-\(i): ERROR - Could not convert C string to Swift String")
            }
        }
        
        debugPrint("LOG-FSEVENT-006: Successfully got \(paths.count) paths")
        
        guard paths.count == numEvents else {
            debugPrint("LOG-FSEVENT-007: Path count mismatch: \(paths.count) != \(numEvents) - RETURNING")
            return
        }
        
        debugPrint("LOG-FSEVENT-008: About to process \(numEvents) events")
        
        for i in 0..<numEvents {
            debugPrint("LOG-FSEVENT-009: Processing event \(i)")
            
            let path = paths[i]
            let flags = eventFlags[i]
            debugPrint("LOG-FSEVENT-010: Event \(i) - path: \(path), flags: \(flags)")
            
            // Process events safely
            if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0 {
                debugPrint("LOG-FSEVENT-011: File created: \(path)")
                checkAndAddFile(at: path)
            }
            
            if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0 {
                debugPrint("LOG-FSEVENT-012: File removed: \(path)")
                readBar.removeFile(at: path)
            }
            
            if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified) != 0 {
                debugPrint("LOG-FSEVENT-013: File modified: \(path)")
                checkAndAddFile(at: path)
            }
            
            debugPrint("LOG-FSEVENT-014: Finished processing event \(i)")
        }
        
        debugPrint("LOG-FSEVENT-015: handleEvents completing normally")
    }
    
    private func checkAndAddFile(at path: String) {
        let url = URL(fileURLWithPath: path)
        let fileExtension = url.pathExtension.lowercased()
        
        guard fileExtension == "pdf" || fileExtension == "epub" else { return }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            guard let modificationDate = attributes[.modificationDate] as? Date else { return }
            
            // Note: macOS doesn't reliably track last access times, so we use modification date
            // In a real implementation, you might want to track access times manually
            let accessDate = modificationDate
            
            // Determine if this is in the reading directory
            let isReadingDirectory = path.contains("reading")
            let sortDate = isReadingDirectory ? accessDate : modificationDate
            
            let fileName = url.lastPathComponent
            let recentFile = RecentFile(path: path, name: fileName, lastModified: modificationDate, lastAccessed: accessDate, sortDate: sortDate)
            readBar.addFile(recentFile)
        } catch {
            return
        }
    }
    
    func stopMonitoring() {
        debugPrint("🛑 Stopping file monitoring...")
        guard let stream = eventStream else { 
            debugPrint("⚠️ No event stream to stop")
            return 
        }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        eventStream = nil
        debugPrint("✅ File monitoring stopped")
    }
}

class ReadBar {
    private var recentFiles: [RecentFile] = []
    private let maxFiles = 15
    var menuManager: MenuManager?
    
    func addFile(_ file: RecentFile) {
        print("📄 New file detected: \(file.name)")
        recentFiles.removeAll { $0.name == file.name }
        recentFiles.insert(file, at: 0)
        
        if recentFiles.count > maxFiles {
            recentFiles = Array(recentFiles.prefix(maxFiles))
        }
        
        recentFiles.sort { $0.sortDate > $1.sortDate }
        debugPrint("📋 Current files count: \(recentFiles.count)")
        menuManager?.updateMenu()
    }
    
    func removeFile(at path: String) {
        recentFiles.removeAll { $0.path == path }
        menuManager?.updateMenu()
    }
    
    func getRecentFiles() -> [RecentFile] {
        return recentFiles.filter { FileManager.default.fileExists(atPath: $0.path) }
    }
}

class MenuManager: NSObject {
    private let statusItem: NSStatusItem
    private let readBar: ReadBar
    private var filePaths: [String] = []
    
    init(readBar: ReadBar) {
        self.readBar = readBar
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                button.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: "ReadBar")
            } else {
                // Fallback for macOS 10.15
                button.image = NSImage(named: NSImage.quickLookTemplateName)
            }
        }
        
        updateMenu()
    }
    
    func updateMenu() {
        debugPrint("🍽️ Updating menu")
        let menu = NSMenu()
        menu.delegate = self
        let recentFiles = readBar.getRecentFiles()
        debugPrint("📝 Menu will show \(recentFiles.count) files")
        
        // Clear and rebuild file paths array
        filePaths.removeAll()
        
        if recentFiles.isEmpty {
            let item = NSMenuItem(title: "No recent files", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for (index, file) in recentFiles.enumerated() {
                debugPrint("🔗 Adding menu item: \(file.name)")
                
                let item = NSMenuItem(title: file.name, action: #selector(openFileAtIndex(_:)), keyEquivalent: "")
                item.target = self
                item.tag = index
                item.isEnabled = true
                
                // Store path in our array instead of representedObject
                filePaths.append(file.path)
                
                menu.addItem(item)
                debugPrint("✅ Menu item added for: \(file.name) at index \(index)")
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        debugPrint("✅ Menu updated successfully")
    }
    
    @objc private func openFileAtIndex(_ sender: NSMenuItem) {
        debugPrint("LOG-CLICK-001: openFileAtIndex method ENTERED")
        debugPrint("LOG-CLICK-002: sender type: \(type(of: sender))")
        debugPrint("LOG-CLICK-003: sender.tag = \(sender.tag)")
        debugPrint("LOG-CLICK-004: filePaths.count = \(filePaths.count)")
        
        guard sender.tag >= 0 && sender.tag < filePaths.count else {
            debugPrint("LOG-CLICK-005: GUARD FAILED - Invalid file index: \(sender.tag)")
            return
        }
        debugPrint("LOG-CLICK-006: Guard passed - valid index")
        
        let path = filePaths[sender.tag]
        debugPrint("LOG-CLICK-007: Got path from array: \(path)")
        
        guard FileManager.default.fileExists(atPath: path) else {
            debugPrint("LOG-CLICK-008: GUARD FAILED - File does not exist: \(path)")
            return
        }
        debugPrint("LOG-CLICK-009: File exists check passed")
        
        debugPrint("LOG-CLICK-010: About to create URL")
        let fileURL = URL(fileURLWithPath: path)
        debugPrint("LOG-CLICK-011: File URL created: \(fileURL)")
        
        // Get the filename for the print statement
        let fileName = fileURL.lastPathComponent
        print("📖 Opening file: \(fileName)")
        
        debugPrint("LOG-CLICK-012: About to dispatch to background queue")
        DispatchQueue.global(qos: .userInitiated).async {
            debugPrint("LOG-CLICK-013: NOW ON BACKGROUND THREAD")
            debugPrint("LOG-CLICK-014: About to call NSWorkspace.shared.open")
            let success = NSWorkspace.shared.open(fileURL)
            debugPrint("LOG-CLICK-015: NSWorkspace.open returned: \(success)")
            
            debugPrint("LOG-CLICK-016: About to dispatch back to main thread")
            DispatchQueue.main.async {
                debugPrint("LOG-CLICK-017: Back on main thread")
                debugPrint("LOG-CLICK-018: File open result: \(success)")
                debugPrint("LOG-CLICK-019: About to finish main thread callback")
            }
            debugPrint("LOG-CLICK-020: Background thread callback finishing")
        }
        
        debugPrint("LOG-CLICK-021: About to return from openFileAtIndex")
        debugPrint("LOG-CLICK-022: openFileAtIndex method EXITING")
    }
}

extension MenuManager: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        debugPrint("LOG-MENU-001: menuWillOpen called")
        debugPrint("LOG-MENU-002: menu has \(menu.items.count) items")
    }
    
    func menuDidClose(_ menu: NSMenu) {
        debugPrint("LOG-MENU-003: menuDidClose called")
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var readBar: ReadBar!
    private var fileMonitor: FileMonitor!
    private var menuManager: MenuManager!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        debugPrint("🚀 App launched")
        readBar = ReadBar()
        debugPrint("📋 ReadBar initialized")
        
        menuManager = MenuManager(readBar: readBar)
        debugPrint("🍽️ MenuManager initialized")
        
        // Set up the bidirectional relationship properly
        readBar.menuManager = menuManager
        debugPrint("🔗 ReadBar-MenuManager relationship established")
        
        fileMonitor = FileMonitor(readBar: readBar)
        debugPrint("👀 FileMonitor initialized")
        fileMonitor.startMonitoring()
        
        // Scan for the 15 most recent PDF/EPUB files from all directories
        debugPrint("🔍 Scanning for 15 most recent PDF/EPUB files...")
        DispatchQueue.global(qos: .background).async {
            self.findMostRecentFiles()
        }
        
        debugPrint("✅ App initialization completed")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        debugPrint("LOG-APP-001: applicationWillTerminate called")
        debugPrint("LOG-APP-002: About to stop file monitoring")
        fileMonitor?.stopMonitoring()
        debugPrint("LOG-APP-003: File monitoring stopped")
        debugPrint("LOG-APP-004: applicationWillTerminate finishing")
    }
    
    private func findMostRecentFiles() {
        debugPrint("📂 Starting safe scan for most recent 15 files...")
        let paths = [
            NSString(string: "~/Downloads").expandingTildeInPath,
            NSString(string: "~/Desktop").expandingTildeInPath,
            NSString(string: "~/Library/Mobile Documents/com~apple~CloudDocs/reading").expandingTildeInPath
        ]
        
        var allFiles: [(path: String, name: String, modified: Date, accessed: Date, sortDate: Date)] = []
        
        for directoryPath in paths {
            debugPrint("📁 Scanning: \(directoryPath)")
            
            // Check if directory exists first
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: directoryPath, isDirectory: &isDirectory) && isDirectory.boolValue else {
                debugPrint("⚠️ Directory doesn't exist or isn't directory: \(directoryPath)")
                continue
            }
            
            // Determine if this is the reading directory
            let isReadingDirectory = directoryPath.contains("reading")
            
            // Use safe directory enumeration
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: directoryPath)
                var fileCount = 0
                
                for fileName in contents {
                    // Safety limit per directory (increased to handle large reading directory)
                    if fileCount >= 200 {
                        debugPrint("⚠️ Hit safety limit of 200 files per directory")
                        break
                    }
                    
                    let fullPath = (directoryPath as NSString).appendingPathComponent(fileName)
                    let url = URL(fileURLWithPath: fullPath)
                    let fileExtension = url.pathExtension.lowercased()
                    
                    if fileExtension == "pdf" || fileExtension == "epub" {
                        do {
                            let attributes = try FileManager.default.attributesOfItem(atPath: fullPath)
                            if let modificationDate = attributes[.modificationDate] as? Date {
                                // Note: macOS doesn't reliably track last access times, so we use modification date
                                // In a real implementation, you might want to track access times manually
                                let accessDate = modificationDate
                                
                                // For reading directory, use access date for sorting; for others, use modification date
                                let sortDate = isReadingDirectory ? accessDate : modificationDate
                                
                                allFiles.append((path: fullPath, name: fileName, modified: modificationDate, accessed: accessDate, sortDate: sortDate))
                                fileCount += 1
                            }
                        } catch {
                            debugPrint("⚠️ Could not read attributes for: \(fileName)")
                            continue
                        }
                    }
                }
                
                debugPrint("📊 Found \(fileCount) PDF/EPUB files in \(directoryPath)")
                
            } catch {
                debugPrint("❌ Error reading directory \(directoryPath): \(error)")
                continue
            }
        }
        
        // Sort by sort date (newest first) and take top 15
        let sortedFiles = allFiles.sorted { $0.sortDate > $1.sortDate }.prefix(15)
        
        debugPrint("📋 Total found: \(allFiles.count) files, showing top \(sortedFiles.count)")
        
        // Add files to tracker on main thread
        DispatchQueue.main.async {
            debugPrint("📋 About to add \(sortedFiles.count) files to tracker")
            for (index, fileData) in sortedFiles.enumerated() {
                let recentFile = RecentFile(path: fileData.path, name: fileData.name, lastModified: fileData.modified, lastAccessed: fileData.accessed, sortDate: fileData.sortDate)
                debugPrint("📄 Adding file \(index+1)/\(sortedFiles.count): \(fileData.name)")
                self.readBar.addFile(recentFile)
            }
            debugPrint("✅ File scanning completed - \(sortedFiles.count) files added")
            
            // Write debug info to file
            let debugInfo = "Files found: \(sortedFiles.count)\n" + sortedFiles.map { "- \($0.name) (\($0.path))" }.joined(separator: "\n")
            try? debugInfo.write(to: URL(fileURLWithPath: "/tmp/readbar_debug.txt"), atomically: true, encoding: .utf8)
        }
    }
}

debugPrint("LOG-MAIN-001: Creating NSApplication")
let app = NSApplication.shared
debugPrint("LOG-MAIN-002: Creating AppDelegate")
let delegate = AppDelegate()
debugPrint("LOG-MAIN-003: Setting delegate")
app.delegate = delegate
debugPrint("LOG-MAIN-004: Setting activation policy")
app.setActivationPolicy(.accessory)
debugPrint("LOG-MAIN-005: About to call app.run()")
app.run()
debugPrint("LOG-MAIN-006: app.run() returned - this should never print!")