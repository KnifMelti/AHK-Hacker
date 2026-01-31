#Requires AutoHotkey v2.0
#Include Notifications.ahk

; ====================================================================
; AHK-Hacker - System Informer Launcher
; ====================================================================
; This library handles System Informer installation and launching for
; MPRESS-packed executables that require manual memory dumping.
;
; Usage: #Include lib/Launch-SystemInformer.ahk
;        OfferSystemInformer(exePath, logFile)
; ====================================================================

; Global silent mode flag (set by parent script)
global SilentMode := false

/**
 * OfferSystemInformer - Shows dialog offering to launch System Informer for memory dumping
 * @param exePath - Path to the MPRESS-packed executable
 * @param logFile - Path to log file for operation logging
 * @return Object - {mpressPID: N, siPID: M} if launched, {mpressPID: 0, siPID: 0} if cancelled or failed
 */
OfferSystemInformer(exePath, logFile) {
    ; Show dialog asking if user wants to launch System Informer
    dialogText := "MPRESS-Packed Executable Detected`n`n"
    dialogText .= "This executable is MPRESS-packed and requires manual memory dumping.`n`n"
    dialogText .= "AHK-Hacker will:`n"
    dialogText .= "1. Download System Informer (if needed)`n"
    dialogText .= "2. Launch System Informer`n"
    dialogText .= "3. Start the MPRESS executable`n"
    dialogText .= "4. Guide you through memory dumping`n`n"
    dialogText .= "Press OK to continue.`n"
    dialogText .= "Press Cancel (or ESC) to exit."

    result := MsgBox(dialogText, "AHK-Hacker - MPRESS Detection", "OKCancel Icon! 48")

    if (result = "Cancel") {
        FileAppend("User cancelled System Informer offer`r`n", logFile, "UTF-8-RAW")
        return {mpressPID: 0, siPID: 0}
    }

    ; User accepted - ensure System Informer is installed
    systemInformerPath := EnsureSystemInformerInstalled(logFile)

    if (systemInformerPath = "") {
        ; Installation failed
        MsgBox("Failed to install System Informer.`n`nPlease download manually from:`nhttps://systeminformer.com/downloads", "AHK-Hacker Error", "Icon! 16")
        FileAppend("System Informer installation failed`r`n", logFile, "UTF-8-RAW")
        return {mpressPID: 0, siPID: 0}
    }

    ; Launch both System Informer and the MPRESS executable
    pids := LaunchSystemInformer(exePath, systemInformerPath, logFile)

    if (pids.mpressPID > 0) {
        FileAppend("System Informer and MPRESS exe launched successfully`r`n", logFile, "UTF-8-RAW")
    }

    return pids
}

/**
 * FindSystemInformer - Locates System Informer in known locations
 * @return String - Path to SystemInformer.exe, or "" if not found
 */
