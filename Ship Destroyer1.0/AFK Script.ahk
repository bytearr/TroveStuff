#Requires AutoHotkey v1.1.33+
#NoEnv
; Compatibility entry point. Keep one implementation of the session engine.
Run, "%A_AhkPath%" "%A_ScriptDir%\..\ShipDestroyer1.1\ShipDestroyer.ahk", %A_ScriptDir%, UseErrorLevel
if (ErrorLevel)
    MsgBox, 16, Trove Toolkit, Could not open the current dashboard. Keep the repository folders together.
ExitApp
