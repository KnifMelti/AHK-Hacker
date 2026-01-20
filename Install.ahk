#Requires AutoHotkey v2.0
#SingleInstance Force

; ====================================================================
; AHK-Hacker - Installation Script
; ====================================================================
; This script performs the complete installation process:
; 1. Unblocks all files (removes Windows security warnings)
; 2. Updates ResourceHacker to the latest version
; 3. Installs the context menu integration
; ====================================================================

; Show installation banner
MsgBox("AHK-Hacker Installation`n======================`n`nThis will:`n• Unblock all files`n• Update ResourceHacker`n• Install context menu integration", "AHK-Hacker Installation", 64)

; Get script directory
scriptDir := A_ScriptDir

; ====================================================================
; STEP 1: UNBLOCK FILES
; ====================================================================

ShowProgress("Unblocking files...", 1)

; Unblock all files recursively using PowerShell
; Note: -ExecutionPolicy Bypass is required because downloaded files are marked as
; "from internet" until unblocked. This is the same approach used by Install.ps1
; and Update-ResourceHacker.ahk. The Bypass policy is only for this single command.
; Escape single quotes in path by doubling them for PowerShell
escapedScriptDir := StrReplace(scriptDir, "'", "''")
psUnblock := 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -Path ''' . escapedScriptDir . ''' -Recurse | Unblock-File -ErrorAction SilentlyContinue"'
RunWait(psUnblock, , "Hide")

ShowProgress("All files unblocked!", 2)
Sleep(1000)

; ====================================================================
; STEP 2: UPDATE RESOURCEHACKER
; ====================================================================

ShowProgress("Updating ResourceHacker...", 1)

updaterPath := scriptDir . "\Update-ResourceHacker.ahk"

if (FileExist(updaterPath)) {
    ; Run updater in silent mode (it will show TrayTips for progress)
    ; Path is from A_ScriptDir (trusted system variable), properly quoted for spaces
    RunWait('"' . updaterPath . '" /silent', , "Hide")
    ShowProgress("ResourceHacker updated!", 2)
} else {
    ; Update-ResourceHacker.ahk missing is a warning, not fatal error
    ; ResourceHacker4.exe is bundled as fallback in lib folder
    ShowProgress("Warning: Update-ResourceHacker.ahk not found!", 3)
}

Sleep(1000)

; ====================================================================
; STEP 3: INSTALL CONTEXT MENU
; ====================================================================

ShowProgress("Installing context menu integration...", 1)

installerPath := scriptDir . "\Install-ContextMenu.ahk"

if (FileExist(installerPath)) {
    ; Path is from A_ScriptDir (trusted system variable), properly quoted for spaces
    RunWait('"' . installerPath . '"')
    ShowProgress("Context menu installed!", 2)
} else {
    ; Install-ContextMenu.ahk is required - fatal error if missing
    ShowProgress("Error: Install-ContextMenu.ahk not found!", 3)
    MsgBox("Installation failed!`n`nInstall-ContextMenu.ahk not found.", "Error", 16)
    ExitApp(1)
}

Sleep(1000)

; ====================================================================
; STEP 4: COMPLETION
; ====================================================================

MsgBox("Installation complete!`n`nYou can now right-click any .exe file and select 'AHK-Hacker - Decompile'.`n`nNote: This only affects your user account.", "Success", 64)
ExitApp(0)

; ====================================================================
; HELPER FUNCTION
; ====================================================================

ShowProgress(message, iconType := 1) {
    ; Icon types match AHK 2.0 TrayTip options (consistent with rest of codebase):
    ; 1 = Info icon, 2 = Warning icon, 3 = Error icon
    TrayTip(message, "AHK-Hacker Installation", iconType)
}
