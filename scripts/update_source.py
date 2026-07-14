#!/usr/bin/env python3
"""Patch source/apps.json for a release.

The source is served raw from main, so this must only land on main after the
release asset is actually downloadable (i.e. the GitHub release is published).
Used by make_ipa.sh locally and by .github/workflows/publish-source.yml.
"""
import argparse
import json
from pathlib import Path

DEFAULT_NOTES = "See release notes on GitHub"
MIN_OS_VERSION = "12.0"


def main():
    parser = argparse.ArgumentParser(description="Update the AltStore/SideStore source")
    parser.add_argument("--version", required=True)
    parser.add_argument("--download-url", required=True)
    parser.add_argument("--size", type=int, required=True, help="IPA size in bytes")
    parser.add_argument("--date", required=True, help="ISO 8601, e.g. 2026-07-14T11:11:29Z")
    parser.add_argument("--notes-file", help="file with the changelog text")
    parser.add_argument("--file", default="source/apps.json")
    args = parser.parse_args()

    notes = DEFAULT_NOTES
    if args.notes_file:
        text = Path(args.notes_file).read_text(encoding="utf-8").strip()
        if text:
            notes = text

    path = Path(args.file)
    data = json.loads(path.read_text(encoding="utf-8"))
    app = data["apps"][0]

    entry = {
        "version": args.version,
        "date": args.date,
        "localizedDescription": notes,
        "downloadURL": args.download_url,
        "size": args.size,
        "minOSVersion": MIN_OS_VERSION,
    }
    older = [v for v in app.get("versions", []) if v.get("version") != args.version]
    app["versions"] = [entry] + older

    # AltStore reads these root-level duplicates of the latest version entry.
    app["version"] = args.version
    app["versionDate"] = args.date
    app["versionDescription"] = notes
    app["downloadURL"] = args.download_url
    app["size"] = args.size

    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Updated {path}: {app['name']} v{args.version} ({args.size} bytes)")


if __name__ == "__main__":
    main()
