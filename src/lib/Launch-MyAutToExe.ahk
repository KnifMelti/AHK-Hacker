#Requires AutoHotkey v2.0
#Include Notifications.ahk

; ====================================================================
; AHK-Hacker - myAutToExe Launcher
; ====================================================================
; This library handles myAutToExe installation and launching for
; very old AutoHotkey executables (v1.0.48.5 and earlier).
;
; Usage: #Include lib/Launch-MyAutToExe.ahk
;        OfferMyAutToExe(exePath)
; ====================================================================

; Global silent mode flag (set by parent script)
global SilentMode := false

/**
 * OfferMyAutToExe - Shows dialog offering to try myAutToExe decompilation
 * @param exePath - Path to the AHK executable that failed automatic decompilation
 * @param writableDir - Optional writable directory to copy exe to if source is read-only
 * @return bool - True if monitoring mATE (caller should not exit), False otherwise
 */
OfferMyAutToExe(exePath, writableDir := "") {
    ; Show dialog asking if user wants to try myAutToExe
    result := MsgBox("Failed to decompile automatically.`n`nThis may be a very old AutoHotkey executable (v1.0.48.5 or earlier).`n`nWould you like to try myAutToExe decompiler?", "AHK-Hacker", "YesNo Icon! 48")

    if (result = "No") {
        ; User declined - exit
        return false
    }

    ; User wants to try myAutToExe - ensure it's installed
    myAutToExePath := EnsureMyAutToExeInstalled()

    if (myAutToExePath = "") {
        ; Installation failed
        MsgBox("Failed to install myAutToExe.`n`nPlease download manually from:`nhttps://github.com/daovantrong/myAutToExe/releases/latest", "AHK-Hacker Error", "Icon! 16")
        return false
    }

    ; Determine working exe path based on directory writability
    workingExePath := exePath
    usedFallbackLocation := false

    if (writableDir != "") {
        ; Source directory is read-only - copy exe to writable location
        SplitPath(exePath, , , , &fileNameNoExt)
        timestamp := A_Now
        ; Use short temp name to avoid long output filenames from mATE
        workingExePath := writableDir . "\temp_" . timestamp . ".exe"

        try {
            ShowProgress("Copying executable to writable location...", 1, "AHK-Hacker")
            FileCopy(exePath, workingExePath, true)

            ; Verify copy succeeded and file is not empty
            if (!FileExist(workingExePath)) {
                MsgBox("Failed to copy executable: File does not exist after copy", "AHK-Hacker Error", "Icon! 16")
                return false
            }

            ; Check file size to ensure it's not empty
            originalSize := FileGetSize(exePath)
            copiedSize := FileGetSize(workingExePath)

            if (copiedSize = 0) {
                MsgBox("Failed to copy executable: Copied file is empty (0 bytes)", "AHK-Hacker Error", "Icon! 16")
                try FileDelete(workingExePath)
                return false
            }

            if (copiedSize != originalSize) {
                MsgBox("Failed to copy executable: File size mismatch`n`nOriginal: " . originalSize . " bytes`nCopied: " . copiedSize . " bytes", "AHK-Hacker Error", "Icon! 16")
                try FileDelete(workingExePath)
                return false
            }

            usedFallbackLocation := true
        } catch Error as err {
            MsgBox("Failed to copy executable to writable location:`n`n" . err.Message, "AHK-Hacker Error", "Icon! 16")
            return false
        }
    }

    ; Determine output path (same directory as working exe, with _decompiled.ahk)
    SplitPath(workingExePath, &fileName, &workingFileDir, &fileExt, &fileNameNoExt)
    outputPath := workingFileDir . "\" . fileNameNoExt . "_decompiled.ahk"

    ; Notify user if using fallback location
    if (usedFallbackLocation) {
        ShowProgress("Output will be saved to: " . workingFileDir, 1, "AHK-Hacker", 3000)
    }

    ; Get working directory (where myAutToExe.exe is located)
    SplitPath(myAutToExePath, , &myAutToExeDir)

    ; Launch myAutToExe GUI for manual decompilation
    try {
        ; Launch myAutToExe GUI with the executable loaded
        ; Set working directory to myAutToExe folder so it can find Data folder
        PID := Run('"' . myAutToExePath . '" "' . workingExePath . '"', myAutToExeDir)

        ; If copied exe exists, wait for mATE to close, then cleanup
        if (usedFallbackLocation && workingExePath != exePath) {
            ; Wait for mATE window to appear before we start waiting for close
            ; mATE spawns a subprocess, so the original PID becomes invalid
            Sleep(1000)

            ; Wait for any myAutToExe process to close (not using PID since it spawns subprocesses)
            ; We'll poll for the window title instead
            Loop {
                ; Check if any myAut2Exe window exists
                if (!WinExist("myAut2Exe")) {
                    ; No mATE window found - either hasn't started yet or already closed
                    Sleep(1000)
                    ; Check again
                    if (!WinExist("myAut2Exe")) {
                        ; Still no window - mATE is done
                        break
                    }
                } else {
                    ; Window exists - wait for it to close
                    WinWaitClose("myAut2Exe")
                    break
                }
            }

            ; mATE has closed normally - cleanup temp file and rename output
            try {
                ; Find the decompiled .ahk file that mATE created
                SplitPath(workingExePath, , , , &tempFileNameNoExt)
                tempAhkFile := workingFileDir . "\" . tempFileNameNoExt . ".ahk"

                ; Determine proper output name based on original exe
                SplitPath(exePath, , , , &originalNameNoExt)
                finalAhkFile := workingFileDir . "\" . originalNameNoExt . "_decompiled.ahk"

                ; Rename if temp ahk file exists
                if (FileExist(tempAhkFile)) {
                    FileMove(tempAhkFile, finalAhkFile, true)
                }

                ; Delete temp exe file
                if (FileExist(workingExePath)) {
                    FileDelete(workingExePath)
                }

                ; Also clean up any log files with temp name
                tempLogFile := workingFileDir . "\" . tempFileNameNoExt . "_myExeToAut.log"
                if (FileExist(tempLogFile)) {
                    finalLogFile := workingFileDir . "\" . originalNameNoExt . "_myExeToAut.log"
                    FileMove(tempLogFile, finalLogFile, true)
                }
            }

            ; Open Explorer to show where decompiled file was saved
            try {
                Run('explorer.exe "' . workingFileDir . '"')
            }

            ; Return true to indicate caller should not exit (we already handled everything)
            return true
        }

        ; Not using fallback - return false (caller can exit normally)
        return false

    } catch Error as err {
        MsgBox("Failed to launch myAutToExe:`n`n" . err.Message, "AHK-Hacker Error", "Icon! 16")
        ; Clean up copied exe if it exists
        if (usedFallbackLocation) {
            try FileDelete(workingExePath)
        }
        return false
    }
}

