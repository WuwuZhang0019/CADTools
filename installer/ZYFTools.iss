#define AppName "张裕锋工具集"
#define AppVersion "1.3.8"
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
CloseApplications=no
RestartApplications=no
SetupMutex=ZYFTools-Installer-D33FF8C5-66B0-4F5C-A4C0-1094E75BE7A5

[Languages]
Name: "default"; MessagesFile: "compiler:Default.isl"

[Messages]
FinishedLabelNoIcons=安装完成。请在方便时保存图纸并重启所有 AutoCAD 窗口，以加载新版本。
FinishedLabel=安装完成。请在方便时保存图纸并重启所有 AutoCAD 窗口，以加载新版本。

[Files]
Source: "{#ProjectRoot}\Zyf.autoCAD\PackageContents.xml"; Flags: dontcopy
Source: "{#BuildOutput}\*"; DestDir: "{app}\ZYF.bundle\Contents\{code:GetInstallSlot}"; Flags: ignoreversion recursesubdirs createallsubdirs

[UninstallDelete]
Type: filesandordirs; Name: "{app}\ZYF.bundle"
Type: dirifempty; Name: "{app}"

[Code]
var
  InstallSlot: String;
  ActivationFailure: String;

function GetCurrentProcessId(): LongWord;
  external 'GetCurrentProcessId@kernel32.dll stdcall';

function GetFileAttributes(Path: string): LongWord;
  external 'GetFileAttributesW@kernel32.dll stdcall';

function RemoveDirectory(Path: string): Boolean;
  external 'RemoveDirectoryW@kernel32.dll stdcall';

function MoveFileEx(ExistingFileName, NewFileName: string; Flags: LongWord): Boolean;
  external 'MoveFileExW@kernel32.dll stdcall';

function GetInstallSlot(Param: String): String;
begin
  Result := InstallSlot;
end;

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

function StandardBundleIsInstalledBundle(): Boolean;
var
  MarkerName, MarkerPath: String;
