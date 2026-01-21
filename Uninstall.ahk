#Requires AutoHotkey v2.0
#SingleInstance Force
#Include lib/Notifications.ahk

; ====================================================================
; AHK-Hacker - Uninstallation Script
; ====================================================================
; This script performs the complete uninstallation process:
; 1. Removes context menu integration
; 2. Cleans up downloaded ResourceHacker files from bin/
; 3. Keeps ResourceHacker4.exe (bundled version)
; ====================================================================

; Show uninstallation prompt with OK/Cancel
result := MsgBox("AHK-Hacker Uninstallation`n=========================`n`nThis will:`n• Remove context menu integration`n• Delete downloaded ResourceHacker files`n• Keep ResourceHacker4.exe (bundled version)`n`nDo you want to continue?", "AHK-Hacker Uninstallation", "OKCancel Icon48")
if (result = "Cancel") {
    ExitApp(0)
}

; Get script directory
scriptDir := A_ScriptDir

; ====================================================================
; STEP 1: UNINSTALL CONTEXT MENU
; ====================================================================

ShowProgress("Removing context menu integration...", 1, "AHK-Hacker Uninstallation")

uninstallerPath := scriptDir . "\lib\Uninstall-ContextMenu.ahk"

if (FileExist(uninstallerPath)) {
    ; Run uninstaller in silent mode (no message boxes)
    ; Path is from A_ScriptDir (trusted system variable), properly quoted for spaces
    RunWait('"' . uninstallerPath . '" /silent')
    ShowProgress("Context menu removed!", 0, "AHK-Hacker Uninstallation")
} else {
    ; Uninstall-ContextMenu.ahk missing is a warning, try manual removal
    ShowProgress("Warning: lib/Uninstall-ContextMenu.ahk not found! Trying manual removal...", 2, "AHK-Hacker Uninstallation")

    ; Try to remove registry key manually
    try {
        RegDelete("HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker")
        ShowProgress("Context menu removed manually!", 0, "AHK-Hacker Uninstallation")
    } catch {
        ShowProgress("Warning: Could not remove context menu!", 2, "AHK-Hacker Uninstallation")
    }
}

Sleep(1000)

; ====================================================================
; STEP 2: CLEAN UP BIN FOLDER
; ====================================================================

ShowProgress("Cleaning up downloaded files...", 1, "AHK-Hacker Uninstallation")

binDir := scriptDir . "\bin"

if (FileExist(binDir)) {
    ; Delete downloaded ResourceHacker 5.x and related files
    try FileDelete(binDir . "\ResourceHacker.exe")
    try FileDelete(binDir . "\ResourceHacker.ini")
    try FileDelete(binDir . "\ResourceHacker.def")
    try FileDelete(binDir . "\ReadMe.txt")
    try FileDelete(binDir . "\changes.txt")
    try FileDelete(binDir . "\.rh_version")
    try FileDelete(binDir . "\resource_hacker_temp.zip")

    ; Delete Help and samples folders if they exist
    try DirDelete(binDir . "\Help", true)
    try DirDelete(binDir . "\samples", true)

    ShowProgress("Downloaded files removed!", 0, "AHK-Hacker Uninstallation")
} else {
    ShowProgress("bin/ folder not found - nothing to clean up!", 1, "AHK-Hacker Uninstallation")
}

Sleep(1000)

; ====================================================================
; STEP 3: COMPLETION
; ====================================================================

ShowProgress("Uninstallation complete!", 0, "AHK-Hacker Uninstallation")
Sleep(1000)
MsgBox("Uninstallation complete!`n`nContext menu removed and downloaded files cleaned up.`n`nNote: ResourceHacker4.exe (bundled version) and the AHK-Hacker folder are kept.`nYou can manually delete the folder if you want to remove everything.", "Success", 64)
ExitApp(0)
