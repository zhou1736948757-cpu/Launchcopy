#!/usr/bin/env python3
"""Verify isolated preview metadata without launching code or creating storage."""

import importlib.util
from pathlib import Path
import stat
import sys


# Reuse the canonical native candidate paths, strict profile grammar and bounded
# regular-file plist reader. Importing must not create bytecode beside the tools.
_spec = importlib.util.spec_from_file_location(
    "integrated_preview_shared_paths",
    Path(__file__).resolve().with_name("verify-native-ui-test-entry.py"),
)
_shared = importlib.util.module_from_spec(_spec)
_previous_bytecode = sys.dont_write_bytecode
try:
    sys.dont_write_bytecode = True
    _spec.loader.exec_module(_shared)
finally:
    sys.dont_write_bytecode = _previous_bytecode


MARKER_KEY = "LaunchcopyIntegratedPreviewEntry"
RESERVED_BUNDLE_ID = "com.launchcopy.integrated-preview"
EntryValidationError = _shared.EntryValidationError


def _canonical_bundle(app_path, *, require_existing):
    bundle = _shared.canonical_bundle(app_path, require_existing=require_existing)
    # The preview contract additionally refuses symlink aliases of candidates or
    # app bundles, even when the native canonical path would remain in bounds.
    if Path(app_path).absolute() != bundle:
        raise EntryValidationError("invalid location")
    return bundle


def _validate_additional_storage(bundle, profile):
    # Include every preview output, including capacity storage. The shared native
    # validator covers UITestProfiles, the profile and three base children.
    root = bundle.parent / "UITestProfiles" / profile
    for directory in (root / "Library", root / "LaunchActivity", root / "MainGridCapacity"):
        if directory.resolve(strict=False) != directory:
            raise EntryValidationError("invalid output directory")
        try:
            metadata = directory.lstat()
        except FileNotFoundError:
            continue
        if not stat.S_ISDIR(metadata.st_mode):
            raise EntryValidationError("invalid output directory")


def validate_integrated_destination(app_path, profile):
    """Preflight a new app destination without fixture expansion or writes."""
    _shared.validate_native_destination(app_path, profile)
    bundle = _canonical_bundle(app_path, require_existing=False)
    _validate_additional_storage(bundle, profile)


def validate_app(app_path):
    """Require the dedicated identity and exact v1 marker; reject mixed entries."""
    bundle = _canonical_bundle(app_path, require_existing=True)
    metadata = _shared.read_bundle_metadata(bundle)
    if metadata.get("CFBundleIdentifier") != RESERVED_BUNDLE_ID:
        raise EntryValidationError("invalid metadata")
    if (_shared.MARKER_KEY in metadata
            or "LaunchcopyGestureValidationEntry" in metadata):
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
        # Parser, filesystem and invocation errors expose no paths or profiles.
        print("integrated-preview-entry: rejected")
        return 1
    print("integrated-preview-entry: accepted")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
