#!/usr/bin/env python3
"""Temp-directory verifier tests and static packaging checks; never build or launch."""

from contextlib import redirect_stdout
import importlib.util
import io
import os
from pathlib import Path
import plistlib
import re
import stat
import sys
import tempfile
import unittest
from xml.parsers.expat import ExpatError


SCRIPTS = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location(
    "gesture_entry_verifier", SCRIPTS / "verify-gesture-validation-entry.py"
)
VERIFIER = importlib.util.module_from_spec(SPEC)
PREVIOUS_BYTECODE = sys.dont_write_bytecode
try:
    sys.dont_write_bytecode = True
    SPEC.loader.exec_module(VERIFIER)
finally:
    sys.dont_write_bytecode = PREVIOUS_BYTECODE
REJECTIONS = (ValueError, OSError, RuntimeError, ExpatError)


class GestureValidationEntryTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="gesture-validation-entry-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.candidate = self.root / ".build/candidates/dedicated"
        self.bundle = self.candidate / "GestureValidation.app"
        self.profile = "gesture-test-22"
        self.profile_root = self.candidate / "UITestProfiles" / self.profile

    def marker(self):
        return {"version": 1, "profile": self.profile}

    def write_metadata(self, metadata, *, fmt=plistlib.FMT_XML):
        contents = self.bundle / "Contents"
        contents.mkdir(parents=True, exist_ok=True)
        (contents / "Info.plist").write_bytes(plistlib.dumps(metadata, fmt=fmt))

    def metadata(self):
        return {"CFBundleIdentifier": VERIFIER.RESERVED_BUNDLE_ID,
                VERIFIER.MARKER_KEY: self.marker()}

    def snapshot(self):
        """Record owned entries, modes, bytes and link targets without following links."""
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

    def preflight(self):
        VERIFIER.validate_gesture_destination(self.bundle, self.profile)

    def verify(self):
        VERIFIER.validate_app(self.bundle)

    def test_valid_destination_and_xml_binary_metadata_create_no_profile(self):
        self.assert_read_only(self.preflight)
        self.assertFalse(self.candidate.exists())
        for fmt in (plistlib.FMT_XML, plistlib.FMT_BINARY):
            with self.subTest(fmt=fmt):
                self.write_metadata(self.metadata(), fmt=fmt)
                self.assert_read_only(self.verify)
                self.assertFalse(self.profile_root.parent.exists())
        for name in ("Layout", "Applications", "WallpaperCache"):
            (self.profile_root / name).mkdir(parents=True, exist_ok=True)
        self.assert_read_only(self.verify)

    def test_profile_grammar_is_shared_and_strict(self):
        for profile in ("a", "a" * 48, "gesture-20261022-pkg-01"):
            with self.subTest(valid=profile):
                self.assert_read_only(lambda: VERIFIER.validate_gesture_destination(
                    self.bundle, profile))
        for profile in (None, False, True, 1, 1.0, [], {}, "", "../escape", "a/b",
                        "a\n", "A", " a", "a_1", "é", "a" * 49, "-a"):
            with self.subTest(invalid=profile):
                self.assert_read_only(lambda: VERIFIER.validate_gesture_destination(
                    self.candidate / "New.app", profile), rejected=True)
                metadata = self.metadata()
                metadata[VERIFIER.MARKER_KEY]["profile"] = profile
                self.write_metadata(metadata, fmt=plistlib.FMT_BINARY)
                self.assert_read_only(self.verify, rejected=True)

    def test_marker_requires_exact_integer_one_and_exact_keys(self):
        markers = [None, False, 1, [], "marker", {}, {"version": 1},
                   {"profile": self.profile}]
        for version in (True, False, 1.0, 0, 2, -1, "1", [], {}):
            markers.append({"version": version, "profile": self.profile})
        for extra in ("fixture", "realBackend", "args", "unknown"):
            markers.append({**self.marker(), extra: "sources-v1"})
        for marker in markers:
            with self.subTest(marker=marker):
                metadata = self.metadata()
                metadata[VERIFIER.MARKER_KEY] = marker
                self.write_metadata(metadata, fmt=plistlib.FMT_BINARY)
                self.assert_read_only(self.verify, rejected=True)

    def test_identity_missing_marker_and_any_ui_marker_reject(self):
        for bundle_id in (None, False, 1, [], {}, "", "com.launchcopy.app",
                          "com.launchcopy.ui-test", "com.launchcopy.gesture-validation.extra"):
            with self.subTest(bundle_id=bundle_id):
                metadata = self.metadata()
                metadata["CFBundleIdentifier"] = bundle_id
                self.write_metadata(metadata, fmt=plistlib.FMT_BINARY)
                self.assert_read_only(self.verify, rejected=True)
        for metadata in ({}, {"CFBundleIdentifier": VERIFIER.RESERVED_BUNDLE_ID},
                         {"CFBundleIdentifier": "com.launchcopy.app"}):
            self.write_metadata(metadata)
            self.assert_read_only(self.verify, rejected=True)
        for ui_marker in (False, {}, {"version": 1, "profile": self.profile},
                          {"version": 2, "profile": self.profile, "fixture": "sources-v1"}):
            metadata = self.metadata()
            metadata["LaunchcopyUITestEntry"] = ui_marker
            self.write_metadata(metadata)
            self.assert_read_only(self.verify, rejected=True)

    def test_candidate_ancestry_and_bundle_extension_fail_closed(self):
        for path in (self.root / "Gesture.app", self.root / ".build/Gesture.app",
                     self.root / ".build/candidates/Gesture.app",
                     self.root / ".build/candidates-other/owned/Gesture.app",
                     self.candidate / "Gesture.txt", self.candidate / "Gesture.APP"):
            with self.subTest(path=path):
                self.assert_read_only(lambda: VERIFIER.validate_gesture_destination(
                    path, self.profile), rejected=True)
                original = self.bundle
                try:
                    self.bundle = path
                    self.write_metadata(self.metadata())
                    self.assert_read_only(self.verify, rejected=True)
                finally:
                    self.bundle = original

    def test_existing_destinations_including_dangling_links_reject(self):
        self.candidate.mkdir(parents=True)
        for kind in ("directory", "file", "link", "dangling", "self-link"):
            with self.subTest(kind=kind):
                path = self.candidate / (kind + ".app")
                if kind == "directory":
                    path.mkdir()
                elif kind == "file":
                    path.write_bytes(b"owned")
                else:
                    target = (self.root if kind == "link" else path if kind == "self-link"
                              else self.root / "Missing")
                    path.symlink_to(target)
                self.assert_read_only(lambda: VERIFIER.validate_gesture_destination(
                    path, self.profile), rejected=True)

    def test_canonical_alias_allowed_but_candidate_escape_rejects(self):
        self.candidate.mkdir(parents=True)
        alias = self.root / "Alias"
        alias.symlink_to(self.candidate.parent, target_is_directory=True)
        self.assert_read_only(lambda: VERIFIER.validate_gesture_destination(
            alias / self.candidate.name / self.bundle.name, self.profile))
        self.write_metadata(self.metadata())
        self.assert_read_only(lambda: VERIFIER.validate_app(
            alias / self.candidate.name / self.bundle.name))
        outside = self.root / "Outside"
        outside.mkdir()
        escape = self.candidate.parent / "Escape"
        escape.symlink_to(outside, target_is_directory=True)
        self.assert_read_only(lambda: VERIFIER.validate_gesture_destination(
            escape / self.bundle.name, self.profile), rejected=True)
        original = self.bundle
        try:
            self.bundle = escape / original.name
            self.write_metadata(self.metadata())
            self.assert_read_only(self.verify, rejected=True)
        finally:
            self.bundle = original

    def test_all_seven_storage_guards_reject_files_and_links(self):
        guarded = (self.profile_root.parent, self.profile_root,
                   self.profile_root / "Layout", self.profile_root / "Applications",
                   self.profile_root / "WallpaperCache", self.profile_root / "Library",
                   self.profile_root / "LaunchActivity")
        for directory in guarded:
            for kind in ("file", "escape-link", "local-link", "dangling", "self-link"):
                with self.subTest(directory=directory.name, kind=kind):
                    directory.parent.mkdir(parents=True, exist_ok=True)
                    if kind == "file":
                        directory.write_bytes(b"owned")
                    else:
                        local = directory.parent / (directory.name + "-target")
                        local.mkdir(exist_ok=True)
                        target = {"escape-link": self.root, "local-link": local,
                                  "dangling": self.root / "Absent", "self-link": directory}[kind]
                        directory.symlink_to(target)
                    self.assert_read_only(lambda: VERIFIER.validate_gesture_destination(
                        self.candidate / "New.app", self.profile), rejected=True)
                    self.write_metadata(self.metadata())
                    self.assert_read_only(self.verify, rejected=True)
                    directory.unlink()
        self.assertFalse((self.root / "Absent").exists())

    def test_plist_parser_size_duplicates_and_regular_file_guards(self):
        self.write_metadata(self.metadata())
        plist = self.bundle / "Contents/Info.plist"
        original = plist.read_bytes()
        duplicates = [original.replace(b"<key>version</key>",
                                      b"<key>version</key><integer>1</integer><key>version</key>"),
                      original.replace(b"<key>CFBundleIdentifier</key>",
                                      b"<key>CFBundleIdentifier</key><string>wrong</string>"
                                      b"<key>CFBundleIdentifier</key>")]
        for data in (*duplicates, b"not a plist", b"x" * (1024 * 1024 + 1),
                     plistlib.dumps([])):
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
        os.mkfifo(plist)
        self.assert_read_only(self.verify, rejected=True)
        plist.unlink()
        self.assert_read_only(self.verify, rejected=True)
        contents = self.bundle / "Contents"
        contents.rmdir()
        contents.symlink_to(self.root)
        self.assert_read_only(self.verify, rejected=True)

    def test_cli_is_single_argument_and_output_is_neutral(self):
        for argv in ([], ["--help"], [str(self.bundle)], [str(self.bundle), self.profile],
                     [str(self.bundle), "--real-backend"],
                     [str(self.bundle), "--profile", self.profile]):
            output = io.StringIO()
            with redirect_stdout(output):
                self.assert_read_only(lambda: self.assertEqual(VERIFIER.main(argv), 1))
            self.assertEqual(output.getvalue(), "gesture-validation-entry: rejected\n")
        self.write_metadata(self.metadata())
        output = io.StringIO()
        with redirect_stdout(output):
            self.assert_read_only(lambda: self.assertEqual(
                VERIFIER.main([str(self.bundle)]), 0))
        self.assertEqual(output.getvalue(), "gesture-validation-entry: accepted\n")


class PackagingStaticContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (SCRIPTS / "package-app.sh").read_text(encoding="utf-8")

    def test_dedicated_preflight_precedes_every_write_and_build(self):
        preflight, remainder = self.source.split('mkdir -p "$APP_PARENT_ABS"', 1)
        self.assertNotIn("swift build", preflight)
        self.assertNotIn("mkdir -p", preflight)
        self.assertNotIn("plutil -insert", preflight)
        for guard in (
            'GESTURE_VALIDATION_PROFILE="${GESTURE_VALIDATION_PROFILE:-}"',
            '[[ -n "$GESTURE_VALIDATION_PROFILE" && ( -n "$NATIVE_UI_TEST_PROFILE" || -n "$NATIVE_UI_TEST_FIXTURE" ) ]]',
            '[[ "$GESTURE_VALIDATION_PROFILE" =~ ^[a-z0-9][a-z0-9-]{0,47}$ ]] || die',
            '[[ "$BUNDLE_ID" == "com.launchcopy.gesture-validation" ]] || die',
            '[[ "$LEGACY_DESTRUCTIVE" == "0" ]] || die "gesture validation entry requires non-destructive packaging"',
            'checker.validate_gesture_destination(sys.argv[2], sys.argv[3])',
            'die "reserved bundle ID requires explicit gesture validation profile"',
            'relative = parent.relative_to(root / ".build")',
            'if not relative.parts:',
        ):
            self.assertIn(guard, preflight)
        mixed = preflight.index('if [[ -n "$GESTURE_VALIDATION_PROFILE" &&')
        self.assertLess(mixed, preflight.index('if [[ -n "$NATIVE_UI_TEST_FIXTURE" ]]'))
        self.assertIn('"$APP_DIR" "$GESTURE_VALIDATION_PROFILE" <<', preflight)
        self.assertIn('"$ROOT/Scripts/verify-gesture-validation-entry.py"', preflight)
        self.assertIn("swift build", remainder)
        self.assertIn('die "destination already exists:', remainder)

    def test_exact_dedicated_marker_and_separate_native_branch(self):
        fragments = re.findall(
            r'plutil -insert LaunchcopyGestureValidationEntry -xml "([^"]+)"', self.source)
        self.assertEqual(len(fragments), 1)
        marker = plistlib.loads(('<plist version="1.0">' + fragments[0].replace(
            '${GESTURE_VALIDATION_PROFILE}', 'gesture-test') + '</plist>').encode())
        self.assertEqual(marker, {"version": 1, "profile": "gesture-test"})
        self.assertIs(type(marker["version"]), int)
        assembly = self.source.split('if [[ "$PROFILE_ISOLATED" == "true" ]]; then', 1)[1]
        gesture, native = assembly.split('elif [[ "$NATIVE_UI_TEST_FIXTURE"', 1)
        self.assertIn('if [[ -n "$GESTURE_VALIDATION_PROFILE" ]]; then', gesture)
        self.assertNotIn("LaunchcopyUITestEntry", gesture)
        self.assertIn('python3 -B "$ROOT/Scripts/verify-gesture-validation-entry.py" "$APP_DIR"', gesture)
        self.assertIn('if [[ -n "$NATIVE_UI_TEST_PROFILE" ]]; then\n'
                      '    python3 -B "$ROOT/Scripts/verify-native-ui-test-entry.py"', native)
        self.assertEqual(len(re.findall(r'plutil -insert LaunchcopyUITestEntry -xml', native)), 2)

    def test_manifest_modes_isolation_and_resource_checks_remain(self):
        for fragment in (
            'GESTURE_VALIDATION_ENTRY_MODE="absent"',
            'NATIVE_UI_TEST_ENTRY_MODE="absent"',
            'GESTURE_VALIDATION_ENTRY_MODE="marker-v1"\n  PROFILE_ISOLATED="true"',
            'NATIVE_UI_TEST_ENTRY_MODE="marker-v1"',
            'NATIVE_UI_TEST_ENTRY_MODE="marker-v2-sources-v1"',
            'echo "gesture_validation_entry_mode=$GESTURE_VALIDATION_ENTRY_MODE"',
            'echo "native_ui_test_entry_mode=$NATIVE_UI_TEST_ENTRY_MODE"',
            'echo "profile_isolated=$PROFILE_ISOLATED"',
            'echo "info_plist_sha256=',
            'plutil -lint "$PLIST"',
            'swift build -c "$CONFIGURATION" --product LocalizationResourceProbe',
            '"$RESOURCE_PROBE" "$APP_DIR"',
            'for LANGUAGE in en zh-hans ja; do',
            'LOCALIZATION_RESOURCES.sha256',
            'echo "localization_manifest_sha256=',
            'echo "exe_sha256=',
        ):
            self.assertIn(fragment, self.source)


if __name__ == "__main__":
    unittest.main()
