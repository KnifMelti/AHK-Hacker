# AHK-Hacker

AutoHotkey decompiler with Windows context menu integration.

## Project Overview

AHK-Hacker extracts source code from compiled AutoHotkey executables (.exe) by extracting the embedded RCDATA resource using ResourceHacker. It integrates with the Windows right-click context menu for one-click decompilation.

## Tech Stack

- **Language**: AutoHotkey v2.0
- **External Tool**: ResourceHacker (downloaded automatically)
- **Platform**: Windows 10+

## File Structure

```
AHK-Hacker\
├── AHK-Hacker.ahk            (Main decompiler script)
├── AHK-Hacker.exe            (Compiled and signed executable)
├── Install.ahk               (Installer - unblocks files, prompts OK/Cancel)
├── Uninstall.ahk             (Uninstaller - removes context menu, cleans bin/)
├── AH.ico                    (Resource Hacker icon)
├── README.md                 (User documentation)
├── CLAUDE.md                 (This file - developer documentation)
├── log\                      (Decompilation logs)
├── lib\                      (Shared libraries - synced to GitHub)
│   ├── Notifications.ahk     (Shared notification library)
│   ├── Install-ContextMenu.ahk   (Installs right-click menu)
│   ├── Uninstall-ContextMenu.ahk (Uninstalls right-click menu)
│   └── Update-ResourceHacker.ahk (Downloads latest Resource Hacker)
└── bin\                      (ResourceHacker executables - git-ignored)
    ├── ResourceHacker.exe    (Downloaded automatically - v5.x)
    ├── ResourceHacker4.exe   (Bundled legacy version - v4.x)
    ├── .rh_version           (Version cache)
    ├── Help\                 (Resource Hacker documentation)
    └── samples\              (Resource Hacker samples)
```

## Key Components

### AHK-Hacker.ahk
Main decompiler that:
1. Receives .exe path from context menu argument
2. Runs ResourceHacker 5.x to extract RCDATA resource
3. Falls back to ResourceHacker 4.x if extraction fails (handles older AHK formats like `>AHK WITH ICON<`)
4. Handles both old (`RCData.bin`) and new (`RCDATA1_1.bin`) output formats
5. Converts line endings to Windows CRLF
6. Outputs `filename_decompiled.ahk` in same folder as source

### Install.ahk
Installation script that:
1. Shows OK/Cancel dialog before starting installation
2. Unblocks all files recursively using PowerShell
3. Runs lib/Update-ResourceHacker.ahk in silent mode to download latest ResourceHacker to bin/
4. Runs lib/Install-ContextMenu.ahk to register context menu
5. Shows progress notifications via ShowProgress from lib/Notifications.ahk

### Uninstall.ahk
Uninstallation script that:
1. Shows OK/Cancel dialog before starting uninstallation
2. Runs lib/Uninstall-ContextMenu.ahk in silent mode to remove context menu
3. Cleans up downloaded files from bin/ (ResourceHacker.exe, Help/, samples/, .rh_version, etc.)
4. Keeps ResourceHacker4.exe (bundled version)
5. Shows progress notifications via ShowProgress from lib/Notifications.ahk

### lib/Update-ResourceHacker.ahk
Updater that:
1. Sends HTTP HEAD request to check Last-Modified header
2. Compares with cached `bin/.rh_version` file
3. Downloads ZIP only if newer version available
4. Extracts to bin/ folder and unblocks files (removes "downloaded from internet" flag)
5. Supports `/silent` parameter to suppress notifications

### lib/Install-ContextMenu.ahk
Registry script that adds context menu entry at:
```
HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker
```
No admin rights required.
Supports `/silent` parameter to run without message boxes (uses ShowProgress notifications instead).
Looks for AHK-Hacker.exe in parent directory (since script is in lib/ folder).

### lib/Uninstall-ContextMenu.ahk
Registry script that removes context menu entry.
No admin rights required.
Supports `/silent` parameter to run without message boxes (uses ShowProgress notifications instead).

### lib/Notifications.ahk
Shared notification library that provides:
- `ShowProgress(message, iconType, title)` - Display system tray notifications
- Icon types: 0=Success, 1=Info, 2=Warning, 3=Error
- Used by multiple scripts for consistent user feedback

## Development Notes

### ResourceHacker Compatibility
- **ResourceHacker 5.x**: Latest version, downloaded by lib/Update-ResourceHacker.ahk to bin/ folder. Output naming: `RCDATA1_1.bin`
- **ResourceHacker 4.x**: Bundled legacy version (`bin/ResourceHacker4.exe`). Required for older AHK executables that use `>AHK WITH ICON<` resource naming. Output naming: `RCData.bin`

The decompiler tries 5.x first, then falls back to 4.x automatically.

### Building
`AHK-Hacker.exe` is pre-compiled and digitally signed. The source `AHK-Hacker.ahk` is included for reference.

### Testing
1. Run `Install.ahk` (prompts OK/Cancel, then downloads ResourceHacker 5.x to bin/ and installs context menu)
   - Or run `lib/Update-ResourceHacker.ahk` manually to download ResourceHacker 5.x
   - Or run `lib/Install-ContextMenu.ahk` manually to register context menu
2. Right-click any AHK-compiled .exe and select "AHK-Hacker - Decompile"

## Common Issues

- **"ResourceHacker.exe not found in bin folder"**: Run `lib/Update-ResourceHacker.ahk` (note: `bin/ResourceHacker4.exe` is bundled and should always be present)
- **"Failed to extract script data"**: The .exe is not an AHK executable or uses encryption
- **Context menu missing**: Run `lib/Install-ContextMenu.ahk`, restart Explorer if needed

