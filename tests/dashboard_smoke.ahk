#Requires AutoHotkey v1.1.33+
#NoEnv
#SingleInstance Force
SetTitleMatchMode, 3
SetControlDelay, -1
SetWorkingDir, %A_ScriptDir%
OnExit("Cleanup")
root := A_ScriptDir "\.."
app := root "\ShipDestroyer1.1\ShipDestroyer.ahk"
logPath := A_ScriptDir "\keys.log"
FileDelete, %logPath%
FileCopy, %A_AhkPath%, %A_ScriptDir%\Trove.exe, 1
Run, "%A_ScriptDir%\Trove.exe" /ErrorStdOut "%A_ScriptDir%\fake-client.ahk" "%logPath%",,, fakePID
WinWait, Trove fixture,, 10
if (ErrorLevel)
    Fail("Fixture did not start")
Run, "%A_AhkPath%" /ErrorStdOut "%app%",,, appPID
WinWait, Ship Destroyer,, 10
if (ErrorLevel)
    Fail("Dashboard did not start")
Sleep, 300
AssertText("1 client(s) available")
ControlClick, Start session, Ship Destroyer,,,, NA
Sleep, 350
AssertText("Running / Boomeranger")
ControlClick, Stop / F8, Ship Destroyer,,,, NA
Sleep, 200
AssertText("Stopped. All held keys released.")
FileRead, keys, %logPath%
if (!InStr(keys, "DOWN 77") || !InStr(keys, "UP 77") || !InStr(keys, "UP 69"))
    Fail("Attack/loot keys were not pressed and released")
FileGetSize, stoppedSize, %logPath%
Sleep, 600
FileGetSize, laterSize, %logPath%
if (stoppedSize != laterSize)
    Fail("Input continued after stop")
; Start twice must not stack a second rotation.
ControlClick, Start session, Ship Destroyer,,,, NA
ControlClick, Start session, Ship Destroyer,,,, NA
Sleep, 200
AssertText("Running / Boomeranger")
; Disconnection must stop a non-recovery session.
Process, Close, %fakePID%
Sleep, 400
AssertText("Client disconnected.")
ControlClick, Refresh clients, Ship Destroyer,,,, NA
Sleep, 100
AssertText("Open Trove, then refresh clients.")
ControlClick, Start session, Ship Destroyer,,,, NA
Sleep, 100
AssertText("No connected client selected.")
; Return to the empty state for the screenshot captured by PowerShell.
ControlClick, Refresh clients, Ship Destroyer,,,, NA
FileAppend, Dashboard smoke tests passed.`n, *
; Tell the parent where the window is, then allow it to capture the real UI.
FileAppend, %appPID%, %A_ScriptDir%\dashboard-ready.txt
Sleep, 5000
ExitApp, 0

AssertText(expected) {
    WinGetText, actual, Ship Destroyer
    if (!InStr(actual, expected))
        Fail("Missing UI state: " expected " / " actual)
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
