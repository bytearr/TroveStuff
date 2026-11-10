#Requires AutoHotkey v1.1.33+
#NoEnv
#SingleInstance Force
SetTitleMatchMode, 3
SetControlDelay, -1
OnExit("Cleanup")
root := A_ScriptDir "\.."
app := root "\ShipDestroyer1.1\ShipDestroyer.ahk"
pids := []
Loop, 8 {
    path := A_ScriptDir "\eight-" A_Index ".log"
    FileDelete, %path%
    Run, "%A_ScriptDir%\Trove.exe" /ErrorStdOut "%A_ScriptDir%\fake-client.ahk" "%path%",,, pid
    pids.Push(pid)
}
deadline := A_TickCount + 10000
Loop {
    WinGet, count, Count, ahk_exe Trove.exe
    if (count = 8)
        break
    if (A_TickCount > deadline)
        Fail("Eight fixtures did not start")
    Sleep, 100
}
Run, "%A_AhkPath%" /ErrorStdOut "%app%",,, appPID
window := "Ship Destroyer"
WinWait, %window%,, 10
if (ErrorLevel)
    Fail("Dashboard did not start")
WaitStatus("8 client(s) available")
Sleep, 200
Control, Check,, Use all detected clients (up to 8), %window%
Sleep, 150
ControlClick, Start session, %window%,,,, NA
WaitStatus("Running / Boomeranger / 8 client(s)")
Sleep, 1500
Send, {F8}
WaitStatus("Stopped. All held keys released.")
Sleep, 200
sizes := []
Loop, 8 {
    path := A_ScriptDir "\eight-" A_Index ".log"
    FileRead, keys, %path%
    if (!InStr(keys, "DOWN 77") || !InStr(keys, "UP 77") || !InStr(keys, "DOWN 69") || !InStr(keys, "UP 69"))
        Fail("Missing attack/loot cleanup for client " A_Index)
    FileGetSize, size, %path%
    sizes.Push(size)
}
Sleep, 400
Loop, 8 {
    path := A_ScriptDir "\eight-" A_Index ".log"
    FileGetSize, size, %path%
    if (size != sizes[A_Index])
        Fail("F8 did not stop client " A_Index)
}
WinClose, %window%
WinWaitClose, %window%,, 3
for index, pid in pids {
    if (index != 1)
        Process, Close, %pid%
}
Sleep, 200
FileCopy, %A_AhkPath%, %A_ScriptDir%\GlyphClient.exe, 1
recoveredLog := A_ScriptDir "\recovered-keys.log"
marker := A_ScriptDir "\launcher-click.log"
FileDelete, %recoveredLog%
FileDelete, %marker%
Run, "%A_ScriptDir%\GlyphClient.exe" /ErrorStdOut "%A_ScriptDir%\fake-launcher.ahk" "%recoveredLog%" "%marker%",,, launcherPID
WinWait, Glyph fixture,, 10
if (ErrorLevel)
    Fail("Fake Glyph did not start")
Run, "%A_AhkPath%" /ErrorStdOut "%app%" --recovery,,, appPID
window := "AntiCrash Trove"
WinWait, %window%,, 10
if (ErrorLevel)
    Fail("AntiCrash did not start")
WaitStatus("1 client(s) available")
Sleep, 150
ControlClick, Start monitoring, %window%,,,, NA
WaitStatus("Monitoring / single client / Glyph")
pid := pids[1]
Process, Close, %pid%
WaitStatus("Client disconnected.")
WaitStatus("Client reconnected.", 12000)
if (!FileExist(marker))
    Fail("Recovery did not use the fake launcher")
WinGet, replacement, PID, ahk_exe Trove.exe
pids.Push(replacement)
Sleep, 500
ControlClick, Stop / F8, %window%,,,, NA
WaitStatus("Stopped.")
FileGetSize, size, %recoveredLog%
if (size > 0)
    Fail("Recovery sent attack input to replacement client")
; Stopping during the recovery delay must cancel the pending launcher click.
ControlClick, Refresh clients, %window%,,,, NA
WaitStatus("1 client(s) available")
Sleep, 150
ControlClick, Start monitoring, %window%,,,, NA
WaitStatus("Monitoring / single client / Glyph")
FileDelete, %marker%
Process, Close, %replacement%
WaitStatus("Client disconnected.")
ControlClick, Stop / F8, %window%,,,, NA
WaitStatus("Stopped.")
Sleep, 3500
if (FileExist(marker))
    Fail("Launcher was clicked after cancelling recovery")
WaitStatus("Stopped.")
FileAppend, Eight-client F8 cleanup and crash recovery/cancellation passed.`n, *
ExitApp, 0
WaitStatus(expected, timeout := 5000) {
    global window
    deadline := A_TickCount + timeout
    Loop {
        WinGetText, contents, %window%
        if (InStr(contents, expected))
            return
        if (A_TickCount > deadline)
            Fail("Missing state: " expected " / " contents)
        Sleep, 50
    }
}
Fail(message) {
    FileAppend, %message%`n, **
    ExitApp, 1
}
Cleanup(reason, code) {
    global pids, appPID, launcherPID
    if (appPID)
        Process, Close, %appPID%
    if (launcherPID)
        Process, Close, %launcherPID%
    for _, pid in pids
        Process, Close, %pid%
}
