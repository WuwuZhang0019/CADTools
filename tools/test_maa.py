"""Execute the actual MAA source with injected CAD calls.

Date: 2026-11-03. This does not validate native Tianzheng display behavior.
Set AUTOLISP_TESTS if the existing test host is outside the sibling project.
"""

import os
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
HOST_DIR = Path(os.environ.get(
    "AUTOLISP_TESTS",
    str(ROOT.parent / "AI画CAD" / "Emergency-Lighting" / "tests"),
))
if not (HOST_DIR / "autolisp_host.py").is_file():
    raise SystemExit("Set AUTOLISP_TESTS to the directory containing autolisp_host.py")
sys.dont_write_bytecode = True
sys.path.insert(0, str(HOST_DIR))
from autolisp_host import Host, Pair, Symbol, parse  # noqa: E402

VARIANTS = (
    (ROOT / "Zyf.autoCAD/Tools/06 文字复制(maa).lsp", "MAA"),
    (ROOT / "test/MAANAMETEST.lsp", "MAANAMETEST"),
)


def field(data, code):
    return next((p.cdr for p in data if p.car == code), None)


def replace(data, code, value):
    return [Pair(code, value) if p.car == code else p for p in data]


class Cad:
    def __init__(self, path, command, source_kind="TEXT", target_kind="TCH_DRAWINGNAME",
                 text="电装变-05C", failure=None, scale="1:150"):
        self.host = Host()
        self.forms = parse(path.read_bytes().decode("gb2312", errors="strict"))
        for form in self.forms:
            if isinstance(form, list) and form[0] == "DEFUN":
                self.host.evaluate(form)
        self.command = command
        self.failure = failure
        self.viewport = 2
        self.highlights, self.writes, self.refreshes, self.messages = set(), [], [], []
        self.data = {
            "source": [Pair(-1, "source"), Pair(0, source_kind), Pair(1, text), Pair(2, "1:100")],
            "target": [Pair(-1, "target"), Pair(0, target_kind), Pair(5, "E48"),
                       Pair(100, "AcDbEntity"), Pair(8, "DIM_SYMB"),
                       Pair(100, "TDbDrawingName"), Pair(1, "地下二层装修照明平面图"),
                       Pair(2, scale), Pair(40, 7.0), Pair(41, 5.0), Pair(340, "6B")],
        }
        self.original = self.data["target"][:]
        self.picks = iter(("source", "target"))
        self.host.builtins.update({
            "VL-LOAD-COM": lambda: None, "CHR": chr,
            "NENTSEL": self.pick, "ENTGET": self.read,
            "ENTMOD": self.write, "ENTUPD": self.refreshes.append,
            "GETVAR": lambda name: self.viewport if name == "CVPORT" else None,
            "SETVAR": self.setvar, "REDRAW": self.redraw,
            "PRINC": lambda *values: self.messages.extend(values),
        })

    def pick(self, prompt):
        entity = next(self.picks)
        if entity == "target":
            self.viewport = 3
        return [entity, [0, 0, 0]]

    def setvar(self, name, value):
        assert name == "CVPORT"
        self.viewport = value
        return value

    def redraw(self, entity, mode):
        key = (entity, self.viewport)
        if mode == 3:
            self.highlights.add(key)
        elif mode == 4:
            self.highlights.discard(key)
        else:
            raise AssertionError(mode)

    def read(self, entity, apps=None):
        if self.failure == "read" and entity == "target" and len(self.writes) == 1:
            raise RuntimeError("injected readback failure")
        return self.data[entity][:]

    def write(self, data):
        self.writes.append(data[:])
        if len(self.writes) == 1:
            if self.failure == "reject":
                return None
            if self.failure == "throw":
                raise RuntimeError("injected write failure")
            if self.failure == "title":
                data = replace(data, 1, "stale title")
            if self.failure == "scale":
                data = replace(data, 2, "1:999")
        self.data[field(data, -1)] = data[:]
        return data

    def run(self):
        self.host.call(Symbol("C:" + self.command), [])
        return self


