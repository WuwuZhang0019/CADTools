"""Verify the immutable Emergency-Lighting runtime and optional build output.

Date: 2026-10-16
"""

import argparse
import hashlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "Zyf.autoCAD" / "Tools" / "Emergency-Lighting"
VERSION = "lite-v0.1.61"
FILE_COUNT = 139
TOTAL_BYTES = 2722854
TREE_SHA256 = "254e7316012f2f17b0ca5d1aa1ad12de8d688e18b7fbc213651129cad06b8810"


def verify(output: Path | None = None) -> None:
    files = {
        path.relative_to(MODULE).as_posix(): path.read_bytes()
        for path in MODULE.rglob("*")
        if path.is_file()
    }
    if len(files) != FILE_COUNT or sum(map(len, files.values())) != TOTAL_BYTES:
        raise ValueError("Runtime file count or byte count differs from the delivery")

    digest = hashlib.sha256()
    encoded_count = 0
    for name, data in sorted(files.items()):
        digest.update(name.encode("utf-8") + b"\0" + hashlib.sha256(data).digest())
        if name.endswith((".lsp", ".dcl")):
            if data.startswith((b"\xef\xbb\xbf", b"\xff\xfe", b"\xfe\xff")):
                raise ValueError(f"{name}: BOM is not allowed")
            if data.decode("gb2312", errors="strict").encode("gb2312", errors="strict") != data:
                raise ValueError(f"{name}: strict GB2312 byte round-trip failed")
            encoded_count += 1
    if digest.hexdigest() != TREE_SHA256:
        raise ValueError("Runtime content differs from the verified lite-v0.1.61 delivery")
    print(f"PASS: {VERSION}: {len(files)} files, {TOTAL_BYTES} bytes; delivery tree SHA-256 matches")
    print(f"PASS: {encoded_count} LISP/DCL files round-trip as strict GB2312 without BOM")

    if output is not None:
        actual = {
            path.relative_to(output).as_posix(): path.read_bytes()
            for path in output.rglob("*")
            if path.is_file()
        }
        if files != actual:
            missing = sorted(files.keys() - actual.keys())
            extra = sorted(actual.keys() - files.keys())
            changed = sorted(name for name in files.keys() & actual.keys() if files[name] != actual[name])
            raise ValueError(f"Build output differs: missing={missing}, extra={extra}, changed={changed}")
        print(f"PASS: all {len(files)} build-output files match the runtime byte for byte")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Build-output Tools/Emergency-Lighting directory")
    args = parser.parse_args()
    try:
        verify(args.output)
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"ERROR: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
