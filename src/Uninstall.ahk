#Requires AutoHotkey v2.0
#SingleInstance Force
#Include lib/Notifications.ahk

; ====================================================================
; AHK-Hacker - Uninstallation Script
; ====================================================================
; This script performs the complete uninstallation process:
; 1. Removes context menu integration
; 2. Cleans up downloaded files from bin/ (UPX, mATE)
; ====================================================================

; Show uninstallation prompt with OK/Cancel
result := MsgBox("AHK-Hacker Uninstallation`n=========================`n`nThis will:`n• Remove context menu integration`n• Delete downloaded UPX unpacker`n• Delete downloaded mATE decompiler`n• Delete downloaded System Informer`n• Keep log files and ahk output folder`n`nDo you want to continue?", "AHK-Hacker Uninstallation", "OKCancel 48")
if (result = "Cancel") {
    ExitApp(0)
}

; Get script directory
scriptDir := A_ScriptDir

; ====================================================================
; STEP 1: UNINSTALL CONTEXT MENU
; ====================================================================

uninstallerPath := scriptDir . "\lib\Uninstall-ContextMenu.ahk"

if (FileExist(uninstallerPath)) {
    ; Run uninstaller in silent mode (no message boxes)
    ; Path is from A_ScriptDir (trusted system variable), properly quoted for spaces
    exitCode := RunWait('"' . uninstallerPath . '" /silent')
    if (exitCode != 0) {
        MsgBox("Uninstallation warning!`n`nCould not remove context menu entry.", "Warning", 48)
    }
} else {
    ; Uninstall-ContextMenu.ahk missing is a warning, try manual removal
    try {
        RegDelete("HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker")
    }
}

; ====================================================================
; STEP 2: CLEAN UP BIN FOLDER
; ====================================================================

binDir := scriptDir . "\bin"

if (FileExist(binDir)) {
    ; Delete downloaded UPX unpacker
    try FileDelete(binDir . "\upx.exe")

    ; Clean up any leftover UPX temp files
    try FileDelete(binDir . "\upx_temp.zip")
    try DirDelete(binDir . "\upx_temp_extract", true)

    ; Delete downloaded mATE decompiler
    try DirDelete(binDir . "\mATE", true)

    ; Delete downloaded System Informer
    try DirDelete(binDir . "\SystemInformer", true)

    ; Clean up any leftover System Informer temp files
    try FileDelete(binDir . "\systeminformer_temp.zip")
    try DirDelete(binDir . "\systeminformer_temp_extract", true)
}

; ====================================================================
; STEP 3: COMPLETION
; ====================================================================

MsgBox("Uninstallation complete!`n`nContext menu removed and downloaded files cleaned up.`n`nNote: Log files, ahk output folder, and the AHK-Hacker folder are kept.`nYou can manually delete the folder if you want to remove everything.", "Success", 64)
ExitApp(0)
