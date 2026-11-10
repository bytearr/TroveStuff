#Requires AutoHotkey v1.1.33+
#NoEnv
#SingleInstance Off
logPath := A_Args[1]
marker := A_Args[2]
launched := false
Gui, Show, w400 h200, Glyph fixture
OnMessage(0x201, "LaunchClient")
return
LaunchClient() {
    global logPath, marker, launched
    if (launched)
        return
    launched := true
    FileAppend, Launcher clicked.`n, %marker%
    Run, "%A_ScriptDir%\Trove.exe" /ErrorStdOut "%A_ScriptDir%\fake-client.ahk" "%logPath%"
}
GuiClose:
ExitApp
