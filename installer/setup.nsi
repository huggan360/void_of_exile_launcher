; Void of Exile online installer (Windows). Built by .github/workflows/build.yml with makensis:
;   makensis -DVERSION=1.2.0 installer/setup.nsi   ->  build/VoidOfExileSetup.exe
;
; Small on purpose: it downloads the newest launcher from void.plainshow.se (the Pi mirrors every launcher
; release, server/void_release.py in void_of_exile_account), unpacks it into <folder>\Launcher and adds the
; Start menu and desktop shortcuts and an entry in Apps & features. Per user, no admin prompt: the default
; folder is %LOCALAPPDATA%\Programs\Void of Exile, where the launcher also puts Game and Server.
; The launcher runs it silently to update itself:  VoidOfExileSetup.exe /S /D=<folder>

Unicode true
!include "MUI2.nsh"

!ifndef VERSION
  !define VERSION "0.0.0"
!endif
!define NAME "Void of Exile"
!define PUBLISHER "Void of Exile"
!define ZIP_URL "https://void.plainshow.se/files/launcher/VoidOfExileLauncher-Windows.zip"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\VoidOfExile"
!define EXE "$INSTDIR\Launcher\VoidOfExileLauncher.exe"

Name "${NAME}"
OutFile "../build/VoidOfExileSetup.exe"
InstallDir "$LOCALAPPDATA\Programs\Void of Exile"
InstallDirRegKey HKCU "Software\Void of Exile" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
BrandingText "${NAME}"
VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${NAME} Setup"
VIAddVersionKey "CompanyName" "${PUBLISHER}"
VIAddVersionKey "FileDescription" "${NAME} Setup"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "${PUBLISHER}"

!define MUI_ICON "../assets/icon.ico"
!define MUI_UNICON "../assets/icon.ico"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "${EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Start the Void of Exile launcher"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Launcher"
  SetOutPath "$INSTDIR"
  ; A running launcher holds its files: ask it to close first.
  nsExec::Exec 'taskkill /IM VoidOfExileLauncher.exe /F'
  Pop $0
  DetailPrint "Downloading the newest launcher"
  InitPluginsDir
  nsExec::ExecToLog `powershell -NoProfile -ExecutionPolicy Bypass -Command "$$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '${ZIP_URL}' -OutFile '$PLUGINSDIR\launcher.zip'; Expand-Archive -Force -Path '$PLUGINSDIR\launcher.zip' -DestinationPath '$INSTDIR\Launcher'"`
  Pop $0
  IfFileExists "${EXE}" downloaded
    MessageBox MB_ICONSTOP "The launcher couldn't be downloaded. Check your internet connection and run the installer again."
    Abort
  downloaded:
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateShortcut "$SMPROGRAMS\${NAME}.lnk" "${EXE}" "" "${EXE}" 0
  CreateShortcut "$DESKTOP\${NAME}.lnk" "${EXE}" "" "${EXE}" 0
  WriteRegStr HKCU "Software\Void of Exile" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${NAME}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "${EXE}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "${PUBLISHER}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "URLInfoAbout" "https://void.plainshow.se"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
  ; Silent runs are the launcher updating itself: start it again when done.
  IfSilent 0 +2
    Exec '"${EXE}"'
SectionEnd

Section "Uninstall"
  nsExec::Exec 'taskkill /IM VoidOfExileLauncher.exe /F'
  Pop $0
  RMDir /r "$INSTDIR\Launcher"
  Delete "$SMPROGRAMS\${NAME}.lnk"
  Delete "$DESKTOP\${NAME}.lnk"
  IfSilent keep_game
  MessageBox MB_YESNO|MB_ICONQUESTION "Also remove the game and server files in $INSTDIR? Your characters are kept on your account either way." IDNO keep_game
    RMDir /r "$INSTDIR\Game"
    RMDir /r "$INSTDIR\Server"
  keep_game:
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  DeleteRegKey HKCU "Software\Void of Exile"
SectionEnd
