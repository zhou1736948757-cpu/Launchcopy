#!/usr/bin/env python3
"""Stdlib temporary-directory and static packaging checks; never build or launch."""

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
    "integrated_preview_verifier", SCRIPTS / "verify-integrated-preview-entry.py"
)
VERIFIER = importlib.util.module_from_spec(SPEC)
PREVIOUS_BYTECODE = sys.dont_write_bytecode
try:
    sys.dont_write_bytecode = True
    SPEC.loader.exec_module(VERIFIER)
finally:
    sys.dont_write_bytecode = PREVIOUS_BYTECODE
REJECTIONS = (ValueError, OSError, RuntimeError, ExpatError)


class IntegratedPreviewEntryTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="integrated-preview-entry-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.candidate = self.root / ".build/candidates/preview"
        self.bundle = self.candidate / "IntegratedPreview.app"
        self.profile = "preview-test-23"
        self.profile_root = self.candidate / "UITestProfiles" / self.profile

    def metadata(self):
        return {"CFBundleIdentifier": VERIFIER.RESERVED_BUNDLE_ID,
                VERIFIER.MARKER_KEY: {"version": 1, "profile": self.profile}}

    def write_metadata(self, metadata, *, fmt=plistlib.FMT_XML):
        contents = self.bundle / "Contents"
        contents.mkdir(parents=True, exist_ok=True)
        (contents / "Info.plist").write_bytes(plistlib.dumps(metadata, fmt=fmt))

    def snapshot(self):
        """Record bytes, modes and link targets without following links."""
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

    def preflight(self, path=None, profile=None):
        VERIFIER.validate_integrated_destination(
            self.bundle if path is None else path,
            self.profile if profile is None else profile)

    def verify(self):
        VERIFIER.validate_app(self.bundle)

    def test_valid_destination_and_xml_binary_metadata_create_no_storage(self):
        self.assert_read_only(self.preflight)
        self.assertFalse(self.candidate.exists())
        for fmt in (plistlib.FMT_XML, plistlib.FMT_BINARY):
            with self.subTest(fmt=fmt):
                self.write_metadata(self.metadata(), fmt=fmt)
                self.assert_read_only(self.verify)
                self.assertFalse(self.profile_root.parent.exists())
        for child in ("Layout", "Applications", "WallpaperCache", "Library", "LaunchActivity"):
            (self.profile_root / child).mkdir(parents=True, exist_ok=True)
        self.assert_read_only(self.verify)
        self.assert_read_only(lambda: self.preflight(self.candidate / "Fresh.app"))
        self.assertFalse((self.profile_root / "Applications/Baseline").exists())
        self.assertFalse((self.profile_root / "Applications/Extras").exists())

    def test_profile_grammar_rejects_wrong_types_and_unsafe_ids(self):
        for profile in ("a", "a" * 48, "preview-20261023-pkg-01"):
            self.assert_read_only(lambda: self.preflight(profile=profile))
        for profile in (None, False, True, 1, 1.0, [], {}, "", "../escape", "a/b",
                        "a\n", "A", " a", "a_1", "é", "a" * 49, "-a"):
            with self.subTest(profile=profile):
                self.assert_read_only(lambda: VERIFIER.validate_integrated_destination(
                    self.candidate / "Fresh.app", profile), rejected=True)
                metadata = self.metadata()
                metadata[VERIFIER.MARKER_KEY]["profile"] = profile
                self.write_metadata(metadata, fmt=plistlib.FMT_BINARY)
                self.assert_read_only(self.verify, rejected=True)

    def test_exact_marker_keys_and_integer_one(self):
        markers = [None, False, 1, [], "marker", {}, {"version": 1},
                   {"profile": self.profile}]
        markers += [{"version": version, "profile": self.profile}
                    for version in (True, False, 1.0, 0, 2, -1, "1", [], {})]
        markers += [{"version": 1, "profile": self.profile, extra: "sources-v1"}
                    for extra in ("fixture", "realBackend", "args", "unknown")]
        for marker in markers:
            with self.subTest(marker=marker):
                metadata = self.metadata()
                metadata[VERIFIER.MARKER_KEY] = marker
                self.write_metadata(metadata, fmt=plistlib.FMT_BINARY)
                self.assert_read_only(self.verify, rejected=True)

    def test_wrong_identity_missing_and_all_mixed_markers_reject(self):
        for bundle_id in (None, False, 1, 1.0, [], {}, "", "com.launchcopy.app",
                          "com.launchcopy.ui-test", "com.launchcopy.gesture-validation",
                          "com.launchcopy.integrated-preview.extra"):
            with self.subTest(bundle_id=bundle_id):
                metadata = self.metadata()
                metadata["CFBundleIdentifier"] = bundle_id
                self.write_metadata(metadata, fmt=plistlib.FMT_BINARY)
                self.assert_read_only(self.verify, rejected=True)
        for metadata in ({}, {"CFBundleIdentifier": VERIFIER.RESERVED_BUNDLE_ID},
                         {"CFBundleIdentifier": "com.launchcopy.app"}):
            self.write_metadata(metadata)
            self.assert_read_only(self.verify, rejected=True)
        for keys in (("LaunchcopyUITestEntry",), ("LaunchcopyGestureValidationEntry",),
                     ("LaunchcopyUITestEntry", "LaunchcopyGestureValidationEntry")):
            for marker in (False, {}, {"version": 1, "profile": self.profile},
                           {"version": 2, "profile": self.profile, "fixture": "sources-v1"}):
                with self.subTest(keys=keys, marker=marker):
                    metadata = self.metadata()
                    metadata.update({key: marker for key in keys})
                    self.write_metadata(metadata)
                    self.assert_read_only(self.verify, rejected=True)

    def test_candidate_ancestry_and_extension_fail_closed(self):
        for path in (self.root / "Preview.app", self.root / ".build/Preview.app",
                     self.root / ".build/candidates/Preview.app",
                     self.root / ".build/candidates-other/owned/Preview.app",
                     self.candidate / "Preview.txt", self.candidate / "Preview.APP"):
            with self.subTest(path=path):
                self.assert_read_only(lambda: self.preflight(path), rejected=True)
                original = self.bundle
                try:
                    self.bundle = path
                    self.write_metadata(self.metadata())
                    self.assert_read_only(self.verify, rejected=True)
                finally:
                    self.bundle = original

    def test_existing_destinations_and_symlink_candidate_aliases_reject(self):
        self.write_metadata(self.metadata())
        self.assert_read_only(self.preflight, rejected=True)
        for kind in ("file", "app-link", "dangling", "self-link"):
            path = self.candidate / (kind + ".app")
            if kind == "file":
                path.write_bytes(b"owned")
            else:
                target = {"app-link": self.bundle, "dangling": self.root / "Absent",
                          "self-link": path}[kind]
                path.symlink_to(target)
            self.assert_read_only(lambda: self.preflight(path), rejected=True)
            self.assert_read_only(lambda: VERIFIER.validate_app(path), rejected=True)
        outside = self.root / "Outside"
        outside.mkdir()
        for name, target in (("Alias", self.candidate), ("Escape", outside)):
            alias = self.candidate.parent / name
            alias.symlink_to(target, target_is_directory=True)
            self.assert_read_only(lambda: self.preflight(alias / "Fresh.app"), rejected=True)
            self.assert_read_only(lambda: VERIFIER.validate_app(
                alias / self.bundle.name), rejected=True)
        escaped = self.candidate / ".." / ".." / ".." / "Outside/Preview.app"
        self.assert_read_only(lambda: self.preflight(escaped), rejected=True)

    def test_all_eight_storage_guards_reject_files_and_links(self):
        guarded = (self.profile_root.parent, self.profile_root,
                   *(self.profile_root / child for child in
                     ("Layout", "Applications", "WallpaperCache", "Library", "LaunchActivity", "MainGridCapacity")))
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
                    self.assert_read_only(lambda: self.preflight(
                        self.candidate / "Fresh.app"), rejected=True)
                    self.write_metadata(self.metadata())
                    self.assert_read_only(self.verify, rejected=True)
                    directory.unlink()

    def test_shared_bounded_reader_rejects_duplicates_and_nonregular_metadata(self):
        self.write_metadata(self.metadata())
        plist = self.bundle / "Contents/Info.plist"
        original = plist.read_bytes()
        for key, value in ((b"version", b"<integer>1</integer>"),
                           (b"CFBundleIdentifier", b"<string>wrong</string>")):
            token = b"<key>" + key + b"</key>"
            plist.write_bytes(original.replace(token, token + value + token))
            self.assert_read_only(self.verify, rejected=True)
        for data in (b"not a plist", b"x" * (1024 * 1024 + 1), plistlib.dumps([])):
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

    def test_cli_only_accepts_one_bundle_argument_and_errors_are_neutral(self):
        self.write_metadata(self.metadata())
        for argv in ([], ["--help"], [str(self.root / "Absent.app")],
                     [str(self.bundle), self.profile], [str(self.bundle), "--help"],
                     [str(self.bundle), "--real-backend"],
                     [str(self.bundle), "--profile", self.profile]):
            output = io.StringIO()
            with redirect_stdout(output):
                self.assert_read_only(lambda: self.assertEqual(VERIFIER.main(argv), 1))
            self.assertEqual(output.getvalue(), "integrated-preview-entry: rejected\n")
        output = io.StringIO()
        with redirect_stdout(output):
            self.assert_read_only(lambda: self.assertEqual(
                VERIFIER.main([str(self.bundle)]), 0))
        self.assertEqual(output.getvalue(), "integrated-preview-entry: accepted\n")
        (self.bundle / "Contents/Info.plist").write_bytes(b"invalid private metadata")
        output = io.StringIO()
        with redirect_stdout(output):
            self.assert_read_only(lambda: self.assertEqual(
                VERIFIER.main([str(self.bundle)]), 1))
        self.assertEqual(output.getvalue(), "integrated-preview-entry: rejected\n")


class PackagingStaticContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (SCRIPTS / "package-app.sh").read_text(encoding="utf-8")

    def test_preflight_identity_and_pairwise_exclusion_precede_writes_and_builds(self):
        preflight, remainder = self.source.split('mkdir -p "$APP_PARENT_ABS"', 1)
        for operation in ("swift build", "mkdir -p", "plutil -insert"):
            self.assertNotIn(operation, preflight)
        for guard in (
            'INTEGRATED_PREVIEW_PROFILE="${INTEGRATED_PREVIEW_PROFILE:-}"',
            '[[ -n "$INTEGRATED_PREVIEW_PROFILE" && ( -n "$NATIVE_UI_TEST_PROFILE" || -n "$NATIVE_UI_TEST_FIXTURE" || -n "$GESTURE_VALIDATION_PROFILE" ) ]]',
            '[[ -n "$GESTURE_VALIDATION_PROFILE" && ( -n "$NATIVE_UI_TEST_PROFILE" || -n "$NATIVE_UI_TEST_FIXTURE" ) ]]',
            '[[ "$INTEGRATED_PREVIEW_PROFILE" =~ ^[a-z0-9][a-z0-9-]{0,47}$ ]] || die',
            '[[ "$BUNDLE_ID" == "com.launchcopy.integrated-preview" ]] || die',
            '[[ "$LEGACY_DESTRUCTIVE" == "0" ]] || die "integrated preview entry requires non-destructive packaging"',
            'checker.validate_integrated_destination(sys.argv[2], sys.argv[3])',
            'elif [[ "$BUNDLE_ID" == "com.launchcopy.integrated-preview" ]]; then\n'
            '  die "reserved bundle ID requires explicit integrated preview profile"',
            'relative = parent.relative_to(root / ".build")',
        ):
            self.assertIn(guard, preflight)
        mixed = preflight.index('if [[ -n "$INTEGRATED_PREVIEW_PROFILE" &&')
        self.assertLess(mixed, preflight.index('if [[ -n "$NATIVE_UI_TEST_FIXTURE" ]]'))
        self.assertIn('"$ROOT/Scripts/verify-integrated-preview-entry.py" '
                      '"$APP_DIR" "$INTEGRATED_PREVIEW_PROFILE" <<', preflight)
        self.assertIn("swift build", remainder)

    def test_exact_marker_and_dedicated_verification_without_fixture_imports(self):
        fragments = re.findall(
            r'plutil -insert LaunchcopyIntegratedPreviewEntry -xml "([^"]+)"', self.source)
        self.assertEqual(len(fragments), 1)
        marker = plistlib.loads(('<plist version="1.0">' + fragments[0].replace(
            '${INTEGRATED_PREVIEW_PROFILE}', 'preview-test') + '</plist>').encode())
        self.assertEqual(marker, {"version": 1, "profile": "preview-test"})
        self.assertIs(type(marker["version"]), int)
        assembly = self.source.split('if [[ "$PROFILE_ISOLATED" == "true" ]]; then', 1)[1]
        preview = assembly.split('elif [[ -n "$INTEGRATED_PREVIEW_PROFILE" ]]; then', 1)[1]
        preview = preview.split('elif [[ "$NATIVE_UI_TEST_FIXTURE"', 1)[0]
        self.assertIn('python3 -B "$ROOT/Scripts/verify-integrated-preview-entry.py" '
                      '"$APP_DIR"', preview)
        for unexpected in ("LaunchcopyUITestEntry", "LaunchcopyGestureValidationEntry",
                           "sources-v1", "cp ", "UITestProfiles"):
            self.assertNotIn(unexpected, preview)

    def test_manifest_modes_and_existing_entry_and_resource_contracts_remain(self):
        for fragment in (
            'INTEGRATED_PREVIEW_ENTRY_MODE="absent"',
            'INTEGRATED_PREVIEW_ENTRY_MODE="marker-v1"\n  PROFILE_ISOLATED="true"',
            'echo "integrated_preview_entry_mode=$INTEGRATED_PREVIEW_ENTRY_MODE"',
            'NATIVE_UI_TEST_ENTRY_MODE="absent"',
            'NATIVE_UI_TEST_ENTRY_MODE="marker-v1"',
            'NATIVE_UI_TEST_ENTRY_MODE="marker-v2-sources-v1"',
            'GESTURE_VALIDATION_ENTRY_MODE="absent"',
            'GESTURE_VALIDATION_ENTRY_MODE="marker-v1"',
            'echo "profile_isolated=$PROFILE_ISOLATED"',
            'python3 -B "$ROOT/Scripts/verify-native-ui-test-entry.py" "$APP_DIR"',
            'python3 -B "$ROOT/Scripts/verify-gesture-validation-entry.py" "$APP_DIR"',
            'swift build -c "$CONFIGURATION" --product LocalizationResourceProbe',
            '"$RESOURCE_PROBE" "$APP_DIR"',
            'LOCALIZATION_RESOURCES.sha256',
        ):
            self.assertIn(fragment, self.source)


if __name__ == "__main__":
    unittest.main()
