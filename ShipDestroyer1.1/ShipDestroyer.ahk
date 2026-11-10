#Requires AutoHotkey v1.1.33+
#NoEnv
#SingleInstance Force
SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%
SetControlDelay, -1
SetKeyDelay, 10, 20
#Include %A_ScriptDir%\..\lib\Profiles.ahk

running := false
recovering := false
clients := []
targets := []
buttons := {}
controlBrushes := {}
step := 1
idleStep := 1
nextAttack := 0
nextIdle := 0
nextRecovery := 0
attempts := 0
OnExit("Cleanup")
OnMessage(0x2B, "DrawButton")
OnMessage(0x7C, "KeepButtonStyle")
Gui, +HwndMainWindow +MinimizeBox -MaximizeBox
Gui, Color, 10141D, 1B2332
Gui, Margin, 0, 0
Gui, Font, s10 cE7EDF7, Segoe UI
; Sidebar
Gui, Add, Progress, x0 y0 w190 h646 Background151B27 c151B27, 100
Gui, Font, s9 Bold c7DD3C7, Segoe UI
Gui, Add, Text, x24 y30 w145 h20 BackgroundTrans, TROVE / TOOLKIT
Gui, Font, s19 Bold cF3F6FC, Segoe UI
Gui, Add, Text, x24 y65 w150 h64 BackgroundTrans, Ship`nDestroyer
Gui, Font, s10 Norm c9BAAC0, Segoe UI
Gui, Add, Text, x24 y154 w142 h48 BackgroundTrans, Session control`nfor your accounts.
Gui, Add, Progress, x24 y226 w142 h1 Background303C50, 0
Gui, Font, s9 Bold c7DD3C7, Segoe UI
Gui, Add, Text, x24 y254 w140 h20 BackgroundTrans, BEFORE YOU START
Gui, Font, s10 Norm cB8C4D6, Segoe UI
Gui, Add, Text, x24 y288 w142 h108 BackgroundTrans, Bind attack to M`nSecondary to O`nLoot to E`nSkills to 1 and 2
Gui, Font, s9 c8392A9, Segoe UI
Gui, Add, Text, x24 y534 w144 h76 BackgroundTrans, F8  Stop everything`nInsert  Show / hide`n`nMars / Vash / Yumo
; Main heading
Gui, Font, s23 Bold cF3F6FC, Segoe UI
Gui, Add, Text, x220 y26 w500 h40, Your session, in control.
Gui, Font, s10 Norm c9BAAC0, Segoe UI
Gui, Add, Text, x222 y76 w504 h24, Select your clients. Choose a profile. Start when ready.
; Connection card
Gui, Add, Progress, x220 y116 w520 h150 Background1B2332 c1B2332, 100
Gui, Font, s9 Bold c7DD3C7, Segoe UI
Gui, Add, Text, x240 y133 w300 h20 BackgroundTrans, 01 / CONNECTED CLIENTS
Gui, Font, s10 Norm cE7EDF7, Segoe UI
Gui, Add, DropDownList, x240 y167 w350 vClientChoice, No Trove clients found
AddButton("Refresh clients", "RefreshClients", 602, 165, 118, 30)
Gui, Add, Checkbox, x240 y217 w460 h24 vAllClients gSelectionChanged BackgroundTrans, Use all detected clients (up to 8)
; Profile card
Gui, Add, Progress, x220 y282 w520 h184 Background1B2332 c1B2332, 100
Gui, Font, s9 Bold c7DD3C7, Segoe UI
Gui, Add, Text, x240 y299 w450 h20 BackgroundTrans, 02 / SESSION PROFILE
Gui, Font, s10 Norm cE7EDF7, Segoe UI
Gui, Add, Text, x240 y334 w200 h22 BackgroundTrans, Character class
Gui, Add, DropDownList, x240 y362 w220 vClassChoice Choose1, Boomeranger|Dracolyte|Ice Sage|Lunar Lancer
Gui, Add, Checkbox, x488 y361 w222 h24 vLoot Checked BackgroundTrans, Collect loot
Gui, Add, Checkbox, x240 y414 w220 h24 vAttackEnabled Checked BackgroundTrans, Attack rotation
Gui, Add, Checkbox, x488 y414 w222 h24 vIdleEnabled BackgroundTrans, Anti-AFK movement
; Recovery and controls
Gui, Font, s10 cB8C4D6, Segoe UI
Gui, Add, Checkbox, x222 y484 w305 h24 vRecoveryEnabled gSelectionChanged, Recover a single disconnected client
Gui, Add, DropDownList, x544 y482 w194 vLauncher Choose1, Glyph|Steam
Gui, Font, s9 c8392A9, Segoe UI
Gui, Add, Text, x222 y516 w510 h20, Glyph recovery needs the launcher open on the Trove page.
AddButton("Start session", "StartSession", 220, 551, 250, 42, "7DD3C7", "10141D")
AddButton("Stop / F8", "StopSession", 488, 551, 252, 42, "303C50", "F3F6FC")
Gui, Font, s10 c7DD3C7, Segoe UI
Gui, Add, Text, x222 y610 w516 h24 vStatus, Ready. Refresh clients to connect.
ApplyTheme()
Gui, Show, w770 h646, Ship Destroyer
Gosub, RefreshClients
SetTimer, Tick, 25
return

