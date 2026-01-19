#NoEnv
#Warn
#SingleInstance Force

; ====================================================================
; AHK-Hacker - Resource Hacker Updater
; ====================================================================
; This script checks for and downloads the latest version of
; ResourceHacker from angusj.com using HTTP HEAD to check for updates.
;
; Usage: Run this script manually to check for Resource Hacker updates
; ====================================================================

; Configuration
global RH_URL := "https://www.angusj.com/resourcehacker/resource_hacker.zip"
global LibraryDir := A_ScriptDir . "\lib"
global VersionFile := LibraryDir . "\.rh_version"
global TempZipFile := LibraryDir . "\resource_hacker_temp.zip"
global ResourceHackerExe := LibraryDir . "\ResourceHacker.exe"

; Main execution
Main()
return

Main() {
    ; Show progress
    TrayTip, AHK-Hacker, Checking for Resource Hacker updates..., 3, 1
    Sleep, 500

    ; Ensure library directory exists
    if (!FileExist(LibraryDir)) {
        FileCreateDir, %LibraryDir%
    }

    ; Get current server version info (Last-Modified header)
    serverVersion := GetServerVersion()
    if (serverVersion = "ERROR") {
        TrayTip, AHK-Hacker Error, Failed to check for updates.`nCheck your internet connection., 5, 3
        Sleep, 3000
        ExitApp, 1
    }

    ; Read saved version info
    savedVersion := ""
    if (FileExist(VersionFile)) {
        FileRead, savedVersion, %VersionFile%
        savedVersion := Trim(savedVersion)
    }

    ; Check if ResourceHacker.exe exists
    rhExists := FileExist(ResourceHackerExe)

    ; Determine if update is needed
    needsUpdate := false
    if (!rhExists) {
        needsUpdate := true
        TrayTip, AHK-Hacker, ResourceHacker.exe not found. Downloading..., 3, 1
    } else if (savedVersion = "") {
        needsUpdate := true
        TrayTip, AHK-Hacker, First time version check. Downloading..., 3, 1
    } else if (serverVersion != savedVersion) {
        needsUpdate := true
        TrayTip, AHK-Hacker, New version available! Downloading..., 3, 1
    }

    if (!needsUpdate) {
        TrayTip, AHK-Hacker, Resource Hacker is already up to date., 5, 1
        Sleep, 3000
        ExitApp, 0
    }

    Sleep, 1000

    ; Download and install
    TrayTip, AHK-Hacker, Downloading Resource Hacker..., 3, 1
    if (DownloadAndInstall()) {
        ; Save version info
        FileDelete, %VersionFile%
        FileAppend, %serverVersion%, %VersionFile%

        TrayTip, AHK-Hacker, Resource Hacker updated successfully!, 5, 1
        Sleep, 3000
        ExitApp, 0
    } else {
        TrayTip, AHK-Hacker Error, Failed to update Resource Hacker., 5, 3
        Sleep, 3000
        ExitApp, 1
    }
}

GetServerVersion() {
    ; Use WinHTTP COM object to send HEAD request
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("HEAD", RH_URL, false)
        whr.Send()

        ; Try to get Last-Modified header
        try {
            lastMod := whr.GetResponseHeader("Last-Modified")
            if (lastMod != "")
                return lastMod
        }

        ; Try ETag as fallback
        try {
            etag := whr.GetResponseHeader("ETag")
            if (etag != "")
                return etag
        }

        ; Use Content-Length as last resort
        try {
            contentLen := whr.GetResponseHeader("Content-Length")
            if (contentLen != "")
                return contentLen
        }

        ; If we got here but request succeeded, use current date
        return A_Now
    } catch e {
        return "ERROR"
    }
}

DownloadAndInstall() {
    ; Delete old temp file if exists
    if (FileExist(TempZipFile)) {
        FileDelete, %TempZipFile%
    }

    ; Download ZIP file using UrlDownloadToFile
    UrlDownloadToFile, %RH_URL%, %TempZipFile%
    if (ErrorLevel || !FileExist(TempZipFile)) {
        return false
    }

    ; Check file size (should be > 1MB for valid ZIP)
    FileGetSize, zipSize, %TempZipFile%
    if (zipSize < 1000000) {
        FileDelete, %TempZipFile%
        return false
    }

    ; Extract ZIP using PowerShell
    psCmd := "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ""Expand-Archive -Path '" . TempZipFile . "' -DestinationPath '" . LibraryDir . "' -Force"""
    RunWait, %psCmd%, , Hide

    ; Wait for extraction to complete
    Sleep, 500

    ; Unblock all extracted files (remove "downloaded from internet" flag)
    psUnblock := "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ""Get-ChildItem -Path '" . LibraryDir . "' -Recurse | Unblock-File"""
    RunWait, %psUnblock%, , Hide

    ; Verify extraction
    if (!FileExist(ResourceHackerExe)) {
        ; Clean up temp file
        FileDelete, %TempZipFile%
        return false
    }

    ; Clean up temp file
    FileDelete, %TempZipFile%

    return true
}
