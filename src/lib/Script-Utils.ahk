#Requires AutoHotkey v2.0
#Include Notifications.ahk

; ====================================================================
; AHK-Hacker - Script Utilities
; ====================================================================
; This library provides shared utility functions for script handling.
;
; Usage: #Include lib/Script-Utils.ahk
; ====================================================================

/**
 * SaveExtractedScript - Normalizes and saves extracted script to file
 * @param scriptContent - Extracted script text
 * @param exePath - Original executable path (for naming output)
 * @param outputDir - Directory to save output file
 * @param logFile - Path to log file for operation logging
 * @return bool - True on success, false on failure
 */
SaveExtractedScript(scriptContent, exePath, outputDir, logFile) {
    ; Generate output filename
    SplitPath(exePath, , , , &exeBaseName)
    outputFile := outputDir . "\" . exeBaseName . "_decompiled.ahk"

    try {
        ; Normalize line endings to CRLF (Windows standard)
        scriptContent := StrReplace(scriptContent, "`r`n", "`n")  ; Remove existing CR/LF
        scriptContent := StrReplace(scriptContent, "`r", "`n")     ; Convert lone CR to LF
        scriptContent := StrReplace(scriptContent, "`n", "`r`n")   ; Convert all LF to CR/LF

        ; Write as UTF-8 without BOM
        fileObj := FileOpen(outputFile, "w", "UTF-8-RAW")
        if (!fileObj) {
            ShowProgress("Cannot write to output directory", 3, "AHK-Hacker Error")
            FileAppend("Error: Cannot create output file`r`n", logFile, "UTF-8-RAW")
            return false
        }

        fileObj.Write(scriptContent)
        fileObj.Close()

        outputSize := FileGetSize(outputFile)
        FileAppend("Script saved to: " . outputFile . "`r`n", logFile, "UTF-8-RAW")
        FileAppend("Output file size: " . outputSize . " bytes`r`n", logFile, "UTF-8-RAW")

        return true

    } catch Error as err {
        ShowProgress("Write error: " . err.Message, 3, "AHK-Hacker Error")
        FileAppend("Error writing output: " . err.Message . "`r`n", logFile, "UTF-8-RAW")
        return false
    }
}
