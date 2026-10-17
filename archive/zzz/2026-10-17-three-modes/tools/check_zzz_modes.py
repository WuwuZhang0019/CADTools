"""离线检查 ZZZ 源表达式、三种模式和定向替换边界。

日期：2026-10-17
CAD、字体文件及 DCL 使用替身，不代替原生 AutoCAD 显示和撤销验收。
"""

from dataclasses import dataclass
from pathlib import Path
import copy
import fnmatch
import io
import json
import ntpath
import re


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Zyf.autoCAD" / "Tools" / "14 缺失字体替换(zzz).lsp"


class Symbol(str):
    pass


@dataclass
class Pair:
    car: object
    cdr: object


class CadError(Exception):
    pass


class DialogExit(Exception):
    pass


class Caught:
    def __init__(self, error):
        self.message = str(error)


def parse(text):
    tokens = [t for t in re.findall(r';[^\r\n]*|"(?:\\.|[^"\\])*"|[()]|\x27|[^\s()\x27";]+', text)
              if not t.startswith(";")]
    index = 0

    def read():
        nonlocal index
        token = tokens[index]
        index += 1
        if token == "(":
            items = []
            while index < len(tokens) and tokens[index] != ")":
                items.append(read())
            assert index < len(tokens), "unclosed LISP form"
            index += 1
            if len(items) == 3 and items[1] == Symbol("."):
                return Pair(items[0], items[2])
            return items
        assert token != ")", "unexpected closing parenthesis"
        if token == "'":
            return [Symbol("quote"), read()]
        if token.startswith('"'):
            return json.loads(token)
        try:
            return float(token) if "." in token else int(token)
        except ValueError:
            return Symbol(token.lower())

    forms = []
    while index < len(tokens):
        forms.append(read())
    return forms


def truth(value):
    # AutoLISP 的 0 和空字符串都是真；and/or 返回 T 或 nil。
    return value is not None and value is not False


def boolean(value):
    return True if value else None


def car(value):
    return value.car if isinstance(value, Pair) else value[0] if value else None


def cdr(value):
    return value.cdr if isinstance(value, Pair) else (value[1:] or None) if value else None


def assoc(key, values):
    return next((p for p in values or [] if p.car == key), None)


class Runtime:
    """仅实现此脚本检查所需的表达式；遇到未知调用会失败。"""

    def __init__(self):
        self.scopes = [{}]
        self.functions = {}
        self.native = {}

    def get(self, key):
        return next((scope[key] for scope in reversed(self.scopes) if key in scope), None)

    def set(self, key, value):
        for scope in reversed(self.scopes):
            if key in scope:
                scope[key] = value
                return value
        self.scopes[0][key] = value
        return value

    def sequence(self, forms):
        result = None
        for form in forms:
            result = self.evaluate(form)
        return result

    def evaluate(self, form):
        if isinstance(form, Symbol):
            return True if form == "t" else None if form == "nil" else self.get(form)
        if not isinstance(form, list):
            return form
        if not form:
            return None
        op, args = str(form[0]).lower(), form[1:]
        if op == "quote":
            return args[0] if args[0] != [] else None
        if op == "defun":
            self.functions[str(args[0])] = args[1:]
            return args[0]
        if op == "if":
            assert len(args) in (2, 3), "bad IF arity"
            return self.evaluate(args[1]) if truth(self.evaluate(args[0])) else self.evaluate(args[2]) if len(args) == 3 else None
        if op == "progn":
            return self.sequence(args)
        if op == "setq":
            assert len(args) % 2 == 0, "bad SETQ arity"
            for key, value in zip(args[::2], args[1::2]):
                result = self.set(key, self.evaluate(value))
            return result
        if op in ("and", "or"):
            values = (truth(self.evaluate(x)) for x in args)
            return boolean(all(values) if op == "and" else any(values))
        if op == "cond":
            for branch in args:
                value = self.evaluate(branch[0])
                if truth(value):
                    return self.sequence(branch[1:]) if len(branch) > 1 else value
            return None
        if op in ("foreach", "vlax-for"):
            result = None
            for value in self.evaluate(args[1]) or []:
                self.set(args[0], value)
                result = self.sequence(args[2:])
            return result
        if op == "while":
            result, count = None, 0
            while truth(self.evaluate(args[0])):
                result = self.sequence(args[1:])
                count += 1
                assert count < 10000, "loop guard"
            return result
        return self.call(op, [self.evaluate(x) for x in args])

    def call(self, name, args=()):
        name = str(name).lower()
        if name in self.native:
            return self.native[name](*args)
        params, *body = self.functions[name]
        split = params.index(Symbol("/")) if Symbol("/") in params else len(params)
        assert len(args) == split, (name, "bad function arity")
        local = dict.fromkeys(params[split + 1:])
        local.update(zip(params[:split], args))
        self.scopes.append(local)
        try:
            return self.sequence(body)
        finally:
            self.scopes.pop()

    def caught_call(self, name, args):
        try:
            return self.call(name, args or [])
        except (CadError, KeyError, AssertionError, TypeError, ValueError) as error:
            return Caught(error)


