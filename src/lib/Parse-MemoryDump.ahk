#Requires AutoHotkey v2.0
#Include Notifications.ahk

; ====================================================================
; AHK-Hacker - Memory Dump Parser
; ====================================================================
; This library handles parsing of .bin memory dump files to extract
; AHK scripts from MPRESS-packed executables.
;
; Usage: #Include lib/Parse-MemoryDump.ahk
;        ParseMemoryDump(exePath, outputDir, logFile)
; ====================================================================

/**
 * ParseMemoryDump - Main entry point for parsing .bin memory dumps
 * @param exePath - Path to the original MPRESS-packed executable
 * @param outputDir - Directory where decompiled script will be saved
 * @param logFile - Path to log file for operation logging
 * @return bool - True if extraction succeeded, false if cancelled or failed
 */
ParseMemoryDump(exePath, outputDir, logFile) {
    ; Show OK/Cancel dialog with instructions
    dialogText := "MPRESS-Packed Executable Detected`n`n"
    dialogText .= "This executable is MPRESS-packed and requires manual memory dumping.`n`n"
    dialogText .= "Instructions:`n"
    dialogText .= "1. Run the executable (keep it running)`n"
    dialogText .= "2. Use System Informer to dump process memory from 0x400000`n"
    dialogText .= "3. Save the dump as a .bin file`n`n"
    dialogText .= "Press OK to select your .bin memory dump file.`n"
    dialogText .= "Press Cancel (or ESC) to exit."

    result := MsgBox(dialogText, "AHK-Hacker - MPRESS Detection", "OKCancel Icon! 48")

    if (result = "Cancel") {
        FileAppend("User cancelled MPRESS instructions`r`n", logFile, "UTF-8-RAW")
        return false
    }

    ; Show file picker for .bin file
    binFile := FileSelect(1, , "Select Memory Dump File", "Memory Dump Files (*.bin)")

    if (binFile = "") {
        FileAppend("User cancelled file selection`r`n", logFile, "UTF-8-RAW")
        return false
    }

    FileAppend("`r`n===== MEMORY DUMP PARSING =====`r`n", logFile, "UTF-8-RAW")
    FileAppend("Selected .bin file: " . binFile . "`r`n", logFile, "UTF-8-RAW")

    ; Validate file exists and size
    if (!FileExist(binFile)) {
        ShowProgress("Selected file does not exist", 3, "AHK-Hacker Error")
        FileAppend("Error: File does not exist`r`n", logFile, "UTF-8-RAW")
        return false
    }

    fileSize := FileGetSize(binFile)
    FileAppend("File size: " . fileSize . " bytes`r`n", logFile, "UTF-8-RAW")

    ; Check size limits
    if (fileSize < 1024) {
        ShowProgress("File too small (< 1KB). Not a valid memory dump.", 3, "AHK-Hacker Error")
        FileAppend("Error: File too small - " . fileSize . " bytes`r`n", logFile, "UTF-8-RAW")
        return false
    }

    if (fileSize > 500 * 1024 * 1024) {
        ShowProgress("File too large (> 500MB). Please verify the dump.", 3, "AHK-Hacker Error")
        FileAppend("Error: File exceeds size limit - " . fileSize . " bytes`r`n", logFile, "UTF-8-RAW")
        return false
    }

    ; Search for script signature in binary file
    ShowProgress("Searching for AHK script signature...", 1, "AHK-Hacker")
    searchResult := FindScriptInBinary(binFile, logFile)

    if (!searchResult) {
        ShowProgress("Could not find AHK script signature.`n`nVerify you dumped from address 0x400000", 3, "AHK-Hacker Error")
        FileAppend("Error: Signature not found in " . fileSize . " bytes`r`n", logFile, "UTF-8-RAW")
        return false
    }

    FileAppend("Signature found at offset: " . searchResult.offset . "`r`n", logFile, "UTF-8-RAW")
    FileAppend("Detected encoding: " . searchResult.encoding . "`r`n", logFile, "UTF-8-RAW")

    ; Extract script from found offset
    ShowProgress("Extracting script data...", 1, "AHK-Hacker")
    scriptContent := ExtractScriptFromOffset(binFile, searchResult.offset, searchResult.encoding, logFile)

    if (scriptContent = "") {
        ShowProgress("Found signature but data is corrupted", 3, "AHK-Hacker Error")
        FileAppend("Error: Extraction failed - invalid script data`r`n", logFile, "UTF-8-RAW")
        return false
    }

    ; Save extracted script
    ShowProgress("Saving decompiled script...", 1, "AHK-Hacker")
    success := SaveExtractedScript(scriptContent, exePath, outputDir, logFile)

    return success
}

