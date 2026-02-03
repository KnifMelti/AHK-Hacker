#Requires AutoHotkey v2.0
#SingleInstance Force
#Include lib/Notifications.ahk
#Include lib/PE-Analysis.ahk
#Include lib/Unpack-Exe.ahk
#Include lib/Launch-MyAutToExe.ahk
#Include lib/Automated-MemoryRead.ahk
;@Ahk2Exe-Base C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe
;@Ahk2Exe-Set CompanyName, KnifMelti
;@Ahk2Exe-Set ProductName, AHK-Hacker
;@Ahk2Exe-Set FileDescription, AHK Context Menu Decompiler
;@Ahk2Exe-Set FileVersion, 3.5.8.2
;@Ahk2Exe-Set LegalCopyright, Copyright (C) 2026 KnifMelti
;@Ahk2Exe-Set LegalTrademarks, AHK-Hacker
;@Ahk2Exe-Set InternalName, AHK-Hacker
; Icon path: res/AH.ico (source) or AH.ico (release packages) - change path if compiling from release
;@Ahk2Exe-SetMainIcon res/AH.ico

; ====================================================================
; AHK Context Menu Decompiler
; ====================================================================
; This script decompiles AutoHotkey compiled executables (.exe)
; by extracting the embedded RCDATA resource via Windows LoadLibrary API.
;
; Usage: Right-click on any .exe file and select "AHK-Hacker - Decompile"
; ====================================================================

/**
 * CanWriteToDirectory - Tests if a directory is writable
 * @param dirPath - Path to directory to test
 * @return Boolean - true if writable, false if read-only
 */
CanWriteToDirectory(dirPath) {
    if (!DirExist(dirPath)) {
        return false
    }

    ; Generate random test filename
    testFile := dirPath . "\.ahk_hacker_write_test_" . A_TickCount . ".tmp"

    try {
        ; Try to create a test file
        FileAppend("", testFile)
        ; If successful, delete it
        FileDelete(testFile)
        return true
    } catch {
        ; Write failed - directory is read-only
        return false
    }
}

; Check for silent mode parameter first (needed by PerformUninstall)
global SilentMode := false
if (A_Args.Length > 0) {
    for arg in A_Args {
        if (arg = "/silent" || arg = "-silent") {
            SilentMode := true
            break
        }
    }
}

; Check for /uninstall parameter
if (A_Args.Length > 0) {
    for arg in A_Args {
        if (arg = "/uninstall" || arg = "-uninstall") {
            PerformUninstall()
            ExitApp(0)
        }
    }
}

; Check for /install parameter (optional with /silent for no prompts)
if (A_Args.Length > 0) {
    installRequested := false
    for arg in A_Args {
        if (arg = "/install" || arg = "-install") {
            installRequested := true
            break
        }
    }
    if (installRequested) {
        if (InstallContextMenu(A_ScriptFullPath)) {
            CreateUninstallShortcut(A_ScriptFullPath, A_ScriptDir)
            if (!SilentMode) {
                ShowProgress("Context menu installed!", 0, "AHK-Hacker")
            }
            ExitApp(0)
        } else {
            ; Installation failed; exit with error (no UI in silent mode)
            ExitApp(1)
        }
    }
}

; Check if context menu is installed (prompt every time if not)
if (!IsContextMenuInstalled()) {
    result := PromptInstallContextMenu()
    if (result = "OK") {
        if (InstallContextMenu(A_ScriptFullPath)) {
            CreateUninstallShortcut(A_ScriptFullPath, A_ScriptDir)
            ShowProgress("Context menu installed! Continuing...", 0, "AHK-Hacker")
        }
    }
}

; Get path from context menu (Windows sends "%1" as parameter)
if (A_Args.Length = 0) {
    MsgBox("No file specified!`n`nUsage: Drag .exe file or use from context menu.", "Error", 16)
    ExitApp(1)
}

exePath := A_Args[1]

; ====================================================================
; STEP 1: VALIDATION
; ====================================================================

; Validate input file exists
if (!FileExist(exePath)) {
    MsgBox("File not found:`n`n" . exePath, "AHK-Hacker Error", 16)
    ExitApp(1)
}

