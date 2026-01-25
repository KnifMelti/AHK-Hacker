# AHK-Hacker

AutoHotkey decompiler with Windows context menu integration.

## Project Overview

AHK-Hacker extracts source code from compiled AutoHotkey executables (.exe) by extracting the embedded RCDATA resource using Resource Hacker™. It integrates with the Windows right-click context menu for one-click decompilation.

## Tech Stack

- **Language**: AutoHotkey v2.0
- **External Tool**: Resource Hacker™ (downloaded automatically)
- **Platform**: Windows 10+

## File Structure

```
AHK-Hacker\
├── .github\                              (GitHub Actions workflows)
│   └── workflows\
│       └── release.yml                   (Release automation)
├── src\                                  (Source code)
│   ├── ahk\                              (Decompiled output - git-ignored, when source is read-only)
│   ├── bin\                              (Runtime binaries - git-ignored)
│   │   ├── Help\                         (Resource Hacker™ documentation)
│   │   ├── mATE\                         (myAutToExe - downloaded on-demand)
│   │   ├── samples\                      (Resource Hacker™ samples)
│   │   ├── .rh_version                   (Version cache)
│   │   ├── changes.txt                   (Resource Hacker™ changelog)
│   │   ├── ReadMe.txt                    (Resource Hacker™ readme)
│   │   ├── ResourceHacker.exe            (Downloaded automatically - v5.x)
│   │   ├── ResourceHacker4.exe           (Copied from res/ during release)
│   │   └── upx.exe                       (Downloaded on-demand for unpacking)
│   ├── lib\                              (Shared libraries - synced to GitHub)
│   │   ├── Install-ContextMenu.ahk       (Installs right-click menu)
│   │   ├── Launch-MyAutToExe.ahk         (Optional download of mATE for old AHK decompilation)
│   │   ├── Notifications.ahk             (Notification library)
│   │   ├── Uninstall-ContextMenu.ahk     (Uninstalls right-click menu)
│   │   ├── Unpack-Exe.ahk                (Downloads UPX unpacker for packed executables)
│   │   └── Update-ResourceHacker.ahk     (Downloads latest Resource Hacker™)
│   ├── log\                              (Decompilation logs - git-ignored)
│   ├── res\                              (Development resources - synced to GitHub)
│   │   ├── compile_and_sign.ps1          (Build script for development)
│   │   ├── icon.png                      (Project icon for README)
│   │   ├── ResourceHacker4.exe           (Bundled legacy version - (c) Angus Johnson 1999-2016, copied to bin/ in releases)
│   │   ├── RH.ico                        (AHK-Hacker icon - used for compilation)
│   │   └── sign_exe.ps1                  (Code signing script)
│   ├── AHK-Hacker.ahk                    (Main decompiler script)
│   ├── AHK-Hacker.exe                    (Compiled and signed executable)
│   ├── Install.ahk                       (Installer - unblocks files etc...)
│   └── Uninstall.ahk                     (Uninstaller - removes context menu etc...)
├── .gitattributes                        (Git line ending configuration)
├── .gitignore                            (Git ignore patterns)
├── CLAUDE.md                             (This file - developer documentation)
├── LICENSE.md                            (License information)
└── README.md                             (User documentation)
```

## Key Components

### AHK-Hacker.ahk
Main decompiler that:
1. Receives .exe path from context menu argument
2. Runs Resource Hacker™ 5.x to extract RCDATA resource
3. Falls back to Resource Hacker™ 4.x if extraction fails (handles older AHK formats like `>AHK WITH ICON<`)
4. Validates extracted content - if empty or too small (< 10 bytes), attempts UPX unpacking via lib/Unpack-Exe.ahk
5. If UPX succeeds, retries Resource Hacker™ 5.x → 4.x on unpacked file
6. If all methods fail, offers to open myAutToExe GUI for manual decompilation (very old AHK <= v1.0.48.5)
7. Handles both old (`RCData.bin`) and new (`RCDATA1_1.bin`) output formats
8. Converts line endings to Windows CRLF
9. Outputs `filename_decompiled.ahk` in same folder as source
10. Cleans up temporary unpacked files (`*.unpacked.*.tmp`)

### Install.ahk
Installation script that:
1. Shows OK/Cancel dialog before starting installation
2. Unblocks all files recursively using PowerShell
3. Runs lib/Update-ResourceHacker.ahk in silent mode to download latest Resource Hacker™ to bin/
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
1. Called when Resource Hacker™ extracts empty/invalid RCDATA (< 10 bytes)
2. Runs `upx -d input.exe -o output.tmp`
3. Validates output is valid PE file (starts with "MZ")
4. Returns path to unpacked temp file on success, "" on failure
5. AHK-Hacker.ahk retries Resource Hacker™ on unpacked file
6. Temporary file is cleaned up after decompilation

