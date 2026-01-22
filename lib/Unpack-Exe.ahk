#Requires AutoHotkey v2.0
#Include Notifications.ahk

; ====================================================================
; AHK-Hacker - Executable Unpacker (UPX only)
; ====================================================================
; This library attempts to unpack UPX-compressed executables.
;
; Usage: #Include lib/Unpack-Exe.ahk
;        unpackedPath := TryUnpackExe(exePath, logFile)
; ====================================================================

; Global silent mode flag (set by parent script)
global SilentMode := false

/**
 * TryUnpackExe - Attempts to unpack a UPX-compressed executable
 * @param exePath - Path to the packed executable
 * @param logFile - Path to log file for appending unpacking logs
 * @return String - Path to unpacked temp file on success, "" on failure
 */
TryUnpackExe(exePath, logFile) {
    ; Generate temporary output path for unpacked exe
    SplitPath(exePath, &fileName, &fileDir)
    timestamp := A_Now
    unpackedPath := fileDir . "\" . fileName . ".unpacked." . timestamp . ".tmp"

    ; Append to log
    FileAppend("`n===== UNPACKING ATTEMPT (UPX) =====`n", logFile, "UTF-8-RAW")
    FileAppend("Original file: " . exePath . "`n", logFile, "UTF-8-RAW")

    ; Find or download UPX
    ShowProgress("Looking for UPX unpacker...", 1, "AHK-Hacker")
    upxPath := FindUpx()

    if (upxPath = "") {
        FileAppend("UPX not found - downloading...`n", logFile, "UTF-8-RAW")
        ShowProgress("Downloading UPX unpacker...", 1, "AHK-Hacker")
        upxPath := DownloadUpx(logFile)

        if (upxPath = "") {
            FileAppend("Failed to download UPX`n", logFile, "UTF-8-RAW")
            return ""
        }
    }

    FileAppend("Using UPX: " . upxPath . "`n", logFile, "UTF-8-RAW")

    ; Run UPX unpacker
    ShowProgress("Unpacking with UPX...", 1, "AHK-Hacker")

    ; UPX syntax: upx -d -o output.exe input.exe
    cmd := '"' . upxPath . '" -d -o "' . unpackedPath . '" "' . exePath . '"'    

    FileAppend("Running UPX: " . cmd . "`n", logFile, "UTF-8-RAW")

    try {
        RunWait(cmd, , "Hide")
        Sleep(200)

        ; Check if output file was created
        if (FileExist(unpackedPath)) {
            ; Verify it's a valid PE file (starts with MZ)
            fileObj := FileOpen(unpackedPath, "r")
            magic := fileObj.Read(2)
            fileObj.Close()

            if (magic = "MZ") {
                FileAppend("UPX unpacking succeeded`n", logFile, "UTF-8-RAW")
                ShowProgress("Successfully unpacked with UPX", 0, "AHK-Hacker")
                return unpackedPath
            } else {
                try FileDelete(unpackedPath)
                FileAppend("UPX unpacking failed - invalid PE file`n", logFile, "UTF-8-RAW")
            }
        } else {
            FileAppend("UPX unpacking failed - no output file`n", logFile, "UTF-8-RAW")
        }
    } catch Error as e {
        try FileDelete(unpackedPath)
        FileAppend("UPX unpacking failed with error: " . e.Message . "`n", logFile, "UTF-8-RAW")
    }

    return ""
}

/**
 * FindUpx - Locates UPX in known locations
 * @return String - Path to upx.exe, or "" if not found
 */
FindUpx() {
    searchPaths := []

    ; Check AutoHotkey Compiler directory
    searchPaths.Push(A_ProgramFiles . "\AutoHotkey\Compiler\upx.exe")

    ; Get bin directory relative to AHK-Hacker.exe location
    try {
        registryPath := RegRead("HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker\command")
        registryPath := StrReplace(registryPath, '"', '')
        registryPath := Trim(StrSplit(registryPath, " ")[1])
        SplitPath(registryPath, , &installDir)
        searchPaths.Push(installDir . "\bin\upx.exe")
    } catch {
        SplitPath(A_ScriptFullPath, , &exeDir)
        searchPaths.Push(exeDir . "\..\bin\upx.exe")
    }

    ; Check each location
    for index, path in searchPaths {
        if (FileExist(path)) {
            return path
        }
    }

    return ""
}

