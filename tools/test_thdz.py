"""Run the actual THDZ/THDJ LISP in the existing pure AutoLISP test host.

Date: 2026-11-03. CAD calls are injected; this is not native CAD validation.
Set AUTOLISP_TESTS if the host is outside the default sibling project.
"""

import os
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Zyf.autoCAD" / "Tools" / "04 图号文字递增V2.0(thdz).lsp"
HOST_DIR = Path(os.environ.get(
    "AUTOLISP_TESTS",
    str(ROOT.parent / "AI画CAD" / "Emergency-Lighting" / "tests"),
))
if not (HOST_DIR / "autolisp_host.py").is_file():
    raise SystemExit("Set AUTOLISP_TESTS to the directory containing autolisp_host.py")
sys.dont_write_bytecode = True
sys.path.insert(0, str(HOST_DIR))
from autolisp_host import Host, Pair, Symbol, parse  # noqa: E402


def encoded(value, mode):
    """Represent legacy GB2312 bytes as individual host string units."""
    if isinstance(value, Symbol):
        return value
    if isinstance(value, str):
        return value.encode("gb2312", errors="strict").decode("latin1") if mode == "legacy" else value
    if isinstance(value, list):
        return [encoded(item, mode) for item in value]
    if isinstance(value, Pair):
        return Pair(encoded(value.car, mode), encoded(value.cdr, mode))
    return value


def decoded(value, mode):
    if isinstance(value, str) and mode == "legacy":
        return value.encode("latin1").decode("gb2312", errors="strict")
    return value


FORMS = parse(SOURCE.read_bytes().decode("gb2312", errors="strict"))
MODES = ("unicode", "legacy")


