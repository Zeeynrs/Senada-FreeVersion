; Inno Setup script for Senada. Compiled by build.ps1 after PyInstaller has produced
; dist\Senada\ and the tools have been copied into dist\Senada\bin\.
;   iscc /DAppVersion=1.0.0 senada.iss
; With /DSign and a /Ssenadasign=... sign tool (build.ps1 adds both when a certificate is
; configured) the installer and uninstaller are Authenticode-signed.
;
; The in-app updater runs the new installer with /SILENT /RELAUNCH=1: Senada then starts
; again once the files have been replaced.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define AppName "Senada"
#define AppExe "Senada.exe"
#define AppUrl "https://github.com/Zeeynrs/Senada-FreeVersion"

[Setup]
AppId={{6A0C1F3E-7B52-4C8E-9D1A-5E3F2B8C4D71}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Zeeynrs
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
AppUpdatesURL={#AppUrl}/releases
VersionInfoVersion={#AppVersion}
; per-user install by default: no admin prompt, and yt-dlp.exe stays writable for `yt-dlp -U`
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
LicenseFile=..\..\LICENSE
OutputDir=dist
OutputBaseFilename=Senada-Setup-{#AppVersion}
SetupIconFile=build\senada.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
; tell Windows to refresh its icons when the install ends: an update keeps the shortcut's path,
; so Start and Windows Search would otherwise keep showing an old icon from their cache
ChangesAssociations=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
#ifdef Sign
SignTool=senadasign
SignedUninstaller=yes
#endif

[Languages]
#ifexist "build\Indonesian.isl"
Name: "id"; MessagesFile: "build\Indonesian.isl"
#endif
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[InstallDelete]
; drop files left over from an older version before copying the new build
Type: filesandordirs; Name: "{app}\_internal"

[Files]
Source: "dist\Senada\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; AppUserModelID: "Senada.MusicPlayer"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; AppUserModelID: "Senada.MusicPlayer"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
; update started from inside Senada: open it again
Filename: "{app}\{#AppExe}"; Flags: nowait runasoriginaluser; Check: RelaunchRequested

[UninstallDelete]
; yt-dlp -U may leave a backup next to the bundled copy
Type: filesandordirs; Name: "{app}\bin"

[Code]
function RelaunchRequested: Boolean;
begin
  Result := ExpandConstant('{param:RELAUNCH|0}') = '1';
end;
