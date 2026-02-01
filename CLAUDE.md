# AHK-Hacker

AutoHotkey decompiler with Windows context menu integration.

## Project Overview

AHK-Hacker extracts source code from compiled AutoHotkey executables (.exe) by directly reading the embedded RCDATA resource via Windows LoadLibrary API. It integrates with the Windows right-click context menu for one-click decompilation.

## Tech Stack

- **Language**: AutoHotkey v2.0
- **Platform**: Windows 10+
- **Native APIs**:
  - Windows LoadLibrary for PE resource extraction
  - Windows ReadProcessMemory for MPRESS memory extraction

## File Structure

```
AHK-Hacker\
├── .github\                              (GitHub Actions workflows)
│   └── workflows\
│       └── release.yml                   (Release automation)
├── src\                                  (Source code)
│   ├── ahk\                              (Decompiled output - git-ignored, when source is read-only)
│   ├── bin\                              (Runtime binaries - git-ignored)
│   │   ├── mATE\                         (myAutToExe - downloaded on-demand)
│   │   └── upx.exe                       (Downloaded on-demand for unpacking)
│   ├── lib\                              (Shared libraries - synced to GitHub)
│   │   ├── Automated-MemoryRead.ahk      (Automated MPRESS extraction via ReadProcessMemory API)
│   │   ├── Install-ContextMenu.ahk       (Installs right-click menu)
│   │   ├── Launch-MyAutToExe.ahk         (Optional download of mATE for old AHK decompilation)
│   │   ├── Notifications.ahk             (Notification library)
│   │   ├── PE-Analysis.ahk               (PE analysis, packer detection, RCData extraction)
│   │   ├── Script-Utils.ahk              (Shared script utilities - SaveExtractedScript)
│   │   ├── Uninstall-ContextMenu.ahk     (Uninstalls right-click menu)
│   │   └── Unpack-Exe.ahk                (Downloads UPX unpacker for packed executables)
│   ├── log\                              (Decompilation logs - git-ignored)
│   ├── res\                              (Development resources - synced to GitHub)
│   │   ├── compile_and_sign.ps1          (Build script for development)
│   │   ├── icon.png                      (Project icon for README)
│   │   ├── AH.ico                        (AHK-Hacker icon - used for compilation)
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
2. Analyzes PE file for packer detection (UPX/MPRESS) via lib/PE-Analysis.ahk
3. Validates AHK signature via manifest (RT_MANIFEST)
4. If MPRESS → automatically extracts via ReadProcessMemory API (lib/Automated-MemoryRead.ahk)
5. If UPX → unpacks via UPX, then continues
6. Extracts script data directly from RT_RCDATA resources via LoadLibrary
7. Tries multiple resource IDs (1, 2, 3, 4, 5, 10, 100, 101, 102, 1000)
8. Handles UTF-16 LE, UTF-8, and CP0 encodings
9. Converts line endings to Windows CRLF
10. Outputs `filename_decompiled.ahk` in same folder as source
11. Cleans up temporary unpacked files (`*.unpacked.*.tmp`)

### Install.ahk
Installation script that:
1. Shows OK/Cancel dialog before starting installation
2. Unblocks all files recursively using PowerShell
3. Runs lib/Install-ContextMenu.ahk to register context menu
4. Shows progress notifications via ShowProgress from lib/Notifications.ahk

### Uninstall.ahk
Uninstallation script that:
1. Shows OK/Cancel dialog before starting uninstallation
2. Runs lib/Uninstall-ContextMenu.ahk in silent mode to remove context menu
3. Cleans up downloaded files from bin/ (upx.exe, mATE/)
4. Shows progress notifications via ShowProgress from lib/Notifications.ahk

### lib/PE-Analysis.ahk
PE analysis and direct RCData extraction library that:
1. Analyzes PE files for packer signatures (UPX, MPRESS)
2. Detects AutoHotkey executables via RT_MANIFEST resource
3. Extracts script data directly from RT_RCDATA via LoadLibrary
4. Supports multiple resource IDs and encodings (UTF-16 LE, UTF-8, CP0)
5. Validates extracted scripts via "; <COMPILER:" signature
6. Returns structured analysis data (packer, isAHK, arch, confidence)

**Main Functions:**
- `AnalyzePEFile(filePath)` - Full PE analysis with packer detection
- `DetectAutoHotkeyViaManifest(filePath)` - Manifest-based AHK validation
- `ExtractAHKScriptFromRCData(exePath, outputDir)` - Direct RCData extraction
- `IsUPXPacked(exePath, logFile)` - UPX detection via section parsing

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
1. Called when UPX is detected by PE analysis
2. Runs `upx -d input.exe -o output.tmp`
3. Validates output is valid PE file (starts with "MZ")
4. Returns path to unpacked temp file on success, "" on failure
5. AHK-Hacker.ahk retries RCData extraction on unpacked file
6. Temporary file is cleaned up after decompilation

### lib/Automated-MemoryRead.ahk
Automated memory extraction for MPRESS-packed executables via Windows ReadProcessMemory API:
- **TryAutomatedMemoryRead(exePath, mpressPID, outputDir, logFile)** - Main entry point for automated MPRESS extraction
- **GetModuleBaseAddress(hProcess, logFile)** - Dynamically gets module base address via EnumProcessModulesEx (supports x86 and x64)
- **FindScriptInBuffer(buf, bufSize, logFile)** - Searches for "; <COMPILER:" signature in memory buffer (UTF-16 LE, UTF-8, CP0)
- **ExtractScriptFromBuffer(buf, bufSize, offset, encoding, logFile)** - Extracts script from found offset in buffer with smart garbage cleanup
- Uses `SaveExtractedScript` from Script-Utils.ahk for saving output

**Windows API Usage:**
- `OpenProcess(PROCESS_VM_READ | PROCESS_QUERY_INFORMATION, 0, PID)` - Opens process with read permissions (0x0410)
- `EnumProcessModulesEx(hProcess, hMod, size, &cbNeeded, LIST_MODULES_ALL)` - Gets module base address (x86: 0x400000, x64: 0x140000000+)
- `ReadProcessMemory(hProcess, baseAddress, buffer, 50MB, &bytesRead)` - Reads from dynamic base address
- `CloseHandle(hProcess)` - Closes process handle
- Accepts partial reads (Error 299 / ERROR_PARTIAL_COPY is normal)

**Memory Reading Strategy:**
- **Base Address:** Dynamically retrieved via EnumProcessModulesEx for both x86 and x64 architectures
  - x86 processes: Typically 0x400000
  - x64 processes: Typically 0x140000000 or higher (ASLR-randomized)
- **Read Size:** 50 MB (balances performance vs coverage)
- **Process Load Delay:** 3 seconds after start to ensure script is loaded in memory
- **Encodings:** UTF-16 LE (primary), UTF-8, CP0 (fallback)
- **Signature:** "; <COMPILER:" (11 bytes in UTF-8, 22 bytes in UTF-16 LE)

**Binary Search Algorithm:**
- UTF-16 LE: Searches for `3B 00 20 00 3C 00 43 00...` ("; <COMPILER:" with null bytes between chars)
- UTF-8/CP0: Searches for `3B 20 3C 43 4F 4D 50...` ("; <COMPILER:" as raw ASCII)
- Returns offset and detected encoding on success

**Garbage Cleanup Strategy:**
- **Strategy 1:** RTrim - removes trailing whitespace
- **Strategy 2:** Control character removal - removes trailing control chars < ASCII 32 (except newlines)
- **Strategy 3:** Keyword-based garbage detection - detects and removes trailing trash characters
  - Identifies common AHK keywords (Pause, Exit, Return, etc.) at end of script
  - Removes 1-3 uppercase letters appended without delimiter (e.g., "PausePA" → "Pause")
  - Preserves valid syntax like spaces, quotes, parentheses

**Workflow:**
1. Called when MPRESS is detected by PE analysis
2. Waits 3 seconds for process to fully load into memory
3. Opens process with VM_READ permissions
4. Gets dynamic module base address via EnumProcessModulesEx
5. Reads memory from base address (accepts partial reads)
6. Searches for AHK signature in multiple encodings
7. Extracts script from offset (StrGet handles null-terminated strings)
8. Applies 3-stage cleanup to remove trailing garbage
9. Saves via SaveExtractedScript (normalizes line endings, UTF-8 without BOM)
10. Closes process handle

**Error Handling:**
- Returns false if process terminated before read
- Returns false if OpenProcess fails (permissions, invalid PID)
- Returns false if EnumProcessModulesEx fails (cannot determine base address)
- Returns false if ReadProcessMemory reads 0 bytes
- Returns false if signature not found in memory
- Logs all operations comprehensively

**Architecture Support:**
- **x86 MPRESS**: Fully supported (AHK v1/v2 compilers)
- **x64 MPRESS**: Fully supported (AHK v1/v2 compilers)
- Dynamic base address detection ensures compatibility with both architectures

**Important Notes:**
- Fully automated - no user interaction required for memory dumping
- Process is started by AHK-Hacker and runs for ~3 seconds
- No external tools (System Informer) needed
- mATE is NOT used for MPRESS files
- Handles v2 compiler artifacts (trailing garbage characters) automatically

### lib/Script-Utils.ahk
Shared utility functions for script handling:
- **SaveExtractedScript(scriptContent, exePath, outputDir, logFile)** - Normalizes and saves extracted scripts
  - Normalizes line endings to CRLF (Windows standard)
  - Writes as UTF-8 without BOM
  - Generates filename: `{exeBaseName}_decompiled.ahk`
  - Returns true on success, false on failure
- Used by both Automated-MemoryRead.ahk and PE-Analysis.ahk

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
1. Called when RCData extraction fails for very old AHK executables
2. Shows OK/Cancel dialog asking if user wants to try myAutToExe
3. If OK: ensures myAutToExe is installed (downloads if needed, with progress notifications)
4. Runs myAutToExe.exe GUI
5. NOT used for MPRESS files (MPRESS uses Automated-MemoryRead.ahk instead)

### lib/Notifications.ahk
Shared notification library that provides:
- `ShowProgress(message, iconType, title)` - Display system tray notifications
- Icon types: 0=Success, 1=Info, 2=Warning, 3=Error
- Used by multiple scripts for consistent user feedback

## Development Notes

### PE Analysis and Packer Detection

AHK-Hacker uses comprehensive PE header analysis to detect packers and validate AHK executables:

**Packer Detection:**
- **UPX**: Detects section names "UPX0", "UPX1", "UPX2", ".UPX0", ".UPX1"
- **MPRESS**: Detects section names "MPRESS", ".MPRESS1", ".MPRESS2"
- **Suspicious Detection**: Flags files with high virtual-to-raw size ratios (>3x)

**AHK Validation:**
- Reads RT_MANIFEST (resource type 24) via LoadLibrary
- Searches for AHK signatures: "AutoHotkey", "Microsoft.Windows.AutoHotkey", "AutoHotkeyScript"
- Rejects non-AHK executables early to avoid unnecessary processing

**Analysis Results:**
- `packed` (bool) - Is file packed?
- `packer` (string) - Packer name (UPX/MPRESS/Unknown)
- `isAHK` (bool) - Is AHK-compiled?
- `arch` (string) - x86/x64
- `confidence` (int) - Detection confidence %

**Implementation:**
- `AnalyzePEFile(filePath)` function in lib/PE-Analysis.ahk
- `DetectAutoHotkeyViaManifest(filePath)` for AHK validation
- `IsUPXPacked(exePath, logFile)` for UPX-specific detection
- Comprehensive error handling for corrupted or invalid PE files
- Detailed logging of all detection steps and section names

**Workflow:**
1. PE analysis validates file structure and detects packers
2. Manifest check confirms AHK compilation
3. UPX files → unpack → extract RCData
4. MPRESS files → start process → read memory via API → extract script
5. Clean files → direct RCData extraction

### Building
`AHK-Hacker.exe` is pre-compiled and digitally signed. The source `AHK-Hacker.ahk` is included for reference.

**Build Process:**
Version upgrades, compilation, and code signing are handled manually by the maintainer using the scripts in `src/res/`:
- Version numbers are updated in source files as needed
- `compile_and_sign.ps1` compiles AHK-Hacker.exe from AHK-Hacker.ahk
- `sign_exe.ps1` applies digital signature to the compiled executable

### Testing
1. Run `Install.ahk` (prompts OK/Cancel, then installs context menu)
   - Or run `lib/Install-ContextMenu.ahk` manually to register context menu
2. Right-click any AHK-compiled .exe and select "AHK-Hacker - Decompile"

## Common Issues

- **"Failed to extract script data"**: The .exe is not an AHK executable, uses encryption, or is very old (try mATE)
- **"This is not an AutoHotkey compiled executable"**: Manifest check failed - file is not AHK-compiled
- **Context menu missing**: Run `lib/Install-ContextMenu.ahk`, restart Explorer if needed

## Development Resources (src/res/ folder)

The `src/res/` folder contains development-time resources that are tracked in Git:
- **AH.ico**: Icon used during compilation (referenced in src/AHK-Hacker.ahk compile directive)
- **icon.png**: Project icon displayed in README.md
- **compile_and_sign.ps1**: PowerShell script to compile and sign the executable
- **sign_exe.ps1**: PowerShell script for code signing with digital certificate



