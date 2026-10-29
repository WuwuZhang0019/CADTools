"""Exercise the actual v0.1.84 integration overlay in its pure LISP test host.

Date: 2026-10-29. This does not emulate or validate native AutoCAD/Tianzheng.
Set EMERGENCY_LIGHTING_TESTS if the upstream tests live outside the sibling tree.
"""
import os
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

from emergency_lighting_v84_overlay import OVERLAY


HOST_DIR = Path(os.environ.get(
    "EMERGENCY_LIGHTING_TESTS",
    str(Path(__file__).resolve().parents[2] / "AI画CAD" / "Emergency-Lighting" / "tests"),
))
if not (HOST_DIR / "autolisp_host.py").is_file():
    raise SystemExit("Set EMERGENCY_LIGHTING_TESTS to the Emergency-Lighting tests directory")
sys.path.insert(0, str(HOST_DIR))
from autolisp_host import CaughtError, Host, Pair, Symbol, parse  # noqa: E402


def sym(name):
    return Symbol(name.upper())


class OverlayTests(unittest.TestCase):
    def setUp(self):
        self.h = Host()
        self.h.run("""
        (defun EL:Get (key data) (cdr (assoc key data)))
        (defun EL:DiagnosticFields (data keys / result key row)
          (foreach key keys (if (setq row (assoc key data)) (setq result (cons row result))))
          (reverse result))
        """)
        for form in parse(OVERLAY):
            self.h.evaluate(form)
        self.notices = []
        self.metrics = {}
        self.h.builtins.update({
            "EL:PERFSET": lambda key, value: self.metrics.__setitem__(key, value),
            "EL:LOGEVENT": lambda *args: None,
            "NAMEDOBJDICT": lambda: "NOD",
            "EL:PANELERROR": lambda message: self.notices.append(message),
        })

    def get(self, data, key):
        return self.h.call(sym("EL:Get"), [sym(key), data])

    def test_first_panel_pick_skips_redraw_and_preserves_pick(self):
        picked = ["entity", [1.0, 2.0, 0.0]]
        highlights = []
        self.h.builtins.update({
            "EL:PERFINPUT": lambda *_: picked,
            "EL:HIGHLIGHTPICK": lambda entity: highlights.append(entity),
            "ENTGET": lambda _: [Pair(0, "INSERT"), Pair(8, "PANEL"), Pair(5, "C900")],
        })
        self.assertEqual(self.h.call(sym("EL:PickEntity"), ["\n拾取配电箱："]), picked)
        self.assertEqual(highlights, [])
        self.assertEqual(self.h.lookup("*EL:CADTOOLSPICKSTAGE*"), "entget-returned")
        self.assertEqual(self.h.call(sym("EL:PickEntity"), ["\n拾取导线："]), picked)
        self.assertEqual(highlights, ["entity"])

    def test_first_pick_retains_the_last_completed_stage_on_read_failure(self):
        def fail(_):
            raise RuntimeError("entity read failed")
        self.h.builtins.update({
            "EL:PERFINPUT": lambda *_: ["entity", [1, 2, 0]],
            "ENTGET": fail,
        })
        with self.assertRaisesRegex(RuntimeError, "entity read failed"):
            self.h.call(sym("EL:PickEntity"), ["\n拾取配电箱："])
        self.assertEqual(self.h.lookup("*EL:CADTOOLSPICKSTAGE*"), "reading-entget")

    def test_pick_error_is_not_reclassified_as_a_user_cancellation(self):
        finished, failures = [], []
        self.h.builtins.update({
            "EL:LOGSTART": lambda: None,
            "EL:LOGATTACH": lambda: None,
            "EL:ENSUREROOT": lambda: True,
            "EL:MEASUREDCATCH": lambda *_: CaughtError(RuntimeError("pick error")),
            "EL:CLEARPICKHIGHLIGHTS": lambda: None,
            "EL:LOGFAILURE": lambda message: failures.append(message),
            "EL:LOGFINISH": lambda status: finished.append(status),
            "EL:STARTPICKRETURN": lambda: None,
        })
        self.h.call(sym("EL:FixedStatPick"), [])
        self.assertEqual(failures, ["pick error"])
        self.assertEqual(finished, [])

    def test_home_generate_explains_missing_circuits_without_library_work(self):
        self.h.builtins["EL:GENERATIONRESULT"] = lambda *_: self.fail("unexpected generation")
        self.h.builtins["EL:GENERATIONVERIFY"] = lambda *_: self.fail("unexpected library flush")
        self.h.call(sym("EL:PanelGenerate"), [])
        self.assertIn("先拾取配电箱", self.notices[0])
        self.assertEqual(self.metrics["cadtools-generate-stage"], sym("no-circuits"))

    def test_home_panel_enables_generate_for_explanation(self):
        modes = {}
        self.h.builtins.update({
            "SET_TILE": lambda *_: None,
            "EL:PANELTEXT": lambda *_: None,
            "EL:PANELSYSTEMFILL": lambda: None,
            "MODE_TILE": lambda key, mode: modes.__setitem__(key, mode),
        })
        self.h.call(sym("EL:PanelHomeFill"), [])
        self.assertEqual(modes["p_generate"], 0)
        self.assertEqual(modes["p_trunk"], 1)

    def test_template_missing_and_unexpected_error_are_visible(self):
        self.h.set("*EL:PANELDRAFT*", [Pair(sym("circuits"), [[Pair(sym("id"), "C1")]])])
        self.h.builtins.update({
            "EL:GENERATIONRESULT": lambda result: result,
            "EL:GENERATIONVERIFY": lambda *_: True,
            "EL:PANELCIRCUITLIMITTEXT": lambda *_: None,
            "EL:PANELSYSTEMRECORD": lambda *_: None,
            "EL:PANELSYSTEMMISSING": lambda: "缺少系统图块",
            "EL:PANELSYSTEMFILL": lambda: None,
        })
        self.h.call(sym("EL:PanelGenerate"), [])
        self.assertEqual(self.notices, ["缺少系统图块"])
        self.assertEqual(self.metrics["cadtools-generate-stage"], sym("missing-definitions"))
        self.notices.clear()
        def fail(_):
            raise RuntimeError("generation error")
        self.h.builtins["EL:GENERATIONRESULT"] = fail
        self.h.call(sym("EL:PanelGenerate"), [])
        self.assertIn("generation error", self.notices[0])
        self.assertEqual(self.metrics["cadtools-generate-stage"], sym("error"))

    def test_ready_generation_still_submits_original_capacity_and_action(self):
        closes = []
        draft = [Pair(sym("circuits"), [[Pair(sym("id"), "C1")]])]
        self.h.set("*EL:PANELDRAFT*", draft)
        self.h.set("*EL:PANELTEMPLATEREADY*", True)
        self.h.set("*EL:PANELCAPACITY*", sym("cap600"))
        self.h.builtins.update({
            "EL:GENERATIONRESULT": lambda result: result,
            "EL:GENERATIONVERIFY": lambda *_: True,
            "EL:PANELCIRCUITLIMITTEXT": lambda *_: None,
            "EL:PANELSYSTEMRECORD": lambda *_: None,
            "EL:CAPACITYDEFAULT": lambda value: value,
            "EL:PANELGENERATIONWARNINGS": lambda *_: None,
            "EL:PANELCLOSE": lambda status: closes.append(status),
        })
        self.h.call(sym("EL:PanelGenerate"), [])
        self.assertEqual(closes, [2])
        self.assertEqual(self.h.lookup("*EL:PANELACTION*"), sym("generate"))
        self.assertEqual(self.h.lookup("*EL:PANELCAPACITY*"), sym("cap600"))

    def test_quick_export_never_reads_store_and_labels_live_and_previous_runs(self):
        writes, stages = {}, []
        def forbidden(*_):
            self.fail("quick export must not read stored drawing associations")
        self.h.builtins.update({
            "EL:ENSUREROOT": lambda: True,
            "EL:DIAGNOSTICREQUIRE": lambda condition, message: condition or self.fail(message),
            "EL:DIAGNOSTICFOLDER": lambda: "G:/diagnostic/quick",
            "EL:DIAGNOSTICWINDOWSPATH": lambda path: path,
            "EL:DIAGNOSTICPROGRESS": lambda stage: stages.append(stage),
            "EL:DIAGNOSTICWRITEDATA": lambda path, data: writes.__setitem__(Path(path).name, data),
            "EL:DIAGNOSTICWRITETEXT": lambda path, data: writes.__setitem__(Path(path).name, data),
            "EL:STOREREAD": forbidden,
            "EL:DIAGNOSTICRECORD": forbidden,
            "EL:DIAGNOSTICRESULT": forbidden,
            "GETVAR": lambda name: {"CDATE": 20261029.123456, "DWGNAME": "test.dwg",
                "DWGPREFIX": "G:/", "ACADVER": "23.1"}[name],
        })
        events = [[i, "CAUGHT_ERROR", [Pair(sym("message"), "pick failed")]] for i in range(130, 0, -1)]
        previous = [Pair(sym("summary"), [Pair(sym("status"), sym("failed"))]),
                    Pair(sym("events"), events), Pair(sym("error"), "previous error")]
        self.h.set("*EL:DIAGNOSTICRUNS*", [Pair("NOD", previous)])
        self.h.set("*EL:PERFACTIVE*", True)
        self.h.set("*EL:PERFCOMMAND*", "ELSTAT")
        self.h.set("*EL:DEFERREDLOGEVENTS*", events)
        self.h.set("*EL:MONITORERROR*", "active error")
        self.h.set("*EL:PACKAGEMARKER*", "package-183.marker")
        self.h.set("*EL:PANELDRAFT*", [Pair(sym("panel"), "C900"), Pair(sym("circuits"), [1, 2])])
        self.assertEqual(self.h.call(sym("EL:CADToolsFastDiagnostic"), []), "G:/diagnostic/quick")
        self.assertEqual(stages, ["BUNDLE_BEGIN", "BUNDLE_DONE"])
        self.assertEqual(set(writes), {"state.eld", "active-run.eld", "previous-run.eld", "README.md"})
        self.assertEqual(self.get(self.get(writes["active-run.eld"], "summary"), "status"), sym("in-progress"))
        self.assertEqual(self.get(self.get(writes["previous-run.eld"], "summary"), "status"), sym("failed"))
        self.assertEqual(self.get(writes["active-run.eld"], "error"), "active error")
        recent = self.get(self.get(writes["previous-run.eld"], "events"), "recent")
        self.assertEqual(len(recent), 120)
        self.assertTrue(self.get(self.get(writes["previous-run.eld"], "events"), "older-events-omitted"))
        self.assertEqual(self.get(writes["state.eld"], "circuit-count"), 2)
        self.assertIn("ELDIAG", writes["README.md"])
        self.assertTrue(self.h.lookup("*EL:PERFACTIVE*"))

    def test_quick_export_writes_readable_utf8_with_actual_package_writer(self):
        import test_diagnostic_bundle as upstream

        obj = Path(__file__).resolve().parents[1] / "Zyf.autoCAD/obj"
        archive_path = obj.parent / "Tools/Emergency-Lighting/full-v0.1.84.zip"
        with tempfile.TemporaryDirectory(prefix="overlay-io-", dir=obj) as temp:
            original_check_root = upstream.CHECK_ROOT
            upstream.CHECK_ROOT = Path(temp)
            fixture = upstream.DiagnosticBundleTests("runTest")
            try:
                fixture.setUp()
                host = fixture.h
                with zipfile.ZipFile(archive_path) as archive:
                    name = next(n for n in archive.namelist() if n.endswith("/src/diagram-commands.lsp"))
                    packaged_source = archive.read(name).decode("gb2312", errors="strict")
                wanted = {"EL:DIAGNOSTICNATIVECHARSET", "EL:DIAGNOSTICNATIVETEXT", "EL:DIAGNOSTICWRITEDATA"}
                for form in parse(packaged_source):
                    if isinstance(form, list) and form[0] == "DEFUN" and form[1] in wanted:
                        host.evaluate(form)
                for form in parse(OVERLAY):
                    host.evaluate(form)
                def forbidden():
                    self.fail("quick export must not read the drawing store")
                host.builtins["EL:STOREREAD"] = forbidden
                host.set("*EL:PERFACTIVE*", True)
                host.set("*EL:PERFCOMMAND*", "ELSTAT")
                host.set("*EL:MONITORERROR*", "测试拾取错误")
                host.set("*EL:DEFERREDLOGEVENTS*", [[7, "CAUGHT_ERROR", [Pair(sym("message"), "拾取错误")]]])
                before = fixture.f.before()
                self.assertIn("轻量", host.run("(EL:PanelDiagnosticExport)"))
                folder = Path(host.lookup("*EL:DIAGNOSTICEXPORTPATH*"))
                self.assertIn("测试拾取错误", (folder / "active-run.eld").read_text(encoding="utf-8-sig"))
                self.assertIn("BUNDLE_DONE", (folder / "progress.log").read_text(encoding="gb2312"))
                self.assertFalse((folder / "association.eld").exists())
                self.assertFalse((folder / "drawing-store.eld").exists())
                self.assertTrue(host.lookup("*EL:PERFACTIVE*"))
                fixture.f.assert_business_unchanged(before)
            finally:
                fixture.doCleanups()
                upstream.CHECK_ROOT = original_check_root


if __name__ == "__main__":
    unittest.main(verbosity=2)