; Check that it's an .exe file
SplitPath(exePath, &fileName, &fileDir, &fileExt)
fileDir := RTrim(fileDir, "\")
if (fileExt != "exe") {
    MsgBox("Not an executable file!`n`nOnly .exe files can be decompiled.", "AHK-Hacker Error", 16)
    ExitApp(1)
}

; Get AHK-Hacker installation directory (needed for output path logic)
SplitPath(A_ScriptFullPath, , &installDir)
installDir := RTrim(installDir, "\")

; ====================================================================
; STEP 1.5: PE ANALYSIS
; ====================================================================

; Analyze file for packer and AHK signature
ShowProgress("Analyzing executable...", 1, "AHK-Hacker")
analysis := AnalyzePEFile(exePath)

; Validate that analysis succeeded
if (!IsObject(analysis) || analysis.Has("error")) {
    errorMsg := analysis.Has("error") ? analysis["error"] : "Unknown analysis error"
    MsgBox("Analysis failed:`n`n" . errorMsg, "AHK-Hacker Error", 16)
    ExitApp(1)
}

; Validate it's an AHK-compiled executable
if (!analysis["isAHK"]) {
    MsgBox("This is not an AutoHotkey compiled executable!`n`nThe file does not contain AutoHotkey signature in its manifest.", "AHK-Hacker", 48)
    ExitApp(1)
}

; Ensure log directory exists (needed before writing analysis results)
if (!FileExist("log")) {
    DirCreate("log")
}

; Create timestamp for log
timestamp := A_YYYY . A_MM . A_DD . "_" . A_Hour . A_Min . A_Sec
logFile := "log\" . fileName . "_decompile_" . timestamp . ".log"

FileAppend("`r`n===== PE ANALYSIS RESULTS =====`r`n", logFile, "UTF-8-RAW")
FileAppend("Packed: " . (analysis["packed"] ? "Yes" : "No") . "`r`n", logFile, "UTF-8-RAW")
FileAppend("Packer: " . analysis["packer"] . "`r`n", logFile, "UTF-8-RAW")
FileAppend("AHK detected: Yes (via manifest)`r`n", logFile, "UTF-8-RAW")
FileAppend("Architecture: " . analysis["arch"] . "`r`n", logFile, "UTF-8-RAW")
FileAppend("Confidence: " . analysis["confidence"] . "%`r`n", logFile, "UTF-8-RAW")

; Handle MPRESS-packed files
if (InStr(analysis["packer"], "MPRESS")) {
    FileAppend("`r`n===== MPRESS DETECTION =====`r`n", logFile, "UTF-8-RAW")
    FileAppend("MPRESS packer detected - attempting automated extraction`r`n", logFile, "UTF-8-RAW")

    ; Determine output directory (writable location) before attempting extraction
    usedFallbackForMPRESS := false
    if (CanWriteToDirectory(fileDir)) {
        workingDir := fileDir
    } else {
        ; Directory is read-only - use fallback folder
        workingDir := installDir . "\ahk"
        usedFallbackForMPRESS := true
        if (!FileExist(workingDir)) {
            DirCreate(workingDir)
        }
    }

    ; Show OK/Cancel dialog before starting executable
    dialogText := "MPRESS-Packed Executable Detected`n`n"
    dialogText .= "AHK-Hacker will attempt automated extraction by:`n"
    dialogText .= "1. Starting the executable`n"
    dialogText .= "2. Reading process memory via Windows API`n"
    dialogText .= "3. Extracting the script automatically`n`n"
    dialogText .= "Press OK to continue.`n"
    dialogText .= "Press Cancel (or ESC) to exit."

    result := MsgBox(dialogText, "AHK-Hacker - MPRESS Detection", "OKCancel Icon! 48")

    if (result = "Cancel") {
        FileAppend("User cancelled MPRESS extraction`r`n", logFile, "UTF-8-RAW")
        ExitApp(1)
    }

    ; User approved - start executable and attempt automated memory reading
    ShowProgress("Starting executable for memory extraction...", 1, "AHK-Hacker")
    FileAppend("Starting MPRESS executable: " . exePath . "`r`n", logFile, "UTF-8-RAW")

    ; Start the MPRESS executable
    mpressPID := 0
    try {
        mpressPID := Run(exePath)
        FileAppend("MPRESS Run() returned PID: " . mpressPID . "`r`n", logFile, "UTF-8-RAW")
    } catch Error as e {
        FileAppend("MPRESS Run() threw error: " . e.Message . "`r`n", logFile, "UTF-8-RAW")
        mpressPID := 0
    }

    ; Verify process is running
    SplitPath(exePath, &processName)
    Sleep(1000)

    if (!mpressPID || !IsNumber(mpressPID) || mpressPID = 0) {
        FileAppend("Run() returned invalid PID, searching with ProcessExist...`r`n", logFile, "UTF-8-RAW")
        mpressPID := ProcessExist(processName)
        FileAppend("ProcessExist(" . processName . ") returned: " . mpressPID . "`r`n", logFile, "UTF-8-RAW")
    }

    actualPID := ProcessExist(processName)

    if (actualPID = 0) {
        ; Process failed to start or immediately exited
        FileAppend("ERROR: Failed to start process or process immediately exited`r`n", logFile, "UTF-8-RAW")
        ShowProgress("Cannot execute file - not a valid executable", 3, "AHK-Hacker Error")
        ExitApp(1)
    } else if (actualPID != mpressPID && mpressPID > 0) {
        FileAppend("Note: ProcessExist found different PID: " . actualPID . " (Run returned " . mpressPID . ")`r`n", logFile, "UTF-8-RAW")
        mpressPID := actualPID
    } else {
        mpressPID := actualPID
    }

    FileAppend("MPRESS exe running with PID: " . mpressPID . "`r`n", logFile, "UTF-8-RAW")

    ; Attempt automated memory reading
    if (TryAutomatedMemoryRead(exePath, mpressPID, workingDir, logFile)) {
        ; Success! - Close process and show success
        ShowProgress("Script extracted successfully!", 0, "AHK-Hacker")

        try {
            ProcessClose(mpressPID)
            FileAppend("Closed MPRESS process (PID: " . mpressPID . ")`r`n", logFile, "UTF-8-RAW")
        }

        ; Open output folder if using fallback location
        if (usedFallbackForMPRESS) {
            Run('explorer.exe "' . workingDir . '"')
        }

        ExitApp(0)
    }

    ; Automated extraction failed - cleanup and exit
    FileAppend("Automated extraction failed`r`n", logFile, "UTF-8-RAW")
    ShowProgress("Failed to extract script from memory", 3, "AHK-Hacker Error")

    ; Close the process
    try {
        ProcessClose(mpressPID)
        FileAppend("Closed MPRESS process (PID: " . mpressPID . ")`r`n", logFile, "UTF-8-RAW")
    }

    ; Show error message with log location
    MsgBox("Automated memory extraction failed.`n`nPossible causes:`n- Script signature not found in memory`n- Insufficient permissions`n- Invalid memory layout`n`nCheck log file for details: " . logFile, "AHK-Hacker - Extraction Failed", "Icon! 16")
    ExitApp(1)
}

; ====================================================================
; STEP 2: PREPARATION
; ====================================================================

; Extract filename without extension
SplitPath(fileName, , , , &fileBaseName)

; Generate output name
outputName := fileBaseName . "_decompiled"

; Determine writable output location
if (CanWriteToDirectory(fileDir)) {
    ; Source directory is writable - use current behavior
    ; Normalize directory to avoid double backslashes
    normalizedDir := RTrim(fileDir, "\")
    outputPath := normalizedDir . "\" . outputName . ".ahk"
    usedFallbackFolder := false
} else {
    ; Source directory is read-only - use fallback folder under AHK-Hacker installation
    ahkFolder := installDir . "\ahk"
    if (!FileExist(ahkFolder)) {
        DirCreate(ahkFolder)
    }
    ; Normalize directory to avoid double backslashes
    normalizedDir := RTrim(ahkFolder, "\")
    outputPath := normalizedDir . "\" . outputName . ".ahk"
    usedFallbackFolder := true
}

; ====================================================================
; STEP 3: UNPACKING (if needed)
; ====================================================================

workingExePath := exePath  ; Track which exe to extract from

; If UPX-packed, unpack first
if (InStr(analysis["packer"], "UPX")) {
    FileAppend("`r`n===== UPX UNPACKING =====`r`n", logFile, "UTF-8-RAW")
    ShowProgress("Unpacking with UPX...", 1, "AHK-Hacker")

    unpackedPath := TryUnpackExe(exePath, logFile, (usedFallbackFolder ? ahkFolder : ""))

    if (unpackedPath != "") {
        FileAppend("UPX unpacking succeeded: " . unpackedPath . "`r`n", logFile, "UTF-8-RAW")
        workingExePath := unpackedPath  ; Use unpacked file for extraction
    } else {
        FileAppend("UPX unpacking failed`r`n", logFile, "UTF-8-RAW")
        ; Continue with original file anyway (extraction might still work)
    }
}

; ====================================================================
; STEP 4: RCDATA EXTRACTION
; ====================================================================

FileAppend("`r`n===== RCDATA EXTRACTION =====`r`n", logFile, "UTF-8-RAW")
ShowProgress("Extracting script from executable...", 1, "AHK-Hacker")

; Determine output directory
if (usedFallbackFolder) {
    extractOutputDir := ahkFolder
} else {
    extractOutputDir := fileDir
}

; Try direct RCData extraction (use original filename for output, not temp unpacked filename)
outputFileName := fileBaseName . "_decompiled.ahk"
extractedFile := ExtractAHKScriptFromRCData(workingExePath, extractOutputDir, outputFileName)

; Clean up unpacked temp file if it was created
if (workingExePath != exePath) {
    try FileDelete(workingExePath)
}

; Remove unpacked temp files (if any remain)
Loop Files "*.unpacked.*.tmp"
    try FileDelete(A_LoopFileFullPath)

if (extractedFile) {
    ; Extraction succeeded!
    FileAppend("RCData extraction succeeded: " . extractedFile . "`r`n", logFile, "UTF-8-RAW")

    ; Open output folder if using fallback location
    if (usedFallbackFolder) {
        Run('explorer.exe "' . extractOutputDir . '"')
    }

    ShowProgress("Decompiled: " . fileBaseName . "_decompiled.ahk", 0, "AHK-Hacker")
    ExitApp(0)
}

; Extraction failed - offer mATE as last resort
FileAppend("RCData extraction failed - offering mATE`r`n", logFile, "UTF-8-RAW")

; Check if we already determined the directory is read-only
if (usedFallbackFolder) {
    monitoring := OfferMyAutToExe(exePath, ahkFolder)
    if (monitoring) {
        ; mATE finished, cleanup done, Explorer opened - just exit
        ExitApp(0)
    } else {
        ; User declined or error - exit with error
        ExitApp(1)
    }
} else {
    OfferMyAutToExe(exePath)
    ExitApp(1)
}

; ====================================================================
; CONTEXT MENU INSTALLATION FUNCTIONS
; ====================================================================

/**
 * IsContextMenuInstalled - Check if context menu is registered
 * @return Boolean - true if installed, false otherwise
 */
IsContextMenuInstalled() {
    try {
        RegRead("HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker")
        return true
    } catch {
        return false
    }
}

/**
 * PromptInstallContextMenu - Show installation prompt dialog
 * @return String - "Yes" or "No" based on user choice
 */
PromptInstallContextMenu() {
    result := MsgBox(
        "Context Menu Not Installed`n"
        "==========================`n`n"
        "AHK-Hacker context menu is not installed.`n`n"
        "Installation will:`n"
        "• Register right-click menu for .exe files`n"
        "• Create an uninstall shortcut in this folder`n`n"
        "Install now?",
        "AHK-Hacker",
        1 + 32
    )
    return result
}

/**
 * InstallContextMenu - Install context menu to registry
 * @param exePath - Full path to AHK-Hacker.exe
 * @return Boolean - true if successful, false on error
 */
InstallContextMenu(exePath) {
    try {
        global SilentMode
        RegWrite("AHK-Hacker - Decompile", "REG_SZ",
            "HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker")

        RegWrite(exePath . ",0", "REG_SZ",
            "HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker", "Icon")

        RegWrite('"' . exePath . '" "%1"', "REG_SZ",
            "HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker\command")

        return true
    } catch as err {
        if (!SilentMode) {
            MsgBox("Error installing context menu: " . err.Message,
                "AHK-Hacker", 16)
        }
        return false
    }
}

/**
 * CreateUninstallShortcut - Create uninstall shortcut via COM
 * @param targetExePath - Full path to AHK-Hacker.exe
 * @param lnkDir - Directory to create shortcut in
 * @return Boolean - true if successful, false on error
 */
CreateUninstallShortcut(targetExePath, lnkDir) {
    try {
        global SilentMode
        lnkPath := lnkDir . "\Uninstall AHK-Hacker.lnk"
        shell := ComObject("WScript.Shell")
        shortcut := shell.CreateShortcut(lnkPath)
        shortcut.TargetPath := targetExePath
        shortcut.Arguments := "/uninstall"
        shortcut.WorkingDirectory := lnkDir
        shortcut.Description := "Uninstall AHK-Hacker context menu integration"
        shortcut.IconLocation := targetExePath . ",0"
        shortcut.Save()
        return true
    } catch as err {
        if (!SilentMode) {
            MsgBox("Warning: Could not create shortcut`n" . err.Message,
                "AHK-Hacker", 48)
        }
        return false
    }
}

/**
 * PerformUninstall - Uninstall context menu and remove shortcut
 */
PerformUninstall() {
    global SilentMode

    if (!SilentMode) {
        result := MsgBox(
            "Uninstall AHK-Hacker?`n`n"
            "This will remove the context menu integration.`n`n"
            "Continue?",
            "AHK-Hacker",
            1 + 32
        )
        if (result = "Cancel")
            return
    }

    registryRemoved := false
    try {
        RunWait('reg.exe delete "HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker" /f', , "Hide")
        registryRemoved := true
    } catch as err {
        if (!SilentMode) {
            MsgBox("Error removing registry: " . err.Message,
                "AHK-Hacker", 16)
        }
    }

    try FileDelete(A_ScriptDir . "\Uninstall AHK-Hacker.lnk")

    if (registryRemoved || SilentMode) {
        ShowProgress("Context menu uninstalled!", 0, "AHK-Hacker")
    }
}
