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

> **Note:** AutoHotkey v1.1+ must be installed to run the helper scripts (.ahk files). Download from https://www.autohotkey.com

### Step 1: Download Resource Hacker

1. Run `Update-ResourceHacker.ahk`
2. Wait for download and extraction to complete
3. ResourceHacker.exe will be placed in the `lib\` folder

### Step 2: Install Context Menu

1. Double-click `Install-ContextMenu.ahk`
2. Click **OK** on the success message

**Done!** No administrator privileges required.

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
├── AHK-Hacker.ahk           (Main decompiler script)
├── AHK-Hacker.exe           (Compiled and signed executable)
├── Install-ContextMenu.ahk  (Installs right-click menu)
├── Uninstall-ContextMenu.ahk
├── Update-ResourceHacker.ahk
├── Icon.ico
├── README.md
├── log\                    (Decompilation logs)
└── lib\
    ├── ResourceHacker.exe   (Downloaded automatically - v5.x)
    ├── ResourceHacker4.exe  (Bundled legacy version - v4.x)
    ├── .rh_version          (Version cache)
    └── Help\                (ResourceHacker documentation)
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

---

## Requirements

- **Windows**: 10 or later
- **AutoHotkey**: v1.1+ (for running helper scripts: Install/Uninstall-ContextMenu, Update-ResourceHacker)
- **Internet**: Required for Resource Hacker updates

---

## Technical Details

### Registry Location

```
HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHKHacker
```

### Supported AutoHotkey Versions

Works with compiled scripts from:
- AutoHotkey v1.0.x (uses ResourceHacker 4.x fallback)
- AutoHotkey v1.1.x
- AutoHotkey v2.x

---

## Credits

- **AHK-Hacker** based on AutoHotkey Decompiler v2.97.00C by Jake (A-gent)
- **ResourceHacker** by Angus Johnson - http://www.angusj.com/resourcehacker/