RefreshClients:
if (running) {
    SetStatus("Stop the session before refreshing clients.")
    return
}
clients := FindClients()
items := ""
for index, client in clients
    items .= (index = 1 ? "" : "|") client.title "  /  PID " client.pid
if (!clients.Length())
    items := "No Trove clients found"
GuiControl,, ClientChoice, |%items%
GuiControl, Choose, ClientChoice, 1
SetStatus(clients.Length() ? clients.Length() " client(s) available. Ready to start." : "Open Trove, then refresh clients.")
return

SelectionChanged:
Gui, Submit, NoHide
if (AllClients) {
    GuiControl,, RecoveryEnabled, 0
    GuiControl, Disable, RecoveryEnabled
} else
    GuiControl, Enable, RecoveryEnabled
return

StartSession:
Critical
if (running)
    return
Gui, Submit, NoHide
; AltSubmit returns the selected row, avoiding duplicate or renamed titles.
GuiControl, +AltSubmit, ClientChoice
GuiControlGet, selectedIndex, , ClientChoice
GuiControl, -AltSubmit, ClientChoice
if (!AttackEnabled && !IdleEnabled && !RecoveryEnabled) {
    SetStatus("Enable attack, Anti-AFK, or recovery first.")
    return
}
targets := []
if (AllClients) {
    for index, client in clients {
        if (index <= 8 && IsClient(client))
            targets.Push(client)
    }
} else if (clients.HasKey(selectedIndex) && IsClient(clients[selectedIndex]))
    targets.Push(clients[selectedIndex])
if (!targets.Length()) {
    SetStatus("No connected client selected. Refresh clients first.")
    return
}
if (RecoveryEnabled && FindClients().Length() != 1) {
    SetStatus("Recovery requires exactly one open Trove client.")
    return
}
profile := BuildProfile(ClassChoice, Loot)
idleProfile := BuildIdleProfile()
step := 1
idleStep := 1
nextAttack := A_TickCount
nextIdle := A_TickCount
attempts := 0
recovering := false
running := true
LockSettings(true)
SetStatus("Running / " ClassChoice " / " targets.Length() " client(s)")
return

StopSession:
Critical
StopAll()
return

Tick:
Critical
if (!running)
    return
for index, client in targets {
    if (!IsClient(client)) {
        if (RecoveryEnabled && !AllClients && targets.Length() = 1) {
            if (!recovering) {
                recovering := true
                nextRecovery := A_TickCount + 3000
                SetStatus("Client disconnected. Waiting before recovery...")
            }
        } else {
            StopAll("Client disconnected. Refresh clients before restarting.")
            return
        }
    }
}
if (recovering) {
    RecoverClient()
    return
}
now := A_TickCount
if (AttackEnabled && now >= nextAttack) {
    action := profile[step]
    SendTargets(action.keys)
    nextAttack := now + action.delay
    step := Mod(step, profile.Length()) + 1
}
if (IdleEnabled && now >= nextIdle) {
    action := idleProfile[idleStep]
    SendTargets(action.keys)
    nextIdle := now + action.delay
    idleStep := Mod(idleStep, idleProfile.Length()) + 1
}
return

F8::
Gosub, StopSession
return

