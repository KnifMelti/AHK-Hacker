#Requires AutoHotkey v2.0
#Include Notifications.ahk
#Include Script-Utils.ahk

; ====================================================================
; AHK-Hacker - Automated Memory Reading
; ====================================================================
; This library handles automated process memory reading for MPRESS-packed
; executables using Windows ReadProcessMemory API.
;
; Usage: #Include lib/Automated-MemoryRead.ahk
;        TryAutomatedMemoryRead(exePath, mpressPID, outputDir, logFile)
; ====================================================================

/**
 * TryAutomatedMemoryRead - Attempts to read process memory and extract AHK script
 * @param exePath - Path to the original MPRESS-packed executable
 * @param mpressPID - Process ID of the running MPRESS executable
 * @param outputDir - Directory where decompiled script will be saved
 * @param logFile - Path to log file for operation logging
 * @return bool - True if extraction succeeded, false if failed
 */
TryAutomatedMemoryRead(exePath, mpressPID, outputDir, logFile) {
    FileAppend("`r`n===== AUTOMATED MEMORY READ =====`r`n", logFile, "UTF-8-RAW")
    FileAppend("Attempting automated memory extraction (PID: " . mpressPID . ")`r`n", logFile, "UTF-8-RAW")

    ; Wait for process to fully load into memory
    ShowProgress("Waiting for process to load into memory...", 1, "AHK-Hacker")
    Sleep(3000)  ; 3 seconds to ensure script is loaded

    ; Verify process is still running
    if (!ProcessExist(mpressPID)) {
        FileAppend("Error: Process terminated before memory read`r`n", logFile, "UTF-8-RAW")
        ShowProgress("Process terminated unexpectedly", 3, "AHK-Hacker Error")
        return false
    }

    ; Open process with read permissions
    PROCESS_VM_READ := 0x0010
    PROCESS_QUERY_INFORMATION := 0x0400
    dwDesiredAccess := PROCESS_VM_READ | PROCESS_QUERY_INFORMATION  ; 0x0410

    FileAppend("Opening process with VM_READ permissions...`r`n", logFile, "UTF-8-RAW")
    hProcess := DllCall("OpenProcess", "UInt", dwDesiredAccess, "Int", 0, "UInt", mpressPID, "Ptr")

    if (!hProcess || hProcess = 0) {
        lastError := DllCall("GetLastError")
        FileAppend("Error: OpenProcess failed (Error code: " . lastError . ")`r`n", logFile, "UTF-8-RAW")
        ShowProgress("Cannot access process memory (Error: " . lastError . ")", 3, "AHK-Hacker Error")
        return false
    }

    FileAppend("Process opened successfully (handle: " . hProcess . ")`r`n", logFile, "UTF-8-RAW")

    ; Get module base address (works for both x86 and x64)
    baseAddress := GetModuleBaseAddress(hProcess, logFile)

    if (!baseAddress) {
        DllCall("CloseHandle", "Ptr", hProcess)
        FileAppend("Error: Failed to get module base address`r`n", logFile, "UTF-8-RAW")
        ShowProgress("Cannot determine process base address", 3, "AHK-Hacker Error")
        return false
    }

    FileAppend("Module base address: 0x" . Format("{:X}", baseAddress) . "`r`n", logFile, "UTF-8-RAW")

    readSize := 50 * 1024 * 1024  ; 50 MB

    FileAppend("Reading " . readSize . " bytes from address 0x" . Format("{:X}", baseAddress) . "...`r`n", logFile, "UTF-8-RAW")
    ShowProgress("Reading process memory...", 1, "AHK-Hacker")

    ; Allocate buffer
    buf := Buffer(readSize, 0)
    bytesRead := 0

    ; Read process memory
    success := DllCall("ReadProcessMemory",
        "Ptr", hProcess,           ; hProcess
        "Ptr", baseAddress,        ; lpBaseAddress (0x400000)
        "Ptr", buf.Ptr,            ; lpBuffer
        "UPtr", readSize,          ; nSize
        "UPtr*", &bytesRead,       ; lpNumberOfBytesRead
        "Int")                     ; Return type

    lastError := DllCall("GetLastError")

    ; Accept partial reads - as long as we got SOME data, continue
    ; Error 299 (ERROR_PARTIAL_COPY) is normal when reading more than the available region
    if (bytesRead = 0) {
        DllCall("CloseHandle", "Ptr", hProcess)
        FileAppend("Error: ReadProcessMemory failed - no data read (Error code: " . lastError . ")`r`n", logFile, "UTF-8-RAW")
        ShowProgress("Memory read failed - no data (Error: " . lastError . ")", 3, "AHK-Hacker Error")
        return false
    }

    ; Log if we got a partial read (this is normal and expected)
    if (!success || lastError = 299) {
        FileAppend("Partial read (requested " . readSize . " bytes, got " . bytesRead . " bytes) - this is normal`r`n", logFile, "UTF-8-RAW")
    }

    FileAppend("Successfully read " . bytesRead . " bytes from process memory`r`n", logFile, "UTF-8-RAW")

    ; Close process handle
    DllCall("CloseHandle", "Ptr", hProcess)
    FileAppend("Process handle closed`r`n", logFile, "UTF-8-RAW")

    ; Search for AHK script signature in buffer
    ShowProgress("Searching for AHK script signature...", 1, "AHK-Hacker")
    searchResult := FindScriptInBuffer(buf, bytesRead, logFile)

    if (!searchResult) {
        FileAppend("Error: Script signature not found in memory`r`n", logFile, "UTF-8-RAW")
        ShowProgress("Script signature not found in memory", 3, "AHK-Hacker Error")
        return false
    }

    FileAppend("Signature found at offset: " . searchResult.offset . "`r`n", logFile, "UTF-8-RAW")
    FileAppend("Detected encoding: " . searchResult.encoding . "`r`n", logFile, "UTF-8-RAW")

    ; Extract script from found offset
    ShowProgress("Extracting script data...", 1, "AHK-Hacker")
    scriptContent := ExtractScriptFromBuffer(buf, bytesRead, searchResult.offset, searchResult.encoding, logFile)

    if (scriptContent = "") {
        FileAppend("Error: Extraction failed - invalid script data`r`n", logFile, "UTF-8-RAW")
        ShowProgress("Found signature but data is corrupted", 3, "AHK-Hacker Error")
        return false
    }

    ; Save extracted script
    ShowProgress("Saving decompiled script...", 1, "AHK-Hacker")
    success := SaveExtractedScript(scriptContent, exePath, outputDir, logFile)

    if (success) {
        FileAppend("Automated extraction completed successfully`r`n", logFile, "UTF-8-RAW")
    }

    return success
}

