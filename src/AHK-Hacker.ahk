#Requires AutoHotkey v2.0
#SingleInstance Force
#Include lib/Notifications.ahk
;@Ahk2Exe-Base C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe
;@Ahk2Exe-Set CompanyName, KnifMelti
;@Ahk2Exe-Set ProductName, AHK-Hacker
;@Ahk2Exe-Set FileDescription, AHK Context Menu Decompiler
;@Ahk2Exe-Set FileVersion, 3.2.2.6
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
rh5Log := ""  ; Save RH5 log content for later
if (FileExist(resourceHackerPath)) {
    cmd := '"' . resourceHackerPath . '" -open "' . exePath . '" -save RCData.rc -action extract -mask RCDATA,, -log "' . logFile . '"'
    RunWait(cmd, , "Hide")
    Sleep(100)

    ; Convert log file from UTF-16 LE to UTF-8 and save content
    if (FileExist(logFile)) {
        try {
            fileObj := FileOpen(logFile, "r", "UTF-16")
            logContent := fileObj.Read()
            fileObj.Close()
            if (logContent != "") {
                rh5Log := logContent  ; Save RH5 log
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

    ; Convert log file from UTF-16 LE to UTF-8 and restore RH5 log
    if (FileExist(logFile)) {
        try {
            fileObj := FileOpen(logFile, "r", "UTF-16")
            logContent := fileObj.Read()
            fileObj.Close()
            if (logContent != "") {
                FileDelete(logFile)
                ; Restore RH5 log first, then append RH4 log
                if (rh5Log != "") {
                    FileAppend(rh5Log, logFile, "UTF-8-RAW")
                }
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
    ; STEP 3.5: CHECK UPX DETECTION BEFORE UNPACKING
    #Include lib/Unpack-Exe.ahk

    ; Check if file is UPX-packed before attempting unpacking
    FileAppend("`n===== UPX DETECTION =====`n", logFile, "UTF-8-RAW")
    upxDetected := IsUPXPacked(exePath, logFile)

    if (upxDetected = 1) {
        ; UPX detected - proceed with unpacking
        FileAppend("UPX detected - proceeding with unpacking`n", logFile, "UTF-8-RAW")
        unpackedPath := TryUnpackExe(exePath, logFile)
    } else if (upxDetected = 0) {
        ; Not UPX-packed and no RCDATA found - file is likely not an AHK executable
        FileAppend("Not UPX-packed - file is likely not an AutoHotkey executable`n", logFile, "UTF-8-RAW")
        try FileDelete("RCData.rc")

        MsgBox("Failed to extract script data!`n`nThis file may not be an AutoHotkey executable.", "AHK-Hacker Error", 16)
        ExitApp(1)
    } else {
        ; Detection failed (-1) - try unpacking anyway as fallback
        FileAppend("UPX detection inconclusive - attempting unpacking anyway`n", logFile, "UTF-8-RAW")
        unpackedPath := TryUnpackExe(exePath, logFile)
    }

    if (upxDetected != 0 && unpackedPath != "") {
        ; Unpacking succeeded - retry decompilation on unpacked exe

        ; Save unpacking log content before ResourceHacker overwrites it
        unpackingLog := ""
        if (FileExist(logFile)) {
            try {
                unpackingLog := FileRead(logFile, "UTF-8-RAW")
            }
        }

        ; Try ResourceHacker 5.x on unpacked file
        if (FileExist(resourceHackerPath)) {
            cmd := '"' . resourceHackerPath . '" -open "' . unpackedPath . '" -save RCData.rc -action extract -mask RCDATA,, -log "' . logFile . '"'
            RunWait(cmd, , "Hide")
            Sleep(100)

            ; Convert log file from UTF-16 LE to UTF-8 and restore unpacking log
            if (FileExist(logFile)) {
                try {
                    fileObj := FileOpen(logFile, "r", "UTF-16")
                    logContent := fileObj.Read()
                    fileObj.Close()
                    if (logContent != "") {
                        FileDelete(logFile)
                        ; Restore unpacking log first, then ResourceHacker log
                        if (unpackingLog != "") {
                            FileAppend(unpackingLog, logFile, "UTF-8-RAW")
                        }
                        FileAppend(logContent, logFile, "UTF-8-RAW")
                        logContent := ""
                    }
                }
            }

            ; Check if extraction succeeded
            Loop Files "RCDATA*.bin" {
                binFound := true
                break
            }
            if (!binFound && FileExist("RCData.bin"))
                binFound := true
        }

        ; Try ResourceHacker 4.x if 5.x failed
        if (!binFound && FileExist(resourceHacker4Path)) {
            ; Save current log content (includes unpacking info + possibly RH5 output)
            currentLog := ""
            if (FileExist(logFile)) {
                try {
                    currentLog := FileRead(logFile, "UTF-8-RAW")
                }
            }

            try FileDelete("RCData.rc")
            cmd := '"' . resourceHacker4Path . '" -open "' . unpackedPath . '" -save RCData.rc -action extract -mask RCDATA,, -log "' . logFile . '"'
            RunWait(cmd, , "Hide")
            Sleep(100)

            ; Convert log file from UTF-16 LE to UTF-8 and restore previous log
            if (FileExist(logFile)) {
                try {
                    fileObj := FileOpen(logFile, "r", "UTF-16")
                    logContent := fileObj.Read()
                    fileObj.Close()
                    if (logContent != "") {
                        FileDelete(logFile)
                        ; Restore previous log first, then ResourceHacker 4 log
                        if (currentLog != "") {
                            FileAppend(currentLog, logFile, "UTF-8-RAW")
                        }
                        FileAppend(logContent, logFile, "UTF-8-RAW")
                        logContent := ""
                    }
                }
            }

            Loop Files "RCDATA*.bin" {
                binFound := true
                break
            }
            if (!binFound && FileExist("RCData.bin"))
                binFound := true
        }

        ; Clean up unpacked temporary file
        try FileDelete(unpackedPath)
    }

    ; Final check - if still no .bin found, offer myAutToExe
    if (!binFound) {
        try FileDelete("RCData.rc")

        ; Offer myAutToExe for very old AHK executables
        #Include lib/Launch-MyAutToExe.ahk
        OfferMyAutToExe(exePath)
        ExitApp(1)
    }
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

; Check if content is empty or too small (likely packed/corrupted)
; Valid AHK scripts are typically at least 10 bytes
if (StrLen(scriptContent) < 10) {
    ; Content is too small - file might be packed
    ; Clean up current .bin file
    try FileDelete(binFile)
    try FileDelete("RCData.rc")

    ; Check UPX detection before unpacking
    #Include lib/Unpack-Exe.ahk

    ; Check if file is UPX-packed before attempting unpacking
    FileAppend("`n===== UPX DETECTION (SMALL CONTENT) =====`n", logFile, "UTF-8-RAW")
    upxDetected := IsUPXPacked(exePath, logFile)

    if (upxDetected = 1) {
        ; UPX detected - proceed with unpacking
        FileAppend("UPX detected - proceeding with unpacking`n", logFile, "UTF-8-RAW")
        unpackedPath := TryUnpackExe(exePath, logFile)
    } else if (upxDetected = 0) {
        ; Not UPX-packed and no RCDATA found - file is likely not an AHK executable
        FileAppend("Not UPX-packed - file is likely not an AutoHotkey executable`n", logFile, "UTF-8-RAW")
        try FileDelete("RCData.rc")

        MsgBox("Failed to extract script data!`n`nThis file may not be an AutoHotkey executable.", "AHK-Hacker Error", 16)
        ExitApp(1)
    } else {
        ; Detection failed (-1) - try unpacking anyway as fallback
        FileAppend("UPX detection inconclusive - attempting unpacking anyway`n", logFile, "UTF-8-RAW")
        unpackedPath := TryUnpackExe(exePath, logFile)
    }

    if (upxDetected != 0 && unpackedPath != "") {
        ; Unpacking succeeded - retry extraction on unpacked exe

        ; Save unpacking log before ResourceHacker overwrites it
        unpackingLog := ""
        if (FileExist(logFile)) {
            try {
                unpackingLog := FileRead(logFile, "UTF-8-RAW")
            }
        }

        ; Try ResourceHacker 5.x on unpacked file
        binFound := false
        if (FileExist(resourceHackerPath)) {
            cmd := '"' . resourceHackerPath . '" -open "' . unpackedPath . '" -save RCData.rc -action extract -mask RCDATA,, -log "' . logFile . '"'
            RunWait(cmd, , "Hide")
            Sleep(100)

            ; Convert log file from UTF-16 LE to UTF-8 and restore unpacking log
            if (FileExist(logFile)) {
                try {
                    fileObj := FileOpen(logFile, "r", "UTF-16")
                    logContent := fileObj.Read()
                    fileObj.Close()
                    if (logContent != "") {
                        FileDelete(logFile)
                        if (unpackingLog != "") {
                            FileAppend(unpackingLog, logFile, "UTF-8-RAW")
                        }
                        FileAppend(logContent, logFile, "UTF-8-RAW")
                        logContent := ""
                    }
                }
            }

            ; Check if extraction succeeded
            Loop Files "RCDATA*.bin" {
                binFound := true
                binFile := A_LoopFileName
                break
            }
            if (!binFound && FileExist("RCData.bin")) {
                binFound := true
                binFile := "RCData.bin"
            }
        }

        ; Try ResourceHacker 4.x if 5.x failed
        if (!binFound && FileExist(resourceHacker4Path)) {
            currentLog := ""
            if (FileExist(logFile)) {
                try {
                    currentLog := FileRead(logFile, "UTF-8-RAW")
                }
            }

            try FileDelete("RCData.rc")
            cmd := '"' . resourceHacker4Path . '" -open "' . unpackedPath . '" -save RCData.rc -action extract -mask RCDATA,, -log "' . logFile . '"'
            RunWait(cmd, , "Hide")
            Sleep(100)

            ; Convert log file from UTF-16 LE to UTF-8 and restore previous log
            if (FileExist(logFile)) {
                try {
                    fileObj := FileOpen(logFile, "r", "UTF-16")
                    logContent := fileObj.Read()
                    fileObj.Close()
                    if (logContent != "") {
                        FileDelete(logFile)
                        if (currentLog != "") {
                            FileAppend(currentLog, logFile, "UTF-8-RAW")
                        }
                        FileAppend(logContent, logFile, "UTF-8-RAW")
                        logContent := ""
                    }
                }
            }

            Loop Files "RCDATA*.bin" {
                binFound := true
                binFile := A_LoopFileName
                break
            }
            if (!binFound && FileExist("RCData.bin")) {
                binFound := true
                binFile := "RCData.bin"
            }
        }

        ; Clean up unpacked temporary file
        try FileDelete(unpackedPath)

        ; Check if we got a valid .bin file after unpacking
        if (!binFound || binFile = "") {
            try FileDelete("RCData.rc")

            ; Offer myAutToExe for very old AHK executables
            #Include lib/Launch-MyAutToExe.ahk
            OfferMyAutToExe(exePath)
            ExitApp(1)
        }

        ; Read the new .bin file
        try {
            scriptContent := FileRead(binFile)
        } catch Error as err {
            ShowProgress("Failed to read script data after unpacking!", 3, "AHK-Hacker Error")
            try FileDelete(binFile)
            ExitApp(1)
        }

        ; Check again if content is valid
        if (StrLen(scriptContent) < 10) {
            try FileDelete(binFile)
            try FileDelete("RCData.rc")

            ; Offer myAutToExe for very old AHK executables
            #Include lib/Launch-MyAutToExe.ahk
            OfferMyAutToExe(exePath)
            ExitApp(1)
        }
    } else {
        ; Unpacking failed - offer myAutToExe
        try FileDelete("RCData.rc")

        #Include lib/Launch-MyAutToExe.ahk
        OfferMyAutToExe(exePath)
        ExitApp(1)
    }
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

; Remove unpacked temp files (if any remain)
Loop Files "*.unpacked.*.tmp"
    try FileDelete(A_LoopFileFullPath)

; ====================================================================
; STEP 6: SUCCESS
; ====================================================================

; Show brief success notification
ShowProgress("Decompiled: " . outputName . ".ahk", 0, "AHK-Hacker")
ExitApp(0)
