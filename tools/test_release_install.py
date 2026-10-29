"""Exercise fresh and in-use upgrades with an isolated Inno installer.

Date: 2026-10-29
All installation paths, the fake CAD process and the locked files are fixtures.
"""
from pathlib import Path
import argparse
import ctypes
import os
import shutil
import subprocess
import tempfile
import uuid
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = ROOT / "Zyf.autoCAD/bin/Release/net47"
NO_WINDOW = subprocess.CREATE_NO_WINDOW


def run(args, expected=0, timeout=90):
    result = subprocess.run(args, capture_output=True, timeout=timeout, creationflags=NO_WINDOW)
    if result.returncode != expected:
        raise AssertionError(f"Command returned {result.returncode}, expected {expected}: {result.stdout!r} {result.stderr!r}")
    return result


def files(root):
    return {p.relative_to(root).as_posix(): p.read_bytes() for p in root.rglob("*") if p.is_file()}


def fixture(case, compiler):
    case.mkdir(parents=True)
    install = case / "install 中文 space"
    plugins = case / "plugins"
    plugins.mkdir()
    script = (ROOT / "installer/ZYFTools.iss").read_text(encoding="utf-8-sig")
    replacements = {
        '#define ProjectRoot "G:\\rust\\CADTools"': f'#define ProjectRoot "{ROOT}"',
        'AppId={{D33FF8C5-66B0-4F5C-A4C0-1094E75BE7A5}': 'AppId={{' + str(uuid.uuid4()) + '}',
        'DefaultDirName={autopf}\\ZYFTools': f'DefaultDirName={install}',
        'OutputDir={#ProjectRoot}\\dist': f'OutputDir={case}',
        'PrivilegesRequired=admin': 'PrivilegesRequired=lowest\nCreateUninstallRegKey=no\nUsePreviousAppDir=no',
        "ExpandConstant('{commonappdata}\\Autodesk\\ApplicationPlugins')": f"'{plugins}'",
        "'acad.exe'": "'cadtools-release-fixture-acad.exe'",
        "'09 CAD开图自动选字体.exe'": "'cadtools-release-fixture-font.exe'",
    }
    for old, new in replacements.items():
        assert old in script, old
        script = script.replace(old, new)
    source = case / "fixture.iss"
    source.write_text(script, encoding="utf-8-sig")
    run([compiler, "/Q", "/Ffixture", str(source)])
    command = [str(case / "fixture.exe"), "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", f"/DIR={install}"]
    return install, plugins, command


def active_slot(bundle):
    manifest = ET.parse(bundle / "PackageContents.xml").getroot()
    assert manifest.attrib["NameChs"] == "张裕锋工具集"
    component = manifest.find("./Components/ComponentEntry")
    assert manifest.attrib["AppVersion"] == "1.3.7.0" and component.attrib["Version"] == "1.3.7"
    relative = component.attrib["ModuleName"].replace("\\", "/")
    module = (bundle / relative).resolve()
    assert module.is_relative_to((bundle / "Contents").resolve())
    assert module.name.lower() == "zyf.autocad.dll" and module.is_file()
    return module.parent


def lock_read_only(path, share=1):
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateFileW.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32,
                                   ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p]
    kernel.CreateFileW.restype = ctypes.c_void_p
    handle = kernel.CreateFileW(str(path), 0x80000000, share, None, 3, 0x80, None)
    if handle == ctypes.c_void_p(-1).value:
        raise ctypes.WinError(ctypes.get_last_error())
    return handle


