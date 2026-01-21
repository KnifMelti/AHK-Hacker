#Requires AutoHotkey v2.0
#SingleInstance Force
#Include lib/Notifications.ahk

; ====================================================================
; AHK-Hacker - Context Menu Installer
; ====================================================================
; This script registers the decompiler in Windows context menu
; for .exe files using HKEY_CURRENT_USER (no admin rights required)
;
; Usage: Run this script manually to install context menu
;        Pass /silent parameter to run without message boxes
; ====================================================================

; Configuration
global SilentMode := false

; Check for silent mode parameter
Loop A_Args.Length {
    param := A_Args[A_Index]
    if (param = "/silent" || param = "-silent") {
        SilentMode := true
        break
    }
}

; Get script directory (where AHK-Hacker.exe is located)
scriptDir := A_ScriptDir
decompilerPath := scriptDir . "\AHK-Hacker.exe"

; Check that AHK-Hacker.exe exists
if (!FileExist(decompilerPath)) {
    if (SilentMode) {
        ShowProgress("AHK-Hacker.exe not found!", 3, "AHK-Hacker")
        Sleep(3000)
    } else {
        MsgBox("AHK-Hacker.exe not found!`n`nExpected location: " . decompilerPath . "`n`nPlease compile AHK-Hacker.ahk first by right-clicking it and selecting 'Compile Script'.", "Error", 16)
    }
    ExitApp(1)
}

; Check if already installed
try {
    existingValue := RegRead("HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker")
    if (SilentMode) {
        ; Already installed is not an error in silent mode, just continue
        ExitApp(0)
    } else {
        MsgBox("Context menu is already installed!`n`nTo reinstall, run Uninstall-ContextMenu.ahk first.", "Already Installed", 48)
        ExitApp(0)
    }
}

; Register in registry (HKEY_CURRENT_USER - no admin required)
try {
    RegWrite("AHK-Hacker - Decompile", "REG_SZ", "HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker")
} catch Error as err {
    if (SilentMode) {
        ShowProgress("Failed to write menu entry to registry!", 3, "AHK-Hacker")
        Sleep(3000)
    } else {
        MsgBox("Failed to write menu entry to registry!`n`nError: " . err.Message, "Installation Failed", 16)
    }
    ExitApp(1)
}

try {
    RegWrite(decompilerPath . ",0", "REG_SZ", "HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker", "Icon")
} catch Error as err {
    if (SilentMode) {
        ShowProgress("Menu entry created but failed to set icon.", 2, "AHK-Hacker")
        Sleep(2000)
    } else {
        MsgBox("Menu entry created but failed to set icon.`n`nError: " . err.Message, "Warning", 48)
    }
}

try {
    RegWrite('"' . decompilerPath . '" "%1"', "REG_SZ", "HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker\command")
} catch Error as err {
    if (SilentMode) {
        ShowProgress("Failed to write command to registry!", 3, "AHK-Hacker")
        Sleep(3000)
    } else {
        MsgBox("Failed to write command to registry!`n`nError: " . err.Message, "Installation Failed", 16)
    }
    ExitApp(1)
}

; Success message
if (SilentMode) {
    ShowProgress("Context menu installed successfully!", 0, "AHK-Hacker")
    Sleep(2000)
} else {
    MsgBox("Context menu installed successfully!`n`nYou can now right-click any .exe file and select 'AHK-Hacker - Decompile'.`n`nNote: This only affects your user account.", "Success", 64)
}
ExitApp(0)
