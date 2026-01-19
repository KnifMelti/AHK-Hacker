#NoEnv
#Warn
#SingleInstance Force

; ====================================================================
; AHK-Hacker - Context Menu Installer
; ====================================================================
; This script registers the decompiler in Windows context menu
; for .exe files using HKEY_CURRENT_USER (no admin rights required)
; ====================================================================

; Get script directory (where AHK-Hacker.exe is located)
scriptDir := A_ScriptDir
decompilerPath := scriptDir . "\AHK-Hacker.exe"

; Check that AHK-Hacker.exe exists
if (!FileExist(decompilerPath)) {
    MsgBox, 16, Error, AHK-Hacker.exe not found!`n`nExpected location: %decompilerPath%`n`nPlease compile AHK-Hacker.ahk first by right-clicking it and selecting "Compile Script".
    ExitApp, 1
}

; Register in registry (HKEY_CURRENT_USER - no admin required)
RegWrite, REG_SZ, HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHKHacker, , AHK-Hacker - Decompile
if (ErrorLevel) {
    MsgBox, 16, Installation Failed, Failed to write menu entry to registry!`n`nError: %ErrorLevel%
    ExitApp, 1
}

RegWrite, REG_SZ, HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHKHacker, Icon, %decompilerPath%,0
if (ErrorLevel) {
    MsgBox, 48, Warning, Menu entry created but failed to set icon.`n`nError: %ErrorLevel%
}

RegWrite, REG_SZ, HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHKHacker\command, , "%decompilerPath%" "`%1"
if (ErrorLevel) {
    MsgBox, 16, Installation Failed, Failed to write command to registry!`n`nError: %ErrorLevel%
    ExitApp, 1
}

; Success message
MsgBox, 64, Success, Context menu installed successfully!`n`nYou can now right-click any .exe file and select "AHK-Hacker - Decompile".`n`nNote: This only affects your user account.
ExitApp, 0
