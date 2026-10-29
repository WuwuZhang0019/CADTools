"""Exercise the real Inno uninstaller inside an isolated workspace directory.

Date: 2026-10-20
The generated installer has no registry entry and never uses system plugin paths.
"""

import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import uuid


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "installer" / "ZYFTools.iss"


def run(*args: str, expected: int = 0) -> subprocess.CompletedProcess:
    result = subprocess.run(args, capture_output=True, text=True, errors="replace", timeout=60)
    if result.returncode != expected:
        raise AssertionError(f"Exit {result.returncode}, expected {expected}: {args}\n"
                             f"{result.stdout}\n{result.stderr}")
    return result


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def wait_removed(bundle: Path, alias: Path) -> None:
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if not bundle.exists() and not alias.is_junction():
            return
        time.sleep(0.1)
    raise AssertionError(f"Uninstall left the bundle or junction: {bundle}, {alias}")


def make_script(case: Path, cancel: bool = False) -> Path:
    app = case / "Custom install"
    plugins = case / "Plugins"
    case.mkdir(parents=True)
    plugins.mkdir()
    (case / "probe.txt").write_text("Uninstall fixture 2026-10-20", encoding="utf-8")
    text = SCRIPT.read_text(encoding="utf-8-sig")
    text = text.replace("AppId={{D33FF8C5-66B0-4F5C-A4C0-1094E75BE7A5}", "AppId={{" + str(uuid.uuid4()) + "}")
    text = text.replace("DefaultDirName={autopf}\\ZYFTools", f"DefaultDirName={app}")
    text = text.replace("PrivilegesRequired=admin", "PrivilegesRequired=lowest\nCreateUninstallRegKey=no\nUsePreviousAppDir=no")
    text = text.replace("UninstallLogging=yes", "UninstallLogging=no")
    # Do not inspect or stop the user's CAD/font-helper processes in a fixture run.
    text = text.replace("'acad.exe'", "'cadtools-uninstall-fixture-acad.exe'")
    text = text.replace("'09 CAD开图自动选字体.exe'", "'cadtools-uninstall-fixture-font.exe'")
    text = text.replace('OutputDir={#ProjectRoot}\\dist', f"OutputDir={case}")
    start = text.index("[Files]\n")
    end = text.index("[UninstallDelete]\n", start)
    text = text[:start] + (f'[Files]\nSource: "{case / "probe.txt"}"; '
                            'DestDir: "{app}\\ZYF.bundle\\Contents"; Flags: ignoreversion\n\n') + text[end:]
    text = text.replace("ExpandConstant('{commonappdata}\\Autodesk\\ApplicationPlugins')", f"'{plugins}'")
    if cancel:
        text = text.replace("  Result := WaitForAutoCadClosed();\nend;",
                            "  Result := WaitForAutoCadClosed();\n  Result := False;\nend;")
    script = case / "fixture.iss"
    script.write_text(text, encoding="utf-8-sig")
    return script


def install(compiler: str, script: Path, *, repair: bool = False) -> None:
    options = ["/DRepairUninstallLog=1"] if repair else []
    run(compiler, "/Q", *options, "/Ffixture", str(script))
    run(str(script.parent / "fixture.exe"), "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART",
        f"/LOG={script.parent / ('repair.log' if repair else 'install.log')}")


def uninstall(path: Path, log: Path, *, expected: int = 0) -> None:
    run(str(path), "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", f"/LOG={log}", expected=expected)


def check_launcher(case: Path, bundle: Path, executable: Path, assembly: Path) -> None:
    # Windows PowerShell uses .NET Framework, matching the plugin's runtime.
    shell = Path("C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe")
    probe = case / "launcher.ps1"
    probe.write_text("""param($Assembly, $AliasFile, $RealFile, $Bundle, $ExpectedExe)
$ErrorActionPreference = 'Stop'
$type = [Reflection.Assembly]::LoadFrom($Assembly).GetType('ZYF.autoCAD.Services.UninstallService', $true)
$flags = [Reflection.BindingFlags]'Static,NonPublic'
$resolved = $type.GetMethod('ResolveFilePath', $flags).Invoke($null, @($AliasFile))
if ($resolved -ne $RealFile) { throw "Incorrect real path: $resolved" }
$selected = $type.GetMethod('FindUninstaller', $flags).Invoke($null, @($Bundle))
if ($selected -ne $ExpectedExe) { throw "Incorrect uninstaller: $selected" }
""", encoding="utf-8-sig")
    run(str(shell), "-NoProfile", "-NonInteractive", "-File", str(probe), str(assembly),
        str(case / "Plugins" / "ZYF.bundle" / "Contents" / "probe.txt"),
        str(bundle / "Contents" / "probe.txt"), str(bundle), str(executable))


