#Requires AutoHotkey v2.0

; ====================================================================
; AHK-Hacker - PE Analysis and RCData Extraction
; ====================================================================
; This library provides PE file analysis, packer detection, and direct
; RCData extraction for AutoHotkey executables.
;
; Usage: #Include lib/PE-Analysis.ahk
;        analysis := AnalyzePEFile(exePath)
;        script := ExtractAHKScriptFromRCData(exePath, outputDir)
; ====================================================================

; ====================================================================
; GLOBAL CONSTANTS
; ====================================================================

; Packer signatures
global PACKER_SIGNATURES := Map(
    "MPRESS", {sections: ["MPRESS", ".MPRESS1", ".MPRESS2"]},
    "UPX", {sections: ["UPX0", "UPX1", "UPX2", ".UPX0", ".UPX1"]}
)

; ====================================================================
; PE ANALYSIS FUNCTIONS
; ====================================================================

/**
 * AnalyzePEFile - Analyzes PE file for packer detection and AHK validation
 * @param filePath - Path to executable to analyze
 * @return Map - Analysis results with keys: packed, packer, isAHK, sections, confidence, suspicious, arch
 */
AnalyzePEFile(filePath) {
    if !FileExist(filePath)
        return Map("error", "File not found")

    stage := "start"
    try {
        ; Read PE header
        stage := "open-file"
        file := FileOpen(filePath, "r")
        stage := "size-calc"
        bufferSize := file.Length
        if bufferSize <= 0
            bufferSize := 8192
        else if bufferSize > 8192
            bufferSize := 8192
        stage := "alloc-buffer"
        buf := Buffer(bufferSize)
        stage := "raw-read"
        file.RawRead(buf, bufferSize)
        file.Close()

        stage := "init-result"
        result := Map()
        result["packed"] := false
        result["packer"] := "Unknown"
        result["sections"] := []
        result["suspicious"] := false
        result["confidence"] := 0

        ; Validate PE
        stage := "mz-check"
        if NumGet(buf, 0, "UShort") != 0x5A4D
            return Map("error", "Not a valid PE file (missing MZ signature)")

        stage := "pe-offset"
        peOffset := NumGet(buf, 0x3C, "UInt")
        if peOffset > bufferSize - 4
            return Map("error", "Invalid PE offset")

        stage := "pe-signature"
        if NumGet(buf, peOffset, "UInt") != 0x00004550
            return Map("error", "Invalid PE signature)")

        ; Get architecture
        stage := "arch"
        machine := NumGet(buf, peOffset + 4, "UShort")
        result["arch"] := (machine == 0x8664) ? "x64" : "x86"

        ; Get section info
        stage := "section-info"
        sectionCount := NumGet(buf, peOffset + 6, "UShort")
        optHeaderSize := NumGet(buf, peOffset + 20, "UShort")
        sectionTableOffset := peOffset + 24 + optHeaderSize

        ; Analyze each section
        stage := "detected-packers-init"
        detectedPackers := []

        Loop sectionCount {
            stage := "section-loop"
            sectionOffset := sectionTableOffset + ((A_Index - 1) * 40)

            if sectionOffset + 40 > bufferSize
                break

            ; Read section name
            stage := "read-section-name"
            sectionName := StrGet(buf.Ptr + sectionOffset, 8, "CP0")
            result["sections"].Push(sectionName)

            ; Check against known packer signatures
            for packerName, packerInfo in PACKER_SIGNATURES {
                for sigSection in packerInfo.sections {
                    if InStr(sectionName, sigSection) {
                        if !HasValue(detectedPackers, packerName)
                            detectedPackers.Push(packerName)
                        result["packed"] := true
                        result["confidence"] := 100
                    }
                }
            }

            ; Get section sizes
            virtualSize := NumGet(buf, sectionOffset + 8, "UInt")
            rawSize := NumGet(buf, sectionOffset + 16, "UInt")

            ; Suspicious ratio indicates packing/compression
            if rawSize > 0 && virtualSize > rawSize * 3 {
                result["suspicious"] := true
                if result["confidence"] < 70
                    result["confidence"] := 70
            }
        }

        ; Set packer name
        if detectedPackers.Length > 0 {
            result["packer"] := StrJoin(detectedPackers, " + ")
        } else if result["suspicious"] {
            result["packer"] := "Unknown (suspicious)"
            result["packed"] := true
        } else {
            ; Not packed and not suspicious
            result["packer"] := "None"
            result["confidence"] := 100  ; High confidence it's not packed
        }

        ; Check for AutoHotkey signature
        stage := "detect-ahk"
        result["isAHK"] := DetectAutoHotkeyViaManifest(filePath)

        return result
    }
    catch as err {
        return Map("error", err.Message, "file", err.File, "line", err.Line, "what", err.What, "stage", stage)
    }
}

