#Requires AutoHotkey v2.0

; ====================================================================
; AHK-Hacker - Notification Helper Library
; ====================================================================
; Shared notification functions for showing progress and status messages
; Usage: #Include lib/Notifications.ahk
; ====================================================================

/**
 * ShowToast - Display a custom toast notification in bottom-right corner
 * @param message - The message to display
 * @param iconType - Icon type:
 *                   0 = Success (✓ green)
 *                   1 = Info (ℹ blue)
 *                   2 = Warning (⚠ orange)
 *                   3 = Error (✗ red)
 * @param duration - How long to show toast in milliseconds (default: 1000)
 */
ShowToast(message, iconType := 1, duration := 1000) {
    ; Create GUI window with title (no icon - keeps it simple)
    toastGui := Gui("+AlwaysOnTop +ToolWindow", "AHK-Hacker")
    toastGui.BackColor := "FFFFFF"
    toastGui.MarginX := 15
    toastGui.MarginY := 15

    ; Select icon and color based on type
    icons := ["✓", "ℹ", "⚠", "✗"]
    colors := ["4CAF50", "2196F3", "FF9800", "F44336"]

    ; Add icon (colored, large)
    iconCtrl := toastGui.Add("Text", "x15 y25 w30 h30 c" . colors[iconType + 1], icons[iconType + 1])
    iconCtrl.SetFont("s20")

    ; Add message text
    msgCtrl := toastGui.Add("Text", "x55 y15 w280 h60 Center", message)
    msgCtrl.SetFont("s10", "Segoe UI")

    ; Show window (NoActivate prevents stealing focus)
    toastGui.Show("w350 h90 NoActivate")

    ; Position in bottom-right corner
    ; Get work area (screen minus taskbar)
    MonitorGetWorkArea(MonitorGetPrimary(), , , &workRight, &workBottom)
    toastGui.Move(workRight - 370, workBottom - 150)

    ; Auto-dismiss after duration
    SetTimer(() => toastGui.Destroy(), -duration)
}

/**
 * ShowProgress - Display a notification with silent mode support
 * @param message - The message to display
 * @param iconType - Icon type:
 *                   0 = Success
 *                   1 = Info
 *                   2 = Warning
 *                   3 = Error
 * @param title - Optional title (unused, kept for backward compatibility)
 */
ShowProgress(message, iconType := 1, title := "AHK-Hacker") {
    ; Respect global SilentMode flag (if set by parent script)
    if (IsSet(SilentMode) && SilentMode)
        return

    ; Use toast notification with duration based on type
    ; Errors (type 3) show longer (3000ms) so user can read them
    ; Info/warning/success show briefly (1000ms)
    duration := (iconType = 3) ? 3000 : 1000
    ShowToast(message, iconType, duration)

    ; For errors and success, wait for the toast to be displayed before returning
    ; This ensures the toast isn't destroyed by ExitApp() before user sees it
    if (iconType = 3 || iconType = 0) {
        Sleep(duration)
    }
}
