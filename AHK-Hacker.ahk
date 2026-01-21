#Requires AutoHotkey v2.0
#SingleInstance Force
#Include lib/Notifications.ahk
;@Ahk2Exe-Base C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe
;@Ahk2Exe-Set CompanyName, KnifMelti
;@Ahk2Exe-Set ProductName, AHK-Hacker
;@Ahk2Exe-Set FileDescription, AHK Context Menu Decompiler
;@Ahk2Exe-Set FileVersion, 3.1.0.1
;@Ahk2Exe-Set LegalCopyright, Copyright (C) 2026 KnifMelti
;@Ahk2Exe-Set LegalTrademarks, AHK-Hacker
;@Ahk2Exe-Set InternalName, AHK-Hacker
; Icon path: res/RH.ico (source) or RH.ico (release packages) - change path if compiling from release
;@Ahk2Exe-SetMainIcon res/RH.ico

; ====================================================================
; AHK Context Menu Decompiler
; ====================================================================
; This script decompiles AutoHotkey compiled executables (.exe)
; by extracting the embedded RCDATA resource using ResourceHacker.
;
; Usage: Right-click on any .exe file and select "AHK-Hacker - Decompile"
; ====================================================================

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
    ShowProgress("File not found: " . exePath, 3, "AHK-Hacker Error")
    ExitApp(1)
}

; Check that it's an .exe file
SplitPath(exePath, &fileName, &fileDir, &fileExt)
if (fileExt != "exe") {
    ShowProgress("Not an executable file!", 3, "AHK-Hacker Error")
    ExitApp(1)
}

; ====================================================================
; STEP 2: PREPARATION
; ====================================================================

; Extract filename without extension
SplitPath(fileName, , , , &fileBaseName)

; Generate output name
outputName := fileBaseName . "_decompiled"
outputPath := fileDir . "\" . outputName . ".ahk"

; Create timestamp for log
timestamp := A_YYYY . A_MM . A_DD . "_" . A_Hour . A_Min . A_Sec
logFile := "log\" . fileBaseName . "_decompile_" . timestamp . ".log"

; Ensure log directory exists
if (!FileExist("log")) {
    DirCreate("log")
}

; Clean up old temporary files
try FileDelete("RCData.rc")
try FileDelete("RCData.bin")
Loop Files "RCDATA*.bin"
    try FileDelete(A_LoopFileFullPath)

; ====================================================================
; STEP 3: DECOMPILATION
; ====================================================================

; Build paths to ResourceHacker versions
; Get the directory where AHK-Hacker.exe is registered in the registry
; Read from registry to find the actual installation path
try {
    registryPath := RegRead("HKEY_CURRENT_USER\Software\Classes\exefile\shell\AHK-Hacker\command")
    ; Extract path from registry value (format: "C:\path\to\AHK-Hacker.exe" "%1")
    ; Remove quotes and the "%1" parameter
    registryPath := StrReplace(registryPath, '"', '')
    registryPath := Trim(StrSplit(registryPath, " ")[1])

    ; Get directory from the registry path
    SplitPath(registryPath, , &installDir)

    resourceHackerPath := installDir . "\bin\ResourceHacker.exe"
    resourceHacker4Path := installDir . "\bin\ResourceHacker4.exe"
} catch {
    ; Fallback: try to find bin folder relative to where we are
    exeDir := ""
    SplitPath(A_ScriptFullPath, , &exeDir)
    resourceHackerPath := exeDir . "\bin\ResourceHacker.exe"
    resourceHacker4Path := exeDir . "\bin\ResourceHacker4.exe"
}

; Check that at least one ResourceHacker exists
if (!FileExist(resourceHackerPath) && !FileExist(resourceHacker4Path)) {
    ShowProgress("ResourceHacker.exe not found in bin folder!`n`nRun Update-ResourceHacker.ahk to download it.", 3, "AHK-Hacker Error")
    ExitApp(1)
}

