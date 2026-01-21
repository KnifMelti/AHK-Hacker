#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Notifications.ahk

; ====================================================================
; AHK-Hacker - Context Menu Uninstaller
; ====================================================================
; This script removes the decompiler from Windows context menu
; using HKEY_CURRENT_USER (no admin rights required)
;
; Usage: Run this script manually to uninstall context menu
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

; Check if registry key exists before attempting to delete
keyExists := false
try {
    RegRead("HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker")
    keyExists := true
}

if (!keyExists) {
    if (SilentMode) {
        ; Already uninstalled is not an error in silent mode, just exit
        ExitApp(0)
    } else {
        MsgBox("Context menu is not installed.`n`nNothing to uninstall.", "Not Installed", 48)
        ExitApp(0)
    }
}

; Delete registry keys (HKEY_CURRENT_USER - no admin required)
try {
    ; Use reg.exe command for reliable deletion with /f (force) flag
    RunWait('reg.exe delete "HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker" /f', , "Hide")

    if (!SilentMode) {
        MsgBox("Context menu uninstalled successfully!`n`nThe 'AHK-Hacker - Decompile' option has been removed from the context menu.", "Success", 64)
    }
    ExitApp(0)
} catch Error as err {
    if (!SilentMode) {
        MsgBox("Failed to remove context menu entry.`n`nError: " . err.Message, "Error", 16)
    }
    ExitApp(1)
}