class MaaTests(unittest.TestCase):
    def test_ordinary_sources_update_only_the_title(self):
        for path, command in VARIANTS:
            for kind in ("TEXT", "MTEXT", "ATTRIB"):
                for scale in ("1:150", "1:100", ""):
                    with self.subTest(command=command, source=kind, scale=scale):
                        cad = Cad(path, command, source_kind=kind, scale=scale).run()
                        expected = replace(cad.original, 1, "电装变-05C")
                        self.assertEqual(cad.writes, [expected])
                        self.assertEqual(cad.data["target"], expected)
                        self.assertIn("\n文字复制完成。", cad.messages)
                        self.assertFalse(cad.highlights)
                        self.assertEqual(cad.viewport, 3)

    def test_reverse_copy_still_reads_only_the_title(self):
        for path, command in VARIANTS:
            cad = Cad(path, command, source_kind="TCH_DRAWINGNAME", target_kind="TEXT").run()
            self.assertEqual(field(cad.data["target"], 1), "电装变-05C")
            self.assertNotIn("1:100", field(cad.data["target"], 1))
            self.assertEqual(len(cad.writes), 1)

    def test_multiline_sources_do_not_modify_the_title(self):
        for path, command in VARIANTS:
            for value in ("一行\n二行", "一行\r\n二行", r"一行\P二行"):
                with self.subTest(command=command, value=value):
                    cad = Cad(path, command, source_kind="MTEXT", text=value).run()
                    self.assertEqual(cad.writes, [])
                    self.assertEqual(cad.data["target"], cad.original)
                    self.assertFalse(cad.highlights)

    def test_missing_or_invalid_scale_does_not_write(self):
        for path, command in VARIANTS:
            for scale in (None, 150):
                cad = Cad(path, command, scale=scale)
                if scale is None:
                    cad.data["target"] = [p for p in cad.original if p.car != 2]
                original = cad.data["target"][:]
                cad.run()
                self.assertEqual(cad.writes, [])
                self.assertEqual(cad.data["target"], original)

    def test_failures_restore_the_original_title_and_scale(self):
        for path, command in VARIANTS:
            for failure in ("reject", "throw", "title", "scale", "read"):
                with self.subTest(command=command, failure=failure):
                    cad = Cad(path, command, failure=failure).run()
                    self.assertEqual(cad.data["target"], cad.original)
                    self.assertEqual(cad.writes[-1], cad.original)
                    self.assertNotIn("\n文字复制完成。", cad.messages)
                    self.assertFalse(cad.highlights)
                    self.assertEqual(cad.viewport, 3)

    def test_other_protected_tianzheng_targets_remain_blocked(self):
        for path, command in VARIANTS:
            for kind in ("TCH_MTEXT", "TCH_WIREDIM2"):
                cad = Cad(path, command, target_kind=kind).run()
                self.assertEqual(cad.writes, [])
                self.assertEqual(cad.data["target"], cad.original)
                self.assertIn("\n不支持此种操作", cad.messages)

    def test_test_script_has_matching_definitions_and_waits_for_command(self):
        source = VARIANTS[0][0].read_bytes().decode("gb2312")
        test = VARIANTS[1][0].read_bytes().decode("gb2312")
        normalized = test.replace("MAANAMETEST:", "MAA:").replace("c:MAANAMETEST", "c:maa")
        definitions = lambda text: [f for f in parse(text) if isinstance(f, list) and f[0] == "DEFUN"]
        self.assertEqual(definitions(source), definitions(normalized))
        cad = Cad(*VARIANTS[1])
        for form in cad.forms:
            cad.host.evaluate(form)
        self.assertEqual(cad.writes, [])
        self.assertFalse(cad.highlights)


if __name__ == "__main__":
    unittest.main()
