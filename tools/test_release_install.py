"""Build and install a redirected, unprivileged packaging fixture.

Date: 2026-10-29
All install and junction paths are inside obj; no system plugin path or registry is used.
"""
from pathlib import Path
import argparse
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]


def run(args):
    result = subprocess.run(args, capture_output=True, timeout=120, creationflags=subprocess.CREATE_NO_WINDOW)
    if result.returncode:
        raise AssertionError(f"Command returned {result.returncode}: {result.stdout!r} {result.stderr!r}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", default="F:/Inno Setup 6/ISCC.exe")
    options = parser.parse_args()
    base = Path(tempfile.mkdtemp(prefix="release-install-", dir=ROOT / "Zyf.autoCAD/obj"))
    install = base / "install"
    plugins = base / "plugins"
    plugins.mkdir()
    script = (ROOT / "installer/ZYFTools.iss").read_text(encoding="utf-8-sig")
    replacements = {
        '#define ProjectRoot "G:\\rust\\CADTools"': f'#define ProjectRoot "{ROOT}"',
        'AppId={{D33FF8C5-66B0-4F5C-A4C0-1094E75BE7A5}': 'AppId={{' + str(uuid.uuid4()) + '}',
        'DefaultDirName={autopf}\\ZYFTools': f'DefaultDirName={install}',
        'OutputDir={#ProjectRoot}\\dist': f'OutputDir={base}',
        'PrivilegesRequired=admin': 'PrivilegesRequired=lowest\nCreateUninstallRegKey=no\nUsePreviousAppDir=no',
        "ExpandConstant('{commonappdata}\\Autodesk\\ApplicationPlugins')": f"'{plugins}'",
        "'acad.exe'": "'cadtools-release-fixture-acad.exe'",
        "'09 CAD开图自动选字体.exe'": "'cadtools-release-fixture-font.exe'",
    }
    for old, new in replacements.items():
        assert script.count(old) >= 1, old
        script = script.replace(old, new)
    fixture = base / "fixture.iss"
    fixture.write_text(script, encoding="utf-8-sig")
    run([options.compiler, "/Q", "/Ffixture", str(fixture)])
    run([str(base / "fixture.exe"), "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", f"/DIR={install}"])
    expected = ROOT / "Zyf.autoCAD/bin/Release/net47"
    actual = install / "ZYF.bundle/Contents"
    source = {p.relative_to(expected).as_posix(): p.read_bytes() for p in expected.rglob("*") if p.is_file()}
    installed = {p.relative_to(actual).as_posix(): p.read_bytes() for p in actual.rglob("*") if p.is_file()}
    assert source == installed, (sorted(source.keys() - installed.keys()), sorted(installed.keys() - source.keys()))
    assert (install / "ZYF.bundle/PackageContents.xml").read_bytes() == (ROOT / "Zyf.autoCAD/PackageContents.xml").read_bytes()
    assert (plugins / "ZYF.bundle").is_junction()
    print(f"PASS: {len(source)} output files and plugin manifest match the isolated installed bundle; {base}")


if __name__ == "__main__":
    main()
