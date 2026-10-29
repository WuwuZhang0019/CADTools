#define AppName "张裕锋工具集"
#define AppVersion "1.3.5"
#define AppPublisher "张裕锋"
#define ProjectRoot "G:\rust\CADTools"
#define BuildOutput ProjectRoot + "\Zyf.autoCAD\bin\Release\net47"

[Setup]
AppId={{D33FF8C5-66B0-4F5C-A4C0-1094E75BE7A5}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\ZYFTools
UninstallFilesDir={app}\ZYF.bundle
; 日期：2026-10-20。修复包单独生成卸载记录，避免继续追加已损坏的 .dat。
#ifdef RepairUninstallLog
UninstallLogMode=new
#endif
DisableDirPage=no
DisableProgramGroupPage=yes
OutputDir={#ProjectRoot}\dist
OutputBaseFilename=zyf-cad-toolkit-{#AppVersion}
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin
UninstallDisplayName={#AppName}
UninstallLogging=yes

[Languages]
Name: "default"; MessagesFile: "compiler:Default.isl"

[InstallDelete]
Type: filesandordirs; Name: "{app}\ZYF.bundle\Contents"
Type: files; Name: "{app}\ZYF.bundle\PackageContents.xml"

[Files]
Source: "{#ProjectRoot}\Zyf.autoCAD\PackageContents.xml"; DestDir: "{app}\ZYF.bundle"; Flags: ignoreversion
Source: "{#BuildOutput}\*"; DestDir: "{app}\ZYF.bundle\Contents"; Flags: ignoreversion recursesubdirs createallsubdirs

[UninstallDelete]
Type: filesandordirs; Name: "{app}\ZYF.bundle"
Type: dirifempty; Name: "{app}"

[Code]
function GetFileAttributes(Path: string): LongWord;
  external 'GetFileAttributesW@kernel32.dll stdcall';

function RemoveDirectory(Path: string): Boolean;
  external 'RemoveDirectoryW@kernel32.dll stdcall';

function StandardPluginsPath(): string;
begin
  Result := ExpandConstant('{commonappdata}\Autodesk\ApplicationPlugins');
end;

function StandardBundlePath(): string;
begin
  Result := StandardPluginsPath() + '\ZYF.bundle';
end;

function InstalledBundlePath(): string;
begin
  Result := ExpandConstant('{app}\ZYF.bundle');
end;

function RunHiddenCommand(Parameters: string): Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec(ExpandConstant('{cmd}'), Parameters, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  if Result then
    Result := ResultCode = 0;
end;

function IsProcessRunning(ProcessName: string): Boolean;
var
  ResultCode: Integer;
begin
  if not Exec(ExpandConstant('{cmd}'), '/D /C tasklist /FO CSV /NH /FI "IMAGENAME eq ' + ProcessName + '" | find /I "' + ProcessName + '" >nul', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    RaiseException('无法检查运行中的程序，请稍后重试。');
  if (ResultCode <> 0) and (ResultCode <> 1) then
    RaiseException('检查运行中的程序失败，请稍后重试。');
  Result := ResultCode = 0;
end;

procedure KillProcess(ProcessName: string);
var
  ResultCode: Integer;
begin
  if not Exec(ExpandConstant('{cmd}'), '/C taskkill /F /IM "' + ProcessName + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    RaiseException('无法关闭字体辅助程序，请手动关闭后重试。');
  if IsProcessRunning(ProcessName) then
    RaiseException('字体辅助程序仍在运行，请手动关闭后重试。');
end;

function RemoveStandardBundle(): Boolean;
begin
  Result := RunHiddenCommand('/C if exist "' + StandardBundlePath() + '" rmdir /S /Q "' + StandardBundlePath() + '"');
end;

function CreateBundleJunction(): Boolean;
begin
  if CompareText(ExpandFileName(StandardBundlePath()), ExpandFileName(InstalledBundlePath())) = 0 then
  begin
    Result := True;
    Exit;
  end;

  Result :=
    RunHiddenCommand('/C if not exist "' + StandardPluginsPath() + '" mkdir "' + StandardPluginsPath() + '"') and
    RemoveStandardBundle() and
    RunHiddenCommand('/C mklink /J "' + StandardBundlePath() + '" "' + InstalledBundlePath() + '"');
end;

function PrepareInstall(): Boolean;
begin
  Result := False;

  if IsProcessRunning('acad.exe') then
  begin
    MsgBox('检测到 AutoCAD 正在运行。请先保存图纸并关闭 AutoCAD，然后重新运行安装程序。', mbError, MB_OK);
    Exit;
  end;

  if IsProcessRunning('09 CAD开图自动选字体.exe') then
  begin
    KillProcess('09 CAD开图自动选字体.exe');
  end;

  Result := True;
end;

function InitializeSetup(): Boolean;
begin
  Result := PrepareInstall();
end;

function WaitForAutoCadClosed(): Boolean;
begin
  Result := False;
  while IsProcessRunning('acad.exe') do
  begin
    if UninstallSilent then
    begin
      Log('AutoCAD is running; uninstall cancelled without changes.');
      Exit;
    end;
    if MsgBox('卸载前请先保存图纸并关闭所有 AutoCAD 窗口。关闭后点击“重试”继续卸载；点击“取消”不会卸载软件。',
      mbInformation, MB_RETRYCANCEL or MB_DEFBUTTON2) <> IDRETRY then
      Exit;
  end;
  Result := True;
end;

function InitializeUninstall(): Boolean;
begin
  { 初始化和确认阶段不删除联接、不结束字体辅助程序。 }
  Result := WaitForAutoCadClosed();
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Attributes: LongWord;
begin
  if CurUninstallStep = usUninstall then
  begin
    if not WaitForAutoCadClosed() then
      Abort;
    if IsProcessRunning('09 CAD开图自动选字体.exe') then
      KillProcess('09 CAD开图自动选字体.exe');
  end;

  if CurUninstallStep = usPostUninstall then
  begin
    { 只移除目录联接本身；不递归删除联接指向的目录或手工部署目录。 }
    Attributes := GetFileAttributes(StandardBundlePath());
    if (Attributes <> $FFFFFFFF) and ((Attributes and $400) <> 0) then
      if not RemoveDirectory(StandardBundlePath()) then
        Log('Unable to remove the AutoCAD bundle junction: ' + StandardBundlePath());
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    if not CreateBundleJunction() then
    begin
      MsgBox('安装文件已复制，但创建 AutoCAD 标准加载路径联接失败。请确认安装程序以管理员权限运行后重试。', mbError, MB_OK);
    end;
  end;
end;
