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
├── AHK-Hacker.ahk                (Main decompiler script)
├── AHK-Hacker.exe                (Compiled and signed executable)
├── Install.ahk                   (Installer - unblocks files etc...)
├── Uninstall.ahk                 (Uninstaller - removes context menu etc...)
├── README.md                     (User documentation)
├── CLAUDE.md                     (This file - developer documentation)
├── log\                          (Decompilation logs)
├── lib\                          (Shared libraries - synced to GitHub)
│   ├── Notifications.ahk         (Notification library)
│   ├── Install-ContextMenu.ahk   (Installs right-click menu)
│   ├── Uninstall-ContextMenu.ahk (Uninstalls right-click menu)
│   ├── Update-ResourceHacker.ahk (Downloads latest Resource Hacker)
│   ├── Unpack-Exe.ahk            (Downloads UPX unpacker for packed executables)
│   └── Launch-MyAutToExe.ahk     (Optional download/launch of myAutToExe GUI for automatic old AHK decompilation)
├── res\                          (Development resources - synced to GitHub)
│   ├── ResourceHacker4.exe       (Bundled legacy version - v4.x, copied to bin/ in releases)
│   ├── RH.ico                    (Resource Hacker icon - used for compilation)
│   ├── icon.png                  (Project icon for README)
│   ├── compile_and_sign.ps1      (Build script for development)
│   └── sign_exe.ps1              (Code signing script)
└── bin\                          (Runtime binaries - git-ignored)
    ├── ResourceHacker.exe        (Downloaded automatically - v5.x)
    ├── ResourceHacker4.exe       (Bundled and copied from res/ during installation/release)
    ├── upx.exe                   (Downloaded on-demand for unpacking)
    ├── .rh_version               (Version cache)
    ├── Help\                     (Resource Hacker documentation)
    └── samples\                  (Resource Hacker samples)