/**
 * GetModuleBaseAddress - Gets the base address of the main executable module
 * @param hProcess - Process handle
 * @param logFile - Path to log file
 * @return Integer - Base address, or 0 on failure
 */
GetModuleBaseAddress(hProcess, logFile) {
    ; EnumProcessModulesEx to get first module (main executable)
    ; Works for both x86 and x64 processes

    ; Get module handle
    hMod := Buffer(A_PtrSize, 0)
    cbNeeded := 0

    ; LIST_MODULES_ALL = 0x03
    result := DllCall("Psapi.dll\EnumProcessModulesEx",
        "Ptr", hProcess,
        "Ptr", hMod.Ptr,
        "UInt", A_PtrSize,
        "UInt*", &cbNeeded,
        "UInt", 0x03,  ; LIST_MODULES_ALL
        "Int")

    if (!result) {
        lastError := DllCall("GetLastError")
        FileAppend("Error: EnumProcessModulesEx failed (Error code: " . lastError . ")`r`n", logFile, "UTF-8-RAW")
        return 0
    }

    ; Get module base address (this IS the base address)
    baseAddr := NumGet(hMod, 0, "Ptr")

    if (!baseAddr) {
        FileAppend("Error: Module base address is null`r`n", logFile, "UTF-8-RAW")
        return 0
    }

    return baseAddr
}

/**
 * FindScriptInBuffer - Searches for AHK script signature in memory buffer
 * @param buf - Buffer containing process memory
 * @param bufSize - Size of buffer in bytes
 * @param logFile - Path to log file
 * @return Object|false - {offset: N, encoding: "UTF-16"} on success, false on failure
 */