/**
 * EnsureMyAutToExeInstalled - Checks if myAutToExe is installed, downloads if needed
 * @return String - Path to myAutToExe.exe, or "" if installation failed
 */
EnsureMyAutToExeInstalled() {
    ; Check if myAutToExe is already installed to bin folder
    binPath := A_ScriptDir . "\bin\mATE"

    ; Search for myAutToExe.exe in the installation folder
    myAutToExePath := ""
    if (DirExist(binPath)) {
        ; Look for myAutToExe.exe recursively in bin\mATE\
        Loop Files binPath . "\*", "FR"
        {
            if (A_LoopFileName = "myAutToExe.exe") {
                myAutToExePath := A_LoopFileFullPath
                break
            }
        }
    }

    if (myAutToExePath != "" && FileExist(myAutToExePath)) {
        ; Already installed
        return myAutToExePath
    }

    ; Not installed - download and install
    ShowProgress("Looking for myAutToExe decompiler...", 1, "AHK-Hacker")
    return DownloadMyAutToExe()
}

/**
 * DownloadMyAutToExe - Downloads and installs myAutToExe to bin folder
 * @return String - Path to myAutToExe.exe, or "" on failure
 */
DownloadMyAutToExe() {
    ShowProgress("Downloading myAutToExe decompiler...", 1, "AHK-Hacker")

    binPath := A_ScriptDir . "\bin\mATE"
    downloadUrl := "https://github.com/KnifMelti/SandboxStart/raw/master/Source/assets/mATE.zip"

    try {
        ; Download ZIP file to temp location
        tempZip := A_Temp . "\mATE_temp.zip"
        try FileDelete(tempZip)

        Download(downloadUrl, tempZip)

        if (!FileExist(tempZip)) {
            ShowProgress("Failed to download myAutToExe", 3, "AHK-Hacker Error")
            return ""
        }

        ShowProgress("Download complete, extracting files...", 1, "AHK-Hacker")

        ; Remove old installation if it exists
        if (DirExist(binPath)) {
            try DirDelete(binPath, true)
        }

        ; Extract to temp folder first
        tempExtract := A_Temp . "\mATE_extract"
        if (DirExist(tempExtract)) {
            try DirDelete(tempExtract, true)
        }
        try DirCreate(tempExtract)

        ; Show notification that will stay visible during extraction (5 seconds)
        ShowProgress("Extracting archive...", 1, "AHK-Hacker", 50000)

        ; Extract using PowerShell
        psCmd := "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"Expand-Archive -Path '" . tempZip . "' -DestinationPath '" . tempExtract . "' -Force`""
        RunWait(psCmd, , "Hide")
        Sleep(500)

        ; Move mATE folder from temp to bin
        mATESourcePath := tempExtract . "\mATE"
        if (!DirExist(mATESourcePath)) {
            ShowProgress("Could not find mATE folder in archive", 3, "AHK-Hacker Error")
            try FileDelete(tempZip)
            try DirDelete(tempExtract, true)
            return ""
        }

        ShowProgress("Installing mATE to bin folder...", 1, "AHK-Hacker")

        ; Ensure bin folder exists
        binDir := RegExReplace(binPath, "\\mATE$", "")
        if (!DirExist(binDir)) {
            try DirCreate(binDir)
        }

        ; Move the mATE folder to bin
        DirMove(mATESourcePath, binPath, true)

        ShowProgress("Unblocking files...", 1, "AHK-Hacker")

        ; Unblock all files recursively
        psUnblock := "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"Get-ChildItem -Path '" . binPath . "' -Recurse | Unblock-File`""
        RunWait(psUnblock, , "Hide")

        ; Clean up temp files
        try FileDelete(tempZip)
        try DirDelete(tempExtract, true)

        ; Find myAutToExe.exe in the extracted files
        myAutToExePath := ""
        Loop Files binPath . "\*", "FR"
        {
            if (A_LoopFileName = "myAutToExe.exe") {
                myAutToExePath := A_LoopFileFullPath
                break
            }
        }

        if (myAutToExePath = "") {
            ShowProgress("myAutToExe.exe not found after extraction", 3, "AHK-Hacker Error")
            return ""
        }

        ShowProgress("myAutToExe installed successfully", 0, "AHK-Hacker")
        return myAutToExePath

    } catch Error as err {
        ShowProgress("Download error: " . err.Message, 3, "AHK-Hacker Error")
        try FileDelete(A_Temp . "\mATE_temp.zip")
        return ""
    }
}
