; ─────────────────────────────────────────────────────────────────────────────
; DrumOut — Inno Setup Installer Script
; Requer: Inno Setup 6.x  →  https://jrsoftware.org/isdl.php
; Compilar com:  ISCC.exe setup.iss
; ─────────────────────────────────────────────────────────────────────────────

#define AppName      "DrumOut"
#define AppVersion   "1.0.0"
#define AppPublisher "DrumOut"
#define AppExeName   "DrumOut.exe"
#define SourceDir    "dist\DrumOut"
#define AssetsDir    "assets"

[Setup]
; GUID único do app — não altere após a primeira publicação
AppId={{A7F3C2D1-8B4E-4F2A-9C3D-1E5F7A8B9C0D}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=no
OutputDir=installer_output
OutputBaseFilename=DrumOut_Setup_v{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
InternalCompressLevel=ultra64
; Windows 10 1903+ (WebView2 edge nativo)
MinVersion=10.0.18362
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Permite instalar sem admin em pasta pessoal
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline dialog
WizardStyle=modern
WizardResizable=no
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
; Ícone do instalador (descomente quando tiver o arquivo)
; SetupIconFile={#AssetsDir}\drumout.ico

[Languages]
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "english";    MessagesFile: "compiler:Default.isl"

[CustomMessages]
portuguese.WebView2Msg=Verificando Microsoft Edge WebView2...
portuguese.VCRedistMsg=Instalando Visual C++ Redistributable...
english.WebView2Msg=Checking Microsoft Edge WebView2...
english.VCRedistMsg=Installing Visual C++ Redistributable...

[Tasks]
Name: "desktopicon";  Description: "Criar ícone na Área de Trabalho"; Flags: checked
Name: "startmenu";    Description: "Criar atalho no Menu Iniciar";    Flags: checked

[Files]
; ── Bundle principal (toda a saída do PyInstaller) ───────────────────────────
Source: "{#SourceDir}\*"; DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

; ── ffmpeg embutido ──────────────────────────────────────────────────────────
Source: "{#AssetsDir}\ffmpeg.exe"; DestDir: "{app}"; Flags: ignoreversion

; ── WebView2 Bootstrapper (detecta se já instalado; não faz nada se sim) ────
; Baixe em: https://go.microsoft.com/fwlink/p/?LinkId=2124703
Source: "{#AssetsDir}\MicrosoftEdgeWebview2Setup.exe"; \
    DestDir: "{tmp}"; Flags: deleteafterinstall; \
    Check: FileExists(ExpandConstant('{#AssetsDir}\MicrosoftEdgeWebview2Setup.exe'))

; ── Visual C++ Redistributable (necessário para DLLs do torch) ──────────────
; Baixe em: https://aka.ms/vs/17/release/vc_redist.x64.exe
Source: "{#AssetsDir}\vc_redist.x64.exe"; \
    DestDir: "{tmp}"; Flags: deleteafterinstall; \
    Check: FileExists(ExpandConstant('{#AssetsDir}\vc_redist.x64.exe'))

[Icons]
; Área de trabalho
Name: "{autodesktop}\{#AppName}"; \
    Filename: "{app}\{#AppExeName}"; \
    Comment: "Remove bateria de músicas do YouTube"; \
    Tasks: desktopicon

; Menu Iniciar
Name: "{group}\{#AppName}"; \
    Filename: "{app}\{#AppExeName}"; \
    Comment: "Remove bateria de músicas do YouTube"; \
    Tasks: startmenu
Name: "{group}\Desinstalar {#AppName}"; \
    Filename: "{uninstallexe}"; \
    Tasks: startmenu

[Run]
; Instala VC++ Runtime silenciosamente (idempotente se já instalado)
Filename: "{tmp}\vc_redist.x64.exe"; \
    Parameters: "/install /quiet /norestart"; \
    StatusMsg: "{cm:VCRedistMsg}"; \
    Flags: waitprogress runhidden; \
    Check: FileExists(ExpandConstant('{tmp}\vc_redist.x64.exe'))

; WebView2 bootstrapper — /silent não faz nada se já instalado
Filename: "{tmp}\MicrosoftEdgeWebview2Setup.exe"; \
    Parameters: "/silent /install"; \
    StatusMsg: "{cm:WebView2Msg}"; \
    Flags: waitprogress runhidden; \
    Check: FileExists(ExpandConstant('{tmp}\MicrosoftEdgeWebview2Setup.exe'))

; Pergunta se quer abrir o app após instalação
Filename: "{app}\{#AppExeName}"; \
    Description: "Abrir DrumOut agora"; \
    Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Remove arquivos gerados em runtime
Type: filesandordirs; Name: "{app}\tmp"
Type: files;          Name: "{app}\drumout.log"
Type: filesandordirs; Name: "{app}\build"
Type: filesandordirs; Name: "{app}\__pycache__"

[Code]
// Verifica Windows 10 versão 1903+ (build 18362) para Edge WebView2 nativo
function InitializeSetup(): Boolean;
var
  Ver: TWindowsVersion;
begin
  GetWindowsVersionEx(Ver);
  if (Ver.Major < 10) or ((Ver.Major = 10) and (Ver.Build < 18362)) then
  begin
    MsgBox(
      'DrumOut requer Windows 10 versão 1903 (build 18362) ou superior.' + #13#10 +
      'Por favor, atualize o Windows e tente novamente.',
      mbError, MB_OK
    );
    Result := False;
  end
  else
    Result := True;
end;