class Cad:
    def __init__(self, runtime):
        self.vm = runtime
        self.files, self.objects, self.writes, self.messages = {}, {}, [], []
        self.tiles, self.modes, self.actions, self.events = {}, {}, {}, []
        self.doc = {"styles": []}
        self.system = {"CMDECHO": 0, "UNDOCTL": 1, "ACADPREFIX": r"C:\fonts", "DWGPREFIX": ""}
        self.active = False
        self.handle = 1
        self.resources = {}

    def font_file(self, name, kind="unifont"):
        path = ntpath.join(r"C:\fonts", name)
        self.files[ntpath.normcase(path)] = (path, "AutoCAD-86 " + kind + " 1.0\r\n")
        return path

    def find_file(self, name):
        assert isinstance(name, str) and name, "invalid font path"
        key = ntpath.normcase(ntpath.normpath(name))
        if key in self.files:
            return self.files[key][0]
        if ntpath.basename(name) == name:
            value = self.files.get(ntpath.normcase(ntpath.join(r"C:\fonts", name)))
            return value[0] if value else None
        return None

    def style(self, name, file, big="", face="", flags=0):
        obj = {"id": len(self.objects) + 1, "name": name, "file": file, "big": big,
               "font": [face, -1, 0, 134 if face else 0, 22 if face else 0], "flags": flags,
               "height": 2.5, "width": 0.8, "angle": 0.1}
        self.objects[obj["id"]] = obj
        return obj

    def data(self, obj, apps=None):
        result = [Pair(-1, obj["id"]), Pair(0, "STYLE"), Pair(2, obj["name"]), Pair(70, obj["flags"]),
                  Pair(3, obj["file"]), Pair(4, obj["big"]), Pair(40, obj["height"]), Pair(41, obj["width"]), Pair(50, obj["angle"])]
        if apps:
            result.append(Pair(-3, copy.deepcopy(obj["font"])))
        return result

    def entmod(self, data):
        assert not self.active, "entity write inside modal dialog"
        obj = self.objects[assoc(-1, data).cdr]
        for key, code in (("file", 3), ("big", 4), ("height", 40), ("width", 41), ("angle", 50)):
            obj[key] = assoc(code, data).cdr
        if assoc(-3, data):
            obj["font"] = copy.deepcopy(assoc(-3, data).cdr)
        self.writes.append(("entmod", obj["id"]))
        return data

    def get_font(self, obj, *names):
        if obj.get("fail_read"):
            raise CadError("injected font read failure")
        for name, value in zip(names, obj["font"]):
            self.vm.set(name, value)

    def put_file(self, obj, path):
        assert not self.active, "font write inside modal dialog"
        self.writes.append(("file", obj["id"]))
        obj["file"], obj["font"] = path, ["", 0, 0, 0, 0]

    def put_big(self, obj, path):
        assert not self.active, "bigfont write inside modal dialog"
        if obj.get("fail_clear") and path == "":
            raise CadError("empty bigfont rejected")
        self.writes.append(("big", obj["id"]))
        obj["big"] = path
        if obj.get("mutate_main"):
            obj["file"] = "unexpected.shx"

    def set_font(self, obj, *font):
        assert not self.active, "font descriptor write inside modal dialog"
        self.writes.append(("setfont", obj["id"]))
        if obj.get("fail_write"):
            raise CadError("injected SetFont failure")
        obj["font"] = list(font)

    def open(self, name, mode):
        if mode == "r":
            value = self.files.get(ntpath.normcase(name))
            return io.StringIO(value[1]) if value else None
        return io.StringIO()

    def select(self, key, index):
        self.tiles[key] = str(index)
        self.vm.sequence(parse(self.actions[key]))

    def close_dialog(self, result):
        raise DialogExit(result)

    def start_dialog(self):
        self.active = True
        try:
            for event in self.events:
                event()
            return 0
        except DialogExit as exit:
            return exit.args[0]
        finally:
            self.active = False

    def regen(self, doc, which):
        assert not self.active, "regen inside modal dialog"
        doc["regen"] = doc.get("regen", 0) + 1

    def bind(self):
        vm = self.vm
        vm.native.update({
            "type": lambda x: Symbol("str") if type(x) is str else Symbol("sym") if isinstance(x, Symbol) else Symbol("int"),
            "strcat": lambda *x: "".join(x), "strlen": len,
            "strcase": lambda x, lower=None: x.lower() if truth(lower) else x.upper(),
            "substr": lambda x, start, size=None: x[start - 1:] if size is None else x[start - 1:start - 1 + size],
            "vl-string-search": lambda a, b: b.index(a) if a in b else None,
            "vl-filename-base": lambda x: ntpath.splitext(ntpath.basename(x))[0],
            "vl-filename-extension": lambda x: ntpath.splitext(x)[1] or None,
            "vl-filename-directory": ntpath.dirname, "findfile": self.find_file,
            "vl-file-directory-p": lambda x: boolean(ntpath.normcase(x) == ntpath.normcase(r"C:\fonts")),
            "getenv": lambda key: None, "getvar": lambda key: self.system[key],
            "setvar": lambda key, value: self.system.__setitem__(key, value) or value,
            "boundp": lambda key: boolean(any(key in scope for scope in vm.scopes)),
            "list": lambda *x: list(x) or None, "listp": lambda x: boolean(x is None or isinstance(x, list)),
            "car": car, "cdr": cdr, "cadr": lambda x: car(cdr(x)),
            "nth": lambda n, x: x[n] if x and n < len(x) else None,
            "cons": lambda a, b: [a] + (b or []) if b is None or isinstance(b, list) else Pair(a, b),
            "append": lambda *xs: sum((list(x or []) for x in xs), []) or None,
            "reverse": lambda x: list(reversed(x or [])) or None,
            "member": lambda a, x: x[x.index(a):] if a in (x or []) else None,
            "vl-position": lambda a, x: x.index(a) if a in (x or []) else None,
            "assoc": assoc, "subst": lambda n, o, xs: [n if x == o else x for x in xs],
            "=": lambda a, b: boolean(a == b), "/=": lambda a, b: boolean(a != b),
            "equal": lambda a, b: boolean(a == b), "eq": lambda a, b: boolean(a == b),
            ">": lambda a, b: boolean(a > b), "<": lambda a, b: boolean(a < b), ">=": lambda a, b: boolean(a >= b),
            "+": lambda a, b: a + b, "1+": lambda x: x + 1, "logand": lambda a, b: a & b, "logior": lambda a, b: a | b,
            "null": lambda x: boolean(not truth(x)), "not": lambda x: boolean(not truth(x)),
            "atoi": lambda x: int(x) if x else 0, "itoa": str, "chr": chr,
            "wcmatch": lambda value, pattern: boolean(any(fnmatch.fnmatchcase(value, part) for part in pattern.split(","))),
            "open": self.open, "close": lambda stream: stream.close(),
            "read-char": lambda stream: ord(char) if (char := stream.read(1)) else None,
            "write-line": lambda line, stream: stream.write(line + "\n"),
            "vl-directory-files": lambda d, p, m: [ntpath.basename(v[0]) for v in self.files.values()
                                                     if fnmatch.fnmatch(ntpath.basename(v[0]), p)] or None,
            "acad_strlsort": lambda xs: sorted(xs or [], key=str.lower) or None,
            "vl-catch-all-apply": vm.caught_call, "vl-catch-all-error-p": lambda x: boolean(isinstance(x, Caught)),
            "vl-catch-all-error-message": lambda x: x.message,
            "vlax-vla-object->ename": lambda obj: obj["id"],
            "entget": lambda oid, apps=None: self.data(self.objects[oid], apps), "entmod": self.entmod,
            "vla-get-name": lambda obj: obj["name"], "vla-get-fontfile": lambda obj: obj["file"],
            "vla-get-bigfontfile": lambda obj: obj["big"], "vla-getfont": self.get_font,
            "vla-put-fontfile": self.put_file, "vla-put-bigfontfile": self.put_big, "vla-setfont": self.set_font,
            "vl-load-com": lambda: None, "princ": lambda value=None: self.messages.append(value),
            "start_list": lambda key: None, "add_list": lambda value: None, "end_list": lambda: None,
            "mode_tile": lambda key, mode: self.modes.__setitem__(key, mode),
            "get_tile": lambda key: self.tiles.get(key, ""), "set_tile": lambda key, value: self.tiles.__setitem__(key, value),
            "action_tile": lambda key, action: self.actions.__setitem__(key, action),
            "start_dialog": self.start_dialog, "done_dialog": self.close_dialog,
            "vl-filename-mktemp": lambda *args: r"C:\temp\zzz.dcl", "load_dialog": lambda path: self.handle,
            "new_dialog": lambda *args: self.resources.__setitem__("opened", True) or True,
            "unload_dialog": lambda handle: self.resources.__setitem__("unloaded", handle),
            "vl-file-delete": lambda path: self.resources.__setitem__("deleted", path),
            "alert": lambda value: self.messages.append(value),
            "vlax-get-acad-object": lambda: True, "vla-get-activedocument": lambda app: self.doc,
            "vla-get-textstyles": lambda doc: doc["styles"], "vla-regen": self.regen,
            "vla-startundomark": lambda doc: doc.__setitem__("start", doc.get("start", 0) + 1),
            "vla-endundomark": lambda doc: doc.__setitem__("end", doc.get("end", 0) + 1),
            "quit": lambda: (_ for _ in ()).throw(CadError("quit / exit abort")),
        })