Insert::
if (DllCall("IsWindowVisible", "Ptr", MainWindow))
    Gui, Hide
else
    Gui, Show
return

GuiClose:
ExitApp
return

FindClients() {
    found := []
    WinGet, windows, List, ahk_exe Trove.exe
    Loop, %windows% {
        hwnd := windows%A_Index%
        WinGetTitle, title, ahk_id %hwnd%
        if (title = "")
            continue
        WinGet, pid, PID, ahk_id %hwnd%
        found.Push({hwnd: hwnd, pid: pid, title: StrReplace(title, "|", "/")})
    }
    return found
}

IsClient(client) {
    hwnd := client.hwnd
    WinGet, pid, PID, ahk_id %hwnd%
    WinGet, exe, ProcessName, ahk_id %hwnd%
    return (pid = client.pid && exe = "Trove.exe")
}

SendTargets(keys) {
    global targets
    if (keys = "")
        return
    for index, client in targets {
        if (IsClient(client)) {
            hwnd := client.hwnd
            ControlSend,, %keys%, ahk_id %hwnd%
        }
    }
}

StopAll(message := "Stopped. All held keys released.") {
    global running, recovering
    running := false
    recovering := false
    SendTargets("{m up}{o up}{e up}{1 up}{2 up}{z up}{Space up}{Esc up}")
    LockSettings(false)
    SetStatus(message)
}

Cleanup(reason, code) {
    global running
    running := false
    SendTargets("{m up}{o up}{e up}{1 up}{2 up}{z up}{Space up}{Esc up}")
}

LockSettings(locked) {
    global AllClients
    for index, name in ["ClientChoice", "AllClients", "ClassChoice", "Loot", "AttackEnabled", "IdleEnabled", "RecoveryEnabled", "Launcher"] {
        action := locked ? "Disable" : "Enable"
        GuiControl, %action%, %name%
    }
    if (!locked && AllClients)
        GuiControl, Disable, RecoveryEnabled
}

SetStatus(message) {
    GuiControl,, Status, %message%
}

RecoverClient() {
    global targets, recovering, nextRecovery, attempts, Launcher, step, idleStep, nextAttack, nextIdle
    if (A_TickCount < nextRecovery)
        return
    found := FindClients()
    if (found.Length() = 1) {
        targets := found
        recovering := false
        attempts := 0
        step := 1
        idleStep := 1
        ; Allow the restarted game to load before resuming input.
        nextAttack := A_TickCount + 15000
        nextIdle := nextAttack
        SetStatus("Client reconnected. Resuming in 15 seconds.")
        return
    }
    if (found.Length() > 1) {
        StopAll("Multiple clients found. Select the correct account manually.")
        return
    }
    if (attempts >= 3) {
        StopAll("Recovery timed out. Check the launcher and refresh clients.")
        return
    }
    attempts += 1
    nextRecovery := A_TickCount + 60000
    if (Launcher = "Steam") {
        Run, steam://rungameid/304050,, UseErrorLevel
        if (ErrorLevel)
            StopAll("Steam could not be opened. Start Trove manually.")
    } else {
        hwnd := WinExist("ahk_exe GlyphClient.exe")
        if (!hwnd) {
            StopAll("Open Glyph on its Trove page before enabling recovery.")
            return
        }
        VarSetCapacity(rect, 16, 0)
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", &rect)
        width := NumGet(rect, 8, "Int")
        height := NumGet(rect, 12, "Int")
        if (width <= 0 || height <= 0) {
            StopAll("Glyph is not ready. Restore its window and try again.")
            return
        }
        position := "x" Round(width * 0.80) " y" Round(height * 0.14)
        ControlClick, %position%, ahk_id %hwnd%,,,, NA
    }
    SetStatus("Recovery attempt " attempts " / 3. Waiting for Trove...")
}

AddButton(text, label, x, y, w, h, bg := "303C50", fg := "E7EDF7") {
    global buttons
    Gui, Font, s10 Bold, Segoe UI
    Gui, Add, Button, x%x% y%y% w%w% h%h% +0xB hwndhandle g%label%, %text%
    buttons[handle] := {text: text, bg: bg, fg: fg}
    ; AHK normalizes button types during creation. Apply owner-draw afterwards.
    style := DllCall("GetWindowLong", "Ptr", handle, "Int", -16, "UInt")
    DllCall("SetWindowLong", "Ptr", handle, "Int", -16, "UInt", (style & ~15) | 11)
    Gui, Font, s10 Norm cE7EDF7, Segoe UI
}

