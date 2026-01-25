#Requires AutoHotkey v2.0
#Include Notifications.ahk

; ====================================================================
; AHK-Hacker - Executable Unpacker (UPX only)
; ====================================================================
; This library attempts to unpack UPX-compressed executables.
;
; Usage: #Include lib/Unpack-Exe.ahk
;        unpackedPath := TryUnpackExe(exePath, logFile)
; ====================================================================

; Global silent mode flag (set by parent script)
global SilentMode := false

/**
 * TryUnpackExe - Attempts to unpack a UPX-compressed executable
 * @param exePath - Path to the packed executable
 * @param logFile - Path to log file for appending unpacking logs
 * @param writableDir - Optional writable directory for output (defaults to source directory)
 * @return String - Path to unpacked temp file on success, "" on failure
 */
TryUnpackExe(exePath, logFile, writableDir := "") {
    ; Generate temporary output path for unpacked exe
    SplitPath(exePath, &fileName, &fileDir)
    timestamp := A_Now
    targetDir := (writableDir != "") ? writableDir : fileDir
    unpackedPath := targetDir . "\" . fileName . ".unpacked." . timestamp . ".tmp"

    ; Append to log
    FileAppend("`n===== UNPACKING ATTEMPT (UPX) =====`n", logFile, "UTF-8-RAW")
    FileAppend("Original file: " . exePath . "`n", logFile, "UTF-8-RAW")

    ; Find or download UPX
    ShowProgress("Looking for UPX unpacker...", 1, "AHK-Hacker")
    upxPath := FindUpx()

    if (upxPath = "") {
        FileAppend("UPX not found - downloading...`n", logFile, "UTF-8-RAW")
        ShowProgress("Downloading UPX unpacker...", 1, "AHK-Hacker")
        upxPath := DownloadUpx(logFile)

        if (upxPath = "") {
            FileAppend("Failed to download UPX`n", logFile, "UTF-8-RAW")
            return ""
        }
    }

    FileAppend("Using UPX: " . upxPath . "`n", logFile, "UTF-8-RAW")

    ; Run UPX unpacker
    ShowProgress("Unpacking with UPX...", 1, "AHK-Hacker")

    ; UPX syntax: upx -d -o output.exe input.exe
    cmd := '"' . upxPath . '" -d -o "' . unpackedPath . '" "' . exePath . '"'    

    FileAppend("Running UPX: " . cmd . "`n", logFile, "UTF-8-RAW")

    try {
        RunWait(cmd, , "Hide")
        Sleep(200)

        ; Check if output file was created
        if (FileExist(unpackedPath)) {
            ; Verify it's a valid PE file (starts with MZ)
            fileObj := FileOpen(unpackedPath, "r")
            magic := fileObj.Read(2)
            fileObj.Close()

            if (magic = "MZ") {
                FileAppend("UPX unpacking succeeded`n", logFile, "UTF-8-RAW")
                ShowProgress("Successfully unpacked with UPX", 0, "AHK-Hacker")
                return unpackedPath
            } else {
                try FileDelete(unpackedPath)
                FileAppend("UPX unpacking failed - invalid PE file`n", logFile, "UTF-8-RAW")
            }
        } else {
            FileAppend("UPX unpacking failed - no output file`n", logFile, "UTF-8-RAW")
        }
    } catch Error as e {
        try FileDelete(unpackedPath)
        FileAppend("UPX unpacking failed with error: " . e.Message . "`n", logFile, "UTF-8-RAW")
    }

    return ""
}

/**
 * FindUpx - Locates UPX in known locations
 * @return String - Path to upx.exe, or "" if not found
 */
FindUpx() {
    searchPaths := []

    ; Check AutoHotkey Compiler directory
    searchPaths.Push(A_ProgramFiles . "\AutoHotkey\Compiler\upx.exe")

    ; Get bin directory relative to AHK-Hacker.exe location
    SplitPath(A_ScriptFullPath, , &installDir)
    searchPaths.Push(installDir . "\bin\upx.exe")

    ; Check each location
    for index, path in searchPaths {
        if (FileExist(path)) {
            return path
        }
    }

    return ""
}

