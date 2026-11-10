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
FileDelete, %A_ScriptDir%\test-results.log
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
; Two real process handles receive every class/loot combination.
Run, "%A_ScriptDir%\Trove.exe" /ErrorStdOut "%A_ScriptDir%\fake-client.ahk" "%logPath%",,, fakePID
logPath2 := A_ScriptDir "\keys-second.log"
FileDelete, %logPath2%
Run, "%A_ScriptDir%\Trove.exe" /ErrorStdOut "%A_ScriptDir%\fake-client.ahk" "%logPath2%",,, secondPID
Sleep, 500
ControlClick, Refresh clients, Ship Destroyer,,,, NA
Sleep, 100
AssertText("2 client(s) available")
; Recovery must never silently bind to another existing account.
Control, Check,, Recover a single disconnected client, Ship Destroyer
ControlClick, Start session, Ship Destroyer,,,, NA
Sleep, 100
AssertText("Recovery requires exactly one open Trove client.")
Control, Uncheck,, Recover a single disconnected client, Ship Destroyer
Control, Check,, Use all detected clients (up to 8), Ship Destroyer
for _, name in ["Boomeranger", "Dracolyte", "Ice Sage", "Lunar Lancer"] {
    Control, ChooseString, %name%, ComboBox2, Ship Destroyer
    for _, loot in [false, true] {
        action := loot ? "Check" : "Uncheck"
        Control, %action%,, Collect loot, Ship Destroyer
        FileDelete, %logPath%
        FileDelete, %logPath2%
        ControlClick, Start session, Ship Destroyer,,,, NA
        Sleep, 200
        AssertText("Running / " name " / 2 client(s)")
        ControlClick, Stop / F8, Ship Destroyer,,,, NA
        Sleep, 150
        FileRead, first, %logPath%
        FileRead, second, %logPath2%
        key := name = "Ice Sage" ? 79 : 77
        if (!InStr(first, "DOWN " key) || !InStr(second, "DOWN " key))
            Fail("Multi-client attack missing: " name)
        if (!InStr(first, "UP " key) || !InStr(second, "UP " key))
            Fail("Multi-client release missing: " name)
        if (loot != !!InStr(first, "DOWN 69") || loot != !!InStr(second, "DOWN 69"))
            Fail("Loot option incorrect: " name)
    }
}
; Anti-AFK uses its own finite steps and stops independently of attack.
Control, Uncheck,, Attack rotation, Ship Destroyer
Control, Check,, Anti-AFK movement, Ship Destroyer
FileDelete, %logPath%
ControlClick, Start session, Ship Destroyer,,,, NA
Sleep, 250
ControlClick, Stop / F8, Ship Destroyer,,,, NA
Sleep, 200
FileRead, keys, %logPath%
if (!InStr(keys, "DOWN 32") || !InStr(keys, "UP 32"))
    Fail("Anti-AFK jump was not pressed/released")
FileGetSize, stoppedSize, %logPath%
Sleep, 500
FileGetSize, laterSize, %logPath%
if (stoppedSize != laterSize)
    Fail("Anti-AFK continued after stop")
Process, Close, %fakePID%
Process, Close, %secondPID%
Control, Uncheck,, Use all detected clients (up to 8), Ship Destroyer
Control, Check,, Attack rotation, Ship Destroyer
Control, Uncheck,, Anti-AFK movement, Ship Destroyer
Control, ChooseString, Boomeranger, ComboBox2, Ship Destroyer
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
    FileAppend, %message%`n, %A_ScriptDir%\test-results.log
    ExitApp, 1
}
Cleanup(reason, code) {
    global appPID, fakePID, secondPID
    if (appPID)
        Process, Close, %appPID%
    if (fakePID)
        Process, Close, %fakePID%
    if (secondPID)
        Process, Close, %secondPID%
}