/**
 * FindScriptInBinary - Searches for AHK script signature in .bin file
 * @param binPath - Path to .bin memory dump file
 * @param logFile - Path to log file
 * @return Object|false - {offset: N, encoding: "UTF-16"} on success, false on failure
 */
FindScriptInBinary(binPath, logFile) {
    signature := "; <COMPILER:"

    ; Open file for binary reading
    file := FileOpen(binPath, "r")
    if (!file) {
        FileAppend("Error: Cannot open .bin file for reading`r`n", logFile, "UTF-8-RAW")
        return false
    }

    fileSize := file.Length

    if (fileSize <= 0) {
        file.Close()
        FileAppend("Error: Invalid file size`r`n", logFile, "UTF-8-RAW")
        return false
    }

    ; Read entire file into buffer (safe since we validated size < 500MB)
    buf := Buffer(fileSize)
    bytesRead := file.RawRead(buf, fileSize)
    file.Close()

    if (bytesRead != fileSize) {
        FileAppend("Error: Failed to read complete file (read " . bytesRead . " of " . fileSize . " bytes)`r`n", logFile, "UTF-8-RAW")
        return false
    }

    FileAppend("Searching for signature in " . fileSize . " bytes...`r`n", logFile, "UTF-8-RAW")

    ; Try UTF-16 LE (most common for AHK compiled scripts)
    ; Signature in UTF-16 LE: each ASCII char followed by 0x00
    sigLen := StrLen(signature)
    utf16Len := sigLen * 2  ; UTF-16 is 2 bytes per character

    ; Search for UTF-16 LE signature
    Loop fileSize - utf16Len {
        offset := A_Index - 1
        found := true

        ; Check if pattern matches UTF-16 LE encoding
        Loop sigLen {
            charIndex := A_Index - 1
            expectedChar := Ord(SubStr(signature, A_Index, 1))

            ; Read 2 bytes (little-endian)
            lowByte := NumGet(buf, offset + charIndex * 2, "UChar")
            highByte := NumGet(buf, offset + charIndex * 2 + 1, "UChar")

            ; UTF-16 LE: low byte = ASCII char, high byte = 0x00
            if (lowByte != expectedChar || highByte != 0x00) {
                found := false
                break
            }
        }

        if (found) {
            FileAppend("UTF-16 LE signature found at offset " . offset . "`r`n", logFile, "UTF-8-RAW")
            return {offset: offset, encoding: "UTF-16"}
        }
    }

    ; Try UTF-8 / CP0 (same binary representation for ASCII)
    sigBytes := Buffer(sigLen)
    Loop sigLen {
        NumPut("UChar", Ord(SubStr(signature, A_Index, 1)), sigBytes, A_Index - 1)
    }

    ; Search for UTF-8/CP0 signature
    Loop fileSize - sigLen {
        offset := A_Index - 1
        found := true

        Loop sigLen {
            if (NumGet(buf, offset + A_Index - 1, "UChar") != NumGet(sigBytes, A_Index - 1, "UChar")) {
                found := false
                break
            }
        }

        if (found) {
            FileAppend("UTF-8/CP0 signature found at offset " . offset . "`r`n", logFile, "UTF-8-RAW")
            return {offset: offset, encoding: "UTF-8"}
        }
    }

    ; Signature not found
    FileAppend("Signature not found in file`r`n", logFile, "UTF-8-RAW")
    return false
}

/**
 * ExtractScriptFromOffset - Extracts script content from found offset
 * @param binPath - Path to .bin memory dump file
 * @param offset - Offset where signature was found
 * @param encoding - Detected encoding ("UTF-16" or "UTF-8")
 * @param logFile - Path to log file
 * @return String - Extracted script content, or "" on failure
 */
