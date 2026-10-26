#!/usr/bin/env python3
"""Verify dedicated gesture metadata without launching code or creating storage."""

import importlib.util
from pathlib import Path
import sys
import stat


# Keep candidate/profile paths and bounded plist reading identical to the native
# verifier. Loading this shared implementation must not create __pycache__ files.
_spec = importlib.util.spec_from_file_location(
    "gesture_validation_shared_paths",
    Path(__file__).resolve().with_name("verify-native-ui-test-entry.py"),
)
_shared = importlib.util.module_from_spec(_spec)
_previous_bytecode = sys.dont_write_bytecode
try:
    sys.dont_write_bytecode = True
    _spec.loader.exec_module(_shared)
finally:
    sys.dont_write_bytecode = _previous_bytecode


MARKER_KEY = "LaunchcopyGestureValidationEntry"
RESERVED_BUNDLE_ID = "com.launchcopy.gesture-validation"
EntryValidationError = _shared.EntryValidationError


def validate_gesture_destination(app_path, profile):
    """Validate a new candidate before packaging writes; no fixture expansion."""
    _shared.validate_native_destination(app_path, profile)
    _validate_additional_storage(_shared.canonical_bundle(app_path, require_existing=False), profile)


def _validate_additional_storage(bundle, profile):
    # UITestProfile also owns these directories. The older shared validator
    # predates them; keep the dedicated preflight identical to runtime refusal.
    root = bundle.parent / "UITestProfiles" / profile
    for directory in (root / "Library", root / "LaunchActivity"):
        if directory.resolve(strict=False) != directory:
            raise EntryValidationError("invalid output directory")
        try:
            metadata = directory.lstat()
        except FileNotFoundError:
            continue
        if not stat.S_ISDIR(metadata.st_mode):
            raise EntryValidationError("invalid output directory")


def validate_app(app_path):
    """Require the dedicated identity and exact v1 marker, never a UI marker."""
    bundle = _shared.canonical_bundle(app_path, require_existing=True)
    metadata = _shared.read_bundle_metadata(bundle)
    if metadata.get("CFBundleIdentifier") != RESERVED_BUNDLE_ID:
        raise EntryValidationError("invalid metadata")
    if _shared.MARKER_KEY in metadata:
        raise EntryValidationError("invalid metadata")
    marker = metadata.get(MARKER_KEY)
    if (not isinstance(marker, dict)
            or set(marker) != {"version", "profile"}
            or type(marker["version"]) is not int
            or marker["version"] != 1):
        raise EntryValidationError("invalid metadata")
    _shared.validate_profile(marker["profile"])
    _shared.validate_candidate_location(bundle, marker["profile"])
    _validate_additional_storage(bundle, marker["profile"])


def main(argv):
    try:
        if len(argv) != 1:
            raise EntryValidationError("invalid invocation")
        validate_app(argv[0])
    except Exception:
        # Keep all parser/filesystem errors path-free and profile-free.
        print("gesture-validation-entry: rejected")
        return 1
    print("gesture-validation-entry: accepted")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
