#NoEnv
#Warn
#SingleInstance Force
;@Ahk2Exe-Base C:\Program Files\AutoHotkey\v1.1.37.02\Unicode 64-bit.bin
;@Ahk2Exe-Set CompanyName, KnifMelti
;@Ahk2Exe-Set ProductName, AHK-Hacker
;@Ahk2Exe-Set FileDescription, AHK Context Menu Decompiler
;@Ahk2Exe-Set FileVersion, 3.0.0.1
;@Ahk2Exe-Set LegalCopyright, Copyright (C) 2026 KnifMelti
;@Ahk2Exe-Set LegalTrademarks, AHK-Hacker
;@Ahk2Exe-Set InternalName, AHK-Hacker
;@Ahk2Exe-SetMainIcon RH.ico

; ====================================================================
; AHK Context Menu Decompiler
; ====================================================================
; This script decompiles AutoHotkey compiled executables (.exe)
; by extracting the embedded RCDATA resource using ResourceHacker.
;
; Usage: Right-click on any .exe file and select "AHK-Hacker - Decompile"
; ====================================================================

; Get path from context menu (Windows sends "%1" as parameter)
if (A_Args.Length() = 0) {
    MsgBox, 16, Error, No file specified!`n`nUsage: Drag .exe file or use from context menu.
    ExitApp, 1
}

exePath := A_Args[1]

; Set working directory to script folder
SetWorkingDir, %A_ScriptDir%

; ====================================================================
; STEP 1: VALIDATION
; ====================================================================

; Validate input file exists
if (!FileExist(exePath)) {
    TrayTip, AHK-Hacker Error, File not found: %exePath%, 5, 3
    ExitApp, 1
}

; Check that it's an .exe file
SplitPath, exePath, fileName, fileDir, fileExt
if (fileExt != "exe") {
    TrayTip, AHK-Hacker Error, Not an executable file!, 5, 3
    ExitApp, 1
}

; ====================================================================
; STEP 2: PREPARATION
; ====================================================================

; Extract filename without extension
SplitPath, fileName, , , , fileBaseName

; Generate output name
outputName := fileBaseName . "_decompiled"
outputPath := fileDir . "\" . outputName . ".ahk"

; Create timestamp for log
timestamp := A_YYYY . A_MM . A_DD . "_" . A_Hour . A_Min . A_Sec
logFile := "log\" . fileBaseName . "_decompile_" . timestamp . ".log"

; Ensure log directory exists
if (!FileExist("log")) {
    FileCreateDir, log
}

; Clean up old temporary files
FileDelete, RCData.rc
FileDelete, RCData.bin
FileDelete, RCDATA*.bin

; ====================================================================
; STEP 3: DECOMPILATION
; ====================================================================

; Build paths to ResourceHacker versions
resourceHackerPath := A_ScriptDir . "\lib\ResourceHacker.exe"
resourceHacker4Path := A_ScriptDir . "\lib\ResourceHacker4.exe"

; Check that at least one ResourceHacker exists
if (!FileExist(resourceHackerPath) && !FileExist(resourceHacker4Path)) {
    TrayTip, AHK-Hacker Error, ResourceHacker.exe not found in lib folder!`n`nRun Update-ResourceHacker.ahk to download it., 5, 3
    ExitApp, 1
}

; Try ResourceHacker 5.x first (if available)
binFound := false
if (FileExist(resourceHackerPath)) {
    cmd := """" . resourceHackerPath . """ -open """ . exePath . """ -save RCData.rc -action extract -mask RCDATA,, -log """ . logFile . """"
    RunWait, %cmd%, , Hide
    Sleep, 100

    ; Convert log file from UTF-16 LE to UTF-8
    if (FileExist(logFile)) {
        fileObj := FileOpen(logFile, "r", "UTF-16")
        if (IsObject(fileObj)) {
            logContent := fileObj.Read()
            fileObj.Close()
            if (logContent != "") {
                FileDelete, %logFile%
                FileAppend, %logContent%, %logFile%, UTF-8-RAW
                logContent := ""
            }
        }
    }

    ; Check if any .bin files were extracted
    Loop, Files, RCDATA*.bin
    {
        binFound := true
        break
    }
    if (!binFound && FileExist("RCData.bin"))
        binFound := true
}

