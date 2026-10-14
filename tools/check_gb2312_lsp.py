"""Check the AutoLISP source files loaded or tested by CADTools.

Date: 2026-10-14
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LISP_DIRS = (ROOT / "Zyf.autoCAD" / "Tools", ROOT / "test")


def main() -> int:
    paths = sorted(path for directory in LISP_DIRS for path in directory.rglob("*.lsp"))
    errors = []

    for path in paths:
        raw = path.read_bytes()
        relative = path.relative_to(ROOT)
        if raw.startswith(b"\xef\xbb\xbf"):
            errors.append(f"{relative}: UTF-8 BOM is not allowed")
            continue
        try:
            text = raw.decode("gb2312", errors="strict")
            rebuilt = text.encode("gb2312", errors="strict")
        except UnicodeError as exc:
            errors.append(f"{relative}: {exc}")
            continue
        if rebuilt != raw:
            errors.append(f"{relative}: GB2312 byte round-trip mismatch")

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    print(f"PASS: {len(paths)} LSP files decode and round-trip as strict GB2312; no BOM")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