ExtractScriptFromOffset(binPath, offset, encoding, logFile) {
    file := FileOpen(binPath, "r")
    if (!file) {
        FileAppend("Error: Cannot open file for extraction`r`n", logFile, "UTF-8-RAW")
        return ""
    }

    ; Seek to offset
    file.Seek(offset, 0)

    ; Read up to 10MB max (safety limit)
    maxSize := 10 * 1024 * 1024
    remaining := file.Length - offset
    readSize := Min(remaining, maxSize)

    if (readSize <= 0) {
        file.Close()
        FileAppend("Error: Invalid read size`r`n", logFile, "UTF-8-RAW")
        return ""
    }

    buf := Buffer(readSize)
    bytesRead := file.RawRead(buf, readSize)
    file.Close()

    if (bytesRead = 0) {
        FileAppend("Error: Failed to read from offset`r`n", logFile, "UTF-8-RAW")
        return ""
    }

    ; Convert to string based on encoding
    if (encoding = "UTF-16") {
        ; UTF-16 LE: 2 bytes per character
        charCount := bytesRead // 2
        content := StrGet(buf.Ptr, charCount, "UTF-16")
    } else {
        ; UTF-8 or CP0 - specify byte length
        content := StrGet(buf.Ptr, bytesRead, "UTF-8")
        ; If UTF-8 fails, try CP0
        if (content = "" || !InStr(content, ";")) {
            content := StrGet(buf.Ptr, bytesRead, "CP0")
        }
    }

    FileAppend("Extracted " . StrLen(content) . " characters`r`n", logFile, "UTF-8-RAW")

    ; Validate extracted content starts with signature
    if (InStr(content, "; <COMPILER:") != 1) {
        FileAppend("Error: Extracted content does not start with signature`r`n", logFile, "UTF-8-RAW")
        FileAppend("Content starts with: " . SubStr(content, 1, 50) . "`r`n", logFile, "UTF-8-RAW")
        return ""
    }

    FileAppend("Extracted " . StrLen(content) . " characters`r`n", logFile, "UTF-8-RAW")
    return content
}

/**
 * TruncateAtNaturalBoundary - Finds natural end of script in extracted content
 * @param content - Raw extracted content
 * @param logFile - Path to log file
 * @return String - Truncated content at natural boundary
 */
TruncateAtNaturalBoundary(content, logFile) {
    contentLen := StrLen(content)

    ; Look for sequences of null characters (common end marker)
    ; In AHK v2, Chr(0) is a null character
    nullSequence := Chr(0) . Chr(0) . Chr(0) . Chr(0)
    nullPos := InStr(content, nullSequence)

    if (nullPos > 0) {
        FileAppend("Natural boundary found at null sequence (position " . nullPos . ")`r`n", logFile, "UTF-8-RAW")
        content := SubStr(content, 1, nullPos - 1)
        return content
    }

    ; If no null sequence found, scan for invalid character sequences
    ; Look for long runs of non-printable characters (except tab, LF, CR)
    invalidCount := 0
    lastValidPos := contentLen

    Loop contentLen {
        char := SubStr(content, A_Index, 1)
        charCode := Ord(char)

        ; Allow printable chars (>= 0x20) and tab (0x09), LF (0x0A), CR (0x0D)
        if (charCode >= 0x20 || charCode = 0x09 || charCode = 0x0A || charCode = 0x0D) {
            invalidCount := 0  ; Reset counter
            lastValidPos := A_Index
        } else {
            invalidCount++
            ; If we hit 50 consecutive invalid chars, truncate here
            if (invalidCount >= 50) {
                FileAppend("Natural boundary found at invalid character sequence (position " . lastValidPos . ")`r`n", logFile, "UTF-8-RAW")
                content := SubStr(content, 1, lastValidPos)
                return content
            }
        }
    }

    ; No obvious boundary found - return as is
    FileAppend("No clear boundary found, using full extraction`r`n", logFile, "UTF-8-RAW")
    return content
}

/**
 * SaveExtractedScript - Normalizes and saves extracted script to file
 * @param scriptContent - Extracted script text
 * @param exePath - Original executable path (for naming output)
 * @param outputDir - Directory to save output file
 * @param logFile - Path to log file
 * @return bool - True on success, false on failure
 */
SaveExtractedScript(scriptContent, exePath, outputDir, logFile) {
    ; Generate output filename
    SplitPath(exePath, , , , &exeBaseName)
    outputFile := outputDir . "\" . exeBaseName . "_decompiled.ahk"

    try {
        ; Normalize line endings to CRLF (reuse pattern from PE-Analysis.ahk)
        scriptContent := StrReplace(scriptContent, "`r`n", "`n")  ; Remove existing CR/LF
        scriptContent := StrReplace(scriptContent, "`r", "`n")     ; Convert lone CR to LF
        scriptContent := StrReplace(scriptContent, "`n", "`r`n")   ; Convert all LF to CR/LF

        ; Write as UTF-8 without BOM (reuse pattern from PE-Analysis.ahk)
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