/**
 * DownloadUpx - Downloads UPX from GitHub releases
 * @param logFile - Path to log file
 * @return String - Path to downloaded upx.exe, or "" on failure
 */
DownloadUpx(logFile) {
    ; Get bin directory
    SplitPath(A_ScriptFullPath, , &installDir)
    binDir := installDir . "\bin"

    ; Ensure bin directory exists
    if (!FileExist(binDir)) {
        DirCreate(binDir)
    }

    ; Get latest UPX version from GitHub API
    apiUrl := "https://api.github.com/repos/upx/upx/releases/latest"

    try {
        ; Download JSON response
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", apiUrl, false)
        whr.SetRequestHeader("User-Agent", "AHK-Hacker")
        whr.Send()

        jsonResponse := whr.ResponseText

        ; Parse browser_download_url for win64 zip
        if (RegExMatch(jsonResponse, '"browser_download_url"\s*:\s*"([^"]*win64\.zip)"', &match)) {
            zipUrl := match[1]
        } else {
            FileAppend("Failed to find win64.zip download URL from GitHub API`n", logFile, "UTF-8-RAW")
            return ""
        }

        ; Extract version from URL for logging (optional)
        if (RegExMatch(zipUrl, "upx-([0-9.]+)-win64", &verMatch)) {
            version := verMatch[1]
            FileAppend("Downloading UPX v" . version . "...`n", logFile, "UTF-8-RAW")
        } else {
            FileAppend("Downloading UPX...`n", logFile, "UTF-8-RAW")
        }

        tempZip := binDir . "\upx_temp.zip"

        ; Download ZIP
        Download(zipUrl, tempZip)
        if (!FileExist(tempZip)) {
            FileAppend("Failed to download UPX ZIP`n", logFile, "UTF-8-RAW")
            return ""
        }

        ; Extract ZIP to temp folder
        tempExtract := binDir . "\upx_temp_extract"
        if (FileExist(tempExtract)) {
            DirDelete(tempExtract, true)
        }
        DirCreate(tempExtract)

        psExtract := "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"Expand-Archive -Path '" . tempZip . "' -DestinationPath '" . tempExtract . "' -Force`""
        RunWait(psExtract, , "Hide")
        Sleep(500)

        ; Log extracted contents for debugging
        FileAppend("Extracted contents:`n", logFile, "UTF-8-RAW")
        Loop Files, tempExtract . "\*", "DR" {
            FileAppend("  " . A_LoopFileFullPath . "`n", logFile, "UTF-8-RAW")
        }

        ; Find upx.exe recursively
        upxExePath := ""
        Loop Files, tempExtract . "\*", "FR" {
            if (A_LoopFileName = "upx.exe") {
                upxExePath := A_LoopFileFullPath
                break
            }
        }

        if (upxExePath = "") {
            ; Cleanup and fail
            try FileDelete(tempZip)
            try DirDelete(tempExtract, true)
            FileAppend("UPX executable not found in ZIP`n", logFile, "UTF-8-RAW")
            return ""
        }

        ; Copy to bin folder
        finalPath := binDir . "\upx.exe"
        FileCopy(upxExePath, finalPath, true)

        ; Unblock file
        psUnblock := "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"Unblock-File -Path '" . finalPath . "'`""
        RunWait(psUnblock, , "Hide")

        ; Cleanup
        try FileDelete(tempZip)
        try DirDelete(tempExtract, true)

        FileAppend("UPX downloaded successfully to: " . finalPath . "`n", logFile, "UTF-8-RAW")
        return finalPath

    } catch Error as e {
        try FileDelete(binDir . "\upx_temp.zip")
        try DirDelete(binDir . "\upx_temp_extract", true)
        FileAppend("UPX download failed: " . e.Message . "`n", logFile, "UTF-8-RAW")
        return ""
    }
}

; ====================================================================
; PE PARSING HELPER FUNCTIONS
; ====================================================================

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
