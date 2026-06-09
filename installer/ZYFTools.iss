#define AppName "张裕锋工具集"
#define AppVersion "1.1.0"
#define AppPublisher "WuwuZhang"
#define ProjectRoot "G:\rust\CADTools"
#define BuildOutput ProjectRoot + "\Zyf.autoCAD\bin\Release\net47"

[Setup]
AppId={{D33FF8C5-66B0-4F5C-A4C0-1094E75BE7A5}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={commonappdata}\Autodesk\ApplicationPlugins\ZYF.bundle
DisableDirPage=yes
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
Type: filesandordirs; Name: "{app}\Contents"

[Files]
Source: "{#ProjectRoot}\Zyf.autoCAD\PackageContents.xml"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildOutput}\*"; DestDir: "{app}\Contents"; Flags: ignoreversion recursesubdirs createallsubdirs

[UninstallDelete]
Type: filesandordirs; Name: "{app}\Contents"
Type: files; Name: "{app}\PackageContents.xml"

[Code]
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

  Result := True;
end;
