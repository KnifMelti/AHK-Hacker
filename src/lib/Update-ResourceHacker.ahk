#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Notifications.ahk

; ====================================================================
; AHK-Hacker - Resource Hacker Updater
; ====================================================================
; This script checks for and downloads the latest version of
; ResourceHacker from angusj.com using HTTP HEAD to check for updates.
;
; Usage: Run this script manually to check for Resource Hacker updates
;        Pass /silent parameter to run without notifications
; ====================================================================

; Configuration
global RH_URL := "https://www.angusj.com/resourcehacker/resource_hacker.zip"
global BinDir := A_ScriptDir . "\..\bin"
global VersionFile := BinDir . "\.rh_version"
global TempZipFile := BinDir . "\resource_hacker_temp.zip"
global ResourceHackerExe := BinDir . "\ResourceHacker.exe"
global SilentMode := false

; Check for silent mode parameter
Loop A_Args.Length {
    param := A_Args[A_Index]
    if (param = "/silent" || param = "-silent") {
        SilentMode := true
        break
    }
}

; Main execution
Main()
return

Main() {
    ; Show progress
    if (!SilentMode) {
        ShowProgress("Checking for Resource Hacker updates...", 1)
    }
    Sleep(500)

    ; Ensure bin directory exists
    if (!FileExist(BinDir)) {
        DirCreate(BinDir)
    }

    ; Get current server version info (Last-Modified header)
    serverVersion := GetServerVersion()
    if (serverVersion = "ERROR") {
        if (!SilentMode) {
            ShowProgress("Failed to check for updates.`n`nCheck your internet connection.", 3, "AHK-Hacker Error")
        }
        Sleep(3000)
        ExitApp(1)
    }

    ; Read saved version info
    savedVersion := ""
    if (FileExist(VersionFile)) {
        savedVersion := FileRead(VersionFile)
        savedVersion := Trim(savedVersion)
    }

    ; Check if ResourceHacker.exe exists
    rhExists := FileExist(ResourceHackerExe)

    ; Determine if update is needed
    needsUpdate := false
    if (!rhExists) {
        needsUpdate := true
        if (!SilentMode) {
            ShowProgress("ResourceHacker.exe not found. Downloading...", 1)
        }
    } else if (savedVersion = "") {
        needsUpdate := true
        if (!SilentMode) {
            ShowProgress("First time version check. Downloading...", 1)
        }
    } else if (serverVersion != savedVersion) {
        needsUpdate := true
        if (!SilentMode) {
            ShowProgress("New version available! Downloading...", 1)
        }
    }

    if (!needsUpdate) {
        if (!SilentMode) {
            ShowProgress("Resource Hacker is already up to date.", 1)
        }
        Sleep(3000)
        ExitApp(0)
    }

    Sleep(1000)

    ; Download and install
   if (DownloadAndInstall()) {
        ; Save version info
        if (FileExist(VersionFile)) {
            FileDelete(VersionFile)
        }
        FileAppend(serverVersion, VersionFile)

        if (!SilentMode) {
            ShowProgress("Resource Hacker updated successfully!", 0)
        }
        Sleep(3000)
        ExitApp(0)
    } else {
        if (!SilentMode) {
            ShowProgress("Failed to update Resource Hacker.", 3, "AHK-Hacker Error")
        }
        Sleep(3000)
        ExitApp(1)
    }
}

GetServerVersion() {
    ; Use WinHTTP COM object to send HEAD request
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
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
    } catch Error as e {
        return "ERROR"
    }
}

DownloadAndInstall() {
    ; Delete old temp file if exists
    if (FileExist(TempZipFile)) {
        FileDelete(TempZipFile)
    }

    ; Download ZIP file using Download function
    try {
        Download(RH_URL, TempZipFile)
        if (!FileExist(TempZipFile)) {
            return false
        }
    } catch Error as err {
        return false
    }

    ; Check file size (should be > 1MB for valid ZIP)
    zipSize := FileGetSize(TempZipFile)
    if (zipSize < 1000000) {
        FileDelete(TempZipFile)
        return false
    }

    ; Extract ZIP using PowerShell
    psCmd := "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"Expand-Archive -Path '" . TempZipFile . "' -DestinationPath '" . BinDir . "' -Force`""
    RunWait(psCmd, , "Hide")

    ; Wait for extraction to complete
    Sleep(500)

    ; Unblock all extracted files (remove "downloaded from internet" flag)
    psUnblock := "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"Get-ChildItem -Path '" . BinDir . "' -Recurse | Unblock-File`""
    RunWait(psUnblock, , "Hide")

    ; Verify extraction
    if (!FileExist(ResourceHackerExe)) {
        ; Clean up temp file
        FileDelete(TempZipFile)
        return false
    }

    ; Clean up temp file
    FileDelete(TempZipFile)

    return true
}