begin
  Result := False;
  if CompareText(ExpandFileName(StandardBundlePath()), ExpandFileName(InstalledBundlePath())) = 0 then
  begin
    Result := True;
    Exit;
  end;
  if not DirExists(InstalledBundlePath()) then
    Exit;
  MarkerName := '.zyftools-location-' + InstallSlot + '.tmp';
  MarkerPath := InstalledBundlePath() + '\' + MarkerName;
  if FileExists(MarkerPath) or DirExists(MarkerPath) then
    RaiseException('安装目录检查文件已存在，请重新运行安装程序。');
  if not SaveStringToFile(MarkerPath, 'ZYFTools location check', False) then
    RaiseException('无法检查原安装目录，请检查安装路径权限。');
  try
    Result := FileExists(StandardBundlePath() + '\' + MarkerName);
  finally
    if not DeleteFile(MarkerPath) then
      Log('Unable to remove location-check file: ' + MarkerPath);
  end;
end;

function CreateBundleJunction(): Boolean;
begin
  if GetFileAttributes(StandardBundlePath()) <> $FFFFFFFF then
  begin
    Result := StandardBundleIsInstalledBundle();
    Exit;
  end;

  Result :=
    RunHiddenCommand('/C if not exist "' + StandardPluginsPath() + '" mkdir "' + StandardPluginsPath() + '"') and
    RunHiddenCommand('/C mklink /J "' + StandardBundlePath() + '" "' + InstalledBundlePath() + '"');
end;

function InitializeSetup(): Boolean;
begin
  { 每次安装使用独立目录，正在运行的 CAD 保留原来的程序集和工具文件。 }
  InstallSlot := '{#AppVersion}-' + GetDateTimeString('yyyymmddhhnnsszzz', '-', '-') + '-' + IntToStr(GetCurrentProcessId());
  Result := True;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  SlotPath: String;
begin
  Result := '';
  if (GetFileAttributes(StandardBundlePath()) <> $FFFFFFFF) and not StandardBundleIsInstalledBundle() then
  begin
    Result := 'AutoCAD 的标准插件路径已指向其他位置。请使用原来的工具集安装目录，或先处理该路径后重试。';
    Exit;
  end;
  SlotPath := InstalledBundlePath() + '\Contents\' + InstallSlot;
  if FileExists(SlotPath) or DirExists(SlotPath) then
    Result := '本次版本目录已存在，请重新运行安装程序。';
end;

function PreviousToolDirectory(): String;
var
  Lines: TArrayOfString;
  I, StartAt, EndAt, Found: Integer;
  Line, Tail, ModuleName, ModulePath, ContentsPath, ManifestPath: String;
begin
  Result := '';
  ManifestPath := InstalledBundlePath() + '\PackageContents.xml';
  if not FileExists(ManifestPath) then
  begin
    if DirExists(InstalledBundlePath() + '\Contents\Tools') then
      Result := InstalledBundlePath() + '\Contents\Tools';
    Exit;
  end;
  if not LoadStringsFromFile(ManifestPath, Lines) then
    RaiseException('无法读取原版本加载清单，旧版设置未被修改。');
  Found := 0;
  for I := 0 to GetArrayLength(Lines) - 1 do
  begin
    Line := Lines[I];
    StartAt := Pos('ModuleName="', Line);
    if StartAt > 0 then
    begin
      Tail := Copy(Line, StartAt + Length('ModuleName="'), Length(Line));
      EndAt := Pos('"', Tail);
      if EndAt = 0 then
        RaiseException('原版本加载清单中的程序集路径不完整。');
      ModuleName := Copy(Tail, 1, EndAt - 1);
      if CompareText(ExtractFileName(ModuleName), 'ZYF.AutoCAD.dll') = 0 then
      begin
        Found := Found + 1;
        ModulePath := ExpandFileName(InstalledBundlePath() + '\' + ModuleName);
        ContentsPath := AddBackslash(ExpandFileName(InstalledBundlePath() + '\Contents'));
        if CompareText(Copy(ModulePath, 1, Length(ContentsPath)), ContentsPath) <> 0 then
          RaiseException('原版本程序集路径不在工具集目录内，旧版设置未被修改。');
        Result := AddBackslash(ExtractFilePath(ModulePath)) + 'Tools';
      end;
    end;
  end;
  if Found <> 1 then
    RaiseException('无法从原版本加载清单唯一确定工具目录，旧版设置未被修改。');
end;

procedure PreservePreviousToolData();
var
  PreviousTools, NewTools, SourcePath, DestinationPath: String;
  I: Integer;
  Names: TArrayOfString;
begin
  PreviousTools := PreviousToolDirectory();
  if PreviousTools = '' then
    Exit;
  NewTools := InstalledBundlePath() + '\Contents\' + InstallSlot + '\Tools';
  SetArrayLength(Names, 2);
  Names[0] := 'FSNDataBase';
  Names[1] := 'cad开图自动选字体.txt';
  for I := 0 to GetArrayLength(Names) - 1 do
  begin
    SourcePath := AddBackslash(PreviousTools) + Names[I];
    DestinationPath := AddBackslash(NewTools) + Names[I];
    if FileExists(SourcePath) and not FileCopy(SourcePath, DestinationPath, False) then
      RaiseException('无法复制原有工具配置：' + SourcePath + '。原文件已保留，新版尚未激活。');
  end;
end;

procedure PublishBundleManifest();
var
  Lines: TArrayOfString;
  I, Replacements: Integer;
  TemporaryPath, ManifestPath: String;
begin
  ExtractTemporaryFile('PackageContents.xml');
  if not LoadStringsFromFile(ExpandConstant('{tmp}\PackageContents.xml'), Lines) then
    RaiseException('无法读取插件加载清单。');
  Replacements := 0;
  for I := 0 to GetArrayLength(Lines) - 1 do
    Replacements := Replacements + StringChangeEx(Lines[I], '.\Contents\ZYF.AutoCAD.dll',
      '.\Contents\' + InstallSlot + '\ZYF.AutoCAD.dll', True);
  if Replacements <> 1 then
    RaiseException('插件加载清单中的程序集路径不符合预期。');
  ManifestPath := InstalledBundlePath() + '\PackageContents.xml';
  TemporaryPath := InstalledBundlePath() + '\PackageContents-' + InstallSlot + '.tmp';
  if FileExists(TemporaryPath) or DirExists(TemporaryPath) then
    RaiseException('临时加载清单已存在，请重新运行安装程序。');
  try
    if not SaveStringsToUTF8FileWithoutBOM(TemporaryPath, Lines, False) then
      RaiseException('无法写入新的插件加载清单。');
    { 原子替换清单，旧版本文件仍可供已经打开的 CAD 使用。 }
    if not MoveFileEx(TemporaryPath, ManifestPath, $1 or $8) then
      RaiseException('无法更新插件加载清单；原有清单和旧版文件已保留。');
  finally
    if FileExists(TemporaryPath) then
      DeleteFile(TemporaryPath);
  end;
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
    try
      if not CreateBundleJunction() then
        RaiseException('无法安全使用 AutoCAD 标准插件路径。');
      PreservePreviousToolData();
      PublishBundleManifest();
    except
      ActivationFailure := GetExceptionMessage();
      Log('Activation failed: ' + ActivationFailure);
      if not WizardSilent() then
        MsgBox('新版文件已复制，但尚未激活；原有文件已保留。请重试或联系维护人员。' + #13#10#13#10 + ActivationFailure,
          mbError, MB_OK);
    end;
  end;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if (CurPageID = wpFinished) and (ActivationFailure <> '') then
  begin
    WizardForm.FinishedHeadingLabel.Caption := '新版本未激活';
    WizardForm.FinishedLabel.Caption := '新版文件已复制，但加载清单未更新。原有文件已保留，请重试或联系维护人员。';
  end;
end;

function GetCustomSetupExitCode(): Integer;
begin
  if ActivationFailure <> '' then
    Result := 100
  else
    Result := 0;
end;