### lib/Launch-MyAutToExe.ahk
Automatic decompilation fallback for very old AutoHotkey executables (v1.0.48.5 and earlier):
- **OfferMyAutToExe(exePath)** - Shows dialog offering to try myAutToExe decompilation
- **EnsureMyAutToExeInstalled()** - Checks if myAutToExe is installed to bin folder, downloads if needed
- **DownloadMyAutToExe()** - Downloads and extracts mATE from GitHub to bin\mATE\
- Downloads ZIP from GitHub (KnifMelti/SandboxStart repository)
- Extracts mATE folder to bin\mATE\
- Unblocks all files recursively
- Runs myAutToExe.exe GUI

**Installation location:**
- bin\mATE\ (extracted from mATE.zip)

**Workflow:**
1. Called when all automatic methods fail (RH5 → RH4 → UPX)
2. Shows Yes/No dialog asking if user wants to try myAutToExe
3. If Yes: ensures myAutToExe is installed (downloads if needed, with progress notifications)
4. Runs myAutToExe.exe GUI

### lib/Notifications.ahk
Shared notification library that provides:
- `ShowProgress(message, iconType, title)` - Display system tray notifications
- Icon types: 0=Success, 1=Info, 2=Warning, 3=Error
- Used by multiple scripts for consistent user feedback

## Development Notes

### Resource Hacker™ Compatibility
- **Resource Hacker™ 5.x**: Latest version, downloaded by lib/Update-ResourceHacker.ahk to bin/ folder. Output naming: `RCDATA1_1.bin`
- **Resource Hacker™ 4.x**: Bundled legacy version (stored in `res/ResourceHacker4.exe` in source, copied to `bin/ResourceHacker4.exe` in release packages). Required for older AHK executables that use `>AHK WITH ICON<` resource naming. Output naming: `RCData.bin`

The decompiler tries 5.x first, then falls back to 4.x automatically.

**Note on file locations:**
- **Development (source code)**: ResourceHacker4.exe is in `src/res/` folder (tracked in Git)
- **Release packages**: ResourceHacker4.exe is copied to `src/bin/` folder by the GitHub Actions workflow
- **Runtime**: AHK-Hacker.ahk always looks for ResourceHacker4.exe in `bin/` folder (relative to script location)

#### Resource Hacker™ 5.x Known Bug - Special Characters in Resource Names

**Confirmed Bug:** Resource Hacker 5.x fails to extract RCDATA resources via command-line when the resource name contains special characters (`<` and `>`), specifically the `>AHK WITH ICON<` resource used by older AutoHotkey executables.

**Symptoms:**
- GUI correctly displays the resource in the tree view
- Command-line extraction creates the `.rc` file with the reference `>AHK WITH ICON< RCDATA ">AHK WITH ICON<.bin"`
- The actual `.bin` file is **never created** on disk

**Test Commands (all fail to create .bin file):**
```bash
# Standard extraction (fails)
ResourceHacker.exe -open "input.exe" -save "output.rc" -action extract -mask RCDATA,, -log "log.txt"

# Specific resource name (fails)
ResourceHacker.exe -open "input.exe" -save "output.rc" -action extract -mask "RCDATA,>AHK WITH ICON<," -log "log.txt"

# Escape attempts (all fail)
ResourceHacker.exe -open "input.exe" -save "output.rc" -action extract -mask "RCDATA,\>AHK WITH ICON\<," -log "log.txt"
ResourceHacker.exe -open "input.exe" -save "output.rc" -action extract -mask "RCDATA,\\>AHK WITH ICON\\<," -log "log.txt"
ResourceHacker.exe -open "input.exe" -save "output.rc" -action extract -mask "RCDATA,^>AHK WITH ICON^<," -log "log.txt"
ResourceHacker.exe -open "input.exe" -save "output.rc" -action extract -mask "RCDATA,%3EAHK WITH ICON%3C," -log "log.txt"
```

**Result:** All commands above create only the `.rc` file (containing MENU, DIALOG, ACCELERATORS resources and the RCDATA reference), but the `.bin` file is not extracted.

