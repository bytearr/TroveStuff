# TroveStuff

Tools for Trove by Mars, Vash / bytearr, and Yumo. Free to use with attribution.

## Ship Destroyer

A single session dashboard for one client or up to eight clients: four class
rotations, optional loot, Anti-AFK movement, and opt-in single-client recovery.

### Run

1. Install **AutoHotkey v1.1.33 or later in the v1.1 series** (not v2). Both 32-bit
   and 64-bit Unicode runtimes work; the old USkin DLL is no longer loaded.
2. Download/clone the **whole repository**, keeping `lib` beside `ShipDestroyer1.1`.
3. Run `ShipDestroyer1.1/ShipDestroyer.ahk` and open Trove.
4. Bind primary attack to **M**, secondary attack to **O**, loot to **E**, and skills
   to **1** / **2** in Trove. Anti-AFK uses **Z** and **Space**.
5. Refresh clients, select the desired window (identified by title and process ID),
   choose a class and options, then start the session.

The dashboard uses process-verified window handles; no window renaming is needed.
Use **Stop / F8** to stop everything and release held keys. **Insert** hides/shows
its window. Closing the dashboard also releases keys. Settings lock during a
session; stop before changing them. Multi-client mode uses the first eight clients
shown by refresh, all with the same class/options.

The former `AntiCrash tr0ve.ahk` and `Ship Destroyer1.0/AFK Script.ahk` are compatibility
launchers for this dashboard. The old 1.0 entertainment links are retired; its
credits are retained. Old DLLs/styles/screenshots are historical assets only.

### Recovery

Recovery is opt-in and available only for a single selected client. Steam recovery
opens the Trove Steam launch URI. Glyph recovery requires **Glyph already open on
its Trove page** and clicks its historical play-button position (80% across, 14%
down its client area). Glyph layout changes can break this heuristic; it is not a
launcher API. Recovery makes at most three attempts, spaced one minute apart.

A uniquely detected replacement client resumes after a 15-second loading delay.
Multiple detected clients stop recovery so you can select the correct account.
Recovery cannot log in, select a character, or return to a farm automatically.
Without recovery, any disconnected target stops the entire session. The script
never sends input to whichever unrelated window happens to be active.

## Mod migration (Python source)

Requires Python 3.10+. Put `.tmod` files in `mods` and `.cfg` files in `ModCfgs`,
next to `TroveModMigration Tool.py`, then run:

```powershell
python "TroveModMigration Tool.py" --dry-run
python "TroveModMigration Tool.py"
```

Glyph registry entries and Steam library folders are detected automatically.
You can also specify paths explicitly (the destination must be the **mods folder**):

```powershell
python "TroveModMigration Tool.py" --source "D:\MyModPack" --destination "D:\Trove\Live\mods"
```

Config files default to `%APPDATA%\Trove\ModCfgs`; override with
`--config-destination`. Existing files are skipped, never overwritten. The source
files remain in place. Subfolders, symlinks, and unrelated extensions are ignored.
If a copy fails, the incomplete new file is removed; files copied earlier in that
run remain. Rerunning safely skips those completed files. `--dry-run` writes nothing.

`TroveMigrationTool.exe` is an **unchanged historical Rust binary**, not a build of
this Python source. Its source is maintained separately in
[TroveModMigrationTool](https://github.com/VashTetr/TroveModMigrationTool/tree/main).
The fixes here do not update that binary.

## Development and verification

```sh
python -m unittest discover -s tests -v
python -m py_compile "TroveModMigration Tool.py"
```

GitHub Actions runs migration tests on Linux and Windows, plus AutoHotkey v1 profile
and dashboard integration tests on Windows. The latter uses an isolated fake
`Trove.exe` window to verify input and key release without connecting to the game;
it uploads a Windows screenshot for UI inspection.

Before release, also check with real Trove on Windows:

- All four classes, loot on/off, one client and multiple clients.
- Stop/F8/close during held attacks; no stuck keys or continued input.
- Anti-AFK stop and disconnect behavior, and elevated-game permissions if relevant.
- Steam and Glyph recovery, slow loading, launcher layout and multiple-account ambiguity.
- Layout and keyboard navigation at 100%, 125%, 150% and 200% display scaling.

Automated fake-client tests do not establish compatibility with Trove's live input
handling, launcher layout, or loading times.