; Try ResourceHacker 5.x first (if available)
binFound := false
if (FileExist(resourceHackerPath)) {
    cmd := '"' . resourceHackerPath . '" -open "' . exePath . '" -save RCData.rc -action extract -mask RCDATA,, -log "' . logFile . '"'
    RunWait(cmd, , "Hide")
    Sleep(100)

    ; Convert log file from UTF-16 LE to UTF-8
    if (FileExist(logFile)) {
        try {
            fileObj := FileOpen(logFile, "r", "UTF-16")
            logContent := fileObj.Read()
            fileObj.Close()
            if (logContent != "") {
                FileDelete(logFile)
                FileAppend(logContent, logFile, "UTF-8-RAW")
                logContent := ""
            }
        }
    }

    ; Check if any .bin files were extracted
    Loop Files "RCDATA*.bin"
    {
        binFound := true
        break
    }
    if (!binFound && FileExist("RCData.bin"))
        binFound := true
}

; If ResourceHacker 5.x failed, try ResourceHacker 4.x (handles older AHK formats)
if (!binFound && FileExist(resourceHacker4Path)) {
    try FileDelete("RCData.rc")
    cmd := '"' . resourceHacker4Path . '" -open "' . exePath . '" -save RCData.rc -action extract -mask RCDATA,, -log "' . logFile . '"'
    RunWait(cmd, , "Hide")
    Sleep(100)

    ; Convert log file from UTF-16 LE to UTF-8
    if (FileExist(logFile)) {
        try {
            fileObj := FileOpen(logFile, "r", "UTF-16")
            logContent := fileObj.Read()
            fileObj.Close()
            if (logContent != "") {
                FileDelete(logFile)
                FileAppend(logContent, logFile, "UTF-8-RAW")
                logContent := ""
            }
        }
    }

    ; Check again for .bin files
    Loop Files "RCDATA*.bin"
    {
        binFound := true
        break
    }
    if (!binFound && FileExist("RCData.bin"))
        binFound := true
}

; Check that extraction succeeded
if (!binFound) {
    ShowProgress("Not an AutoHotkey executable or packed/protected: " . fileName, 3, "AHK-Hacker Error")
    try FileDelete("RCData.rc")
    ExitApp(1)
}

; ====================================================================
; STEP 4: FINALIZATION
; ====================================================================

; Delete RCData.rc (we only need .bin)
try FileDelete("RCData.rc")

; Wait a bit to ensure .bin file has been created
Sleep(100)

; Find the extracted .bin file (new ResourceHacker uses RCDATA1_1.bin format, old used RCData.bin)
binFile := ""
if (FileExist("RCData.bin")) {
    binFile := "RCData.bin"
} else {
    ; Look for new naming pattern: RCDATA1_1.bin, RCDATA1_2.bin, etc.
    Loop Files "RCDATA*.bin"
    {
        binFile := A_LoopFileName
        break  ; Use the first one found
    }
}

; Check that a .bin file was found
if (binFile = "") {
    ShowProgress("Failed to extract script data!`n`nThis file may not be an AutoHotkey executable.", 3, "AHK-Hacker Error")
    ExitApp(1)
}

; Read the binary data and convert line endings to Windows CRLF
try {
    scriptContent := FileRead(binFile)
} catch Error as err {
    ShowProgress("Failed to read script data!", 3, "AHK-Hacker Error")
    try FileDelete(binFile)
    ExitApp(1)
}

; Convert Unix LF to Windows CRLF
scriptContent := StrReplace(scriptContent, "`r`n", "`n")  ; Normalize to LF first
scriptContent := StrReplace(scriptContent, "`n", "`r`n")  ; Convert to CRLF

; Write to output file with Windows line endings
try FileDelete(outputPath)
try {
    FileAppend(scriptContent, outputPath)
} catch Error as err {
    ShowProgress("Failed to create output file: " . outputPath, 3, "AHK-Hacker Error")
    try FileDelete(binFile)
    ExitApp(1)
}

; Clear variable to free memory before deleting file
scriptContent := ""

; ====================================================================
; STEP 5: CLEANUP
; ====================================================================

; Cleanup: Remove temporary files
try FileDelete("RCData.rc")
Sleep(50)
try FileDelete(binFile)

; Remove any remaining .rc and .bin files (from ResourceHacker)
Loop Files "*.rc"
    try FileDelete(A_LoopFileFullPath)
Loop Files "RCDATA*.bin"
    try FileDelete(A_LoopFileFullPath)

; ====================================================================
; STEP 6: SUCCESS NOTIFICATION
; ====================================================================

; Show success message
ShowProgress(outputName . ".ahk", 0, "AHK-Hacker Decompiled")

; Wait a bit so the notification has time to show
Sleep(2000)
ExitApp(0)
