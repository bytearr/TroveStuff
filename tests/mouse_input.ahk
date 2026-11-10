#Requires AutoHotkey v1.1.33+
#NoEnv
#SingleInstance Force
SetTitleMatchMode, 3
CoordMode, Mouse, Screen
OnExit("Cleanup")
root := A_ScriptDir "\.."
app := root "\ShipDestroyer1.1\ShipDestroyer.ahk"
logPath := A_ScriptDir "\mouse-keys.log"
FileDelete, %logPath%
Run, "%A_ScriptDir%\Trove.exe" /ErrorStdOut "%A_ScriptDir%\fake-client.ahk" "%logPath%",,, fakePID
WinWait, Trove fixture,, 10
if (ErrorLevel)
    Fail("Fixture did not start")
Run, "%A_AhkPath%" /ErrorStdOut "%app%",,, appPID
WinWait, Ship Destroyer,, 10
if (ErrorLevel)
    Fail("Dashboard did not start")
window := "Ship Destroyer"
WinActivate, %window%
WinWaitActive, %window%,, 3
Sleep, 200
; Actual pointer clicks exercise Windows hit testing, unlike ControlClick/BM_CLICK.
for _, combo in ["ComboBox1", "ComboBox2"] {
    MouseClickControl(combo)
    ControlGet, hwnd, Hwnd,, %combo%, %window%
    SendMessage, 0x157, 0, 0,, ahk_id %hwnd%
    if (!ErrorLevel)
        Fail("Mouse did not open " combo)
    Send, {Down}{Enter}
    Sleep, 100
}
ControlGet, selected, Choice,, ComboBox2, %window%
if (selected != "Dracolyte")
    Fail("Class selection did not change via mouse-opened dropdown")
for _, caption in ["Use all detected clients (up to 8)", "Collect loot", "Attack rotation", "Anti-AFK movement"] {
    ControlGet, before, Checked,, %caption%, %window%
    MouseClickControl(caption, false)
    ControlGet, after, Checked,, %caption%, %window%
    if (before = after)
        Fail("Mouse did not toggle " caption)
    MouseClickControl(caption, false)
}
MouseClickControl("Refresh clients", false)
WinGetText, contents, %window%
if (!InStr(contents, "1 client(s) available"))
    Fail("Refresh did not finish")
WinClose, %window%
WinWaitClose, %window%,, 3
; The old AntiCrash entry point must now present recovery-only controls.
wrapper := root "\AntiCrash tr0ve.ahk"
Run, "%A_AhkPath%" /ErrorStdOut "%wrapper%"
window := "AntiCrash Trove"
WinWait, %window%,, 10
if (ErrorLevel)
    Fail("Dedicated AntiCrash window did not open")
WinGet, appPID, PID, %window%
WinActivate, %window%
WinWaitActive, %window%,, 3
Sleep, 200
for _, control in ["ComboBox2", "Collect loot", "Attack rotation", "Anti-AFK movement"] {
    ControlGet, visible, Visible,, %control%, %window%
    if (visible)
        Fail("Recovery mode exposed " control)
}
MouseClickControl("ComboBox1")
Send, {Enter}
MouseClickControl("ComboBox3")
Send, {Down}{Enter}
Sleep, 100
FileDelete, %logPath%
MouseClickControl("Start monitoring", false)
WinGetText, contents, %window%
if (!InStr(contents, "Monitoring / single client / Steam"))
    Fail("Recovery mode did not start monitoring")
MouseClickControl("Stop / F8", false)
WinClose, %window%
WinWaitClose, %window%,, 3
Sleep, 100
FileGetSize, size, %logPath%
if (size > 0)
    Fail("Recovery-only mode sent game input")
FileAppend, Physical mouse and AntiCrash entry-point tests passed.`n, *
ExitApp, 0

MouseClickControl(control, rightEdge := true) {
    global window
    ControlGet, hwnd, Hwnd,, %control%, %window%
    if (!hwnd)
        Fail("Missing control: " control)
    VarSetCapacity(rect, 16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", &rect)
    x := rightEdge ? NumGet(rect, 8, "Int") - 12 : NumGet(rect, 0, "Int") + 12
    y := (NumGet(rect, 4, "Int") + NumGet(rect, 12, "Int")) // 2
    Click, %x%, %y%
    Sleep, 150
}
Fail(message) {
    FileAppend, %message%`n, **
    ExitApp, 1
}
Cleanup(reason, code) {
    global appPID, fakePID
    if (appPID)
        Process, Close, %appPID%
    if (fakePID)
        Process, Close, %fakePID%
}