/**
 * DetectAutoHotkeyViaManifest - Detects AHK executables via RT_MANIFEST
 * @param filePath - Path to executable to check
 * @return Boolean - true if AHK signatures found in manifest
 */
DetectAutoHotkeyViaManifest(filePath) {
    ; Tries to read RT_MANIFEST (type 24) via LoadLibraryEx and scans for known AutoHotkey identifiers
    hMod := 0
    try {
        hMod := DllCall("LoadLibraryExW", "Str", filePath, "Ptr", 0, "UInt", 0x00000002 | 0x00000020, "Ptr") ; LOAD_LIBRARY_AS_DATAFILE | AS_IMAGE_RESOURCE
        if !hMod
            return false
        hRes := DllCall("FindResourceW", "Ptr", hMod, "Ptr", 1, "UInt", 24, "Ptr") ; resource #1, type 24 (manifest)
        if !hRes {
            DllCall("FreeLibrary", "Ptr", hMod)
            return false
        }
        size := DllCall("SizeofResource", "Ptr", hMod, "Ptr", hRes, "UInt")
        hGlobal := DllCall("LoadResource", "Ptr", hMod, "Ptr", hRes, "Ptr")
        p := DllCall("LockResource", "Ptr", hGlobal, "Ptr")
        content := ""
        if p && size {
            bom := NumGet(p, 0, "UShort")
            if (bom = 0xFEFF || bom = 0xFFFE) {
                content := StrGet(p, size // 2, "UTF-16")
            } else {
                ; Most manifests are UTF-8 without BOM
                content := StrGet(p, size, "UTF-8")
            }
        }
        DllCall("FreeLibrary", "Ptr", hMod)
        if content = ""
            return false
        ahkManifestIds := [
            "AutoHotkey",
            "Microsoft.Windows.AutoHotkey",
            "AutoHotkeyScript"
        ]
        for sig in ahkManifestIds {
            if InStr(content, sig)
                return true
        }
        return false
    } catch {
        if hMod
            DllCall("FreeLibrary", "Ptr", hMod)
        return false
    }
}

; ====================================================================
; RCDATA EXTRACTION FUNCTIONS
; ====================================================================

/**
 * ExtractAHKScriptFromRCData - Extracts AHK script directly from RT_RCDATA
 * @param exePath - Path to AHK executable
 * @param outputDir - Directory to save extracted script
 * @param outputFileName - Optional output filename (if not provided, generated from exePath)
 * @return String - Path to extracted file, or false on failure
 */
ExtractAHKScriptFromRCData(exePath, outputDir, outputFileName := "") {
    ; Try to extract AHK script from RCData resources
    hMod := 0
    try {
        ; Load the executable as a data file
        hMod := DllCall("LoadLibraryExW", "Str", exePath, "Ptr", 0, "UInt", 0x00000002 | 0x00000020, "Ptr")
        if !hMod
            return false

        ; Enumerate through RCData resources (type 10)
        ; Try common resource IDs and names used by AutoHotkey compilers

        ; First try named resources used by older AHK versions
        namedResources := [">AHK WITH ICON<", ">AUTOHOTKEY SCRIPT<"]

        for resName in namedResources {
            hRes := DllCall("FindResourceW", "Ptr", hMod, "Str", resName, "UInt", 10, "Ptr")
            if (hRes && TryExtractResource(hMod, hRes, exePath, outputDir, outputFileName, &result)) {
                DllCall("FreeLibrary", "Ptr", hMod)
                return result
            }
        }

        ; Then try numeric resource IDs
        resourceIDs := [1, 2, 3, 4, 5, 10, 100, 101, 102, 1000]

        for resID in resourceIDs {
            hRes := DllCall("FindResourceW", "Ptr", hMod, "Ptr", resID, "UInt", 10, "Ptr")  ; 10 = RT_RCDATA
            if !hRes
                continue

            if (TryExtractResource(hMod, hRes, exePath, outputDir, outputFileName, &result)) {
                DllCall("FreeLibrary", "Ptr", hMod)
                return result
            }
        }

        DllCall("FreeLibrary", "Ptr", hMod)
        return false
    } catch as err {
        if hMod
            DllCall("FreeLibrary", "Ptr", hMod)
        return false
    }
}

/**
 * TryExtractResource - Helper function to extract and validate a resource
 * @param hMod - Module handle
 * @param hRes - Resource handle
 * @param exePath - Original executable path
 * @param outputDir - Output directory
 * @param outputFileName - Optional output filename (if empty, generated from exePath)
 * @param result - ByRef parameter for the extracted file path
 * @return Boolean - true if extraction succeeded, false otherwise
 */
TryExtractResource(hMod, hRes, exePath, outputDir, outputFileName, &result) {
    result := false

    size := DllCall("SizeofResource", "Ptr", hMod, "Ptr", hRes, "UInt")
    if !size || size < 20  ; Too small to be a script
        return false

    hGlobal := DllCall("LoadResource", "Ptr", hMod, "Ptr", hRes, "Ptr")
    if !hGlobal
        return false

    pData := DllCall("LockResource", "Ptr", hGlobal, "Ptr")
    if !pData
        return false

    ; Read the data and check for the signature
    content := ""
    try {
        ; Try UTF-16 LE first (common for AHK compiled scripts)
        bom := NumGet(pData, 0, "UShort")
        if (bom = 0xFEFF) {
            content := StrGet(pData, size // 2, "UTF-16")
        } else {
            ; Try UTF-8
            content := StrGet(pData, size, "UTF-8")
            ; If that didn't work, try CP0 (ANSI)
            if (content = "" || !InStr(content, ";"))
                content := StrGet(pData, size, "CP0")
        }
    }

    ; Check if this resource contains the AHK script signature
    if InStr(content, "; <COMPILER:") = 1 {
        ; Extract to file - use provided filename or generate from exePath
        ; Normalize outputDir to avoid double backslashes (e.g., root directories like "D:\")
        normalizedDir := RTrim(outputDir, "\")

        if (outputFileName = "") {
            baseName := RegExReplace(exePath, ".*\\", "")
            baseName := RegExReplace(baseName, "\.[^.]+$", "")
            outputFile := normalizedDir . "\" . baseName . "_decompiled.ahk"
        } else {
            outputFile := normalizedDir . "\" . outputFileName
        }

        try {
            ; Normalize line endings to CR/LF
            content := StrReplace(content, "`r`n", "`n")  ; Remove existing CR/LF
            content := StrReplace(content, "`r", "`n")     ; Convert lone CR to LF
            content := StrReplace(content, "`n", "`r`n")   ; Convert all LF to CR/LF

            ; Write as UTF-8 without BOM
            FileObj := FileOpen(outputFile, "w", "UTF-8-RAW")
            if FileObj {
                FileObj.Write(content)
                FileObj.Close()
                result := outputFile
                return true
            }
        }
    }

    return false
}

; ====================================================================
; UPX DETECTION
; ====================================================================

/**
 * IsUPXPacked - Detects if executable is UPX-packed by checking PE section names
 * @param exePath - Path to executable to check
 * @param logFile - Optional log file path for detection logging
 * @return Integer - 1 if UPX detected, 0 if not UPX, -1 if detection failed
 */
IsUPXPacked(exePath, logFile := "") {
    LogDetection(logFile, "UPX Detection: Analyzing " . exePath)

    try {
        ; Validate file exists
        if (!FileExist(exePath)) {
            LogDetection(logFile, "UPX Detection: File does not exist")
            return -1
        }

        ; Open file in binary read mode
        fileObj := FileOpen(exePath, "r")
        if (!IsObject(fileObj)) {
            LogDetection(logFile, "UPX Detection: Failed to open file")
            return -1
        }

        ; Read DOS header (first 64 bytes)
        dosHeader := Buffer(64)
        bytesRead := fileObj.RawRead(dosHeader, 64)
        if (bytesRead < 64) {
            fileObj.Close()
            LogDetection(logFile, "UPX Detection: File too small for PE format")
            return -1
        }

        ; Validate MZ signature at offset 0x00
        mz := ReadBytes(dosHeader, 0, 2)
        if (mz != "MZ") {
            fileObj.Close()
            LogDetection(logFile, "UPX Detection: Not a valid PE file (no MZ signature)")
            return 0  ; Not a PE file = not UPX-packed
        }

        ; Read e_lfanew at offset 0x3C (pointer to PE header)
        e_lfanew := ReadDWord(dosHeader, 0x3C)

        ; Sanity check: e_lfanew should be reasonable (between 64 bytes and 4MB)
        if (e_lfanew < 64 || e_lfanew > 0x400000) {
            fileObj.Close()
            LogDetection(logFile, "UPX Detection: Invalid e_lfanew offset: " . e_lfanew)
            return -1
        }

        ; Seek to PE header location
        fileObj.Seek(e_lfanew, 0)

        ; Read PE header (4 bytes signature + 20 bytes COFF header)
        peHeader := Buffer(24)
        bytesRead := fileObj.RawRead(peHeader, 24)
        if (bytesRead < 24) {
            fileObj.Close()
            LogDetection(logFile, "UPX Detection: Failed to read PE header")
            return -1
        }

        ; Validate PE signature ("PE\0\0")
        peSig := ReadBytes(peHeader, 0, 2)
        if (peSig != "PE") {
            fileObj.Close()
            LogDetection(logFile, "UPX Detection: Invalid PE signature")
            return -1
        }

        ; Read NumberOfSections at offset PE+6 (within COFF header)
        numberOfSections := ReadWord(peHeader, 6)

        ; Sanity check: reasonable number of sections (typically < 100)
        if (numberOfSections < 1 || numberOfSections > 100) {
            fileObj.Close()
            LogDetection(logFile, "UPX Detection: Invalid number of sections: " . numberOfSections)
            return -1
        }

        ; Read SizeOfOptionalHeader at offset PE+20
        sizeOfOptionalHeader := ReadWord(peHeader, 20)

        ; Sanity check: optional header size should be reasonable (typically 224 for PE32+, 96 for PE32)
        if (sizeOfOptionalHeader < 96 || sizeOfOptionalHeader > 512) {
            fileObj.Close()
            LogDetection(logFile, "UPX Detection: Invalid optional header size: " . sizeOfOptionalHeader)
            return -1
        }

        ; Calculate section headers offset: PE + 24 (COFF header) + SizeOfOptionalHeader
        sectionsOffset := e_lfanew + 24 + sizeOfOptionalHeader

        ; Seek to section headers
        fileObj.Seek(sectionsOffset, 0)

        ; Read all section headers (40 bytes each)
        sectionsData := Buffer(numberOfSections * 40)
        bytesRead := fileObj.RawRead(sectionsData, numberOfSections * 40)
        if (bytesRead < numberOfSections * 40) {
            fileObj.Close()
            LogDetection(logFile, "UPX Detection: Failed to read section headers")
            return -1
        }

        ; Close file - we have all the data we need
        fileObj.Close()

        ; Check each section name for UPX signature
        LogDetection(logFile, "UPX Detection: Checking " . numberOfSections . " sections")
        Loop numberOfSections {
            sectionOffset := (A_Index - 1) * 40
            sectionName := ReadBytes(sectionsData, sectionOffset, 8)

            ; Log section name for debugging
            LogDetection(logFile, "  Section " . A_Index . ": " . sectionName)

            ; Check if section name matches UPX pattern (UPX0, UPX1, UPX2, etc.)
            ; Use case-insensitive comparison
            if (RegExMatch(sectionName, "i)^UPX[0-9]$")) {
                LogDetection(logFile, "UPX Detection: UPX signature found in section: " . sectionName)
                return 1  ; UPX detected
            }
        }

        ; No UPX sections found
        LogDetection(logFile, "UPX Detection: No UPX sections found - file is not UPX-packed")
        return 0

    } catch Error as err {
        LogDetection(logFile, "UPX Detection ERROR: " . err.Message)
        return -1
    }
}

; ====================================================================
; HELPER FUNCTIONS
; ====================================================================

/**
 * HasValue - Checks if array contains value
 * @param arr - Array to search
 * @param value - Value to find
 * @return Boolean - true if found
 */
HasValue(arr, value) {
    for item in arr {
        if item == value
            return true
    }
    return false
}

/**
 * StrJoin - Joins array elements with delimiter
 * @param arr - Array to join
 * @param delimiter - String to insert between elements
 * @return String - Joined string
 */
StrJoin(arr, delimiter := ", ") {
    result := ""
    for item in arr
        result .= (result ? delimiter : "") . item
    return result
}

/**
 * ReadDWord - Read 4-byte little-endian DWORD from buffer
 * @param buffer - Buffer object containing binary data
 * @param offset - Offset position to read from (0-indexed)
 * @return Integer - 32-bit unsigned integer value
 */
ReadDWord(buffer, offset) {
    return NumGet(buffer, offset, "UInt")
}

/**
 * ReadWord - Read 2-byte little-endian WORD from buffer
 * @param buffer - Buffer object containing binary data
 * @param offset - Offset position to read from (0-indexed)
 * @return Integer - 16-bit unsigned integer value
 */
ReadWord(buffer, offset) {
    return NumGet(buffer, offset, "UShort")
}

/**
 * ReadBytes - Read byte sequence as string from buffer
 * @param buffer - Buffer object containing binary data
 * @param offset - Offset position to start reading from (0-indexed)
 * @param length - Number of bytes to read
 * @return String - ASCII string (stops at first null byte)
 */
ReadBytes(buffer, offset, length) {
    result := ""
    Loop length {
        byte := NumGet(buffer, offset + A_Index - 1, "UChar")
        if (byte = 0)
            break
        result .= Chr(byte)
    }
    return result
}

/**
 * LogDetection - Append message to log file (if provided)
 * @param logFile - Path to log file (empty string = no logging)
 * @param message - Message to append to log
 */
LogDetection(logFile, message) {
    if (logFile != "") {
        FileAppend(message . "`n", logFile, "UTF-8-RAW")
    }
}