**Resource Hacker 4.x Comparison (works correctly):**
```bash
# Same command with v4.x successfully creates RCData.bin
ResourceHacker4.exe -open "input.exe" -save "output.rc" -action extract -mask RCDATA,, -log "log.txt"
```

**Verified Results:**
- **RH 5.x:** Creates only `.rc` file (3,942 bytes), no `.bin` file
- **RH 4.x:** Creates both `.rc` file (3,942 bytes) AND `RCData.bin` (419 bytes with valid AutoHotkey v1.1 script)

**Root Cause:**
Resource Hacker 5.x uses the resource name directly as the output filename without sanitization or validation. Windows prohibits the following characters in filenames:
```
< > : " / \ | ? *
```

When attempting to create `>AHK WITH ICON<.bin`, Windows rejects the filename due to the `<` and `>` characters, causing silent failure.

**Filename Strategy Comparison:**
- **RH 4.x:** Uses generic safe names (`RCData.bin`) regardless of resource name
- **RH 5.x:** Uses resource name directly (e.g., `RCDATA1_1.bin` for numeric IDs, `>AHK WITH ICON<.bin` for string names)

**Attempted Workarounds (all failed):**
- Escape sequences in `-mask` parameter (backslash, caret, URL encoding)
- Extracting to folder instead of file (creates only `ExtractedResources.rc`)
- Wildcard resource masks (same issue)

Resource Hacker 5.x provides no mechanism to override or sanitize the output filename for extracted binary resources.

**Impact:**
This bug affects decompilation of AutoHotkey <= v1.1.30.0 executables compiled with the `>AHK WITH ICON<` resource format. Resource Hacker 4.x fallback is **mandatory** and cannot be replaced with an escape sequence workaround.

**Affected Versions:**
- Resource Hacker v5.2.8 (build 448) - Confirmed (tested on 2026-01-25)

**Workaround:**
AHK-Hacker maintains Resource Hacker 4.x as a bundled fallback. The decompiler automatically falls back to v4.x when v5.x fails to extract `.bin` files (detected at AHK-Hacker.ahk:145-187).

### UPX Detection

AHK-Hacker uses PE header analysis to detect UPX-packed executables before attempting unpacking:
- Parses PE section headers to check for "UPX0", "UPX1", "UPX2" signatures
- Only downloads/runs UPX if file is confirmed UPX-packed
- Falls back to unpacking attempt if detection fails (conservative approach)
- Improves performance by 50-75% for non-UPX files (saves 6-13 seconds)

**Detection states:**
- **1**: UPX detected → Proceed with unpacking
- **0**: Not UPX → Skip to mATE offer
- **-1**: Detection error → Try unpacking anyway (safe fallback)

**Implementation:**
- `IsUPXPacked(exePath, logFile)` function in lib/Unpack-Exe.ahk
- Reads DOS header, PE header, and section table
- Matches section names against UPX pattern (case-insensitive regex: `^UPX[0-9]$`)
- Comprehensive error handling for corrupted or invalid PE files
- Detailed logging of all detection steps and section names

### Building
`AHK-Hacker.exe` is pre-compiled and digitally signed. The source `AHK-Hacker.ahk` is included for reference.

### Testing
1. Run `Install.ahk` (prompts OK/Cancel, then downloads Resource Hacker™ 5.x to bin/ and installs context menu)
   - Or run `lib/Update-ResourceHacker.ahk` manually to download Resource Hacker™ 5.x
   - Or run `lib/Install-ContextMenu.ahk` manually to register context menu
2. Right-click any AHK-compiled .exe and select "AHK-Hacker - Decompile"

## Common Issues

- **"ResourceHacker.exe not found in bin folder"**: Run `lib/Update-ResourceHacker.ahk` (note: `bin/ResourceHacker4.exe` is bundled in releases and should always be present)
- **"Failed to extract script data"**: The .exe is not an AHK executable or uses encryption
- **Context menu missing**: Run `lib/Install-ContextMenu.ahk`, restart Explorer if needed

## Development Resources (src/res/ folder)

The `src/res/` folder contains development-time resources that are tracked in Git:
- **ResourceHacker4.exe**: Legacy Resource Hacker™ v4.x binary (copied to `src/bin/` in release packages)
- **RH.ico**: Icon used during compilation (referenced in src/AHK-Hacker.ahk compile directive)
- **icon.png**: Project icon displayed in README.md
- **compile_and_sign.ps1**: PowerShell script to compile and sign the executable
- **sign_exe.ps1**: PowerShell script for code signing with digital certificate

During release, ResourceHacker4.exe is copied to the src/bin/ folder in release packages.



