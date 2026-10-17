; EternalMonitor host installer (Inno Setup 6)
; Builds a single EternalMonitor-Setup.exe that installs the host app, the FFmpeg
; runtime, and (optionally) bundles + installs the Virtual Display Driver so the iPad
; can act as an extended display with no manual driver steps.
;
; Do not compile this directly — run scripts\build-installer.ps1, which stages the
; files and passes the required /D defines below:
;   StagingDir  : absolute path to the staged payload (app exe, DLLs, docs, driver\)
;   AppVersion  : version string, e.g. 0.1.1
;   IncludeDriver (optional, defined only when a driver setup .exe was staged)

#ifndef StagingDir
  #error "StagingDir is not defined — run scripts\build-installer.ps1 instead of compiling the .iss directly."
#endif
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
; Native Windows Ink pen injection requires the Windows 10 1809 APIs.
MinVersion=10.0.17763
AppId={{B7E6F2C4-3A91-4E0D-9C2A-ETERNALMONITOR}}
AppName=EternalMonitor
AppVersion={#AppVersion}
AppVerName=EternalMonitor {#AppVersion}
AppPublisher=Ali Younes
AppPublisherURL=https://github.com/sidebandstudio/EternalMonitor
AppSupportURL=https://github.com/sidebandstudio/EternalMonitor
AppUpdatesURL=https://github.com/sidebandstudio/EternalMonitor/releases
AppContact=hello@sideband.studio
DefaultDirName={autopf}\EternalMonitor
DefaultGroupName=EternalMonitor
DisableProgramGroupPage=yes
DisableDirPage=yes
; Driver installation requires elevation — request it once for the whole run.
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#StagingDir}\..\out
OutputBaseFilename=EternalMonitor-Setup
Compression=lzma2/max
SolidCompression=yes
; --- Branding (see docs/design.md) --------------------------------------------
WizardStyle=modern
SetupIconFile=..\host\assets\icon.ico
WizardImageFile=assets\wizard-large.bmp
WizardSmallImageFile=assets\wizard-small.bmp
WizardImageStretch=yes
UninstallDisplayName=EternalMonitor
UninstallDisplayIcon={app}\EternalMonitor-host.exe
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "languages\ChineseSimplified.isl"

[CustomMessages]
english.DesktopShortcut=Create a desktop shortcut
chinesesimplified.DesktopShortcut=创建桌面快捷方式
english.Shortcuts=Shortcuts:
chinesesimplified.Shortcuts=快捷方式：
english.Quickstart=Quickstart (read me)
chinesesimplified.Quickstart=快速入门（自述文件）
english.UninstallApp=Uninstall EternalMonitor
chinesesimplified.UninstallApp=卸载 EternalMonitor
english.LaunchNow=Launch EternalMonitor now
chinesesimplified.LaunchNow=立即启动 EternalMonitor
english.FirewallStatus=Allowing display traffic through Windows Firewall...
chinesesimplified.FirewallStatus=正在允许 EternalMonitor 通过 Windows 防火墙…
english.DriverStatus=Installing the virtual display driver (this enables the extended screen)...
chinesesimplified.DriverStatus=正在安装虚拟显示驱动（用于启用扩展屏幕）…
english.DisplayTaskStatus=Configuring the on-demand virtual display...
chinesesimplified.DisplayTaskStatus=正在配置按需启用的虚拟显示器…

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopShortcut}"; GroupDescription: "{cm:Shortcuts}"
; Autostart is handled inside the app (Settings -> "Start with Windows",
; which writes HKCU\Run for the signed-in user) — no installer task needed.

[Files]
Source: "{#StagingDir}\EternalMonitor-host.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#StagingDir}\*.dll";                   DestDir: "{app}"; Flags: ignoreversion
Source: "{#StagingDir}\ffmpeg.exe";              DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#StagingDir}\README.md";               DestDir: "{app}"; Flags: ignoreversion isreadme skipifsourcedoesntexist
Source: "{#StagingDir}\LICENSE";                 DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#StagingDir}\QUICKSTART.txt";          DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
; Scripts that register/remove the scheduled tasks the host uses to toggle the display, plus the
; toggle script the tasks invoke. Keep these in app-only upgrades as well so an existing VDD can
; be repaired without reinstalling the third-party driver package.
Source: "scripts\vdd-tasks-setup.ps1";  DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "scripts\vdd-tasks-remove.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "scripts\vdd-driver-remove.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "scripts\vdd-driver-verify.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "scripts\vdd-toggle.ps1";       DestDir: "{app}\scripts"; Flags: ignoreversion
#ifdef IncludeDriver
; Third-party Virtual Display Driver setup, bundled so the tester never touches GitHub.
Source: "{#StagingDir}\driver\*"; DestDir: "{app}\driver"; Flags: ignoreversion recursesubdirs
#endif

[Icons]
Name: "{group}\EternalMonitor";            Filename: "{app}\EternalMonitor-host.exe"
Name: "{group}\{cm:Quickstart}";            Filename: "{app}\QUICKSTART.txt"
Name: "{group}\{cm:UninstallApp}";          Filename: "{uninstallexe}"
Name: "{autodesktop}\EternalMonitor";      Filename: "{app}\EternalMonitor-host.exe"; Tasks: desktopicon

[Run]
; Replace only this product's named rules so upgrades remain idempotent.
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""EternalMonitor Host UDP"""; Flags: runhidden waituntilterminated
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""EternalMonitor Host TCP"""; Flags: runhidden waituntilterminated
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""EternalMonitor Host UDP"" dir=in action=allow program=""{app}\EternalMonitor-host.exe"" protocol=UDP profile=private,public enable=yes"; StatusMsg: "{cm:FirewallStatus}"; Flags: runhidden waituntilterminated
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""EternalMonitor Host TCP"" dir=in action=allow program=""{app}\EternalMonitor-host.exe"" protocol=TCP profile=private,public enable=yes"; Flags: runhidden waituntilterminated
#ifdef IncludeDriver
; The vendor setup prompts to uninstall an existing installation even with silent
; switches. Preserve an existing driver and install only when it is absent.
Filename: "{app}\driver\vdd-setup-x64.exe"; Parameters: "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"; StatusMsg: "{cm:DriverStatus}"; Flags: waituntilterminated; Check: NeedsVddInstall; AfterInstall: RecordVddOwnership
#endif
; Register high-privilege enable/disable tasks and leave the virtual display OFF by default —
; EternalMonitor turns it on only while streaming to it, so there's no phantom monitor. This also
; repairs task definitions during an app-only upgrade when the VDD package is already installed.
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\vdd-tasks-setup.ps1"""; StatusMsg: "{cm:DisplayTaskStatus}"; Flags: runhidden waituntilterminated; Check: ShouldConfigureVdd; AfterInstall: VerifyVddDriver
; Launch the app at the end.
Filename: "{app}\EternalMonitor-host.exe"; Description: "{cm:LaunchNow}"; Flags: nowait postinstall skipifsilent; Check: VddInstallSucceeded

[UninstallRun]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""EternalMonitor Host UDP"""; Flags: runhidden waituntilterminated; RunOnceId: "EternalMonitorFirewallUDP"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""EternalMonitor Host TCP"""; Flags: runhidden waituntilterminated; RunOnceId: "EternalMonitorFirewallTCP"
; Remove the scheduled tasks and disable the device before removing an owned driver.
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\vdd-tasks-remove.ps1"""; Flags: runhidden; RunOnceId: "VddTasksRemove"
#ifdef IncludeDriver
; Always record this entry to supersede older VddUninstall commands on upgrade.
; A Check that returns false at install time leaves the old command in place.
; The helper checks ownership when the uninstaller actually runs.
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\vdd-driver-remove.ps1"""; Flags: runhidden waituntilterminated; RunOnceId: "VddUninstall"
#endif

#ifdef IncludeDriver
[UninstallDelete]
Type: files; Name: "{app}\driver\installed-by-eternalmonitor.txt"
#endif

[Code]
var
  VddInstallFailed: Boolean;

function VddInstallSucceeded: Boolean;
begin
  Result := not VddInstallFailed;
end;

function GetCustomSetupExitCode: Integer;
begin
  Result := 0;
  if VddInstallFailed then
    Result := 1;
end;

const
  VddRegistryKey = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\VirtualDisplayDriver_is1';

function ReadVddRegistration(var Directory, Version: String): Boolean;
begin
  Result := RegQueryStringValue(HKLM64, VddRegistryKey, 'InstallLocation', Directory);
  if Result then
    Result := RegQueryStringValue(HKLM64, VddRegistryKey, 'DisplayVersion', Version)
  else begin
    Result := RegQueryStringValue(HKLM32, VddRegistryKey, 'InstallLocation', Directory);
    if Result then
      Result := RegQueryStringValue(HKLM32, VddRegistryKey, 'DisplayVersion', Version);
  end;
  Result := Result and (Directory <> '') and (Version <> '');
end;

function ShouldConfigureVdd: Boolean;
var
  Directory, Version: String;
begin
  Result := VddInstallSucceeded and ReadVddRegistration(Directory, Version);
end;

procedure VerifyVddDriver;
var
  ExitCode: Integer;
begin
  { [Run] ignores a child process's exit code. Check the actual PnP binding
    explicitly, including upgrades that preserve an existing registration. }
  if not Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
      '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\scripts\vdd-driver-verify.ps1') + '"',
      '', SW_HIDE, ewWaitUntilTerminated, ExitCode) or (ExitCode <> 0) then begin
    VddInstallFailed := True;
    RaiseException('Windows did not finish installing the virtual display driver. Run setup while signed into Windows and approve its publisher prompt. If the driver already exists, repair it before trying again.');
  end;
end;

#ifdef IncludeDriver

function NeedsVddInstall: Boolean;
var
  Directory, Version: String;
begin
  Result := not ReadVddRegistration(Directory, Version);
  if not Result then
    Log('Preserving existing Virtual Display Driver package ' + Version);
end;

procedure RecordVddOwnership;
var
  Directory, Version: String;
begin
  VerifyVddDriver;
  if not ReadVddRegistration(Directory, Version) then
    RaiseException('Virtual Display Driver installation did not register successfully.');
  if not FileExists(AddBackslash(Directory) + 'unins000.exe') then
    RaiseException('Virtual Display Driver uninstaller is missing after installation.');
  if not SaveStringToFile(ExpandConstant('{app}\driver\installed-by-eternalmonitor.txt'),
      AddBackslash(Directory) + 'unins000.exe' + #13#10 + Version, False) then
    RaiseException('Could not record Virtual Display Driver installation ownership.');
end;

#endif
