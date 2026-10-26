#!/usr/bin/env python3
"""Tempfile-only verifier tests and static packaging checks; never run packaging."""

from contextlib import redirect_stdout
import importlib.util
import io
import os
from pathlib import Path
import plistlib
import re
import stat
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location(
    "native_entry_verifier", SCRIPTS / "verify-native-ui-test-entry.py"
)
VERIFIER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFIER)
REJECTIONS = (VERIFIER.EntryValidationError, OSError, RuntimeError, plistlib.InvalidFileException)


class NativeSourcesFixtureEntryTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="native-sources-entry-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.candidate = self.root / ".build/candidates/owned"
        self.bundle = self.candidate / "Native.app"
        self.profile = "sources-test-19"
        self.profile_root = self.candidate / "UITestProfiles" / self.profile
        self.applications = self.profile_root / "Applications"

    def marker(self, version):
        marker = {"version": version, "profile": self.profile}
        if version == 2:
            marker["fixture"] = "sources-v1"
        return marker

    def write_metadata(self, marker, bundle_id=VERIFIER.RESERVED_BUNDLE_ID):
        contents = self.bundle / "Contents"
        contents.mkdir(parents=True, exist_ok=True)
        metadata = {"CFBundleIdentifier": bundle_id}
        if marker is not None:
            metadata[VERIFIER.MARKER_KEY] = marker
        (contents / "Info.plist").write_bytes(plistlib.dumps(metadata))

    def snapshot(self):
        """Record entries, symlink targets and file bytes without following links."""
        entries = []
        for directory, subdirs, files in os.walk(self.root, followlinks=False):
            for name in sorted(subdirs + files):
                path = Path(directory) / name
                mode = path.lstat().st_mode
                value = (os.readlink(path) if stat.S_ISLNK(mode)
                         else path.read_bytes() if stat.S_ISREG(mode) else None)
                entries.append((str(path.relative_to(self.root)), mode, value))
        return sorted(entries)

    def assert_read_only(self, action, *, rejected=False):
        before = self.snapshot()
        if rejected:
            with self.assertRaises(REJECTIONS):
                action()
        else:
            action()
        self.assertEqual(self.snapshot(), before)

    def preflight(self, fixture=""):
        VERIFIER.validate_native_destination(self.bundle, self.profile, fixture)

    def verify(self):
        VERIFIER.validate_app(self.bundle)

    def test_strict_versions_accept_missing_children_without_creation(self):
        # Both the legacy two-argument API and explicit empty fixture remain valid.
        self.assert_read_only(lambda: VERIFIER.validate_native_destination(
            self.bundle, self.profile))
        self.assert_read_only(self.preflight)
        self.assert_read_only(lambda: self.preflight("sources-v1"))
        for version in (1, 2):
            with self.subTest(version=version):
                self.write_metadata(self.marker(version))
                self.assert_read_only(self.verify)
                self.assertFalse(self.profile_root.exists())

    def test_existing_real_children_accepted_without_writes(self):
        for name in ("Baseline", "Extras"):
            (self.applications / name).mkdir(parents=True)
        self.assert_read_only(lambda: self.preflight("sources-v1"))
        self.write_metadata(self.marker(2))
        self.assert_read_only(self.verify)

    def test_strict_marker_versions_types_and_keys(self):
        invalid = [False, True, "sources-v1", [], {}, {"profile": self.profile}]
        for version in (False, True, 0, -1, 3, 1.0, 2.0, "1", "2", [], {}):
            invalid.append({"version": version, "profile": self.profile})
            invalid.append({"version": version, "profile": self.profile,
                            "fixture": "sources-v1"})
        invalid.extend([
            {"version": 1}, {"version": 2, "fixture": "sources-v1"},
            {"version": 1, "profile": self.profile, "fixture": "sources-v1"},
            {"version": 2, "profile": self.profile},
        ])
        for fixture in ("", "sources-v2", "SOURCES-V1", "sources-v1\n",
                        "/tmp/fixture", "$(touch ignored)", True, 2, [], {}, b"sources-v1"):
            invalid.append({**self.marker(2), "fixture": fixture})
        for version in (1, 2):
            for key in ("path", "catalogRoots", "command", "arguments", "extra"):
                invalid.append({**self.marker(version), key: "ignored"})
            for profile in ("", "../escape", "Upper", "a" * 49, "a\n",
                            True, 1, [], {}, b"profile"):
                invalid.append({**self.marker(version), "profile": profile})
        for marker in invalid:
            with self.subTest(marker=marker):
                self.write_metadata(marker)
                self.assert_read_only(self.verify, rejected=True)

    def test_bundle_identity_and_absent_marker_legacy_behavior(self):
        for version in (1, 2):
            for bundle_id in ("com.launchcopy.app", "", True, 1, []):
                with self.subTest(version=version, bundle_id=bundle_id):
                    self.write_metadata(self.marker(version), bundle_id)
                    self.assert_read_only(self.verify, rejected=True)
        self.write_metadata(None)
        self.assert_read_only(self.verify, rejected=True)
        self.write_metadata(None, "com.launchcopy.app")
        self.assert_read_only(self.verify)

    def test_invalid_fixture_and_profile_preflight_no_creation(self):
        for fixture in (None, False, 2, [], {}, "unknown", "sources-v1\n", "/tmp"):
            with self.subTest(fixture=fixture):
                self.assert_read_only(lambda: self.preflight(fixture), rejected=True)
        for profile in (None, False, 2, [], {}, "", "../escape", "a\n", "A"):
            for fixture in ("", "sources-v1"):
                with self.subTest(profile=profile, fixture=fixture):
                    self.assert_read_only(lambda: VERIFIER.validate_native_destination(
                        self.bundle, profile, fixture), rejected=True)

    def test_both_children_reject_files_links_and_dangling_without_creation(self):
        for child in ("Baseline", "Extras"):
            for kind in ("file", "directory-link", "dangling-link", "escape-link", "self-link"):
                with self.subTest(child=child, kind=kind):
                    self.applications.mkdir(parents=True, exist_ok=True)
                    path = self.applications / child
                    target = self.applications / "Nested"
                    target.mkdir(exist_ok=True)
                    if kind == "file":
                        path.write_text("owned fixture", encoding="utf-8")
                    elif kind == "directory-link":
                        path.symlink_to(target, target_is_directory=True)
                    elif kind == "dangling-link":
                        path.symlink_to(self.applications / "Missing")
                    elif kind == "escape-link":
                        path.symlink_to(self.root, target_is_directory=True)
                    else:
                        path.symlink_to(path)
                    # Preflight needs a destination that does not yet exist.
                    new_bundle = self.candidate / "New.app"
                    self.assert_read_only(lambda: VERIFIER.validate_native_destination(
                        new_bundle, self.profile, "sources-v1"), rejected=True)
                    self.write_metadata(self.marker(2))
                    self.assert_read_only(self.verify, rejected=True)
                    # v1 never inspects or creates either optional Sources child.
                    self.assert_read_only(lambda: VERIFIER.validate_native_destination(
                        new_bundle, self.profile))
                    self.write_metadata(self.marker(1))
                    self.assert_read_only(self.verify)
                    path.unlink()
                    self.assertFalse((self.applications / "Missing").exists())

    def test_existing_five_namespace_guards_remain_for_both_versions(self):
        guarded = (self.candidate / "UITestProfiles", self.profile_root,
                   self.profile_root / "Layout", self.applications,
                   self.profile_root / "WallpaperCache")
        for directory in guarded:
            for kind in ("file", "link", "dangling"):
                with self.subTest(directory=directory.name, kind=kind):
                    directory.parent.mkdir(parents=True, exist_ok=True)
                    if kind == "file":
                        directory.write_bytes(b"owned fixture")
                    else:
                        directory.symlink_to(self.root if kind == "link"
                                             else self.root / "Absent")
                    for version, fixture in ((1, ""), (2, "sources-v1")):
                        self.assert_read_only(lambda: VERIFIER.validate_native_destination(
                            self.candidate / "New.app", self.profile, fixture), rejected=True)
                        self.write_metadata(self.marker(version))
                        self.assert_read_only(self.verify, rejected=True)
                    directory.unlink()

    def test_candidate_ancestry_extension_and_existing_destination_guards(self):
        for fixture in ("", "sources-v1"):
            for path in (self.root / "Native.app", self.root / ".build/Native.app",
                         self.root / ".build/candidates/Native.app",
                         self.candidate / "Native.txt"):
                with self.subTest(path=path, fixture=fixture):
                    self.assert_read_only(lambda: VERIFIER.validate_native_destination(
                        path, self.profile, fixture), rejected=True)
        for kind in ("directory", "file", "dangling"):
            self.candidate.mkdir(parents=True, exist_ok=True)
            if kind == "directory":
                self.bundle.mkdir()
            elif kind == "file":
                self.bundle.write_bytes(b"owned fixture")
            else:
                self.bundle.symlink_to(self.root / "Absent")
            for fixture in ("", "sources-v1"):
                self.assert_read_only(lambda: self.preflight(fixture), rejected=True)
            if kind == "directory":
                self.bundle.rmdir()
            else:
                self.bundle.unlink()

    def test_plist_duplicate_keys_and_regular_file_guards(self):
        self.write_metadata(self.marker(2))
        plist = self.bundle / "Contents/Info.plist"
        original = plist.read_bytes()
        duplicate = original.replace(b"<key>fixture</key>",
                                     b"<key>version</key><integer>2</integer><key>fixture</key>")
        for data in (duplicate, b"not a plist", b"x" * (VERIFIER.MAX_PLIST_BYTES + 1)):
            plist.write_bytes(data)
            self.assert_read_only(self.verify, rejected=True)
        plist.unlink()
        target = self.root / "metadata.plist"
        target.write_bytes(original)
        plist.symlink_to(target)
        self.assert_read_only(self.verify, rejected=True)
        plist.unlink()
        plist.mkdir()
        self.assert_read_only(self.verify, rejected=True)
        plist.rmdir()
        contents = self.bundle / "Contents"
        contents.rmdir()
        contents.symlink_to(self.root)
        self.assert_read_only(self.verify, rejected=True)

    def test_verifier_cli_has_one_bundle_argument_and_neutral_output(self):
        for argv in ([], ["--help"], [str(self.bundle), "sources-v1"],
                     [str(self.bundle), "--fixture", "sources-v1"]):
            output = io.StringIO()
            with redirect_stdout(output):
                self.assert_read_only(lambda: self.assertEqual(VERIFIER.main(argv), 1))
            self.assertEqual(output.getvalue(), "native-ui-test-entry: rejected\n")
        for version in (1, 2):
            self.write_metadata(self.marker(version))
            output = io.StringIO()
            with redirect_stdout(output):
                self.assert_read_only(lambda: self.assertEqual(
                    VERIFIER.main([str(self.bundle)]), 0))
            self.assertEqual(output.getvalue(), "native-ui-test-entry: accepted\n")


class PackagingStaticContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (SCRIPTS / "package-app.sh").read_text(encoding="utf-8")

    def test_opt_in_and_all_native_guards_precede_writes_and_builds(self):
        preflight, remainder = self.source.split('mkdir -p "$APP_PARENT_ABS"', 1)
        self.assertNotIn("swift build", preflight)
        self.assertNotIn("mkdir -p", preflight)
        self.assertIn('NATIVE_UI_TEST_FIXTURE="${NATIVE_UI_TEST_FIXTURE:-}"', preflight)
        for guard in (
            '[[ "$NATIVE_UI_TEST_FIXTURE" == "sources-v1" ]] || die',
            '[[ -n "$NATIVE_UI_TEST_PROFILE" ]] || die',
            '[[ "$NATIVE_UI_TEST_PROFILE" =~ ^[a-z0-9][a-z0-9-]{0,47}$ ]] || die',
            '[[ "$BUNDLE_ID" == "com.launchcopy.ui-test" ]] || die',
            '[[ "$LEGACY_DESTRUCTIVE" == "0" ]] || die',
            'die "reserved bundle ID requires explicit native test profile"',
            'checker.validate_native_destination(sys.argv[2], sys.argv[3], sys.argv[4])',
            'relative = parent.relative_to(root / ".build")',
            'if not relative.parts:',
        ):
            self.assertIn(guard, preflight)
        fixture_guard = preflight.index('if [[ -n "$NATIVE_UI_TEST_FIXTURE" ]]')
        profile_guard = preflight.index('if [[ -n "$NATIVE_UI_TEST_PROFILE" ]]')
        self.assertLess(fixture_guard, profile_guard)
        self.assertIn('"$APP_DIR" "$NATIVE_UI_TEST_PROFILE" "$NATIVE_UI_TEST_FIXTURE" <<',
                      preflight)
        self.assertIn("swift build", remainder)
        self.assertIn('die "destination already exists:', remainder)

    def test_exact_marker_schemas_manifest_and_legacy_branch(self):
        fragments = re.findall(r'plutil -insert LaunchcopyUITestEntry -xml "([^"]+)"',
                               self.source)
        self.assertEqual(len(fragments), 2)
        markers = [plistlib.loads(
            ('<plist version="1.0">' + fragment.replace('${NATIVE_UI_TEST_PROFILE}',
                                                        'test-profile') + '</plist>').encode()
        ) for fragment in fragments]
        self.assertEqual(markers, [
            {"version": 2, "profile": "test-profile", "fixture": "sources-v1"},
            {"version": 1, "profile": "test-profile"},
        ])
        self.assertTrue(all(type(marker["version"]) is int for marker in markers))
        self.assertIn('NATIVE_UI_TEST_ENTRY_MODE="marker-v1"', self.source)
        self.assertIn('NATIVE_UI_TEST_ENTRY_MODE="marker-v2-sources-v1"', self.source)
        self.assertIn('echo "native_ui_test_entry_mode=$NATIVE_UI_TEST_ENTRY_MODE"',
                      self.source)
        self.assertIn('echo "info_plist_sha256=', self.source)
        assembly = self.source.split('if [[ "$PROFILE_ISOLATED" == "true" ]]; then', 1)[1]
        self.assertIn('if [[ "$NATIVE_UI_TEST_FIXTURE" == "sources-v1" ]]; then', assembly)
        self.assertIn('else\n    plutil -insert LaunchcopyUITestEntry', assembly)
        self.assertIn('python3 -B "$ROOT/Scripts/verify-native-ui-test-entry.py" "$APP_DIR"',
                      assembly)


if __name__ == "__main__":
    unittest.main()
