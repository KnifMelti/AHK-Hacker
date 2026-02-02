![GitHub all releases](https://img.shields.io/github/downloads/KnifMelti/AHK-Hacker/total)
<img src="https://github.com/KnifMelti/AHK-Hacker/blob/main/src/res/icon.png" alt="Icon" width="128" align="right"><br><br>

# AHK-Hacker

AutoHotkey Decompiler with Windows Context Menu Integration

## Overview

AHK-Hacker extracts source code from compiled AutoHotkey executables (.exe) by directly reading the embedded RCDATA resource via Windows LoadLibrary API.<br>
Simply right-click any .exe file and select "AHK-Hacker - Decompile".

### Features

- **One-click decompilation** - Right-click context menu integration
- **Drag-and-drop support** - Drop `.exe` onto `AHK-Hacker.exe`
- **Automatic file naming** - Output as `filename_decompiled.ahk`
- **Works anywhere** - Decompile files from any location `[R/O|R/W]`
- **No admin rights needed** - Uses HKEY_CURRENT_USER registry
- **Automatic packer detection** - Detects UPX and MPRESS packers:
  - **UPX**: Unpacks UPX-compressed executables
  - **MPRESS**: Extracts via Windows ReadProcessMemory API

---

## Installation

**No installation required!** Just extract and run.

### Quick Start

1. Download the latest release zip from [Releases](https://github.com/KnifMelti/AHK-Hacker/releases)
2. Extract the zip file anywhere you like
3. **Run `AHK-Hacker.exe`** (or drag an `.exe` file onto it)

**First-run auto-install:** The first time you run `AHK-Hacker.exe`, it will prompt to install the context menu integration:
- Click **OK** to install → Adds right-click menu + creates uninstall shortcut
- Click **Cancel** to skip → Continues with decompilation (prompts again next time)

**Done!** No administrator privileges, AutoHotkey, or external downloads required.

---

## Usage

### Decompiling an AutoHotkey Executable

1. **Right-click** any `.exe` file in Windows Explorer
2. Select **"AHK-Hacker - Decompile"** from the context menu
3. Wait a few seconds
4. A notification will appear with the result
5. The decompiled `.ahk` file will be in the **same folder** as the `.exe`

### Drag-and-Drop

You can also drag any `.exe` file onto `AHK-Hacker.exe`:

1. Drag the target `.exe` file onto `AHK-Hacker.exe`
2. Wait a few seconds for processing
3. The decompiled `.ahk` file is saved using the same output rules as above

### Example

```
Input:  C:\MyPrograms\MyScript.exe
Output: C:\MyPrograms\MyScript_decompiled.ahk
Log:    [AHK-Hacker folder]\log\MyScript_decompile_20250118_143052.log

Note: If the source file is on a read-only location, output will be saved to:
Output: [AHK-Hacker folder]\ahk\MyScript_decompiled.ahk
```

---

## Release Folder Structure

```
AHK-Hacker\
├── ahk\                             (Decompiled output - when source is read-only)
├── bin\                             (Runtime binaries - downloaded on-demand)
│   ├── mATE\                        (myAutToExe decompiler - downloaded if needed)
│   └── upx.exe                      (UPX unpacker - downloaded if needed)
├── lib\                             (Shared libraries - source reference only)
│   ├── Automated-MemoryRead.ahk     (Automated memory extraction via ReadProcessMemory API)
│   ├── Launch-MyAutToExe.ahk        (Downloads mATE for very old AHK decompilation)
│   ├── Notifications.ahk            (Notification library)
│   ├── PE-Analysis.ahk              (PE analysis, packer detection, RCData extraction)
│   ├── Script-Utils.ahk             (Shared script utilities)
│   └── Unpack-Exe.ahk               (Downloads UPX unpacker for packed executables)
├── log\                             (Decompilation logs)
├── AH.ico                           (AHK-Hacker icon)
├── AHK-Hacker.ahk                   (Main decompiler script - source reference only)
├── AHK-Hacker.exe                   (Compiled and signed executable - run this!)
└── Uninstall AHK-Hacker.lnk         (Uninstall shortcut - created on first run)
```

**Note:** Source files (`.ahk`) are included as reference only. You only need `AHK-Hacker.exe` to run the decompiler.

---

## Uninstallation

### Using Uninstall Shortcut

1. **Double-click `Uninstall AHK-Hacker.lnk`** (created on first run)
2. Click **OK** on the uninstallation prompt (or Cancel to abort)

This will automatically:
- Remove the context menu integration
- Delete the uninstall shortcut itself

### Using Command Line

Alternatively, run from command line:
```cmd
AHK-Hacker.exe /uninstall
```

Or silently without prompts:
```cmd
AHK-Hacker.exe /uninstall /silent
```

**Note:** The AHK-Hacker folder, log files, bin folder, and ahk output folder are not deleted. You can manually delete the folder if you want to remove everything.

---

## Troubleshooting

### "This is not an AutoHotkey compiled executable"

**Cause:** The .exe file is not a compiled AutoHotkey script (validated via RT_MANIFEST resource).

### "Failed to extract script data"

**Possible causes:**
- The file is not an AutoHotkey compiled executable
- The executable is protected/encrypted (e.g., Themida, Enigma)
- The executable is very old (will try the myAutToExe decompiler fallback)
- The executable is corrupted
- Not enough disk space

---

## Requirements

- **Windows**: 10 or later
- **Internet**: Required for downloading **UPX** / **mATE** (only when needed)

**No AutoHotkey installation required!** The compiled `AHK-Hacker.exe` is self-contained.

---

## Technical Details

### Registry Location

```
HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker
```

### Supported AutoHotkey Versions

Works with compiled scripts from:
- AutoHotkey <= v1.0.48.5 (myAutToExe decompiler offered as fallback)
- AutoHotkey v1.1.x (all versions)
- AutoHotkey v2.x (all versions)

**Packer Support:**
- **UPX-packed**: Automatically detected and unpacked via UPX tool
- **MPRESS-packed**: Automatically detected and extracted via ReadProcessMemory API
- See [CLAUDE.md](https://github.com/KnifMelti/AHK-Hacker/blob/main/CLAUDE.md) for details

---

## Credits

- **AHK-Hacker** - inspired by: [AutoHotkey Decompiler v2.97.00C by Jake (A-gent)](https://github.com/A-gent/AutoHotkey-Decompiler)
- **AutoHotkey** - Powerful. Easy to learn: [The ultimate automation scripting language for Windows.](https://www.autohotkey.com/)
- **UPX** - [the Ultimate Packer for eXecutables](https://upx.github.io/)
- **myAutToExe (mATE)** - [AutoIt Decompiler](https://github.com/daovantrong/myAutToExe)

















