#Requires AutoHotkey v2.0

; ====================================================================
; AHK-Hacker - Notification Helper Library
; ====================================================================
; Shared notification functions for showing progress and status messages
; Usage: #Include lib/Notifications.ahk
; ====================================================================

/**
 * ShowProgress - Display a system tray notification
 * @param message - The message to display
 * @param iconType - Icon type:
 *                   0 = No icon (or Success)
 *                   1 = Info icon
 *                   2 = Warning icon
 *                   3 = Error icon
 * @param title - Optional title for the notification (default: "AHK-Hacker")
 */
ShowProgress(message, iconType := 1, title := "AHK-Hacker") {
    TrayTip(message, title, iconType)
}
