#!/usr/bin/env python3
"""Validate bounded bundle metadata without launching code or opening preferences."""

import os
from pathlib import Path
import plistlib
import re
import stat
import sys


MARKER_KEY = "LaunchcopyUITestEntry"
RESERVED_BUNDLE_ID = "com.launchcopy.ui-test"
MAX_PLIST_BYTES = 1024 * 1024
PROFILE_PATTERN = re.compile(r"[a-z0-9][a-z0-9-]{0,47}", re.ASCII)
SOURCES_FIXTURE = "sources-v1"


class EntryValidationError(ValueError):
    """Neutral failure; never include paths or profile identifiers."""


class UniqueKeyDictionary(dict):
    """Reject duplicate plist keys instead of silently accepting the last value."""

    def __setitem__(self, key, value):
        if key in self:
            raise EntryValidationError("invalid metadata")
        super().__setitem__(key, value)


def validate_profile(profile):
    if type(profile) is not str or PROFILE_PATTERN.fullmatch(profile) is None:
        raise EntryValidationError("invalid metadata")


def canonical_bundle(app_path, *, require_existing):
    bundle = Path(app_path).resolve(strict=require_existing)
    if bundle.suffix != ".app" or (require_existing and not bundle.is_dir()):
        raise EntryValidationError("invalid bundle")
    return bundle


def validate_fixture(fixture):
    if type(fixture) is not str or fixture not in ("", SOURCES_FIXTURE):
        raise EntryValidationError("invalid metadata")


def validate_candidate_location(bundle, profile, fixture=""):
    """Mirror profile guards and the optional fixed Sources children; never create."""
    validate_profile(profile)
    validate_fixture(fixture)
    candidate = bundle.parent
    components = candidate.parts
    if not any(
        components[index] == ".build"
        and components[index + 1] == "candidates"
        for index in range(len(components) - 2)
    ):
        raise EntryValidationError("invalid location")

    profiles = candidate / "UITestProfiles"
    root = profiles / profile
    directories = (
        profiles,
        root,
        root / "Layout",
        root / "Applications",
        root / "WallpaperCache",
    )
    if fixture == SOURCES_FIXTURE:
        directories += (root / "Applications" / "Baseline", root / "Applications" / "Extras")
    for directory in directories:
        if directory.resolve(strict=False) != directory:
            raise EntryValidationError("invalid output directory")
        try:
            metadata = directory.lstat()
        except FileNotFoundError:
            continue
        if not stat.S_ISDIR(metadata.st_mode):
            # Includes dangling symlinks, even if resolution leaves the path unchanged.
            raise EntryValidationError("invalid output directory")


def validate_native_destination(app_path, profile, fixture=""):
    """Packaging preflight: validate a new destination before any artifact writes."""
    validate_profile(profile)
    supplied = Path(app_path)
    try:
        supplied.lstat()
    except FileNotFoundError:
        pass
    else:
        raise EntryValidationError("existing destination")
    bundle = canonical_bundle(supplied, require_existing=False)
    validate_candidate_location(bundle, profile, fixture)


def read_bundle_metadata(bundle):
    contents = bundle / "Contents"
    if not stat.S_ISDIR(contents.lstat().st_mode):
        raise EntryValidationError("invalid metadata")
    # Only read this fixed regular file, never a symlink, device, or unbounded stream.
    descriptor = os.open(
        contents / "Info.plist", os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK
    )
    with os.fdopen(descriptor, "rb") as stream:
        metadata = os.fstat(stream.fileno())
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_size > MAX_PLIST_BYTES:
            raise EntryValidationError("invalid metadata")
        data = stream.read(MAX_PLIST_BYTES + 1)
    if len(data) > MAX_PLIST_BYTES:
        raise EntryValidationError("invalid metadata")
    result = plistlib.loads(data, dict_type=UniqueKeyDictionary)
    if not isinstance(result, dict):
        raise EntryValidationError("invalid metadata")
    return result


def validate_app(app_path):
    bundle = canonical_bundle(app_path, require_existing=True)
    metadata = read_bundle_metadata(bundle)
    bundle_id = metadata.get("CFBundleIdentifier")
    if type(bundle_id) is not str or not bundle_id:
        raise EntryValidationError("invalid metadata")
    if MARKER_KEY not in metadata:
        if bundle_id == RESERVED_BUNDLE_ID:
            raise EntryValidationError("missing metadata")
        return

    marker = metadata[MARKER_KEY]
    if not isinstance(marker, dict) or type(marker.get("version")) is not int:
        raise EntryValidationError("invalid metadata")
    version = marker["version"]
    if version == 1 and set(marker) == {"version", "profile"}:
        fixture = ""
    elif version == 2 and set(marker) == {"version", "profile", "fixture"}:
        fixture = marker["fixture"]
        if type(fixture) is not str or fixture != SOURCES_FIXTURE:
            raise EntryValidationError("invalid metadata")
    else:
        raise EntryValidationError("invalid metadata")
    validate_profile(marker["profile"])
    if bundle_id != RESERVED_BUNDLE_ID:
        raise EntryValidationError("invalid metadata")
    validate_candidate_location(bundle, marker["profile"], fixture)


def main(argv):
    try:
        if len(argv) != 1:
            raise EntryValidationError("invalid invocation")
        validate_app(argv[0])
    except Exception:
        # Plist/parser/filesystem failures share the same path-free, profile-free output.
        print("native-ui-test-entry: rejected")
        return 1
    print("native-ui-test-entry: accepted")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