def unlock(handle):
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CloseHandle.argtypes = [ctypes.c_void_p]
    if not kernel.CloseHandle(handle):
        raise ctypes.WinError(ctypes.get_last_error())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", default="F:/Inno Setup 6/ISCC.exe")
    options = parser.parse_args()
    base = Path(tempfile.mkdtemp(prefix="release-install-", dir=ROOT / "Zyf.autoCAD/obj"))
    expected = files(EXPECTED)

    fresh_install, fresh_plugins, fresh_setup = fixture(base / "fresh", options.compiler)
    run(fresh_setup)
    fresh_bundle = fresh_install / "ZYF.bundle"
    fresh_slot = active_slot(fresh_bundle)
    assert files(fresh_slot) == expected and (fresh_plugins / "ZYF.bundle").is_junction()
    print("PASS: fresh installation publishes a UTF-8 manifest pointing at complete versioned files")

    install, plugins, setup = fixture(base / "upgrade", options.compiler)
    bundle = install / "ZYF.bundle"
    old_root = bundle / "Contents"
    (old_root / "Tools").mkdir(parents=True)
    old_dll = old_root / "ZYF.autoCAD.dll"
    old_dll.write_bytes(b"old version locked by CAD")
    (old_root / "Tools/old-tool.lsp").write_bytes(b"old tool")
    (old_root / "Tools/FSNDataBase").write_bytes(b"custom frame database")
    (old_root / "Tools/cad开图自动选字体.txt").write_bytes(b"custom font setting")
    old_manifest = (ROOT / "Zyf.autoCAD/PackageContents.xml").read_text(encoding="utf-8").replace("1.3.7", "1.3.6")
    (bundle / "PackageContents.xml").write_text(old_manifest, encoding="utf-8")
    run(["cmd.exe", "/D", "/C", "mklink", "/J", str(plugins / "ZYF.bundle"), str(bundle)])
    original = files(old_root)
    profile = base / "upgrade/profile/Emergency-Lighting/CADTools/config"
    profile.mkdir(parents=True)
    (profile / "drawing.eld").write_bytes(b"existing drawing configuration")

    source = base / "upgrade/Sleeper.cs"
    source.write_text("class Program { static void Main() { System.Threading.Thread.Sleep(90000); } }", encoding="utf-8")
    fake_cad = base / "upgrade/cadtools-release-fixture-acad.exe"
    run(["C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe", "/nologo", "/target:winexe", f"/out:{fake_cad}", str(source)])
    process = subprocess.Popen([str(fake_cad)], creationflags=NO_WINDOW)
    handles = []
    try:
        handles.append(lock_read_only(old_dll))
        run(setup)
        assert process.poll() is None and files(old_root) == original | files_for_slots(old_root)
        assert old_dll.read_bytes() == b"old version locked by CAD"
        first_slot = active_slot(bundle)
        upgraded_expected = dict(expected)
        upgraded_expected["Tools/FSNDataBase"] = b"custom frame database"
        upgraded_expected["Tools/cad开图自动选字体.txt"] = b"custom font setting"
        assert files(first_slot) == upgraded_expected and (plugins / "ZYF.bundle").is_junction()
        assert (plugins / "ZYF.bundle/Contents/ZYF.autoCAD.dll").read_bytes() == old_dll.read_bytes()
        assert (profile / "drawing.eld").read_bytes() == b"existing drawing configuration"
        print("PASS: an in-use legacy DLL and fake CAD remain untouched; existing tool data is preserved")

        probe = base / "upgrade/tool-paths.ps1"
        probe.write_text('''param($Assembly, $ExpectedTools)
$ErrorActionPreference = 'Stop'
$type = [Reflection.Assembly]::LoadFrom($Assembly).GetType('ZYF.autoCAD.Services.ToolPaths', $true)
$flags = [Reflection.BindingFlags]'Static,NonPublic'
$directory = $type.GetMethod('Directory', $flags).Invoke($null, @())
$maa = $type.GetMethod('LispFile', $flags).Invoke($null, @([string]'06 文字复制(maa).lsp'))
if ($directory -ne $ExpectedTools -or -not [IO.File]::Exists($maa)) { throw "Incorrect tool path: $maa" }
''', encoding="utf-8-sig")
        run(["C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
             "-File", str(probe), str(first_slot / "ZYF.autoCAD.dll"), str(first_slot / "Tools")])
        commands = (ROOT / "Zyf.autoCAD/MyCommand.cs").read_text(encoding="utf-8")
        assert commands.count("ToolPaths.LispFile(") == 9 and commands.count("ToolPaths.Directory()") == 2
        assert "ApplicationPlugins/ZYF.bundle/Contents/Tools" not in commands
        print("PASS: versioned tool paths resolve the installed MAA and font-helper directory")

        handles.append(lock_read_only(first_slot / "ZYF.autoCAD.dll"))
        run(setup)
        second_slot = active_slot(bundle)
        assert second_slot != first_slot and files(first_slot) == upgraded_expected and files(second_slot) == upgraded_expected
        assert process.poll() is None
        print("PASS: repeat installation creates a distinct slot even when the current DLL is locked")

        before_manifest = (bundle / "PackageContents.xml").read_bytes()
        locked_config = lock_read_only(second_slot / "Tools/cad开图自动选字体.txt", share=0)
        try:
            result = subprocess.run(setup, capture_output=True, timeout=90, creationflags=NO_WINDOW)
            assert result.returncode != 0
            assert (bundle / "PackageContents.xml").read_bytes() == before_manifest
            assert active_slot(bundle) == second_slot and process.poll() is None
        finally:
            unlock(locked_config)
        assert (second_slot / "Tools/cad开图自动选字体.txt").read_bytes() == b"custom font setting"
        print("PASS: a locked user setting prevents activation without changing the old version")

        handles.append(lock_read_only(bundle / "PackageContents.xml"))
        result = subprocess.run(setup, capture_output=True, timeout=90, creationflags=NO_WINDOW)
        assert result.returncode != 0, (result.returncode, result.stdout, result.stderr)
        assert (bundle / "PackageContents.xml").read_bytes() == before_manifest
        assert active_slot(bundle) == second_slot and process.poll() is None
        print("PASS: a locked manifest prevents activation and keeps the previous active version")
    finally:
        for handle in reversed(handles):
            unlock(handle)
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)

    conflict_install, conflict_plugins, conflict_setup = fixture(base / "conflict", options.compiler)
    foreign = base / "conflict/foreign/ZYF.bundle"
    foreign.mkdir(parents=True)
    (foreign / "keep.txt").write_bytes(b"keep foreign bundle")
    run(["cmd.exe", "/D", "/C", "mklink", "/J", str(conflict_plugins / "ZYF.bundle"), str(foreign)])
    result = subprocess.run(conflict_setup, capture_output=True, timeout=90, creationflags=NO_WINDOW)
    assert result.returncode != 0
    assert (foreign / "keep.txt").read_bytes() == b"keep foreign bundle"
    assert (conflict_plugins / "ZYF.bundle").is_junction()
    assert not (conflict_install / "ZYF.bundle/PackageContents.xml").exists()
    print("PASS: an unrelated standard bundle is preserved and the conflicting install is rejected")
    print(f"Evidence: {base}")


def files_for_slots(contents):
    """Only the test's newly installed version folders may be added to Contents."""
    return {name: data for name, data in files(contents).items() if name.startswith("1.3.7-")}


if __name__ == "__main__":
    main()
