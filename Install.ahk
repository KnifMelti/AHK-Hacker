#Requires AutoHotkey v2.0
#SingleInstance Force
#Include lib/Notifications.ahk

; ====================================================================
; AHK-Hacker - Installation Script
; ====================================================================
; This script performs the complete installation process:
; 1. Unblocks all files (removes Windows security warnings)
; 2. Updates ResourceHacker to the latest version
; 3. Installs the context menu integration
; ====================================================================

; Show installation prompt with OK/Cancel
result := MsgBox("AHK-Hacker Installation`n======================`n`nThis will:`n• Unblock all files`n• Update ResourceHacker`n• Install context menu integration`n`nDo you want to continue?", "AHK-Hacker Installation", "OKCancel 64")
if (result = "Cancel") {
    ExitApp(0)
}

; Get script directory
scriptDir := A_ScriptDir

; ====================================================================
; STEP 1: UNBLOCK FILES
; ====================================================================

; Unblock all files recursively using PowerShell
; Note: -ExecutionPolicy Bypass is required because downloaded files are marked as
; "from internet" until unblocked. The Bypass policy is only for this single command.
; Escape single quotes in path by doubling them for PowerShell
escapedScriptDir := StrReplace(scriptDir, "'", "''")
psUnblock := "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"Get-ChildItem -Path '" . escapedScriptDir . "' -Recurse | Unblock-File -ErrorAction SilentlyContinue`""
RunWait(psUnblock, , "Hide")

; ====================================================================
; STEP 2: UPDATE RESOURCEHACKER
; ====================================================================

updaterPath := scriptDir . "\lib\Update-ResourceHacker.ahk"

if (FileExist(updaterPath)) {
    ; Run updater in silent mode
    ; Path is from A_ScriptDir (trusted system variable), properly quoted for spaces
    RunWait('"' . updaterPath . '" /silent', , "Hide")
} else {
    ; Update-ResourceHacker.ahk missing is a warning, not fatal error
    ; ResourceHacker4.exe is bundled as fallback in bin folder
}

; ====================================================================
; STEP 3: INSTALL CONTEXT MENU
; ====================================================================

installerPath := scriptDir . "\lib\Install-ContextMenu.ahk"

if (FileExist(installerPath)) {
    ; Path is from A_ScriptDir (trusted system variable), properly quoted for spaces
    exitCode := RunWait('"' . installerPath . '" /silent')
    if (exitCode != 0) {
        MsgBox("Installation failed!`n`nCould not install context menu integration.", "Error", 16)
        ExitApp(1)
    }
} else {
    ; Install-ContextMenu.ahk is required - fatal error if missing
    MsgBox("Installation failed!`n`nlib/Install-ContextMenu.ahk not found.", "Error", 16)
    ExitApp(1)
}

; ====================================================================
; STEP 4: COMPLETION
; ====================================================================

MsgBox("Installation complete!`n`nYou can now right-click any .exe file and select 'AHK-Hacker - Decompile'.`n`nNote: This only affects your user account.", "Success", 64)
ExitApp(0)
