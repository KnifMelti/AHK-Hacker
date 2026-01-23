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
 * @return void - Exits app after user chooses
 */
OfferMyAutToExe(exePath) {
    ; Show dialog asking if user wants to try myAutToExe
    result := MsgBox("Failed to decompile automatically.`n`nThis may be a very old AutoHotkey executable (v1.0.48.5 or earlier).`n`nWould you like to try myAutToExe decompiler?", "AHK-Hacker", "YesNo Icon! 48")

    if (result = "No") {
        ; User declined - exit
        return
    }

    ; User wants to try myAutToExe - ensure it's installed
    myAutToExePath := EnsureMyAutToExeInstalled()

    if (myAutToExePath = "") {
        ; Installation failed
        MsgBox("Failed to install myAutToExe.`n`nPlease download manually from:`nhttps://github.com/daovantrong/myAutToExe/releases/latest", "AHK-Hacker Error", "Icon! 16")
        return
    }

    ; Determine output path (same as original exe, with _decompiled.ahk)
    SplitPath(exePath, &fileName, &fileDir, &fileExt, &fileNameNoExt)
    outputPath := fileDir . "\" . fileNameNoExt . "_decompiled.ahk"

    ; Get working directory (where myAutToExe.exe is located)
    SplitPath(myAutToExePath, , &myAutToExeDir)

    ; Launch myAutToExe GUI for manual decompilation
    try {
        ShowProgress("Opening myAutToExe...", 1, "AHK-Hacker")

        ; Launch myAutToExe GUI with the executable loaded
        ; Set working directory to myAutToExe folder so it can find Data folder
        Run '"' . myAutToExePath . '" "' . exePath . '"', myAutToExeDir
    } catch Error as err {
        MsgBox("Failed to launch myAutToExe:`n`n" . err.Message, "AHK-Hacker Error", "Icon! 16")
    }
}

/**
 * EnsureMyAutToExeInstalled - Checks if myAutToExe is installed, downloads if needed
 * @return String - Path to myAutToExe.exe, or "" if installation failed
 */
EnsureMyAutToExeInstalled() {
    ; Check if myAutToExe is already installed to Desktop
    desktopPath := A_Desktop . "\myAutToExe"

    ; Search for myAutToExe.exe in the installation folder
    myAutToExePath := ""
    if (DirExist(desktopPath)) {
        ; Look for myAutToExe.exe recursively in Desktop\myAutToExe\
        Loop Files desktopPath . "\*", "FR"
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
 * DownloadMyAutToExe - Downloads and installs myAutToExe to Desktop
 * @return String - Path to myAutToExe.exe, or "" on failure
 */
DownloadMyAutToExe() {
    ShowProgress("Downloading myAutToExe decompiler...", 1, "AHK-Hacker")

    desktopPath := A_Desktop . "\myAutToExe"
    apiUrl := "https://api.github.com/repos/daovantrong/myAutToExe/releases/latest"

    try {
        ; Download release info from GitHub API
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", apiUrl, false)
        whr.SetRequestHeader("User-Agent", "AHK-Hacker")
        whr.Send()

        jsonResponse := whr.ResponseText

        ; Find zipball_url (latest release source)
        if (RegExMatch(jsonResponse, '"zipball_url"\s*:\s*"([^"]+)"', &match)) {
            zipUrl := match[1]
        } else {
            ShowProgress("Could not find myAutToExe download URL", 3, "AHK-Hacker Error")
            return ""
        }

        ; Download ZIP file to temp location
        tempZip := A_Temp . "\myAutToExe_temp.zip"
        try FileDelete(tempZip)

        Download(zipUrl, tempZip)

        if (!FileExist(tempZip)) {
            ShowProgress("Failed to download myAutToExe", 3, "AHK-Hacker Error")
            return ""
        }

        ShowProgress("Download complete, extracting files...", 1, "AHK-Hacker")

        ; Extract ZIP to Desktop\myAutToExe\
        ShowProgress("Installing myAutToExe to Desktop...", 1, "AHK-Hacker")

        ; Remove old installation if it exists
        if (DirExist(desktopPath)) {
            try DirDelete(desktopPath, true)
        }

        ; Create destination folder
        try DirCreate(desktopPath)

        ; Extract to temp folder first
        tempExtract := A_Temp . "\myAutToExe_extract"
        if (DirExist(tempExtract)) {
            try DirDelete(tempExtract, true)
        }
        try DirCreate(tempExtract)

        ; Show notification that will stay visible during extraction (25 seconds)
        ShowProgress("Extracting archive (this may take 20-25 seconds)...", 1, "AHK-Hacker", 25000)

        ; Extract using PowerShell (takes ~10-15 seconds)
        psCmd := "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"Expand-Archive -Path '" . tempZip . "' -DestinationPath '" . tempExtract . "' -Force`""
        RunWait(psCmd, , "Hide")
        Sleep(500)

        ; Show next step - extraction done
        ShowProgress("Archive extracted, organizing files...", 1, "AHK-Hacker")

        ; Find the subdirectory (daovantrong-myAutToExe-*)
        subDir := ""
        Loop Files tempExtract . "\*", "D"
        {
            if (InStr(A_LoopFileName, "daovantrong-myAutToExe-")) {
                subDir := A_LoopFileFullPath
                break
            }
        }

        if (subDir = "") {
            ShowProgress("Could not find myAutToExe subdirectory", 3, "AHK-Hacker Error")
            try FileDelete(tempZip)
            try DirDelete(tempExtract, true)
            return ""
        }

        ShowProgress("Copying myAutToExe files...", 1, "AHK-Hacker")

        ; Copy Data folder
        if (DirExist(subDir . "\Data")) {
            DirCopy(subDir . "\Data", desktopPath . "\Data", true)
        }

        ; Copy Tidy folder
        if (DirExist(subDir . "\Tidy")) {
            DirCopy(subDir . "\Tidy", desktopPath . "\Tidy", true)
        }

        ; Copy all root files (not subdirectories)
        Loop Files subDir . "\*", "F"
        {
            FileCopy(A_LoopFileFullPath, desktopPath . "\" . A_LoopFileName, true)
        }

        ShowProgress("Unblocking files...", 1, "AHK-Hacker")

        ; Unblock all files recursively
        psUnblock := "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"Get-ChildItem -Path '" . desktopPath . "' -Recurse | Unblock-File`""
        RunWait(psUnblock, , "Hide")

        ; Clean up temp files
        try FileDelete(tempZip)
        try DirDelete(tempExtract, true)

        ; Find myAutToExe.exe in the extracted files
        myAutToExePath := ""
        Loop Files desktopPath . "\*", "FR"
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
        try FileDelete(A_Temp . "\myAutToExe_temp.zip")
        return ""
    }
}