; If ResourceHacker 5.x failed, try ResourceHacker 4.x (handles older AHK formats)
if (!binFound && FileExist(resourceHacker4Path)) {
    FileDelete, RCData.rc
    cmd := """" . resourceHacker4Path . """ -open """ . exePath . """ -save RCData.rc -action extract -mask RCDATA,, -log """ . logFile . """"
    RunWait, %cmd%, , Hide
    Sleep, 100

    ; Convert log file from UTF-16 LE to UTF-8
    if (FileExist(logFile)) {
        fileObj := FileOpen(logFile, "r", "UTF-16")
        if (IsObject(fileObj)) {
            logContent := fileObj.Read()
            fileObj.Close()
            if (logContent != "") {
                FileDelete, %logFile%
                FileAppend, %logContent%, %logFile%, UTF-8-RAW
                logContent := ""
            }
        }
    }

    ; Check again for .bin files
    Loop, Files, RCDATA*.bin
    {
        binFound := true
        break
    }
    if (!binFound && FileExist("RCData.bin"))
        binFound := true
}

; Check that extraction succeeded
if (!binFound) {
    TrayTip, AHK-Hacker Error, Not an AutoHotkey executable or packed/protected: %fileName%, 5, 3
    FileDelete, RCData.rc
    ExitApp, 1
}

; ====================================================================
; STEP 4: FINALIZATION
; ====================================================================

; Delete RCData.rc (we only need .bin)
FileDelete, RCData.rc

; Wait a bit to ensure .bin file has been created
Sleep, 100

; Find the extracted .bin file (new ResourceHacker uses RCDATA1_1.bin format, old used RCData.bin)
binFile := ""
if (FileExist("RCData.bin")) {
    binFile := "RCData.bin"
} else {
    ; Look for new naming pattern: RCDATA1_1.bin, RCDATA1_2.bin, etc.
    Loop, Files, RCDATA*.bin
    {
        binFile := A_LoopFileName
        break  ; Use the first one found
    }
}

; Check that a .bin file was found
if (binFile = "") {
    TrayTip, AHK-Hacker Error, Failed to extract script data!`n`nThis file may not be an AutoHotkey executable., 5, 3
    ExitApp, 1
}

; Read the binary data and convert line endings to Windows CRLF
FileRead, scriptContent, %binFile%
if (ErrorLevel) {
    TrayTip, AHK-Hacker Error, Failed to read script data!, 5, 3
    FileDelete, %binFile%
    ExitApp, 1
}

; Convert Unix LF to Windows CRLF
scriptContent := StrReplace(scriptContent, "`r`n", "`n")  ; Normalize to LF first
scriptContent := StrReplace(scriptContent, "`n", "`r`n")  ; Convert to CRLF

; Write to output file with Windows line endings
FileDelete, %outputPath%
FileAppend, %scriptContent%, %outputPath%
if (ErrorLevel) {
    TrayTip, AHK-Hacker Error, Failed to create output file: %outputPath%, 5, 3
    FileDelete, %binFile%
    ExitApp, 1
}

; Clear variable to free memory before deleting file
scriptContent := ""

; ====================================================================
; STEP 5: CLEANUP
; ====================================================================

; Cleanup: Remove temporary files
FileDelete, RCData.rc
Sleep, 50
FileDelete, %binFile%

; Remove any remaining .rc and .bin files (from ResourceHacker)
Loop, Files, *.rc
    FileDelete, %A_LoopFileFullPath%
Loop, Files, RCDATA*.bin
    FileDelete, %A_LoopFileFullPath%

; ====================================================================
; STEP 6: SUCCESS NOTIFICATION
; ====================================================================

; Show success message
TrayTip, AHK-Hacker Decompiled, %outputName%.ahk, 5, 1

; Wait a bit so the notification has time to show
Sleep, 2000
ExitApp, 0
