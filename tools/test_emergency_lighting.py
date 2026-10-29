"""Exercise the built runtime's extraction and data protection in a fixture.

Date: 2026-10-29
Uses Windows PowerShell and the Release assembly; does not start AutoCAD.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "Zyf.autoCAD/Tools/Emergency-Lighting"
ASSEMBLY = ROOT / "Zyf.autoCAD/bin/Release/net47/ZYF.autoCAD.dll"
SHELL = Path("C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe")
PREFIX = "应急照明-v0.1.84/"


def main():
    base = Path(tempfile.mkdtemp(prefix="emergency-v84-", dir=ROOT / "Zyf.autoCAD/obj"))
    probe = base / "probe.ps1"
    probe.write_text(r"""param($Assembly, $Mode, $Module, $Data, $Output)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$assemblyObj = [Reflection.Assembly]::LoadFrom($Assembly)
$flags = [Reflection.BindingFlags]'Static,NonPublic,Public'
try {
    if ($Mode -eq 'prepare') {
        $type = $assemblyObj.GetType('ZYF.autoCAD.Services.EmergencyLightingRuntime', $true)
        $result = $type.GetMethod('PrepareAt', $flags).Invoke($null, @($Module, $Data))
        Write-Output $result
    } else {
        $type = $assemblyObj.GetType('ZYF.autoCAD.Services.EmergencyLightingScript', $true)
        $result = $type.GetMethod('Build', $flags).Invoke($null, @($Data, $Module))
        [IO.File]::WriteAllText($Output, $result, [Text.UTF8Encoding]::new($false))
    }
} catch {
    [Console]::Error.WriteLine($_.Exception.ToString())
    exit 2
}
""", encoding="utf-8-sig")

    def args(mode, module, data, output=""):
        return [str(SHELL), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(probe),
                "-Assembly", str(ASSEMBLY), "-Mode", mode, "-Module", str(module), "-Data", str(data), "-Output", str(output)]

    def run(mode, module, data, output="", expected=0):
        result = subprocess.run(args(mode, module, data, output), capture_output=True, text=True, encoding="utf-8", timeout=90)
        if result.returncode != expected:
            raise AssertionError(f"unexpected exit {result.returncode}: {result.stdout} {result.stderr}")
        return result

    runtime = base / "用户 data" / "CADTools"
    (runtime / "config").mkdir(parents=True)
    (runtime / "output").mkdir()
    (runtime / "config/drawing-existing.eld").write_bytes(b"existing config")
    (runtime / "output/result-existing.eld").write_bytes(b"existing output")
    run("prepare", MODULE, runtime)
    with zipfile.ZipFile(MODULE / "full-v0.1.84.zip") as archive:
        extracted = []
        for member in archive.infolist():
            if member.is_dir():
                continue
            name = member.filename.removeprefix(PREFIX)
            if name == "package-183.marker" or name.startswith(("src/", "ui/", "native/", "templates/", "assets/default-device-library/")):
                assert (runtime / name).read_bytes() == archive.read(member), name
                extracted.append(name)
        assert len(extracted) == 150
    run("prepare", MODULE, runtime)
    assert (runtime / "config/drawing-existing.eld").read_bytes() == b"existing config"
    assert (runtime / "output/result-existing.eld").read_bytes() == b"existing output"
    print("PASS: 150 runtime files match the full ZIP; repeated preparation preserves user data")

    conflict = runtime / "src/common.lsp"
    conflict.write_bytes(b"user-modified-runtime")
    failed = run("prepare", MODULE, runtime, expected=2)
    assert "不一致" in failed.stderr and conflict.read_bytes() == b"user-modified-runtime"
    assert (runtime / "config/drawing-existing.eld").read_bytes() == b"existing config"
    print("PASS: conflicting runtime file is retained and preparation fails")

    bad = base / "bad package"
    shutil.copytree(MODULE, bad)
    archive = bad / "full-v0.1.84.zip"
    with archive.open("r+b") as stream:
        stream.seek(1234)
        before = stream.read(1)
        stream.seek(1234)
        stream.write(bytes([before[0] ^ 1]))
    rejected_root = base / "rejected"
    run("prepare", bad, rejected_root, expected=2)
    assert not rejected_root.exists()
    print("PASS: corrupt package is rejected before creating user data")

    parallel_root = base / "parallel"
    a = subprocess.Popen(args("prepare", MODULE, parallel_root), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    b = subprocess.Popen(args("prepare", MODULE, parallel_root), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    oa, ea = a.communicate(timeout=90)
    ob, eb = b.communicate(timeout=90)
    assert a.returncode == b.returncode == 0, (oa, ea, ob, eb)
    assert not list(parallel_root.rglob("*.tmp"))
    print("PASS: two independent preparers use the same runtime without partial files")

    expression = base / "generated-command.txt"
    run("build", MODULE / "ELFULL84-CADTools.lsp", runtime, expression)
    text = expression.read_text(encoding="utf-8")
    assert "full-v0.1.84" in text and "package-183.marker" in text and "C:ELFULL84" in text
    print(f"PASS: built assembly generated the v0.1.84 command; evidence: {base}")


if __name__ == "__main__":
    main()
