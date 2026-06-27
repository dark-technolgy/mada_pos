; Mada Smart POS — Windows installer (Inno Setup 6)
; Build: scripts\build_windows_installer.ps1

#define MyAppName "Mada Smart POS"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Mada"
#define MyAppExeName "mada_pos.exe"
#define MyBuildDir "..\build\windows\x64\runner\Release"
#define MyDistDir "..\dist"
#define MyRedistDir "..\installer\redist"

[Setup]
AppId={{A7B3C4D5-E6F7-4890-ABCD-MADAPOS2026}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Mada Smart POS
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=no
OutputDir={#MyDistDir}
OutputBaseFilename=Mada_POS_Setup_{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
MinVersion=10.0
AppCopyright=Copyright (C) 2026 {#MyAppPublisher}
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} — نظام إدارة المبيعات
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#MyDistDir}\Mada_POS_User_Manual_AR.pdf"; DestDir: "{app}\docs"; Flags: ignoreversion; Check: FileExists(ExpandConstant('{#MyDistDir}\Mada_POS_User_Manual_AR.pdf'))
Source: "{#MyDistDir}\Mada_POS_User_Manual_EN.pdf"; DestDir: "{app}\docs"; Flags: ignoreversion; Check: FileExists(ExpandConstant('{#MyDistDir}\Mada_POS_User_Manual_EN.pdf'))
Source: "{#MyDistDir}\Mada_POS_User_Manual_KU.pdf"; DestDir: "{app}\docs"; Flags: ignoreversion; Check: FileExists(ExpandConstant('{#MyDistDir}\Mada_POS_User_Manual_KU.pdf'))
Source: "{#MyRedistDir}\vc_redist.x64.exe"; DestDir: "{app}\redist"; Flags: ignoreversion; Check: FileExists(ExpandConstant('{#MyRedistDir}\vc_redist.x64.exe'))
Source: "{#MyRedistDir}\ndp48-web.exe"; DestDir: "{app}\redist"; Flags: ignoreversion; Check: FileExists(ExpandConstant('{#MyRedistDir}\ndp48-web.exe'))
Source: "{#MyRedistDir}\ndp48-x86-x64-allos-enu.exe"; DestDir: "{app}\redist"; Flags: ignoreversion; Check: FileExists(ExpandConstant('{#MyRedistDir}\ndp48-x86-x64-allos-enu.exe'))
Source: "Start_Mada_POS.bat"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{#MyAppName} (مع تثبيت المكتبات)"; Filename: "{app}\Start_Mada_POS.bat"
Name: "{group}\دليل المستخدم"; Filename: "{app}\docs\Mada_POS_User_Manual_AR.pdf"; Check: FileExists(ExpandConstant('{app}\docs\Mada_POS_User_Manual_AR.pdf'))
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Visual C++ 2015-2022 x64
Filename: "{app}\redist\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Visual C++ Runtime..."; Flags: waituntilterminated; Check: NeedsVcRedist and FileExists(ExpandConstant('{app}\redist\vc_redist.x64.exe'))
; .NET Framework 4.8 (offline if bundled, else web bootstrapper)
Filename: "{app}\redist\ndp48-x86-x64-allos-enu.exe"; Parameters: "/q /norestart"; StatusMsg: "Installing .NET Framework 4.8..."; Flags: waituntilterminated; Check: NeedsDotNet48 and FileExists(ExpandConstant('{app}\redist\ndp48-x86-x64-allos-enu.exe'))
Filename: "{app}\redist\ndp48-web.exe"; Parameters: "/q /norestart"; StatusMsg: "Installing .NET Framework 4.8..."; Flags: waituntilterminated; Check: NeedsDotNet48 and (not FileExists(ExpandConstant('{app}\redist\ndp48-x86-x64-allos-enu.exe'))) and FileExists(ExpandConstant('{app}\redist\ndp48-web.exe'))
Filename: "{app}\{#MyAppExeName}"; Description: "تشغيل {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Code]
function InitializeSetup(): Boolean;
begin
  if not FileExists(ExpandConstant('{#MyBuildDir}\{#MyAppExeName}')) then
  begin
    MsgBox('لم يُعثر على ملف البناء.' + #13#10 +
      'شغّل أولاً: scripts\build_windows_installer.ps1',
      mbError, MB_OK);
    Result := False;
  end
  else
    Result := True;
end;

function VcRedistInstalled: Boolean;
begin
  Result :=
    RegKeyExists(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64') or
    RegKeyExists(HKLM, 'SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64');
end;

function DotNet48Installed: Boolean;
var
  Release: Cardinal;
begin
  Result :=
    RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', 'Release', Release) and
    (Release >= 528040);
end;

function NeedsVcRedist: Boolean;
begin
  Result := not VcRedistInstalled;
end;

function NeedsDotNet48: Boolean;
begin
  Result := not DotNet48Installed;
end;
