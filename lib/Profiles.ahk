; AutoHotkey v1.1. Each step sends keys, then waits without blocking the GUI.
BuildProfile(name, loot := false) {
    pickup := loot ? "{e down}" : ""
    release := loot ? "{e up}" : ""
    if (name = "Boomeranger")
        return [{keys: "{m down}" pickup, delay: 5000}
            , {keys: release "{m up}{o down}", delay: 500}
            , {keys: "{o up}{2 down}", delay: 200}
            , {keys: "{2 up}", delay: 100}]
    if (name = "Dracolyte")
        return [{keys: "{m down}{1 down}" pickup, delay: 100}
            , {keys: "{1 up}", delay: 700}
            , {keys: "{2 down}" release, delay: 100}
            , {keys: "{2 up}{m up}", delay: 100}]
    if (name = "Ice Sage")
        return [{keys: "{o down}{1 down}" pickup, delay: 100}
            , {keys: "{o up}{1 up}", delay: 300}
            , {keys: release, delay: 25}]
    if (name = "Lunar Lancer")
        return [{keys: "{m down}" pickup, delay: 5000}
            , {keys: "{m up}" release, delay: 500}
            , {keys: "{2 down}", delay: 200}
            , {keys: "{2 up}", delay: 100}]
    return []
}

BuildIdleProfile() {
    return [{keys: "{z}{Space}", delay: 400}
        , {keys: "{Space}", delay: 400}
        , {keys: "{Space}", delay: 400}
        , {keys: "{Space}", delay: 20200}]
}
