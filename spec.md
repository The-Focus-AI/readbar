# macOS Menubar File Tracker Specification

## Overview

A Swift-based menubar application that monitors specified directories for new PDF and EPUB files, displaying recent files in a menu with one-click opening functionality.

## Architecture

### Core Components

1. **App Delegate** - Manages app lifecycle and menubar integration
2. **File Monitor** - Uses FSEvents to monitor directory changes
3. **File Tracker** - Maintains in-memory list of recent files with metadata
4. **Menu Manager** - Builds and updates the menubar menu

### Data Structure

```swift
struct RecentFile {
    let path: String
    let name: String
    let lastModified: Date
}
```

## Implementation Details

### Directory Monitoring

- Monitor 3 directories using FSEvents:
    - `~/Downloads`
    - `~/Desktop`
    - `~/Library/Mobile Documents/com~apple~CloudDocs/reading`
- Watch for file creation events only (new files)
- Filter for PDF and EPUB file extensions only

### File Tracking

- Maintain list of up to 10 most recent files
- Sort by last modified date (newest first)
- Automatically remove files when deleted from filesystem
- Automatically promote updated files to top of list
- No duplicate filenames (keep newest version)

### Menu Interface

- Menubar icon: Simple, clean icon
- Menu items: File names only (up to 10 most recent)
- Click behavior: Open file with default application
- Quit option in menu

### File System Integration

- Use `FSEventStream` for efficient real-time monitoring
- Handle file system notifications for creation/deletion
- No app badge showing file count

## Technical Requirements

### Dependencies

- Foundation framework (for file system operations)
- AppKit framework (for menubar integration)
- CoreServices framework (for FSEvents)

### Build Requirements

- Swift 5.0+
- macOS 10.15+ deployment target
- Pure Swift compilation without Xcode required

### File Operations

- Monitor directories using FSEvents with `kFSEventStreamCreateFlagFileEvents`
- Only track PDF and EPUB files (`.pdf`, `.epub`)
- Handle directory paths with spaces properly
- Use relative paths for iCloud directory

## Implementation Plan

1. **Setup menubar app structure**
2. **Implement FSEvents monitoring for 3 directories**
3. **Create file tracking logic with sorting and deduplication**
4. **Build dynamic menu interface**
5. **Add click handling to open files**
6. **Implement automatic cleanup of deleted files**

## Error Handling

- Gracefully handle missing directories (silent failure)
- No special error UI required

## Testing Plan

- Unit tests for file tracking logic
- Integration tests for FSEvents monitoring
- Manual testing of file creation/deletion scenarios

Downloading model

0 B / 0 B (0%)
