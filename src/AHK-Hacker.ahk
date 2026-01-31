#Requires AutoHotkey v2.0
#SingleInstance Force
#Include lib/Notifications.ahk
#Include lib/PE-Analysis.ahk
#Include lib/Unpack-Exe.ahk
#Include lib/Launch-MyAutToExe.ahk
#Include lib/Launch-SystemInformer.ahk
#Include lib/Parse-MemoryDump.ahk
;@Ahk2Exe-Base C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe
;@Ahk2Exe-Set CompanyName, KnifMelti
;@Ahk2Exe-Set ProductName, AHK-Hacker
;@Ahk2Exe-Set FileDescription, AHK Context Menu Decompiler
;@Ahk2Exe-Set FileVersion, 3.5.0.0
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

; Get path from context menu (Windows sends "%1" as parameter)
if (A_Args.Length = 0) {
    MsgBox("No file specified!`n`nUsage: Drag .exe file or use from context menu.", "Error", 16)
    ExitApp(1)
}

; Check for silent mode parameter
global SilentMode := false
if (A_Args.Length > 1) {
    Loop A_Args.Length {
        if (A_Args[A_Index] = "/silent" || A_Args[A_Index] = "-silent") {
            SilentMode := true
            break
        }
    }
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
if (fileExt != "exe") {
    MsgBox("Not an executable file!`n`nOnly .exe files can be decompiled.", "AHK-Hacker Error", 16)
    ExitApp(1)
}

; Get AHK-Hacker installation directory (needed for output path logic)
SplitPath(A_ScriptFullPath, , &installDir)

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
    FileAppend("MPRESS packer detected - offering System Informer`r`n", logFile, "UTF-8-RAW")

    ; Offer to launch System Informer (downloads if needed, starts SI + exe)
    ; Returns object with {mpressPID: N, siPID: M}, or {mpressPID: 0, siPID: 0} if cancelled/failed
    pids := OfferSystemInformer(exePath, logFile)

    if (pids.mpressPID = 0) {
        ; User cancelled or launch failed
        FileAppend("User cancelled System Informer offer or launch failed`r`n", logFile, "UTF-8-RAW")
        ExitApp(1)
    }

    ; System Informer and exe are now running (PIDs: mpressPID=" . pids.mpressPID . ", siPID=" . pids.siPID . ")
    ; Determine output directory (writable location)
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

    ; Show memory dump instructions and file picker
    if (ParseMemoryDump(exePath, workingDir, logFile)) {
        ; Parsing succeeded - show success notification
        ShowProgress("Script extracted successfully!", 0, "AHK-Hacker")

        ; Close both processes now that we're done
        try {
            ProcessClose(pids.mpressPID)
            FileAppend("Closed MPRESS process (PID: " . pids.mpressPID . ")`r`n", logFile, "UTF-8-RAW")
        }
        try {
            ProcessClose(pids.siPID)
            FileAppend("Closed System Informer (PID: " . pids.siPID . ")`r`n", logFile, "UTF-8-RAW")
        }

        ; Open output folder if using fallback location
        if (usedFallbackForMPRESS) {
            Run('explorer.exe "' . workingDir . '"')
        }

        ExitApp(0)
    } else {
        ; User cancelled or parsing failed - cleanup both processes
        try {
            ProcessClose(pids.mpressPID)
            FileAppend("User cancelled - closed MPRESS process (PID: " . pids.mpressPID . ")`r`n", logFile, "UTF-8-RAW")
        }
        try {
            ProcessClose(pids.siPID)
            FileAppend("User cancelled - closed System Informer (PID: " . pids.siPID . ")`r`n", logFile, "UTF-8-RAW")
        }
        ExitApp(1)
    }
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
    outputPath := fileDir . "\" . outputName . ".ahk"
    usedFallbackFolder := false
} else {
    ; Source directory is read-only - use fallback folder under AHK-Hacker installation
    ahkFolder := installDir . "\ahk"
    if (!FileExist(ahkFolder)) {
        DirCreate(ahkFolder)
    }
    outputPath := ahkFolder . "\" . outputName . ".ahk"
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
