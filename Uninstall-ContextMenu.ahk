#NoEnv
#Warn
#SingleInstance Force

; ====================================================================
; AHK-Hacker - Context Menu Uninstaller
; ====================================================================
; This script removes the decompiler from Windows context menu
; using HKEY_CURRENT_USER (no admin rights required)
; ====================================================================

; Delete registry keys (HKEY_CURRENT_USER - no admin required)
RegDelete, HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHKHacker

if (ErrorLevel) {
    MsgBox, 48, Notice, Context menu entry not found or already removed.`n`nError: %ErrorLevel%
    ExitApp, 1
} else {
    MsgBox, 64, Success, Context menu uninstalled successfully!`n`nThe "AHK-Hacker - Decompile" option has been removed from the context menu.
    ExitApp, 0
}
