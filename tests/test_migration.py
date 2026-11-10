import contextlib
import importlib.util
import io
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("migration", Path(__file__).resolve().parents[1] / "TroveModMigration Tool.py")
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)


class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "source"
        (self.source / "mods").mkdir(parents=True)
        (self.source / "ModCfgs").mkdir()
        self.mods = self.root / "game" / "mods"
        self.configs = self.root / "appdata" / "Trove" / "ModCfgs"
        self.output = contextlib.redirect_stdout(io.StringIO())
        self.output.__enter__()
        self.addCleanup(self.output.__exit__, None, None, None)

    def migrate(self, dry_run=False):
        return migration.migrate(self.source, self.mods, self.configs, dry_run)

    def test_single_file_and_last_file_are_copied(self):
        (self.source / "mods" / "only.tmod").write_bytes(b"mod")
        (self.source / "ModCfgs" / "a.cfg").write_bytes(b"first")
        (self.source / "ModCfgs" / "z.cfg").write_bytes(b"last")
        self.assertEqual(self.migrate(), (3, 0))
        self.assertEqual((self.mods / "only.tmod").read_bytes(), b"mod")
        self.assertEqual((self.configs / "z.cfg").read_bytes(), b"last")

    def test_existing_files_are_never_overwritten(self):
        (self.source / "mods" / "a.tmod").write_bytes(b"new")
        self.mods.mkdir(parents=True)
        (self.mods / "a.tmod").write_bytes(b"old")
        self.assertEqual(self.migrate(), (0, 1))
        self.assertEqual((self.mods / "a.tmod").read_bytes(), b"old")

    def test_extensions_and_case_insensitive_duplicates(self):
        (self.source / "mods" / "a.TMOD").write_bytes(b"new")
        (self.source / "mods" / "notes.txt").write_text("ignore")
        (self.source / "mods" / "folder.tmod").mkdir()
        self.mods.mkdir(parents=True)
        (self.mods / "A.tmod").write_bytes(b"old")
        self.assertEqual(self.migrate(), (0, 1))
        self.assertEqual(len(list(self.mods.iterdir())), 1)

    def test_dry_run_creates_nothing(self):
        (self.source / "mods" / "a.tmod").write_bytes(b"mod")
        self.assertEqual(self.migrate(True), (1, 0))
        self.assertFalse(self.mods.parent.exists())
        self.assertFalse(self.configs.parent.exists())

    def test_missing_source_validates_before_copying(self):
        (self.source / "mods" / "a.tmod").write_bytes(b"mod")
        (self.source / "ModCfgs").rmdir()
        with self.assertRaises(ValueError):
            self.migrate()
        self.assertFalse(self.mods.exists())

    def test_invalid_second_destination_validates_before_copying(self):
        self.configs.parent.mkdir(parents=True)
        self.configs.write_text("not a folder")
        with self.assertRaises(ValueError):
            self.migrate()
        self.assertFalse(self.mods.exists())

    def test_partial_copy_is_removed(self):
        (self.source / "mods" / "a.tmod").write_bytes(b"mod")
        def fail(source, target):
            target.write(b"partial")
            raise OSError("disk full")
        with patch.object(migration.shutil, "copyfileobj", side_effect=fail):
            with self.assertRaises(OSError):
                self.migrate()
        self.assertFalse((self.mods / "a.tmod").exists())

    def test_destination_race_preserves_existing_file(self):
        source = self.source / "mods" / "a.tmod"
        source.write_bytes(b"new")
        original_open = Path.open
        def race(path, mode="r", *args, **kwargs):
            if mode == "xb":
                with original_open(path, "wb") as target:
                    target.write(b"another process")
            return original_open(path, mode, *args, **kwargs)
        with patch.object(Path, "open", race):
            self.assertEqual(self.migrate(), (0, 1))
        self.assertEqual((self.mods / "a.tmod").read_bytes(), b"another process")

    def test_same_source_destination_rejected(self):
        with self.assertRaises(ValueError):
            migration.migrate(self.source, self.source / "mods", self.configs)

    def test_empty_sources_succeed(self):
        self.assertEqual(self.migrate(), (0, 0))

    def test_missing_appdata_has_actionable_error(self):
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(ValueError, "--config-destination"):
                migration.config_destination()

    def test_explicit_cli_destinations_return_success(self):
        self.assertEqual(migration.main(["--source", str(self.source), "--destination", str(self.mods),
                                       "--config-destination", str(self.configs)]), 0)

    def test_missing_installation_fails_without_writing(self):
        with patch.object(migration, "find_installations", return_value={}), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(migration.main(["--source", str(self.source)]), 1)
        self.assertFalse(self.mods.exists())

    def test_steam_secondary_library(self):
        steam = self.root / "Steam"
        (steam / "steamapps").mkdir(parents=True)
        secondary = self.root / "Second library"
        live = secondary / "steamapps" / "common" / "Trove" / "Games" / "Trove" / "Live"
        live.mkdir(parents=True)
        (steam / "steamapps" / "libraryfolders.vdf").write_text(
            '"libraryfolders" { "1" { "path" "' + str(secondary).replace('\\', '\\\\') + '" } }')
        from types import SimpleNamespace
        registry = SimpleNamespace(HKEY_LOCAL_MACHINE=1, HKEY_CURRENT_USER=2)
        def value(root, key, name):
            return steam if name == "SteamPath" else None
        with patch.object(migration, "winreg", registry), patch.object(migration, "registry_value", side_effect=value):
            results = migration.find_installations()
        self.assertIn(live / "mods", results.values())


if __name__ == "__main__":
    unittest.main()
