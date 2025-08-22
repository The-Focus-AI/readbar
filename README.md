# Readbar

A macOS menubar application that monitors your Downloads, Desktop, and iCloud reading directories for PDF and EPUB files, displaying the 15 most recently modified files in a convenient dropdown menu for quick access.

## Features

- **Real-time monitoring** - Uses FSEvents to detect new files as they're added
- **Smart filtering** - Only shows PDF and EPUB files
- **Recent files priority** - Displays the 15 most recently modified files across all monitored directories
- **One-click opening** - Click any file in the menu to open it with the default application
- **Lightweight** - Runs efficiently in the background as a menubar-only app
- **Multi-directory support** - Monitors three key locations:
  - `~/Downloads`
  - `~/Desktop` 
  - `~/Library/Mobile Documents/com~apple~CloudDocs/reading`
- **Smart date sorting** - Uses last accessed times for reading directory, last modified times for Downloads/Desktop

## Installation & Usage

### Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd readbar

# Run the application
swift readbar.swift
```

### Debug Mode

To see detailed logging information, run with the debug flag:

```bash
swift readbar.swift --debug
```

## Using the Interface

1. **Menubar Icon** - Look for the document icon in your menubar
2. **Click the Icon** - Opens a dropdown showing your 15 most recent PDF/EPUB files
3. **Select a File** - Click any file to open it with the default application
4. **Quit** - Use the "Quit" option in the menu to exit

### Monitored Directories

Readbar automatically scans these directories for PDF and EPUB files:

- **Downloads** - Perfect for recently downloaded documents
- **Desktop** - For files you're actively working with
- **iCloud Reading Folder** - For your organized reading collection at `~/Library/Mobile Documents/com~apple~CloudDocs/reading`

## Technical Details

### Requirements

- macOS 10.15+ (Catalina or later)
- Swift 5.0+
- Xcode Command Line Tools (for Swift compilation)

### File Monitoring

- Uses Apple's FSEvents API for efficient real-time file system monitoring
- Automatically detects file creation, modification, and deletion
- Safe handling of concurrent file operations
- Respects system file access permissions

### Performance

- Scans up to 200 files per directory to balance completeness with performance
- Background scanning to avoid blocking the UI
- Efficient memory usage with automatic cleanup of deleted files
- Native macOS integration for optimal responsiveness

## Development

### Running from Source

```bash
# Clone the repository
git clone <repository-url>
cd readbar

# Run locally for testing
swift readbar.swift

# Run with debug output
swift readbar.swift --debug
```

### Project Structure

- `readbar.swift` - Main application source code
- `README.md` - This documentation

### Architecture

The application consists of four main components:

1. **FileMonitor** - Handles FSEvents monitoring and file system events
2. **Readbar** - Manages the list of recent files and metadata
3. **MenuManager** - Creates and updates the menubar dropdown interface
4. **AppDelegate** - Coordinates the application lifecycle and initialization

## Troubleshooting

### Common Issues

**App doesn't appear in menubar**
- Check if the app is running: `ps aux | grep readbar`
- Try running from terminal to see error messages

**Files not appearing**
- Verify the monitored directories exist and are accessible
- Check file permissions on the directories
- Ensure files have `.pdf` or `.epub` extensions

**App crashes when clicking files**
- Verify files exist and haven't been moved/deleted
- Check that default applications are properly configured for PDF/EPUB files

### Logs and Debugging

Readbar includes comprehensive logging. When running with `--debug`, you'll see detailed information about:
- File scanning progress
- Menu updates
- File opening attempts
- FSEvents callback activity

## License

MIT License - See LICENSE file for details

## Contributing

Contributions welcome! Please feel free to submit issues, feature requests, or pull requests.

## Changelog

### v1.0.0
- Initial release
- Real-time file monitoring with FSEvents
- Support for PDF and EPUB files
- Menubar interface with 15 recent files
- Multi-directory monitoring
- One-click file opening
- Smart date sorting (accessed times for reading directory, modified times for others)
- Debug mode support