class ThdzTests(unittest.TestCase):
    def host(self, mode):
        host = Host()
        host.builtins["CHR"] = chr
        for form in FORMS:
            if isinstance(form, list) and form[0] == "DEFUN":
                host.evaluate(encoded(form, mode))
        return host

    def next_text(self, host, text, mode):
        return decoded(host.call(Symbol("THDZ:NEXTTEXT"), [encoded(text, mode)]), mode)

    def previous_text(self, host, text, mode):
        return decoded(host.call(Symbol("THDZ:PREVIOUSTEXT"), [encoded(text, mode)]), mode)

    def command(self, mode, data=None, writable=True, picked=True, load=False, command="THDZ"):
        host = self.host(mode)
        original = encoded(data, mode)
        selections, writes, refreshes, notices = [], [], [], []

        def select(*_):
            selections.append(True)
            return ["entity", [0, 0, 0]] if picked else None

        def read(entity):
            self.assertTrue(picked, "cancelled selection must not read an entity")
            self.assertEqual(entity, "entity")
            return original

        def write(value):
            writes.append(value)
            return value if writable else None

        host.builtins.update({
            "ENTSEL": select,
            "ENTGET": read,
            "ENTMOD": write,
            "ENTUPD": refreshes.append,
            "PRINC": lambda *values: notices.extend(decoded(value, mode) for value in values),
        })
        if load:
            for form in FORMS:
                host.evaluate(encoded(form, mode))
        else:
            host.call(Symbol("C:" + command), [])
        return selections, writes, refreshes, notices

    def test_requested_prefixes_and_numeric_widths(self):
        for mode in MODES:
            host = self.host(mode)
            for prefix in ("电", "建", "水", "暖", "结", "电装", "建装", "地下室电装"):
                for number in ("0", "1", "01", "001", "00001", "12345678901234567890"):
                    text = f"{prefix}施-{number}"
                    for revision in ("A", "B", "C", "D"):
                        expected = f"{prefix}变-{number}{revision}"
                        with self.subTest(mode=mode, text=text):
                            self.assertEqual(self.next_text(host, text, mode), expected)
                        text = expected

    def test_letter_carries_and_long_revisions(self):
        examples = {
            "Y": "Z", "Z": "AA", "AA": "AB", "AZ": "BA",
            "YZ": "ZA", "ZZ": "AAA", "AAZ": "ABA", "AZZ": "BAA",
            "Z" * 40: "A" * 41,
        }
        for mode in MODES:
            host = self.host(mode)
            for lowercase in (False, True):
                for before, after in examples.items():
                    if lowercase:
                        before, after = before.lower(), after.lower()
                    with self.subTest(mode=mode, revision=before):
                        self.assertEqual(
                            self.next_text(host, "电装变-001" + before, mode),
                            "电装变-001" + after,
                        )

    def test_repeated_calls_follow_the_alphabet_across_carries(self):
        for mode in MODES:
            host = self.host(mode)
            for lowercase in (False, True):
                text = "建装变-00001a" if lowercase else "建装施-00001"
                for count in range(2 if lowercase else 1, 705):
                    ordinal, letters = count, ""
                    while ordinal:
                        ordinal, digit = divmod(ordinal - 1, 26)
                        letters = chr(ord("a" if lowercase else "A") + digit) + letters
                    text = self.next_text(host, text, mode)
                    self.assertEqual(text, "建装变-00001" + letters, (mode, lowercase, count))

    def test_decrement_across_letter_borrows(self):
        examples = {
            "B": "A", "Z": "Y", "AA": "Z", "AB": "AA", "BA": "AZ",
            "ZA": "YZ", "AAA": "ZZ", "ABA": "AAZ", "BAA": "AZZ",
            "A" * 40: "Z" * 39,
        }
        for mode in MODES:
            host = self.host(mode)
            for lowercase in (False, True):
                for before, after in examples.items():
                    if lowercase:
                        before, after = before.lower(), after.lower()
                    with self.subTest(mode=mode, revision=before):
                        self.assertEqual(
                            self.previous_text(host, "电装变-001" + before, mode),
                            "电装变-001" + after,
                        )

    def test_decrement_matches_reversed_alphabet_sequence(self):
        for mode in MODES:
            host = self.host(mode)
            for lowercase in (False, True):
                states = ["水施-00001"]
                for count in range(1, 705):
                    ordinal, letters = count, ""
                    while ordinal:
                        ordinal, digit = divmod(ordinal - 1, 26)
                        letters = chr(ord("a" if lowercase else "A") + digit) + letters
                    states.append("水变-00001" + letters)
                for count in range(704, 0, -1):
                    self.assertEqual(
                        self.previous_text(host, states[count], mode), states[count - 1],
                        (mode, lowercase, count),
                    )

    def test_first_revision_restores_stage_and_unmodified_stage_is_unchanged(self):
        for mode in MODES:
            host = self.host(mode)
            for prefix in ("电", "建", "水", "暖", "结", "电装", "建装"):
                for number in ("0", "01", "001", "00001", "12345678901234567890"):
                    initial = prefix + "施-" + number
                    for revision in ("A", "a"):
                        self.assertEqual(
                            self.previous_text(host, prefix + "变-" + number + revision, mode),
                            initial,
                        )
                    self.assertEqual(self.previous_text(host, initial, mode), initial)

    def test_invalid_input_is_rejected(self):
        invalid = (
            None, 123, "", "电", "电施", "施-01", "变-01A", "电施-", "电变-",
            "电施01", "电施--01", "电施-01A", "电变-01", "电变-A",
            "电施-0A1", "电施-001a", "电变-001A1", "电变-001A ",
            "电变-001[", "电初-001", "电施-０１", "电施-01\\P说明",
            "电变-001Aa", "电变-001aA", "电变-001AAa", "电变-001aaA",
        )
        for mode in MODES:
            host = self.host(mode)
            for text in invalid:
                with self.subTest(mode=mode, text=text):
                    self.assertIsNone(self.next_text(host, text, mode))
                    self.assertIsNone(self.previous_text(host, text, mode))

    def test_only_the_text_field_changes(self):
        for mode in MODES:
            for kind in ("TEXT", "MTEXT", "ATTRIB"):
                examples = (
                    ("THDZ", "电装施-001", "电装变-001A"),
                    ("THDZ", "建变-01Z", "建变-01AA"),
                    ("THDZ", "电装变-001az", "电装变-001ba"),
                    ("THDJ", "电装变-001AA", "电装变-001Z"),
                    ("THDJ", "建变-01aa", "建变-01z"),
                    ("THDJ", "暖变-001a", "暖施-001"),
                    ("THDJ", "结变-001A", "结施-001"),
                )
                for command, before, after in examples:
                    original = [Pair(0, kind), Pair(1, before), Pair(8, "图框"), Pair(40, 400.0)]
                    selections, writes, refreshes, notices = self.command(mode, original, command=command)
                    self.assertEqual(len(selections), 1)
                    self.assertEqual(writes, [encoded([
                        Pair(0, kind), Pair(1, after), Pair(8, "图框"), Pair(40, 400.0),
                    ], mode)])
                    self.assertEqual(refreshes, ["entity"])
                    self.assertIn(before + " -> " + after, "".join(notices))

    def test_cancel_does_not_read_or_write(self):
        for mode in MODES:
            for command in ("THDZ", "THDJ"):
                selections, writes, refreshes, _ = self.command(mode, picked=False, command=command)
                self.assertEqual(len(selections), 1)
                self.assertEqual(writes, [])
                self.assertEqual(refreshes, [])

    def test_decrement_of_unmodified_stage_does_not_write_or_refresh(self):
        for mode in MODES:
            selections, writes, refreshes, notices = self.command(
                mode, [Pair(0, "TEXT"), Pair(1, "电装施-00001")], command="THDJ",
            )
            self.assertEqual(len(selections), 1)
            self.assertEqual(writes, [])
            self.assertEqual(refreshes, [])
            self.assertIn("尚未变更", "".join(notices))

    def test_unsupported_entities_and_invalid_text_are_not_written(self):
        examples = [
            [Pair(0, kind), Pair(1, "电施-01")]
            for kind in ("LINE", "INSERT", "TCH_TEXT", "TCH_DRAWINGNAME")
        ] + [
            [Pair(0, "TEXT")],
            [Pair(0, "TEXT"), Pair(1, "电施-01A")],
            [Pair(0, "MTEXT"), Pair(3, "前半段"), Pair(1, "电施-01")],
        ]
        for mode in MODES:
            for command in ("THDZ", "THDJ"):
                for data in examples:
                    with self.subTest(mode=mode, data=data, command=command):
                        _, writes, refreshes, _ = self.command(mode, data, command=command)
                        self.assertEqual(writes, [])
                        self.assertEqual(refreshes, [])

    def test_failed_write_is_reported_without_refresh(self):
        for mode in MODES:
            for command, text in (("THDZ", "电施-01"), ("THDJ", "电变-01a")):
                _, writes, refreshes, notices = self.command(
                    mode, [Pair(0, "TEXT"), Pair(1, text)], writable=False, command=command,
                )
                self.assertEqual(len(writes), 1)
                self.assertEqual(refreshes, [])
                self.assertIn("写入失败", "".join(notices))
                self.assertNotIn(" -> ", "".join(notices))

    def test_loading_the_script_does_not_execute_a_command(self):
        for mode in MODES:
            selections, writes, refreshes, _ = self.command(
                mode, [Pair(0, "TEXT"), Pair(1, "电施-01")], load=True,
            )
            self.assertEqual(selections, [])
            self.assertEqual(writes, [])
            self.assertEqual(refreshes, [])


if __name__ == "__main__":
    unittest.main()