def check_running_cad(compiler: str, case: Path) -> None:
    script = make_script(case)
    install(compiler, script)
    bundle = case / "Custom install" / "ZYF.bundle"
    alias = case / "Plugins" / "ZYF.bundle"
    source = case / "Sleeper.cs"
    source.write_text("class Program { static void Main() { System.Threading.Thread.Sleep(60000); } }",
                      encoding="utf-8")
    cad_exe = case / "cadtools-uninstall-fixture-acad.exe"
    font_exe = case / "cadtools-uninstall-fixture-font.exe"
    csc = "C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe"
    run(csc, "/nologo", "/target:winexe", f"/out:{cad_exe}", str(source))
    shutil.copyfile(cad_exe, font_exe)
    before = {p.relative_to(bundle): digest(p) for p in bundle.rglob("*") if p.is_file()}
    cad = subprocess.Popen([str(cad_exe)], creationflags=subprocess.CREATE_NO_WINDOW)
    font = subprocess.Popen([str(font_exe)], creationflags=subprocess.CREATE_NO_WINDOW)
    try:
        uninstall(alias / "unins000.exe", case / "blocked.log", expected=1)
        after = {p.relative_to(bundle): digest(p) for p in bundle.rglob("*") if p.is_file()}
        assert before == after and alias.is_junction() and font.poll() is None and cad.poll() is None
        assert "AutoCAD is running" in (case / "blocked.log").read_text(encoding="utf-8-sig")
        cad.terminate()
        cad.wait(timeout=10)
        uninstall(alias / "unins000.exe", case / "uninstall.log")
        wait_removed(bundle, alias)
        font.wait(timeout=10)
    finally:
        for process in (cad, font):
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=10)
    print("PASS: running CAD blocks uninstall without changes; helper stops only after CAD exits")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", default="F:/Inno Setup 6/ISCC.exe")
    args = parser.parse_args()
    scratch = ROOT / "Zyf.autoCAD" / "obj"
    scratch.mkdir(exist_ok=True)
    # Keep logs and binaries for review; never recursively clean a directory junction.
    base = Path(tempfile.mkdtemp(prefix="uninstall-smoke-", dir=scratch))
    assembly = ROOT / "Zyf.autoCAD/bin/Release/net47/ZYF.autoCAD.dll"

    clean = base / "clean"
    script = make_script(clean)
    install(args.compiler, script)
    bundle = clean / "Custom install" / "ZYF.bundle"
    alias = clean / "Plugins" / "ZYF.bundle"
    assert alias.is_junction(), "Installer did not create the expected directory junction"
    check_launcher(clean, bundle, bundle / "unins000.exe", assembly)
    uninstall(alias / "unins000.exe", clean / "uninstall.log")
    wait_removed(bundle, alias)
    print("PASS: custom installation, real-path launcher, and uninstall through the junction")

    cancelled = base / "cancelled"
    script = make_script(cancelled, cancel=True)
    install(args.compiler, script)
    bundle = cancelled / "Custom install" / "ZYF.bundle"
    alias = cancelled / "Plugins" / "ZYF.bundle"
    before = {p.relative_to(bundle): digest(p) for p in bundle.rglob("*") if p.is_file()}
    uninstall(alias / "unins000.exe", cancelled / "cancel.log", expected=1)
    after = {p.relative_to(bundle): digest(p) for p in bundle.rglob("*") if p.is_file()}
    assert before == after and alias.is_junction(), "Cancelled initialization changed installed files"
    print("PASS: cancelled initialization preserves the junction and all installed file bytes")

    repair = base / "repair"
    script = make_script(repair)
    install(args.compiler, script)
    bundle = repair / "Custom install" / "ZYF.bundle"
    alias = repair / "Plugins" / "ZYF.bundle"
    data = bundle / "unins000.dat"
    damaged = bytearray(data.read_bytes())
    damaged[-1] ^= 0xFF
    data.write_bytes(damaged)
    uninstall(alias / "unins000.exe", repair / "corrupt.log", expected=1)
    assert "corrupt" in (repair / "corrupt.log").read_text(encoding="utf-8-sig").lower()
    install(args.compiler, script, repair=True)
    assert (bundle / "unins001.dat").exists(), "Repair did not generate a new uninstall record"
    check_launcher(repair, bundle, bundle / "unins001.exe", assembly)
    retained = repair / "user-data.txt"
    retained.write_text("Keep user data 2026-10-20", encoding="utf-8")
    retained_hash = digest(retained)
    uninstall(bundle / "unins001.exe", repair / "uninstall.log")
    wait_removed(bundle, alias)
    assert digest(retained) == retained_hash
    print("PASS: damaged DAT reproduces failure; repair creates unins001 and uninstalls successfully")
    check_running_cad(args.compiler, base / "running-cad")
    print(f"Evidence: {base}")


if __name__ == "__main__":
    main()