FindScriptInBuffer(buf, bufSize, logFile) {
    signature := "; <COMPILER:"

    if (bufSize <= 0) {
        FileAppend("Error: Invalid buffer size`r`n", logFile, "UTF-8-RAW")
        return false
    }

    FileAppend("Searching for signature in " . bufSize . " bytes...`r`n", logFile, "UTF-8-RAW")

    ; Try UTF-16 LE (most common for AHK compiled scripts)
    ; Signature in UTF-16 LE: each ASCII char followed by 0x00
    sigLen := StrLen(signature)
    utf16Len := sigLen * 2  ; UTF-16 is 2 bytes per character

    ; Search for UTF-16 LE signature
    Loop bufSize - utf16Len {
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
    Loop bufSize - sigLen {
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
    FileAppend("Signature not found in buffer`r`n", logFile, "UTF-8-RAW")
    return false
}

/**
 * ExtractScriptFromBuffer - Extracts script content from found offset
 * @param buf - Buffer containing process memory
 * @param bufSize - Size of buffer in bytes
 * @param offset - Offset where signature was found
 * @param encoding - Detected encoding ("UTF-16" or "UTF-8")
 * @param logFile - Path to log file
 * @return String - Extracted script content, or "" on failure
 */
ExtractScriptFromBuffer(buf, bufSize, offset, encoding, logFile) {
    ; Calculate remaining bytes from offset
    remaining := bufSize - offset
    maxSize := 10 * 1024 * 1024  ; 10 MB max script size
    readSize := Min(remaining, maxSize)

    if (readSize <= 0) {
        FileAppend("Error: Invalid read size`r`n", logFile, "UTF-8-RAW")
        return ""
    }

    ; Convert to string based on encoding
    if (encoding = "UTF-16") {
        ; UTF-16 LE: use null-terminated string reading
        content := StrGet(buf.Ptr + offset, "UTF-16")
    } else {
        ; UTF-8 or CP0: use null-terminated string reading
        content := StrGet(buf.Ptr + offset, "UTF-8")
        ; If UTF-8 fails, try CP0
        if (content = "" || !InStr(content, ";")) {
            content := StrGet(buf.Ptr + offset, "CP0")
        }
    }

    FileAppend("Extracted " . StrLen(content) . " characters (before cleanup)`r`n", logFile, "UTF-8-RAW")

    ; Validate extracted content starts with signature
    if (InStr(content, "; <COMPILER:") != 1) {
        FileAppend("Error: Extracted content does not start with signature`r`n", logFile, "UTF-8-RAW")
        FileAppend("Content starts with: " . SubStr(content, 1, 50) . "`r`n", logFile, "UTF-8-RAW")
        return ""
    }

    ; Cleanup: Remove trailing garbage data that may have been read beyond the actual script

    ; Strategy 1: Remove trailing whitespace first
    content := RTrim(content)

    ; Strategy 2: Remove trailing control characters (except newlines)
    while (content != "" && Ord(SubStr(content, -1)) < 32 && Ord(SubStr(content, -1)) != 10 && Ord(SubStr(content, -1)) != 13) {
        content := SubStr(content, 1, -1)
    }

    ; Strategy 3: Detect and remove garbage characters at the end
    ; Pattern: If last "word" contains only uppercase/mixed letters without spaces/newlines before it,
    ; and appears to be trash appended to a valid AHK keyword
    ; Example: "PausePA" where "PA" is trash appended to valid "Pause"

    ; Split into lines and check last line
    lines := StrSplit(content, "`n")
    if (lines.Length > 0) {
        lastLine := RTrim(lines[lines.Length], "`r")  ; Remove CR if present

        ; Common AHK keywords that often appear at end of scripts
        commonKeywords := ["Pause", "Exit", "ExitApp", "Return", "Break", "Continue",
                         "Sleep", "Run", "Send", "Click", "Loop", "If", "Else",
                         "MsgBox", "ToolTip", "Reload"]

        ; Check each keyword to see if the line STARTS with it followed by trash
        for keyword in commonKeywords {
            keywordLen := StrLen(keyword)
            lineLen := StrLen(lastLine)

            ; If line is longer than keyword and starts with it
            if (lineLen > keywordLen && SubStr(lastLine, 1, keywordLen) = keyword) {
                ; Get what comes after the keyword
                afterKeyword := SubStr(lastLine, keywordLen + 1)

                ; If what follows is 1-3 uppercase/alphanumeric chars (likely trash), remove it
                ; But allow spaces, quotes, parentheses (valid AHK syntax)
                if (RegExMatch(afterKeyword, "^[A-Z]{1,3}$")) {
                    FileAppend("Detected garbage '" . afterKeyword . "' after keyword '" . keyword . "', removing it`r`n", logFile, "UTF-8-RAW")

                    ; Keep only the keyword
                    lastLine := keyword
                    lines[lines.Length] := lastLine

                    ; Rejoin lines
                    content := ""
                    for index, line in lines {
                        content .= line
                        if (index < lines.Length) {
                            content .= "`n"
                        }
                    }

                    break  ; Found and fixed, exit loop
                }
            }
        }
    }

    ; Final trim
    content := RTrim(content)

    FileAppend("Final extracted length: " . StrLen(content) . " characters`r`n", logFile, "UTF-8-RAW")

    return content
}

; Note: SaveExtractedScript is defined in Script-Utils.ahk and reused here
