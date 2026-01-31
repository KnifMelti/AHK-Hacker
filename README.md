[![Windows Sandbox](https://img.shields.io/badge/AutoHotkey-Required-orange.svg)](https://www.autohotkey.com/)
![GitHub all releases](https://img.shields.io/github/downloads/KnifMelti/AHK-Hacker/total)
<img src="https://github.com/KnifMelti/AHK-Hacker/blob/main/src/res/icon.png" alt="Icon" width="128" align="right"><br><br>

# AHK-Hacker

AutoHotkey Decompiler with Windows Context Menu Integration

## Overview

AHK-Hacker extracts source code from compiled AutoHotkey executables (.exe) by directly reading the embedded RCDATA resource via Windows LoadLibrary API. Simply right-click any .exe file and select "AHK-Hacker - Decompile".

### Features

- **One-click decompilation** - Right-click context menu integration
- **Automatic file naming** - Output as `filename_decompiled.ahk`
- **Works anywhere** - Decompile files from any location `[R/O|R/W]`
- **No admin rights needed** - Uses HKEY_CURRENT_USER registry
- **Automatic packer detection** - Detects UPX and MPRESS packers
- **Automatic UPX unpacking** - Detects and unpacks UPX-compressed executables
- **MPRESS support** - Offers mATE decompiler for MPRESS-packed files
- **No external dependencies** - Uses native Windows APIs

---

## Installation

> **Note:** AutoHotkey v2.0+ must be installed to run the helper scripts (.ahk files). Download from https://www.autohotkey.com

### Recommended: Automated Install

1. Download the latest release zip from [Releases](https://github.com/KnifMelti/AHK-Hacker/releases)
2. Extract the zip file anywhere you like
3. **Double-click `Install.ahk`**
4. Click **OK** on the installation prompt (or Cancel to abort)

This will automatically:
- Unblock all files (removes Windows security warnings)
- Install the context menu integration

**Done!** No administrator privileges or external downloads required.

### Manual Install

If you prefer to install manually:
1. Unblock the downloaded `.zip` (right-click `.zip` → Properties → Unblock)
2. Extract the zip file
3. Run `lib\Install-ContextMenu.ahk` to add the context menu

---

## Usage

### Decompiling an AutoHotkey Executable

1. **Right-click** any `.exe` file in Windows Explorer
2. Select **"AHK-Hacker - Decompile"** from the context menu
3. Wait a few seconds
4. A notification will appear with the result
5. The decompiled `.ahk` file will be in the **same folder** as the `.exe`

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
├── lib\                             (Shared libraries)
│   ├── Install-ContextMenu.ahk      (Installs right-click menu)
│   ├── Launch-MyAutToExe.ahk        (Downloads mATE for old/MPRESS AHK decompilation)
│   ├── Notifications.ahk            (Notification library)
│   ├── PE-Analysis.ahk              (PE analysis, packer detection, RCData extraction)
│   ├── Uninstall-ContextMenu.ahk    (Uninstalls right-click menu)
│   └── Unpack-Exe.ahk               (Downloads UPX unpacker for packed executables)
├── log\                             (Decompilation logs)
├── AHK-Hacker.ahk                   (Main decompiler script)
├── AHK-Hacker.exe                   (Compiled and signed executable)
├── Install.ahk                      (Installer - unblocks files etc...)
├── AH.ico                           (AHK-Hacker icon)
└── Uninstall.ahk                    (Uninstaller - removes context menu etc...)
```

---

## Uninstallation

### Recommended: Automated Uninstall

1. **Double-click `Uninstall.ahk`**
2. Click **OK** on the uninstallation prompt (or Cancel to abort)

This will automatically:
- Remove the context menu integration
- Delete downloaded UPX unpacker from `bin\` folder
- Delete downloaded mATE decompiler from `bin\mATE\` folder

**Note:** The AHK-Hacker folder, log files, and ahk output folder are not deleted. You can manually delete the folder if you want to remove everything.

### Manual Uninstall

If you prefer to uninstall manually:
1. Run `lib\Uninstall-ContextMenu.ahk` to remove the context menu
2. Manually delete the `[AHK-Hacker folder]` folder if desired

---

## Troubleshooting

### "This is not an AutoHotkey compiled executable"

**Cause:** The .exe file is not a compiled AutoHotkey script (validated via RT_MANIFEST resource).

### "Failed to extract script data"

**Possible causes:**
- The file is not an AutoHotkey compiled executable
- The executable is protected/encrypted (e.g., Themida, Enigma)
- The executable is very old (try the mATE decompiler option)
- The executable is corrupted
- Not enough disk space

**Note:** UPX-packed executables are automatically detected and unpacked. MPRESS-packed files will offer the mATE decompiler automatically.

### Context menu doesn't appear

**Solutions:**
1. Run `lib\Install-ContextMenu.ahk` again
2. Restart Windows Explorer (Task Manager → Restart "Windows Explorer")
3. Check Registry: `HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker`

### Files are blocked / Security warnings

**Solution:** Run `Install.ahk` - it automatically unblocks all files.

---

## Requirements

- **Windows**: 10 or later
- **AutoHotkey**: v2.0+ (for running helper scripts: Install/Uninstall etc...)
- **Internet**: Required for downloading **UPX** / **mATE** (only when needed)

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
- **UPX-packed**: Automatically detected and unpacked
- **MPRESS-packed**: Automatically detected, mATE decompiler offered

---

## Credits

- **AHK-Hacker** - inspired by: [AutoHotkey Decompiler v2.97.00C by Jake (A-gent)](https://github.com/A-gent/AutoHotkey-Decompiler)
- **AutoHotkey** - Powerful. Easy to learn: [The ultimate automation scripting language for Windows.](https://www.autohotkey.com/)
- **UPX** - [the Ultimate Packer for eXecutables](https://upx.github.io/)
- **myAutToExe (mATE)** - [AutoIt Decompiler](https://github.com/daovantrong/myAutToExe)