; Owner-drawn native buttons retain keyboard focus and accessibility labels.
DrawButton(wParam, lParam) {
    global buttons
    hwnd := NumGet(lParam + 0, A_PtrSize = 8 ? 24 : 20, "Ptr")
    if (!buttons.HasKey(hwnd))
        return
    button := buttons[hwnd]
    dc := NumGet(lParam + 0, A_PtrSize = 8 ? 32 : 24, "Ptr")
    rect := lParam + (A_PtrSize = 8 ? 40 : 28)
    state := NumGet(lParam + 0, 16, "UInt")
    color := (state & 1) ? "52637C" : button.bg
    brush := DllCall("CreateSolidBrush", "UInt", BGR(color), "Ptr")
    DllCall("FillRect", "Ptr", dc, "Ptr", rect, "Ptr", brush)
    DllCall("DeleteObject", "Ptr", brush)
    DllCall("SetBkMode", "Ptr", dc, "Int", 1)
    DllCall("SetTextColor", "Ptr", dc, "UInt", BGR(button.fg))
    font := DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
    old := DllCall("SelectObject", "Ptr", dc, "Ptr", font, "Ptr")
    DllCall("DrawText", "Ptr", dc, "Str", button.text, "Int", -1, "Ptr", rect, "UInt", 0x25)
    DllCall("SelectObject", "Ptr", dc, "Ptr", old)
    if (state & 0x10)
        DllCall("DrawFocusRect", "Ptr", dc, "Ptr", rect)
    return true
}

BGR(hex) {
    value := "0x" hex
    return ((value & 255) << 16) | (value & 65280) | ((value >> 16) & 255)
}

ApplyTheme() {
    global MainWindow, controlBrushes
    dark := 1
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", MainWindow, "UInt", 20, "Int*", dark, "UInt", 4)
    for _, message in [0x133, 0x134, 0x138]
        OnMessage(message, "ColorControl")
    for _, name in ["ClientChoice", "AllClients", "ClassChoice", "Loot", "AttackEnabled", "IdleEnabled", "RecoveryEnabled", "Launcher"] {
        GuiControlGet, hwnd, Hwnd, %name%
        bg := (name = "RecoveryEnabled" || name = "Launcher") ? "10141D" : "1B2332"
        color := BGR(bg)
        brush := DllCall("CreateSolidBrush", "UInt", color, "Ptr")
        controlBrushes[hwnd] := {brush: brush, color: color}
        if (name = "ClientChoice" || name = "ClassChoice" || name = "Launcher")
            DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "WStr", "DarkMode_CFD", "Ptr", 0)
        else
            DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "WStr", "", "WStr", "")
        ; Color the list popup as well as the closed combo box.
        size := A_PtrSize = 8 ? 64 : 52
        VarSetCapacity(info, size, 0)
        NumPut(size, info, 0, "UInt")
        if (DllCall("GetComboBoxInfo", "Ptr", hwnd, "Ptr", &info)) {
            list := NumGet(info, A_PtrSize = 8 ? 56 : 48, "Ptr")
            controlBrushes[list] := {brush: brush, color: color}
            DllCall("uxtheme\SetWindowTheme", "Ptr", list, "WStr", "DarkMode_Explorer", "Ptr", 0)
        }
    }
}

ColorControl(dc, hwnd) {
    global controlBrushes
    if (!controlBrushes.HasKey(hwnd))
        return
    entry := controlBrushes[hwnd]
    DllCall("SetTextColor", "Ptr", dc, "UInt", BGR("E7EDF7"))
    DllCall("SetBkColor", "Ptr", dc, "UInt", entry.color)
    return entry.brush
}

; The dialog manager changes default-button styles when keyboard focus moves.
; Preserve owner-draw while leaving all other style flags intact.
KeepButtonStyle(which, styles, message, hwnd) {
    global buttons
    if ((which = -16 || which = 0xFFFFFFF0) && buttons.HasKey(hwnd)) {
        style := NumGet(styles + 0, 4, "UInt")
        NumPut((style & ~15) | 11, styles + 0, 4, "UInt")
    }
}
