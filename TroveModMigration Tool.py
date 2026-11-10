"""Copy Trove mods/configs without overwriting existing files (Python 3.10+)."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import sys

try:
    import winreg
except ImportError:  # File-copy logic remains testable on other platforms.
    winreg = None


def registry_value(root, key, name):
    if winreg is None:
        return None
    for view in (winreg.KEY_WOW64_32KEY, winreg.KEY_WOW64_64KEY):
        try:
            with winreg.OpenKey(root, key, 0, winreg.KEY_READ | view) as handle:
                value = winreg.QueryValueEx(handle, name)[0]
                if isinstance(value, str) and value.strip():
                    return Path(os.path.expandvars(value.strip().strip('"')))
        except OSError:
            continue
    return None


def find_installations():
    """Discover Glyph installs and Steam libraries; never invent a destination."""
    results = {}
    if winreg is None:
        return results
    key = r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Glyph Trove"
    for suffix in ("", " Europe", " North America"):
        location = registry_value(winreg.HKEY_LOCAL_MACHINE, key + suffix, "InstallLocation")
        if location and location.is_dir():
            results["Glyph" + suffix] = location / "mods"
    steam = registry_value(winreg.HKEY_CURRENT_USER, r"SOFTWARE\Valve\Steam", "SteamPath")
    if steam is None:
        steam = registry_value(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Valve\Steam", "InstallPath")
    if steam:
        libraries = [steam]
        vdf = steam / "steamapps" / "libraryfolders.vdf"
        try:
            content = vdf.read_text(encoding="utf-8-sig")
            for value in re.findall(r'"path"\s*"([^"\r\n]+)"', content, re.IGNORECASE):
                libraries.append(Path(value.replace("\\\\", "\\")))
        except (OSError, UnicodeError):
            pass
        for library in dict.fromkeys(libraries):
            live = library / "steamapps" / "common" / "Trove" / "Games" / "Trove" / "Live"
            if live.is_dir():
                results[f"Steam ({library})"] = live / "mods"
    return results


def config_destination():
    appdata = os.environ.get("APPDATA")
    if not appdata:
        raise ValueError("APPDATA is not set. Supply --config-destination explicitly.")
    return Path(appdata) / "Trove" / "ModCfgs"


def source_files(source, extension):
    if not source.is_dir():
        raise ValueError(f"Source folder not found: {source}")
    return sorted((p for p in source.iterdir()
                   if p.is_file() and not p.is_symlink() and p.suffix.casefold() == extension),
                  key=lambda p: p.name.casefold())


def copy_files(files, destination, dry_run=False):
    """Exclusive creation prevents overwrites, including a destination race."""
    copied = skipped = 0
    if destination.exists() and not destination.is_dir():
        raise ValueError(f"Destination is not a folder: {destination}")
    existing = {p.name.casefold() for p in destination.iterdir()} if destination.is_dir() else set()
    if not dry_run:
        destination.mkdir(parents=True, exist_ok=True)
    for source in files:
        target = destination / source.name
        if source.name.casefold() in existing:
            print(f"  SKIP  {source.name} (already exists)")
            skipped += 1
            continue
        if not dry_run:
            try:
                output = target.open("xb")
            except FileExistsError:
                skipped += 1
                continue
            try:
                with output, source.open("rb") as incoming:
                    shutil.copyfileobj(incoming, output)
            except BaseException:
                target.unlink(missing_ok=True)  # Remove only the partial file we created.
                raise
        existing.add(source.name.casefold())
        copied += 1
        print(f"  {'PLAN' if dry_run else 'COPY'}  {source.name} -> {destination}")
    return copied, skipped


def migrate(source, mods_destination, configs_destination, dry_run=False):
    source = Path(source).resolve()
    mods_destination = Path(mods_destination).resolve()
    configs_destination = Path(configs_destination).resolve()
    # Validate both sources before creating or copying anything.
    mods = source_files(source / "mods", ".tmod")
    configs = source_files(source / "ModCfgs", ".cfg")
    source_dirs = {(source / "mods").resolve(), (source / "ModCfgs").resolve()}
    if mods_destination in source_dirs or configs_destination in source_dirs:
        raise ValueError("Source and destination folders must be different.")
    if mods_destination == configs_destination:
        raise ValueError("Mods and configuration files need separate destination folders.")
    for destination in (mods_destination, configs_destination):
        if destination.exists() and not destination.is_dir():
            raise ValueError(f"Destination is not a folder: {destination}")
    a = copy_files(mods, mods_destination, dry_run)
    b = copy_files(configs, configs_destination, dry_run)
    return a[0] + b[0], a[1] + b[1]


def main(argv=None):
    default_source = Path(sys.executable if getattr(sys, "frozen", False) else __file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=default_source, help="Folder containing mods and ModCfgs")
    parser.add_argument("--destination", type=Path, help="Target Trove mods folder")
    parser.add_argument("--config-destination", type=Path, help="Defaults to %%APPDATA%%/Trove/ModCfgs")
    parser.add_argument("--dry-run", action="store_true", help="Preview without creating folders or copying files")
    args = parser.parse_args(argv)
    try:
        destination = args.destination
        if destination is None:
            installations = list(find_installations().items())
            if not installations:
                raise ValueError("No Trove installation found. Use --destination with your game's mods folder.")
            print("\nTROVE / MOD MIGRATION\n")
            for i, (name, folder) in enumerate(installations, 1):
                print(f"  {i}. {name}\n     {folder}")
            while True:
                choice = input("\nChoose an installation (q to cancel): ").strip()
                if choice.casefold() == "q":
                    return 0
                if choice.isdecimal() and 1 <= int(choice) <= len(installations):
                    destination = installations[int(choice) - 1][1]
                    break
                print("Enter one of the listed numbers.")
        configs = args.config_destination if args.config_destination is not None else config_destination()
        copied, skipped = migrate(args.source, destination, configs, args.dry_run)
        print(f"\n{'Preview complete' if args.dry_run else 'Migration complete'}: {copied} "
              f"{'planned' if args.dry_run else 'copied'}, {skipped} skipped.")
        return 0
    except (OSError, ValueError) as error:
        print(f"Migration failed: {error}", file=sys.stderr)
        return 1
    except (EOFError, KeyboardInterrupt):
        print("\nCancelled.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