```

## Key Components

### AHK-Hacker.ahk
Main decompiler that:
1. Receives .exe path from context menu argument
2. Runs ResourceHacker 5.x to extract RCDATA resource
3. Falls back to ResourceHacker 4.x if extraction fails (handles older AHK formats like `>AHK WITH ICON<`)
4. Validates extracted content - if empty or too small (< 10 bytes), attempts UPX unpacking via lib/Unpack-Exe.ahk
5. If UPX succeeds, retries ResourceHacker 5.x → 4.x on unpacked file
6. If all methods fail, offers to open myAutToExe GUI for manual decompilation (very old AHK <= v1.0.48.5)
7. Handles both old (`RCData.bin`) and new (`RCDATA1_1.bin`) output formats
8. Converts line endings to Windows CRLF
9. Outputs `filename_decompiled.ahk` in same folder as source
10. Cleans up temporary unpacked files (`*.unpacked.*.tmp`)

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
3. Cleans up downloaded files from bin/ (ResourceHacker.exe, upx.exe, Help/, samples/, .rh_version, etc.)
4. Keeps ResourceHacker4.exe in bin/ (bundled version - originally from res/ in source)
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

### lib/Unpack-Exe.ahk
Unpacker library that automatically handles UPX-compressed executables:
- **TryUnpackExe(exePath, logFile)** - Main entry point that attempts UPX unpacking
- **FindUpx()** - Searches for upx.exe in known locations (AutoHotkey\Compiler, bin/)
- **DownloadUpx(logFile)** - Downloads latest UPX from GitHub releases API
- Downloads ZIP, extracts upx.exe using PowerShell, unblocks file
- Validates unpacked files are valid PE executables (MZ header check)
- Creates temporary files with naming: `{filename}.unpacked.{timestamp}.tmp`
- Logs all operations to the decompilation log file

**UPX search order:**
1. `%ProgramFiles%\AutoHotkey\Compiler\upx.exe`
2. `bin/upx.exe` (downloaded/cached)

**Unpacking workflow:**
1. Called when ResourceHacker extracts empty/invalid RCDATA (< 10 bytes)
2. Runs `upx -d input.exe -o output.tmp`
3. Validates output is valid PE file (starts with "MZ")
4. Returns path to unpacked temp file on success, "" on failure
5. AHK-Hacker.ahk retries ResourceHacker on unpacked file
6. Temporary file is cleaned up after decompilation

### lib/Launch-MyAutToExe.ahk
Automatic decompilation fallback for very old AutoHotkey executables (v1.0.48.5 and earlier):
- **OfferMyAutToExe(exePath)** - Shows dialog offering to try myAutToExe decompilation
- **EnsureMyAutToExeInstalled()** - Checks if myAutToExe is installed to Desktop, downloads if needed
- **DownloadMyAutToExe()** - Downloads and extracts latest myAutToExe from GitHub zipball_url to Desktop\myAutToExe\
- Downloads ZIP from GitHub API using zipball_url (latest release source)
- Extracts subdirectory (daovantrong-myAutToExe-*) to temp folder
- Selectively copies Data/, Tidy/ folders and root files to Desktop\myAutToExe\
- Unblocks all files recursively
- Runs myAutToExe.exe with /q /s parameters (silent mode, quit when done)

**Installation location:**
- %USERPROFILE%\Desktop\myAutToExe\ (selective extraction: Data/, Tidy/, and root files only)

**Workflow:**
1. Called when all automatic methods fail (RH5 → RH4 → UPX)
2. Shows Yes/No dialog asking if user wants to try myAutToExe
3. If Yes: ensures myAutToExe is installed (downloads if needed, with progress notifications)
4. Runs myAutToExe.exe in silent mode: `myAutToExe.exe "input.exe" /q /s`
5. Waits for decompilation to complete
6. Renames output from `filename.ahk` to `filename_decompiled.ahk`
7. Shows success or failure message

### lib/Notifications.ahk
Shared notification library that provides:
- `ShowProgress(message, iconType, title)` - Display system tray notifications
- Icon types: 0=Success, 1=Info, 2=Warning, 3=Error
- Used by multiple scripts for consistent user feedback

## Development Notes

### ResourceHacker Compatibility
- **ResourceHacker 5.x**: Latest version, downloaded by lib/Update-ResourceHacker.ahk to bin/ folder. Output naming: `RCDATA1_1.bin`
- **ResourceHacker 4.x**: Bundled legacy version (stored in `res/ResourceHacker4.exe` in source, copied to `bin/ResourceHacker4.exe` in release packages). Required for older AHK executables that use `>AHK WITH ICON<` resource naming. Output naming: `RCData.bin`

The decompiler tries 5.x first, then falls back to 4.x automatically.

**Note on file locations:**
- **Development (source code)**: ResourceHacker4.exe is in `res/` folder (tracked in Git)
- **Release packages**: ResourceHacker4.exe is copied to `bin/` folder by the GitHub Actions workflow
- **Runtime**: AHK-Hacker.ahk always looks for ResourceHacker4.exe in `bin/` folder

### Building
`AHK-Hacker.exe` is pre-compiled and digitally signed. The source `AHK-Hacker.ahk` is included for reference.

### Testing
1. Run `Install.ahk` (prompts OK/Cancel, then downloads ResourceHacker 5.x to bin/ and installs context menu)
   - Or run `lib/Update-ResourceHacker.ahk` manually to download ResourceHacker 5.x
   - Or run `lib/Install-ContextMenu.ahk` manually to register context menu
2. Right-click any AHK-compiled .exe and select "AHK-Hacker - Decompile"

## Common Issues

- **"ResourceHacker.exe not found in bin folder"**: Run `lib/Update-ResourceHacker.ahk` (note: `bin/ResourceHacker4.exe` is bundled in releases and should always be present)
- **"Failed to extract script data"**: The .exe is not an AHK executable or uses encryption
- **Context menu missing**: Run `lib/Install-ContextMenu.ahk`, restart Explorer if needed

## Development Resources (res/ folder)

The `res/` folder contains development-time resources that are tracked in Git:
- **ResourceHacker4.exe**: Legacy ResourceHacker v4.x binary (copied to `bin/` in release packages)
- **RH.ico**: Icon used during compilation (referenced in AHK-Hacker.ahk compile directive)
- **icon.png**: Project icon displayed in README.md
- **compile_and_sign.ps1**: PowerShell script to compile and sign the executable
- **sign_exe.ps1**: PowerShell script for code signing with digital certificate

These files are NOT distributed directly in the res/ folder. During release, ResourceHacker4.exe is copied to the bin/ folder in release packages, and RH.ico is included in the root for visibility.