def main():
    raw = SOURCE.read_bytes()
    text = raw.decode("gb2312")
    assert text.encode("gb2312") == raw and not raw.startswith(b"\xef\xbb\xbf")
    forms = parse(text)
    assert all(isinstance(f, list) and f[0] in ("defun", "vl-load-com", "princ") for f in forms)

    def validate(form):
        if not isinstance(form, list) or not form:
            return
        if form[0] == "if":
            assert len(form) in (3, 4), "bad IF form"
        if form[0] == "setq":
            assert len(form) % 2 == 1, "bad SETQ form"
        if form[0] != "quote":
            for child in form[1:]:
                validate(child)

    for form in forms:
        validate(form)
    vm = Runtime()
    cad = Cad(vm)
    cad.bind()
    for form in forms:
        vm.evaluate(form)
    count = 0

    def check(value, message):
        nonlocal count
        assert value, message
        count += 1

    check(not cad.writes, "loading must not modify styles")
    a = cad.font_file("a.shx")
    b = cad.font_file("b.shx")
    cad.font_file("tssdeng.shx")
    big1 = cad.font_file("one.shx", "bigfont")
    big2 = cad.font_file("two.shx", "bigfont")
    cad.font_file("tssdchn.shx", "bigfont")
    song = cad.font_file("simsun.ttc", "ttf")
    fang = cad.font_file("simfang.ttf", "ttf")
    dirs = [r"C:\fonts"]
    target = vm.call("zzz:ttftarget", ["仿宋", dirs])
    first = cad.style("name-is-not-a-font", a, big1)
    alias = cad.style("another-name", "A.SHX", big2)
    other = cad.style("a.shx", b, big1)
    simsun = cad.style("song", song, face="宋体")
    nsimsun = cad.style("new-song", song, face="NSimSun")
    xref = cad.style("xref|font", a)
    shape = cad.style("shape", a, flags=1)
    cad.doc["styles"] = [first, alias, other, simsun, nsimsun, xref, shape]
    catalog = vm.call("zzz:sourcecatalog", [cad.doc])
    key = vm.call("zzz:sourcekey", [cad.data(first), first["font"], "MAIN"])
    entry = vm.call("zzz:findsource", [key, catalog[0]])
    check(catalog[1:] == [5, 0] and entry[2] == 2, "source grouping and excluded style counts")
    check(vm.call("zzz:sourcekey", [cad.data(simsun), simsun["font"], "MAIN"]) !=
          vm.call("zzz:sourcekey", [cad.data(nsimsun), nsimsun["font"], "MAIN"]), "TTC font families remain distinct")
    english_song = cad.style("english-song", song, face="SimSun")
    check(vm.call("zzz:sourcekey", [cad.data(simsun), simsun["font"], "MAIN"]) ==
          vm.call("zzz:sourcekey", [cad.data(english_song), english_song["font"], "MAIN"]), "known Windows family aliases match")
    before = copy.deepcopy(other)
    request = ["REPLACE", key, target]
    check(vm.call("zzz:processstyle", [other, request, dirs]) == Symbol("notmatched") and other == before,
          "font references must be matched, never style names")
    check(vm.call("zzz:processstyle", [first, request, dirs]) == Symbol("changed"), "replace selected primary font")
    check(first["file"] == fang and first["big"] == "" and first["font"][1:3] == [-1, 0], "TTF state and bold/italic")
    check((first["height"], first["width"], first["angle"]) == (2.5, 0.8, 0.1), "non-font style formatting remains intact")
    check(vm.call("zzz:processstyle", [alias, request, dirs]) == Symbol("changed"), "case-insensitive matching across styles")
    check(vm.call("zzz:processstyle", [xref, request, dirs]) == Symbol("skip") and
          vm.call("zzz:processstyle", [shape, request, dirs]) == Symbol("skip"), "xref/shape exclusion")
    specimen = cad.style("keep-big", a, big1)
    preserve = vm.call("zzz:resolverequest", [["SHX", "b.shx", Symbol("keep")], dirs])
    start = len(cad.writes)
    check(vm.call("zzz:processstyle", [specimen, preserve, dirs]) == Symbol("changed") and specimen["big"] == big1,
          "primary SHX replacement can preserve the original bigfont")
    check([x[0] for x in cad.writes[start:]] == ["file"], "preserving a bigfont must not rewrite it")
    big_source = vm.call("zzz:sourcekey", [cad.data(other), other["font"], "BIG"])
    big_request = vm.call("zzz:resolverequest", [["REPLACE", big_source, ["BIG", "two.shx"]], dirs])
    check(isinstance(vm.call("zzz:resolverequest", [["REPLACE", big_source, ["TTF", "宋体"]], dirs]), str),
          "bigfont source cannot replace a primary font")
    check(isinstance(vm.call("zzz:resolverequest", [["REPLACE", key, ["BIG", "two.shx"]], dirs]), str),
          "primary source cannot replace a bigfont")
    check(isinstance(vm.call("zzz:resolverequest", [["REPLACE", None, ["TTF", "宋体"]], dirs]), str),
          "missing source is rejected before execution")
    before_file, before_font = other["file"], other["font"][:]
    check(vm.call("zzz:processstyle", [other, big_request, dirs]) == Symbol("changed") and other["big"] == big2,
          "targeted bigfont replacement")
    check((other["file"], other["font"]) == (before_file, before_font), "bigfont replacement preserves primary font")
    corrupted = cad.style("unexpected-main-change", a, big1)
    corrupted["mutate_main"] = True
    before = copy.deepcopy(corrupted)
    result = vm.call("zzz:processstyle", [corrupted, big_request, dirs])
    check(isinstance(result, str) and corrupted == before, "unexpected companion changes are rolled back")
    broken = cad.style("write-error", "missing.shx", big1)
    broken["fail_write"] = True
    before = copy.deepcopy(broken)
    check(vm.call("zzz:processstyle", [broken, target, dirs]) == "injected SetFont failure" and broken == before,
          "partial writes restore original missing references")
    normal = cad.style("normal", a)
    missing = cad.style("missing", "missing.shx")
    before = copy.deepcopy(normal)
    check(vm.call("zzz:processstyle", [normal, ["MISSING"], dirs]) == Symbol("unchanged") and normal == before,
          "repair mode preserves available fonts")
    check(vm.call("zzz:processstyle", [missing, ["MISSING"], dirs]) == Symbol("changed") and missing["big"] == "",
          "repair mode does not add an unsolicited bigfont")
    ttf_normal = cad.style("ttf-normal", song, face="SimSun")
    before = copy.deepcopy(ttf_normal)
    check(vm.call("zzz:processstyle", [ttf_normal, ["MISSING"], dirs]) == Symbol("unchanged") and ttf_normal == before,
          "repair mode preserves available Windows fonts")
    ttf_missing = cad.style("ttf-missing", "absent.ttf", face="Unknown")
    check(vm.call("zzz:processstyle", [ttf_missing, ["MISSING"], dirs]) == Symbol("changed") and ttf_missing["file"] == fang,
          "missing Windows font uses the stated fallback")
    source_a = cad.style("source-a", a)
    source_b = cad.style("source-b", b)
    cad.doc = {"styles": [source_a, source_b]}
    before_b = copy.deepcopy(source_b)

    def replace_action():
        vm.call("zzz:changemode", ["REPLACE"])
        check("仅替换" in cad.tiles["scope1"], "targeted scope shown in the dialog")
        cad.select("pop1", vm.get("zzz-ttfs").index("仿宋"))
        vm.call("zzz:accept")

    cad.events = [replace_action]
    start = len(cad.writes)
    vm.call("c:zzz")
    check(source_a["file"] == fang and source_b == before_b, "dialog-to-batch targeted filtering")
    check(all(objid == source_a["id"] for _, objid in cad.writes[start:]), "unmatched styles receive no writes")
    check(cad.doc["start"] == cad.doc["end"] == 1 and cad.system["CMDECHO"] == 0, "balanced undo and CMDECHO=0 restoration")
    check(cad.resources.get("deleted") and cad.resources.get("unloaded") == 1, "dialog resources cleaned up")
    cad.doc = {"styles": [cad.style("all-a", a, big1), cad.style("all-b", b)]}

    def uniform_action():
        vm.call("zzz:changemode", ["ALL"])
        check("全部" in cad.tiles["scope1"] and cad.modes["source"] == 1, "all-font scope and disabled source selector")
        cad.select("pop1", vm.get("zzz-ttfs").index("仿宋"))
        vm.call("zzz:accept")

    cad.events = [uniform_action]
    vm.call("c:zzz")
    check(all(s["file"] == fang for s in cad.doc["styles"]), "uniform mode covers every editable style")
    cad.doc = {"styles": [cad.style("switch-main", a, big1)]}

    def switch_and_cancel():
        check(cad.modes["pop1"] == 1 and cad.modes["source"] == 1, "repair mode disables manual font selectors")
        vm.call("zzz:changemode", ["REPLACE"])
        cad.select("pop1", vm.get("zzz-ttfs").index("仿宋"))
        vm.call("zzz:changemode", ["MISSING"])
        vm.call("zzz:changemode", ["ALL"])
        check(vm.get("zzz-ttf") == "仿宋", "font choice survives switching modes")
        cad.select("target_kind", 1)
        check(Symbol("keep") not in vm.get("zzz-big-values"), "uniform mode never offers per-style bigfont preservation")
        cad.select("pop2", vm.get("zzz-big-values").index(big2.rsplit("\\", 1)[1]))
        vm.call("zzz:changemode", ["REPLACE"])
        check(vm.get("zzz-replace-big") == Symbol("keep"), "targeted SHX defaults to preserving companions")
        sources = vm.get("zzz-sources")
        cad.select("source", next(i for i, e in enumerate(sources) if e[0][0] == "BIG"))
        check(vm.get("zzz-effective-kind") == "BIG" and cad.modes["target_kind"] == 1 and cad.modes["pop2"] == 1,
              "bigfont sources constrain the target type")
        cad.select("source", next(i for i, e in enumerate(sources) if e[0][0] == "MAIN"))
        check(vm.get("zzz-effective-kind") == "SHX", "returning to a primary source restores its target type")
        vm.call("zzz:changemode", ["ALL"])
        check(vm.get("zzz-all-big") == "two.shx", "uniform and targeted companion choices are independent")
        vm.call("zzz:changemode", ["REPLACE"])
        check(vm.get("zzz-replace-big") == Symbol("keep"), "targeted companion choice survives returning")
        cad.close_dialog(0)

    cad.events = [switch_and_cancel]
    start = len(cad.writes)
    vm.call("c:zzz")
    check(len(cad.writes) == start, "switching and cancelling must not modify the drawing")

    def missing_target_and_cancel():
        vm.call("zzz:changemode", ["REPLACE"])
        cad.select("pop1", vm.get("zzz-ttfs").index("仿宋"))
        file = cad.files.pop(ntpath.normcase(fang))
        try:
            vm.call("zzz:accept")
            check("未找到" in cad.tiles["error"] and vm.get("zzz-ttf") == "仿宋",
                  "failed target validation keeps the dialog and user's input")
        finally:
            cad.files[ntpath.normcase(fang)] = file
        cad.close_dialog(0)

    cad.events = [missing_target_and_cancel]
    vm.call("c:zzz")
    check(len(cad.writes) == start, "failed target validation has no drawing side effects")
    cad.doc = {"styles": []}
    cad.events = [lambda: vm.call("zzz:changemode", ["REPLACE"])]
    vm.call("c:zzz")
    check(cad.modes["ok"] == 1, "empty source catalog disables replacement safely")
    cad.doc = {"styles": [cad.style("read-error", a)]}
    cad.doc["styles"][0]["fail_read"] = True
    check(vm.call("zzz:sourcecatalog", [cad.doc])[1:] == [0, 1], "unreadable styles are counted without guessing")
    stream = io.StringIO()
    vm.call("zzz:writedialog", [stream])
    dcl = stream.getvalue()
    balance = 0
    for token in re.findall(r'"(?:\\.|[^"\\])*"|[{}]', dcl):
        if token == "{":
            balance += 1
        elif token == "}":
            balance -= 1
            assert balance >= 0
    check(balance == 0 and dcl.count(":radio_button {") == 3 and dcl.count(":zzz_action_button {") == 3,
          "three mode choices, equal-sized action buttons and balanced DCL")
    keys = re.findall(r'key\s*=\s*"([^"]+)"', dcl)
    check(len(keys) == len(set(keys)) and set(cad.actions) <= set(keys), "DCL keys and callback bindings")
    check('"MOVE"' not in text.upper() and "NETLOAD" not in text.upper(), "no geometry-refresh move or external DLL load")
    print(f"PASS: {count} ZZZ source-expression checks with simulated CAD/files/DCL")
    print("NOTE: native AutoCAD display, save/reopen and Undo remain unverified")


if __name__ == "__main__":
    main()
