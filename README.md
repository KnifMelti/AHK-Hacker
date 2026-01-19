# AHK-Hacker

AutoHotkey Decompiler with Windows Context Menu Integration

## Overview

AHK-Hacker extracts source code from compiled AutoHotkey executables (.exe) by extracting the embedded RCDATA resource. Simply right-click any .exe file and select "AHK-Hacker - Decompile".

### Features

- **One-click decompilation** - Right-click context menu integration
- **Automatic file naming** - Output as `filename_decompiled.ahk`
- **Works anywhere** - Decompile files from any location
- **No admin rights needed** - Uses HKEY_CURRENT_USER registry
- **Auto-update Resource Hacker** - Built-in updater script

---

## Installation

> **Note:** AutoHotkey v2.0+ must be installed to run the helper scripts (.ahk files). Download from https://www.autohotkey.com

### Recommended: PowerShell Install

1. Download the latest release zip from [Releases](https://github.com/KnifMelti/AHK-Hacker/releases)
2. Extract the zip file anywhere you like
3. Right-click `Install.ps1` → **"Run with PowerShell"**

This will automatically:
- Unblock all files (removes Windows security warnings)
- Download the latest ResourceHacker 5.x
- Install the context menu integration

**Done!** No administrator privileges required.

### Manual Install

If you prefer to install manually:
1. Extract the zip file
2. Unblock files if needed (right-click files → Properties → Unblock)
3. Run `Update-ResourceHacker.ahk` to download ResourceHacker 5.x
4. Run `Install-ContextMenu.ahk` to add the context menu

---

## Usage

### Decompiling an AutoHotkey Executable

1. **Right-click** any `.exe` file in Windows Explorer
2. Select **"AHK-Hacker - Decompile"** from the context menu
3. Wait a few seconds
4. A notification will appear with the result
5. The decompiled `.ahk` file will be in the **same folder** as the .exe

### Example

```
Input:  C:\MyPrograms\MyScript.exe
Output: C:\MyPrograms\MyScript_decompiled.ahk
Log:    [AHK-Hacker folder]\log\MyScript_decompile_20250118_143052.log
```

---

## Updating Resource Hacker

Run `Update-ResourceHacker.ahk` to check for and download the latest version of Resource Hacker.

The script uses HTTP HEAD requests to check for updates without downloading the full file each time. Version information is cached in `lib\.rh_version`.

---

## Folder Structure

```
AHK-Hacker\
├── AHK-Hacker.ahk            (Main decompiler script)
├── AHK-Hacker.exe            (Compiled and signed executable)
├── Install-ContextMenu.ahk   (Installs right-click menu)
├── Uninstall-ContextMenu.ahk (Uninstalls right-click menu)
├── Update-ResourceHacker.ahk (Downloads latest Resource Hacker)
├── Install.ps1               (PowerShell installer - unblocks files)
├── RH.ico                    (Resource Hacker icon)
├── README.md                 (You're reading it...)
├── log\                      (Decompilation logs)
└── lib\
    ├── ResourceHacker.exe    (Downloaded automatically - v5.x)
    ├── ResourceHacker4.exe   (Bundled legacy version - v4.x)
    ├── .rh_version           (Version cache)
    ├── help                  (Resource Hacker documentation)
    └── samples\              (Resource Hacker samples)
```

---

## Uninstallation

### Remove Context Menu

1. Double-click `Uninstall-ContextMenu.ahk`
2. Click **OK** on the confirmation message

The context menu entry will be removed immediately.

---

## Troubleshooting

### "ResourceHacker.exe not found"

**Solution:** Run `Update-ResourceHacker.ahk` to download it.

### "Not an AutoHotkey executable"

**Cause:** The .exe file is not a compiled AutoHotkey script.

### "Failed to extract script data"

**Possible causes:**
- The file is not an AutoHotkey compiled executable
- The executable is protected/encrypted
- The executable is corrupted
- Not enough disk space

### Context menu doesn't appear

**Solutions:**
1. Run `Install-ContextMenu.ahk` again
2. Restart Windows Explorer (Task Manager → Restart "Windows Explorer")
3. Check Registry: `HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHKHacker`

### Files are blocked / Security warnings

**Solution:** Run `Install.ps1` with PowerShell - it automatically unblocks all files.

---

## Requirements

- **Windows**: 10 or later
- **AutoHotkey**: v2.0+ (for running helper scripts: Install/Uninstall-ContextMenu, Update-ResourceHacker)
- **Internet**: Required for Resource Hacker updates

---

## Technical Details

### Registry Location

```
HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker
```

### Supported AutoHotkey Versions

Works with compiled scripts from:
- AutoHotkey v1.0.x (uses Resource Hacker 4.x fallback)
- AutoHotkey v1.1.x
- AutoHotkey v2.x

---

## Credits

- **AHK-Hacker** based on [AutoHotkey Decompiler v2.97.00C by Jake (A-gent)](https://github.com/A-gent/AutoHotkey-Decompiler)
- **Resource Hacker** by Angus Johnson - http://www.angusj.com/resourcehacker/

