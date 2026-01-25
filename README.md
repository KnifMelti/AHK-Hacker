[![Windows Sandbox](https://img.shields.io/badge/AutoHotkey-Required-orange.svg)](https://www.autohotkey.com/)
![GitHub all releases](https://img.shields.io/github/downloads/KnifMelti/AHK-Hacker/total)
<img src="https://github.com/KnifMelti/AHK-Hacker/blob/main/src/res/icon.png" alt="Icon" width="128" align="right"><br><br>

# AHK-Hacker

AutoHotkey Decompiler with Windows Context Menu Integration

## Overview

AHK-Hacker extracts source code from compiled AutoHotkey executables (.exe) by extracting the embedded RCDATA resource. Simply right-click any .exe file and select "AHK-Hacker - Decompile".

### Features

- **One-click decompilation** - Right-click context menu integration
- **Automatic file naming** - Output as `filename_decompiled.ahk`
- **Works anywhere** - Decompile files from any location
- **No admin rights needed** - Uses HKEY_CURRENT_USER registry
- **Update Resource Hacker™** - Built-in updater script
- **Automatic UPX unpacking** - Detects and unpacks UPX-compressed executables

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
- Download the latest Resource Hacker™ 5.x to `bin\` folder
- Install the context menu integration

**Done!** No administrator privileges required.

### Manual Install

If you prefer to install manually:
1. Unblock the downloaded `.zip` (right-click `.zip` → Properties → Unblock)
2. Extract the zip file
4. Run `lib\Update-ResourceHacker.ahk` to download Resource Hacker™ 5.x to `bin\` folder
5. Run `lib\Install-ContextMenu.ahk` to add the context menu

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
```

---

## Updating Resource Hacker™

Run `lib\Update-ResourceHacker.ahk` to check for and download the latest version of Resource Hacker™.

The script uses HTTP HEAD requests to check for updates without downloading the full file each time. Version information is cached in `bin\.rh_version`.

---

## Release Folder Structure

```
AHK-Hacker\
├── bin\                             (Runtime binaries)
│   ├── Help\                        (Resource Hacker™ documentation)
│   ├── mATE\                        (myAutToExe decompiler - downloaded on-demand)
│   ├── samples\                     (Resource Hacker™ samples)
│   ├── .rh_version                  (Version cache)
│   ├── changes.txt                  (Resource Hacker™ changelog)
│   ├── ReadMe.txt                   (Resource Hacker™ readme)
│   ├── ResourceHacker.exe           (Downloaded automatically - v5.x)
│   ├── ResourceHacker4.exe          (Bundled legacy version - © Angus Johnson 1999-2016)
│   └── upx.exe                      (Downloaded on-demand for unpacking)
├── lib\                             (Shared libraries)
│   ├── Install-ContextMenu.ahk      (Installs right-click menu)
│   ├── Launch-MyAutToExe.ahk        (Optional download of mATE for old AHK decompilation)
│   ├── Notifications.ahk            (Notification library)
│   ├── Uninstall-ContextMenu.ahk    (Uninstalls right-click menu)
│   ├── Unpack-Exe.ahk               (Downloads UPX unpacker for packed executables)
│   └── Update-ResourceHacker.ahk    (Downloads latest Resource Hacker™)
├── log\                             (Decompilation logs)
├── AHK-Hacker.ahk                   (Main decompiler script)
├── AHK-Hacker.exe                   (Compiled and signed executable)
├── Install.ahk                      (Installer - unblocks files etc...)
├── RH.ico                           (AHK-Hacker icon)
└── Uninstall.ahk                    (Uninstaller - removes context menu etc...)
```

---

## Uninstallation

### Recommended: Automated Uninstall

1. **Double-click `Uninstall.ahk`**
2. Click **OK** on the uninstallation prompt (or Cancel to abort)

This will automatically:
- Remove the context menu integration
- Delete downloaded Resource Hacker™ files from `bin\` folder
- Delete downloaded mATE decompiler from `bin\mATE\` folder
- Keep ResourceHacker4.exe (bundled version) under `bin\`

**Note:** The AHK-Hacker folder itself is not deleted. You can manually delete it if you want to remove everything.

### Manual Uninstall

If you prefer to uninstall manually:
1. Run `lib\Uninstall-ContextMenu.ahk` to remove the context menu
2. Manually delete the `[AHK-Hacker folder]` folder if desired

---

## Troubleshooting

### "ResourceHacker.exe not found in bin folder"

**Solution:** Run `lib\Update-ResourceHacker.ahk` to download it to the `bin\` folder.

### "Not an AutoHotkey executable"

**Cause:** The .exe file is not a compiled AutoHotkey script.

### "Failed to extract script data"

**Possible causes:**
- The file is not an AutoHotkey compiled executable
- The executable is protected/encrypted (e.g., Themida, Enigma)
- The executable is corrupted
- Not enough disk space

**Note:** UPX-packed executables are automatically detected and unpacked. If you see this error with a UPX-packed file, check the decompilation log for details.

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
- **Internet**: Required for downloading **Resource Hacker™** / **UPX** / **mATE**

---

## Technical Details

### Registry Location

```
HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker
```

### Supported AutoHotkey Versions

Works with compiled scripts from:
- AutoHotkey <= v1.0.48.5 (myAutToExe decompiler used automatically as fallback)
- AutoHotkey <= v1.1.30.0 (uses Resource Hacker™ 4.x fallback)
- AutoHotkey v1.1.37.2
- AutoHotkey v2.x

---

## Credits

- **AHK-Hacker** - based on: [AutoHotkey Decompiler v2.97.00C by Jake (A-gent)](https://github.com/A-gent/AutoHotkey-Decompiler)
- **AutoHotkey** - Powerful. Easy to learn: [The ultimate automation scripting language for Windows.](https://www.autohotkey.com/)
- **Resource Hacker™** - [...a freeware resource compiler & decompiler for Windows® applications](https://www.angusj.com/resourcehacker/)
- **UPX** - [the Ultimate Packer for eXecutables](https://upx.github.io/)
- **myAutToExe (mATE)** - [AutoIt Decompiler](https://github.com/daovantrong/myAutToExe)



