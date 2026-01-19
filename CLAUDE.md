# AHK-Hacker

AutoHotkey decompiler with Windows context menu integration.

## Project Overview

AHK-Hacker extracts source code from compiled AutoHotkey executables (.exe) by extracting the embedded RCDATA resource using ResourceHacker. It integrates with the Windows right-click context menu for one-click decompilation.

## Tech Stack

- **Language**: AutoHotkey v1.1
- **External Tool**: ResourceHacker (downloaded automatically)
- **Platform**: Windows 10+

## File Structure

```
AHK-Hacker/
├── AHK-Hacker.ahk           # Main decompiler script
├── AHK-Hacker.exe           # Compiled and signed executable
├── Install-ContextMenu.ahk  # Registers right-click menu in registry
├── Uninstall-ContextMenu.ahk# Removes right-click menu
├── Update-ResourceHacker.ahk# Downloads/updates ResourceHacker
├── Icon.ico                 # Application icon
├── README.md                # User documentation
├── CLAUDE.md                # This file
├── log/                     # Decompilation logs
└── lib/
    ├── ResourceHacker.exe   # Downloaded by Update-ResourceHacker.ahk (v5.x)
    ├── ResourceHacker4.exe  # Bundled legacy version (v4.x) for older AHK formats
    ├── .rh_version          # Version cache (Last-Modified header)
    └── Help/                # ResourceHacker documentation
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

### Update-ResourceHacker.ahk
Updater that:
1. Sends HTTP HEAD request to check Last-Modified header
2. Compares with cached `.rh_version` file
3. Downloads ZIP only if newer version available
4. Extracts and unblocks files (removes "downloaded from internet" flag)

### Install/Uninstall-ContextMenu.ahk
Registry scripts that add/remove context menu entry at:
```
HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHKHacker
```
No admin rights required.

## Development Notes

### ResourceHacker Compatibility
- **ResourceHacker 5.x**: Latest version, downloaded by Update-ResourceHacker.ahk. Output naming: `RCDATA1_1.bin`
- **ResourceHacker 4.x**: Bundled legacy version (`ResourceHacker4.exe`). Required for older AHK executables that use `>AHK WITH ICON<` resource naming. Output naming: `RCData.bin`

The decompiler tries 5.x first, then falls back to 4.x automatically.

### Building
`AHK-Hacker.exe` is pre-compiled and digitally signed. The source `AHK-Hacker.ahk` is included for reference.

### Testing
1. Run `Update-ResourceHacker.ahk` to download ResourceHacker 5.x
2. Run `Install-ContextMenu.ahk`
3. Right-click any AHK-compiled .exe and select "AHK-Hacker - Decompile"

## Common Issues

- **"ResourceHacker.exe not found"**: Run `Update-ResourceHacker.ahk` (note: `ResourceHacker4.exe` is bundled and should always be present)
- **"Failed to extract script data"**: The .exe is not an AHK executable or uses encryption
- **Context menu missing**: Run `Install-ContextMenu.ahk`, restart Explorer if needed