/**
 * DownloadUpx - Downloads UPX from GitHub releases
 * @param logFile - Path to log file
 * @return String - Path to downloaded upx.exe, or "" on failure
 */
DownloadUpx(logFile) {
    ; Get bin directory
    binDir := ""
    try {
        registryPath := RegRead("HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker\command")
        registryPath := StrReplace(registryPath, '"', '')
        registryPath := Trim(StrSplit(registryPath, " ")[1])
        SplitPath(registryPath, , &installDir)
        binDir := installDir . "\bin"
    } catch {
        SplitPath(A_ScriptFullPath, , &exeDir)
        binDir := exeDir . "\..\bin"
    }

    ; Ensure bin directory exists
    if (!FileExist(binDir)) {
        DirCreate(binDir)
    }

    ; Get latest UPX version from GitHub API
    apiUrl := "https://api.github.com/repos/upx/upx/releases/latest"

    try {
        ; Download JSON response
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", apiUrl, false)
        whr.SetRequestHeader("User-Agent", "AHK-Hacker")
        whr.Send()

        jsonResponse := whr.ResponseText

        ; Parse browser_download_url for win64 zip
        if (RegExMatch(jsonResponse, '"browser_download_url"\s*:\s*"([^"]*win64\.zip)"', &match)) {
            zipUrl := match[1]
        } else {
            FileAppend("Failed to find win64.zip download URL from GitHub API`n", logFile, "UTF-8-RAW")
            return ""
        }

        ; Extract version from URL for logging (optional)
        if (RegExMatch(zipUrl, "upx-([0-9.]+)-win64", &verMatch)) {
            version := verMatch[1]
            FileAppend("Downloading UPX v" . version . "...`n", logFile, "UTF-8-RAW")
        } else {
            FileAppend("Downloading UPX...`n", logFile, "UTF-8-RAW")
        }

        tempZip := binDir . "\upx_temp.zip"

        ; Download ZIP
        Download(zipUrl, tempZip)
        if (!FileExist(tempZip)) {
            FileAppend("Failed to download UPX ZIP`n", logFile, "UTF-8-RAW")
            return ""
        }

        ; Extract ZIP to temp folder
        tempExtract := binDir . "\upx_temp_extract"
        if (FileExist(tempExtract)) {
            DirDelete(tempExtract, true)
        }
        DirCreate(tempExtract)

        psExtract := "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"Expand-Archive -Path '" . tempZip . "' -DestinationPath '" . tempExtract . "' -Force`""
        RunWait(psExtract, , "Hide")
        Sleep(500)

        ; Log extracted contents for debugging
        FileAppend("Extracted contents:`n", logFile, "UTF-8-RAW")
        Loop Files, tempExtract . "\*", "DR" {
            FileAppend("  " . A_LoopFileFullPath . "`n", logFile, "UTF-8-RAW")
        }

        ; Find upx.exe recursively
        upxExePath := ""
        Loop Files, tempExtract . "\*", "FR" {
            if (A_LoopFileName = "upx.exe") {
                upxExePath := A_LoopFileFullPath
                break
            }
        }

        if (upxExePath = "") {
            ; Cleanup and fail
            try FileDelete(tempZip)
            try DirDelete(tempExtract, true)
            FileAppend("UPX executable not found in ZIP`n", logFile, "UTF-8-RAW")
            return ""
        }

        ; Copy to bin folder
        finalPath := binDir . "\upx.exe"
        FileCopy(upxExePath, finalPath, true)

        ; Unblock file
        psUnblock := "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"Unblock-File -Path '" . finalPath . "'`""
        RunWait(psUnblock, , "Hide")

        ; Cleanup
        try FileDelete(tempZip)
        try DirDelete(tempExtract, true)

        FileAppend("UPX downloaded successfully to: " . finalPath . "`n", logFile, "UTF-8-RAW")
        return finalPath

    } catch Error as e {
        try FileDelete(binDir . "\upx_temp.zip")
        try DirDelete(binDir . "\upx_temp_extract", true)
        FileAppend("UPX download failed: " . e.Message . "`n", logFile, "UTF-8-RAW")
        return ""
    }
}
