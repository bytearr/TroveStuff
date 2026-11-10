#Requires AutoHotkey v1.1.33+
#NoEnv
#Include %A_ScriptDir%\..\lib\Profiles.ahk
for _, name in ["Boomeranger", "Dracolyte", "Ice Sage", "Lunar Lancer"] {
    for _, loot in [false, true] {
        held := {}
        steps := BuildProfile(name, loot)
        if (steps.Length() < 2)
            Fail("Missing profile: " name)
        for _, action in steps {
            if (action.delay <= 0)
                Fail("Invalid delay: " name)
            position := 1
            while (position := RegExMatch(action.keys, "\{([^ }]+) (down|up)\}", match, position)) {
                held[match1] := match2 = "down"
                position += StrLen(match)
            }
        }
        if (name = "Dracolyte" && !held.HasKey("m"))
            Fail("Dracolyte must use primary attack")
        for key, down in held {
            if (down)
                Fail("Unreleased key: " name " / " key)
        }
        if (loot && !held.HasKey("e"))
            Fail("Missing loot: " name)
        if (!loot && held.HasKey("e"))
            Fail("Unexpected loot: " name)
    }
}
if (BuildProfile("unknown").Length())
    Fail("Unknown profile must be empty")
FileAppend, Profile tests passed.`n, *
ExitApp, 0

Fail(message) {
    FileAppend, %message%`n, **
    ExitApp, 1
}
