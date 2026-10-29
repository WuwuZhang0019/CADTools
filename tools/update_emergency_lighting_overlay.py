"""Embed the reviewed CADTools overlay in the v0.1.84 entry.

Date: 2026-10-29. The original upstream ZIP is never modified.
"""
import hashlib
from pathlib import Path

from emergency_lighting_v84_overlay import END, OVERLAY, START


ROOT = Path(__file__).resolve().parents[1]
ENTRY = ROOT / "Zyf.autoCAD/Tools/Emergency-Lighting/ELFULL84-CADTools.lsp"
BASE_SHA256 = "e711bbe08052f586dadb41d04efcff760c8e4f701742e84949267d0a58721035"
ANCHOR = "\n)\n(defun c:ELFULL84 (/ outcome)"


def main() -> None:
    raw = ENTRY.read_bytes()
    text = raw.decode("gb2312", errors="strict")
    overlay = START + OVERLAY + END
    overlay.encode("gb2312", errors="strict")
    if START in text or END in text:
        if text.count(START) != 1 or text.count(END) != 1:
            raise ValueError("Overlay markers are missing or duplicated")
        begin = text.index(START)
        end = text.index(END, begin) + len(END)
        text = text[:begin] + overlay + text[end:]
    else:
        if hashlib.sha256(raw).hexdigest() != BASE_SHA256 or text.count(ANCHOR) != 1:
            raise ValueError("Unrecognized entry; refusing to insert the overlay")
        text = text.replace(ANCHOR, "\n" + overlay + ANCHOR, 1)
    result = text.encode("gb2312", errors="strict")
    if result.decode("gb2312", errors="strict") != text:
        raise ValueError("GB2312 round trip failed")
    ENTRY.write_bytes(result)
    print("Updated entry SHA256:", hashlib.sha256(result).hexdigest())
    print("Update EntrySha256 in EmergencyLightingRuntime.cs and the integration check.")


if __name__ == "__main__":
    main()
