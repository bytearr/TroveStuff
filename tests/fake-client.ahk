#Requires AutoHotkey v1.1.33+
#NoEnv
#SingleInstance Off
logPath := A_Args[1]
Gui, Add, Text,, Isolated test window. No game is running.
Gui, Show, w360 h90, Trove fixture
OnMessage(0x100, "KeyDown")
OnMessage(0x101, "KeyUp")
return
KeyDown(key) {
    global logPath
    FileAppend, DOWN %key%`n, %logPath%
}
KeyUp(key) {
    global logPath
    FileAppend, UP %key%`n, %logPath%
}
GuiClose:
ExitApp
