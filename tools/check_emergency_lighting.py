"""Verify the v0.1.84 full delivery, host entry and optional build output.

Date: 2026-10-29
"""
import argparse
import hashlib
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "Zyf.autoCAD" / "Tools" / "Emergency-Lighting"
FILES = {
    "full-v0.1.84.zip": "a3525a0e73ec174d6f6caba413edf5f54e00ff5a91fe8290287dbf6970ea8931",
    "ELFULL84-CADTools.lsp": "e711bbe08052f586dadb41d04efcff760c8e4f701742e84949267d0a58721035",
}
PREFIX = "应急照明-v0.1.84/"


def verify(output: Path | None = None) -> None:
    files = {p.relative_to(MODULE).as_posix(): p.read_bytes() for p in MODULE.rglob("*") if p.is_file()}
    if set(files) != set(FILES):
        raise ValueError(f"Module files differ: {sorted(files)}")
    for name, expected in FILES.items():
        if hashlib.sha256(files[name]).hexdigest() != expected:
            raise ValueError(f"Unexpected delivery hash: {name}")
    with zipfile.ZipFile(MODULE / "full-v0.1.84.zip") as archive:
        if archive.testzip() is not None:
            raise ValueError("Full delivery archive is corrupt")
        members = [item for item in archive.infolist() if not item.is_dir()]
        names = [item.filename for item in members]
        if len(members) != 403 or len(set(names)) != len(names) or any(not n.startswith(PREFIX) for n in names):
            raise ValueError("Full delivery file list differs")
        for required in ("ELFULL84.lsp", "src/batch-number.lsp", "src/load.lsp", "package-183.marker",
                         "native/EmergencyLighting.ColdRecognition84.dll", "templates/系统图块库.dwg"):
            if PREFIX + required not in names:
                raise ValueError(f"Missing full-package file: {required}")
        count = 0
        for member in members:
            if member.filename.endswith((".lsp", ".dcl")):
                data = archive.read(member)
                if data.startswith((b"\xef\xbb\xbf", b"\xff\xfe", b"\xfe\xff")):
                    raise ValueError(f"BOM is not allowed: {member.filename}")
                if data.decode("gb2312", errors="strict").encode("gb2312", errors="strict") != data:
                    raise ValueError(f"GB2312 round-trip failed: {member.filename}")
                count += 1
        entry = files["ELFULL84-CADTools.lsp"].decode("gb2312", errors="strict")
        original = archive.read(PREFIX + "ELFULL84.lsp").decode("gb2312", errors="strict")
        batch = archive.read(PREFIX + "src/batch-number.lsp").decode("gb2312", errors="strict")
        if batch not in entry or "'EL:CADToolsStartupRoot" not in entry:
            raise ValueError("The full entry is missing the CADTools root or batch commands")
        if "(defun ELFULL84:Initialize ()" not in original or "(defun ELFULL84:Initialize ()" not in entry:
            raise ValueError("Full entry is missing")
    print(f"PASS: v0.1.84 archive: {len(members)} files; source and adapted-entry hashes match")
    print(f"PASS: {count} archive LISP/DCL files round-trip as strict GB2312 without BOM")
    if output is not None:
        actual = {p.relative_to(output).as_posix(): p.read_bytes() for p in output.rglob("*") if p.is_file()}
        if files != actual:
            raise ValueError(f"Build output differs: {sorted(actual)}")
        print(f"PASS: all {len(files)} packaged files match the build output byte for byte")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        verify(args.output)
    except (OSError, UnicodeError, ValueError, zipfile.BadZipFile) as exc:
        print(f"ERROR: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