FindSystemInformer() {
    searchPaths := []

    ; Check common installation directories
    searchPaths.Push(A_ProgramFiles . "\SystemInformer\SystemInformer.exe")
    searchPaths.Push(A_ProgramFiles . "\SystemInformer\systeminformer.exe")
    searchPaths.Push(A_ProgramFiles . " (x86)\SystemInformer\SystemInformer.exe")
    searchPaths.Push(A_ProgramFiles . " (x86)\SystemInformer\systeminformer.exe")

    ; Check if it's in PATH environment variable
    try {
        ; Run where.exe to find SystemInformer in PATH
        whereCmd := 'cmd.exe /c where SystemInformer.exe 2>nul'
        whereOutput := ""
        shell := ComObject("WScript.Shell")
        exec := shell.Exec(whereCmd)
        whereOutput := exec.StdOut.ReadAll()

        if (whereOutput != "") {
            ; Take first line (first match)
            firstLine := StrSplit(whereOutput, "`n")[1]
            firstLine := Trim(firstLine, " `r`n`t")
            if (FileExist(firstLine)) {
                searchPaths.InsertAt(1, firstLine)  ; Add to front of list
            }
        }
    }

    ; Get bin directory relative to AHK-Hacker installation
    binPath := A_ScriptDir . "\bin\SystemInformer"

    ; Search for SystemInformer executables recursively in bin\SystemInformer\
    if (DirExist(binPath)) {
        searchNames := ["SystemInformer64.exe", "systeminformer64.exe",
                        "SystemInformer.exe", "systeminformer.exe",
                        "SystemInformer32.exe", "systeminformer32.exe"]

        for index, exeName in searchNames {
            Loop Files binPath . "\*", "FR"
            {
                if (A_LoopFileName = exeName) {
                    searchPaths.Push(A_LoopFileFullPath)
                    break
                }
            }
        }
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
 * EnsureSystemInformerInstalled - Checks if System Informer is installed, downloads if needed
 * @param logFile - Path to log file for operation logging
 * @return String - Path to SystemInformer.exe, or "" if installation failed
 */
EnsureSystemInformerInstalled(logFile) {
    ; First, check if System Informer is already installed on the system
    ShowProgress("Looking for System Informer...", 1, "AHK-Hacker")
    systemInformerPath := FindSystemInformer()

    if (systemInformerPath != "" && FileExist(systemInformerPath)) {
        ; Already installed (either in Program Files or bin folder)
        FileAppend("System Informer found: " . systemInformerPath . "`r`n", logFile, "UTF-8-RAW")
        return systemInformerPath
    }

    ; Not found - download and install to bin folder
    FileAppend("System Informer not found - downloading...`r`n", logFile, "UTF-8-RAW")
    return DownloadSystemInformer(logFile)
}

/**
 * DownloadSystemInformer - Downloads and installs System Informer portable to bin folder
 * @param logFile - Path to log file for operation logging
 * @return String - Path to SystemInformer.exe, or "" on failure
 */
DownloadSystemInformer(logFile) {
    ShowProgress("Downloading System Informer...", 1, "AHK-Hacker")

    binPath := A_ScriptDir . "\bin\SystemInformer"
    apiUrl := "https://api.github.com/repos/winsiderss/systeminformer/releases/latest"

    try {
        ; Get latest release info from GitHub API
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", apiUrl, false)
        whr.SetRequestHeader("User-Agent", "AHK-Hacker")
        whr.Send()

        jsonResponse := whr.ResponseText

        ; Parse browser_download_url for release-bin.zip
        if (RegExMatch(jsonResponse, '"browser_download_url"\s*:\s*"([^"]*-release-bin\.zip)"', &match)) {
            zipUrl := match[1]
        } else {
            FileAppend("Failed to find -release-bin.zip download URL from GitHub API`r`n", logFile, "UTF-8-RAW")
            ShowProgress("Failed to find System Informer download URL", 3, "AHK-Hacker Error")
            return ""
        }

        ; Extract version from URL for logging (optional)
        if (RegExMatch(zipUrl, "systeminformer-([0-9.]+)-release-bin", &verMatch)) {
            version := verMatch[1]
            FileAppend("Downloading System Informer v" . version . "...`r`n", logFile, "UTF-8-RAW")
        } else {
            FileAppend("Downloading System Informer...`r`n", logFile, "UTF-8-RAW")
        }

        tempZip := A_ScriptDir . "\bin\systeminformer_temp.zip"

        ; Ensure bin directory exists
        binDir := A_ScriptDir . "\bin"
        if (!DirExist(binDir)) {
            DirCreate(binDir)
        }

        ; Download ZIP
        try FileDelete(tempZip)
        Download(zipUrl, tempZip)

        if (!FileExist(tempZip)) {
            FileAppend("Failed to download System Informer ZIP`r`n", logFile, "UTF-8-RAW")
            ShowProgress("Download failed", 3, "AHK-Hacker Error")
            return ""
        }

        ShowProgress("Download complete, extracting files...", 1, "AHK-Hacker")

        ; Extract ZIP to temp folder
        tempExtract := binDir . "\systeminformer_temp_extract"
        if (DirExist(tempExtract)) {
            DirDelete(tempExtract, true)
        }
        DirCreate(tempExtract)

        ShowProgress("Extracting archive...", 1, "AHK-Hacker", 5000)

        psExtract := "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"Expand-Archive -Path '" . tempZip . "' -DestinationPath '" . tempExtract . "' -Force`""
        RunWait(psExtract, , "Hide")
        Sleep(500)

        ; Log extracted contents for debugging
        FileAppend("Extracted contents:`r`n", logFile, "UTF-8-RAW")
        Loop Files, tempExtract . "\*", "DR" {
            FileAppend("  " . A_LoopFileFullPath . "`r`n", logFile, "UTF-8-RAW")
        }

        ; Find SystemInformer executable recursively
        systemInformerPath := ""
        searchNames := ["SystemInformer64.exe", "systeminformer64.exe",
                        "SystemInformer.exe", "systeminformer.exe",
                        "SystemInformer32.exe", "systeminformer32.exe"]

        for index, exeName in searchNames {
            Loop Files, tempExtract . "\*", "FR" {
                if (A_LoopFileName = exeName) {
                    systemInformerPath := A_LoopFileFullPath
                    FileAppend("Found: " . systemInformerPath . "`r`n", logFile, "UTF-8-RAW")
                    break 2
                }
            }
        }

        if (systemInformerPath = "") {
            ; Cleanup and fail
            try FileDelete(tempZip)
            try DirDelete(tempExtract, true)
            FileAppend("SystemInformer executable not found in ZIP`r`n", logFile, "UTF-8-RAW")
            ShowProgress("SystemInformer.exe not found in archive", 3, "AHK-Hacker Error")
            return ""
        }

        ShowProgress("Installing System Informer to bin folder...", 1, "AHK-Hacker")

        ; Remove old installation if it exists
        if (DirExist(binPath)) {
            try DirDelete(binPath, true)
        }

        ; Move the entire extracted folder structure to bin\SystemInformer\
        ; Find the root folder of extracted content
        extractedRoot := ""
        Loop Files, tempExtract . "\*", "D" {
            extractedRoot := A_LoopFileFullPath
            break  ; Use first directory found
        }

        ; If files are directly in tempExtract (no subfolder), use tempExtract
        if (extractedRoot = "") {
            extractedRoot := tempExtract
        }

        ; Move to final location
        DirMove(extractedRoot, binPath, true)

        ShowProgress("Unblocking files...", 1, "AHK-Hacker")

        ; Unblock all files recursively
        psUnblock := "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"Get-ChildItem -Path '" . binPath . "' -Recurse | Unblock-File`""
        RunWait(psUnblock, , "Hide")

        ; Cleanup temp files
        try FileDelete(tempZip)
        try DirDelete(tempExtract, true)

        ; Find the installed exe
        finalExePath := ""
        for index, exeName in searchNames {
            Loop Files, binPath . "\*", "FR" {
                if (A_LoopFileName = exeName) {
                    finalExePath := A_LoopFileFullPath
                    break 2
                }
            }
        }

        if (finalExePath = "") {
            FileAppend("SystemInformer.exe not found after installation`r`n", logFile, "UTF-8-RAW")
            ShowProgress("Installation failed - exe not found", 3, "AHK-Hacker Error")
            return ""
        }

        ShowProgress("System Informer installed successfully", 0, "AHK-Hacker")
        FileAppend("System Informer installed to: " . finalExePath . "`r`n", logFile, "UTF-8-RAW")
        return finalExePath

    } catch Error as e {
        try FileDelete(A_ScriptDir . "\bin\systeminformer_temp.zip")
        try DirDelete(A_ScriptDir . "\bin\systeminformer_temp_extract", true)
        FileAppend("System Informer download failed: " . e.Message . "`r`n", logFile, "UTF-8-RAW")
        ShowProgress("Download error: " . e.Message, 3, "AHK-Hacker Error")
        return ""
    }
}

/**
 * LaunchSystemInformer - Launches System Informer and the MPRESS executable
 * @param exePath - Path to the MPRESS-packed executable to run
 * @param systemInformerPath - Path to SystemInformer.exe
 * @param logFile - Path to log file for operation logging
 * @return Object - {mpressPID: N, siPID: M} on success, {mpressPID: 0, siPID: 0} on failure
 */
LaunchSystemInformer(exePath, systemInformerPath, logFile) {
    ShowProgress("Launching System Informer and executable...", 1, "AHK-Hacker")

    try {
        ; Get process name from exe path for later verification
        SplitPath(exePath, &processName)

        ; Start the MPRESS executable first
        FileAppend("Starting MPRESS executable: " . exePath . "`r`n", logFile, "UTF-8-RAW")

        ; Launch directly without cmd.exe or quotes (AHK v2 handles paths with spaces)
        mpressPID := 0
        try {
            mpressPID := Run(exePath)
            FileAppend("MPRESS Run() returned PID: " . mpressPID . "`r`n", logFile, "UTF-8-RAW")
        } catch Error as e {
            FileAppend("MPRESS Run() threw error: " . e.Message . "`r`n", logFile, "UTF-8-RAW")
            mpressPID := 0
        }

        ; Wait for process to initialize
        Sleep(1000)

        ; If Run() didn't return valid PID, search for the process by name
        if (!mpressPID || !IsNumber(mpressPID) || mpressPID = 0) {
            FileAppend("Run() returned invalid PID, searching with ProcessExist...`r`n", logFile, "UTF-8-RAW")
            mpressPID := ProcessExist(processName)
            FileAppend("ProcessExist(" . processName . ") returned: " . mpressPID . "`r`n", logFile, "UTF-8-RAW")
        }

        ; Verify process is actually running
        actualPID := ProcessExist(processName)

        if (actualPID = 0) {
            ; Process not found - check if Run() gave us a valid PID that might have exited
            if (mpressPID > 0) {
                FileAppend("ERROR: Process started but immediately exited (PID was " . mpressPID . ")`r`n", logFile, "UTF-8-RAW")
                ShowProgress("Process started but immediately exited", 3, "AHK-Hacker Error")
            } else {
                FileAppend("ERROR: Failed to start process`r`n", logFile, "UTF-8-RAW")
                ShowProgress("Cannot execute file - not a valid executable", 3, "AHK-Hacker Error")
            }
            return {mpressPID: 0, siPID: 0}
        } else if (actualPID != mpressPID && mpressPID > 0) {
            FileAppend("Note: ProcessExist found different PID: " . actualPID . " (Run returned " . mpressPID . ")`r`n", logFile, "UTF-8-RAW")
            mpressPID := actualPID
        } else {
            mpressPID := actualPID
        }

        FileAppend("MPRESS exe running with PID: " . mpressPID . "`r`n", logFile, "UTF-8-RAW")

        ; Start System Informer
        FileAppend("Starting System Informer: " . systemInformerPath . "`r`n", logFile, "UTF-8-RAW")

        ; Launch directly without cmd.exe or quotes (AHK v2 handles paths with spaces)
        try {
            siPID := Run(systemInformerPath)
            FileAppend("SI Run() returned PID: " . siPID . "`r`n", logFile, "UTF-8-RAW")
        } catch Error as e {
            FileAppend("SI Run() threw error: " . e.Message . "`r`n", logFile, "UTF-8-RAW")
            siPID := 0
        }

        ; Wait for System Informer to start
        Sleep(1000)

        ; If Run() didn't return valid PID, search for the process
        if (!siPID || !IsNumber(siPID) || siPID = 0) {
            FileAppend("Run() returned invalid PID, searching with ProcessExist...`r`n", logFile, "UTF-8-RAW")
            siPID := ProcessExist("SystemInformer.exe")
            if (siPID = 0) {
                siPID := ProcessExist("SystemInformer64.exe")
            }
            if (siPID = 0) {
                siPID := ProcessExist("systeminformer.exe")
            }
        }

        FileAppend("System Informer started with PID: " . siPID . "`r`n", logFile, "UTF-8-RAW")

        ShowProgress("System Informer and executable launched", 0, "AHK-Hacker")

        return {mpressPID: actualPID, siPID: siPID}

    } catch Error as err {
        FileAppend("Launch error: " . err.Message . "`r`n", logFile, "UTF-8-RAW")
        ShowProgress("Failed to launch: " . err.Message, 3, "AHK-Hacker Error")
        return {mpressPID: 0, siPID: 0}
    }
}
