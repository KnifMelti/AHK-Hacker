#Requires AutoHotkey v2.0
#SingleInstance Force

; ====================================================================
; AHK-Hacker - Context Menu Uninstaller
; ====================================================================
; This script removes the decompiler from Windows context menu
; using HKEY_CURRENT_USER (no admin rights required)
; ====================================================================

; Check if registry key exists before attempting to delete
keyExists := false
try {
    RegRead("HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker")
    keyExists := true
}

if (!keyExists) {
    MsgBox("Context menu is not installed.`n`nNothing to uninstall.", "Not Installed", 48)
    ExitApp(0)
}

; Delete registry keys (HKEY_CURRENT_USER - no admin required)
try {
    ; Use reg.exe command for reliable deletion with /f (force) flag
    RunWait('reg.exe delete "HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker" /f', , "Hide")

    MsgBox("Context menu uninstalled successfully!`n`nThe 'AHK-Hacker - Decompile' option has been removed from the context menu.", "Success", 64)
    ExitApp(0)
} catch Error as err {
    MsgBox("Failed to remove context menu entry.`n`nError: " . err.Message, "Error", 16)
    ExitApp(1)
}
