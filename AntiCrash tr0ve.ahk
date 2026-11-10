#Requires AutoHotkey v1.1.33+
#NoEnv
; Compatibility entry point. Recovery lives in the maintained dashboard.
Run, "%A_AhkPath%" "%A_ScriptDir%\ShipDestroyer1.1\ShipDestroyer.ahk", %A_ScriptDir%, UseErrorLevel
if (ErrorLevel)
    MsgBox, 16, Trove Toolkit, Could not open ShipDestroyer1.1\ShipDestroyer.ahk. Keep the repository folders together.
ExitApp
