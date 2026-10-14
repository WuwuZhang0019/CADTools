#define AppName "张裕锋工具集"
#define AppVersion "1.3.3"
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
DisableDirPage=no
DisableProgramGroupPage=yes
OutputDir={#ProjectRoot}\dist
OutputBaseFilename=zyf-cad-toolkit-{#AppVersion}
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin
UninstallDisplayName={#AppName}

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
  Exec(ExpandConstant('{cmd}'), Parameters, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := ResultCode = 0;
end;

function IsProcessRunning(ProcessName: string): Boolean;
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{cmd}'), '/C tasklist /FI "IMAGENAME eq ' + ProcessName + '" | find /I "' + ProcessName + '" >nul', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := ResultCode = 0;
end;

procedure KillProcess(ProcessName: string);
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{cmd}'), '/C taskkill /F /IM "' + ProcessName + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

function RemoveStandardBundle(): Boolean;
begin
  Result := RunHiddenCommand('/C if exist "' + StandardBundlePath() + '" rmdir /S /Q "' + StandardBundlePath() + '"');
end;

function CreateBundleJunction(): Boolean;
begin
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

function InitializeUninstall(): Boolean;
begin
  if IsProcessRunning('09 CAD开图自动选字体.exe') then
  begin
    KillProcess('09 CAD开图自动选字体.exe');
  end;

  RemoveStandardBundle();
  Result := True;
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
