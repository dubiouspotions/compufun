@echo off
setlocal enabledelayedexpansion
rem Pulls the latest main, imports the project and starts the game.
rem Git: on the PATH, else GitHub Desktop's (it has LFS), else it offers to install Git with winget.
rem Godot (MIN_GODOT or newer, mono builds too): %GODOT%, else the path saved in godot-path.txt,
rem else a search, else it offers to download GODOT_DOWNLOAD, else it asks for the path.
rem The live voice (ChimeraVoice): VOICE_URL, when it is missing or native/chimera_voice changed.
set "MIN_GODOT=40702"
set "MIN_NAME=4.7.2"
set "GODOT_DOWNLOAD=4.7.2"
set "GODOT_HOME=%LOCALAPPDATA%\Programs\Godot"
set "VOICE_URL=https://github.com/dubiouspotions/compufun/releases/download/live-voice/live-voice-windows.zip"
cd /d "%~dp0"

rem Stop the game if it runs (from this launcher or the editor), but not the editor itself.
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $c = ([string]$_.CommandLine).Replace('\','/'); $_.Name -like 'Godot*' -and ($c -like '*--path Godot*' -or $c -like '*%CD:\=/%/Godot*') -and $c -notmatch ' (-e|--editor)( |$)' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"

where git >nul 2>&1 || (
	for /f "delims=" %%d in ('dir /b /ad /o:n "%LOCALAPPDATA%\GitHubDesktop\app-*" 2^>nul') do set "DESKTOP_GIT=%LOCALAPPDATA%\GitHubDesktop\%%d\resources\app\git\cmd"
	if defined DESKTOP_GIT set "PATH=!DESKTOP_GIT!;!PATH!"
)
where git >nul 2>&1 || (
	where winget >nul 2>&1 || (set "MSG=Git is missing. Install GitHub Desktop: https://desktop.github.com" & goto fail)
	choice /c YN /m "Git is missing. Install it with winget"
	if errorlevel 2 (set "MSG=Git is missing. Install GitHub Desktop: https://desktop.github.com" & goto fail)
	winget install --id Git.Git -e --source winget --accept-package-agreements || (set "MSG=winget could not install Git, see above." & goto fail)
	set "PATH=%ProgramFiles%\Git\cmd;!PATH!"
)
where git >nul 2>&1 || (set "MSG=Git is still not found. Close this window and try again." & goto fail)
git lfs version >nul 2>&1 || (set "MSG=Git LFS is missing: https://git-lfs.com" & goto fail)
git lfs install --local --skip-repo >nul || (set "MSG=Cannot set up Git LFS in %CD%." & goto fail)

rem A pull that stopped half-way (a rebase, a merge, a stash that clashed) blocks the next one: undo it,
rem and stash its unmerged files as they are, conflict markers and all.
for %%o in (rebase merge cherry-pick) do git %%o --abort >nul 2>&1
git diff --name-only --diff-filter=U >"%TEMP%\humanerror-unmerged.txt" || (set "MSG=Cannot list the unmerged files, see above." & goto fail)
for %%z in ("%TEMP%\humanerror-unmerged.txt") do if %%~zz gtr 0 git add --pathspec-from-file="%TEMP%\humanerror-unmerged.txt" || (set "MSG=Cannot take up the unmerged files, see above." & goto fail)
del "%TEMP%\humanerror-unmerged.txt"

for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD') do set "BRANCH=%%b"
if not "!BRANCH!"=="main" (set "MSG=You are on the branch '!BRANCH!', not main. Switch to main first." & goto fail)
rem Local changes, untracked files too, go to the stash and stay there, so the game is always main.
set "DIRTY="
for /f "delims=" %%s in ('git status --porcelain') do set "DIRTY=1"
if defined DIRTY (
	git stash push --include-untracked -m "Play HumanError %DATE% %TIME%" || (set "MSG=Cannot stash the local changes, see above." & goto fail)
	echo Your local changes are in the git stash: git stash pop brings them back.
)
echo Pulling the latest main...
git pull --rebase || (
	git rebase --abort >nul 2>&1
	set "MSG=git pull failed, see above, and the checkout is back as it was. A local commit that clashes with main needs a developer."
	goto fail
)

if not defined GODOT if exist godot-path.txt set /p GODOT=<godot-path.txt
if not defined GODOT (
	for %%d in ("%USERPROFILE%\Desktop" "%USERPROFILE%\Downloads" "%ProgramFiles%\Godot" "%GODOT_HOME%" "%USERPROFILE%\Godot") do (
		if not defined GODOT if exist "%%~d" for /f "delims=" %%f in ('dir /b /s "%%~d\Godot_v4*_win64_console.exe" 2^>nul') do (
			if not defined GODOT (
				call :version "%%f"
				if !GV! geq %MIN_GODOT% set "GODOT=%%f"
			)
		)
	)
	if defined GODOT set "GODOT=!GODOT:_console.exe=.exe!"
)
if not defined GODOT (
	choice /c YN /m "Cannot find Godot %MIN_NAME% or newer. Download Godot %GODOT_DOWNLOAD% (86 MB) into %GODOT_HOME%"
	if not errorlevel 2 call :download
)
if not defined GODOT (
	echo Drag your Godot_v..._win64.exe into this window and press Enter:
	set /p "GODOT="
)
if not defined GODOT (set "MSG=No Godot given." & goto fail)
set "GODOT=!GODOT:"=!"
if not exist "!GODOT!" (set "MSG=Godot is not at: !GODOT!" & goto fail)
set "CONSOLE=!GODOT:.exe=_console.exe!"
if not exist "!CONSOLE!" (set "MSG=Cannot find !CONSOLE!, which comes in the Godot zip next to the editor." & goto fail)
call :version "!CONSOLE!"
if !GV! lss %MIN_GODOT% (set "MSG=!GODOT! is too old: this project needs Godot %MIN_NAME% or newer." & goto fail)
>godot-path.txt echo !GODOT!

call :voice

echo Importing...
"!CONSOLE!" --headless --path Godot --import
if errorlevel 1 (set "MSG=The Godot import failed, see above." & goto fail)
start "" "!GODOT!" --path Godot
exit /b 0

rem Sets GV to the version of the Godot console program %1 as a number: 4.7.2 is 40702, 0 if unknown.
:version
set "GV=0"
set "VA=" & set "VB=" & set "VC=" & set "VERSION_TEXT="
for /f "delims=" %%v in ('"%~1" --version 2^>nul') do set "VERSION_TEXT=%%v"
for /f "tokens=1-3 delims=." %%a in ("!VERSION_TEXT!") do (set "VA=%%a" & set "VB=%%b" & set "VC=%%c")
set /a "VA=VA, VB=VB, VC=VC" 2>nul
set /a "GV=VA*10000 + VB*100 + VC" 2>nul
exit /b 0

rem Downloads Godot GODOT_DOWNLOAD into GODOT_HOME and sets GODOT; on failure GODOT stays unset.
:download
set "ZIP=%TEMP%\Godot_v%GODOT_DOWNLOAD%-stable_win64.exe.zip"
echo Downloading Godot %GODOT_DOWNLOAD%...
curl.exe -fL -o "!ZIP!" "https://github.com/godotengine/godot/releases/download/%GODOT_DOWNLOAD%-stable/Godot_v%GODOT_DOWNLOAD%-stable_win64.exe.zip" || (echo ERROR: the download failed, see above. & exit /b 1)
if not exist "%GODOT_HOME%" mkdir "%GODOT_HOME%" || (echo ERROR: cannot make %GODOT_HOME%. & exit /b 1)
tar -xf "!ZIP!" -C "%GODOT_HOME%" || (echo ERROR: cannot unzip !ZIP!. & exit /b 1)
del "!ZIP!"
set "GODOT=%GODOT_HOME%\Godot_v%GODOT_DOWNLOAD%-stable_win64.exe"
exit /b 0

rem Downloads the live voice unless voice-source.txt says it was built from this native/chimera_voice.
rem A failure is shown, and the game then starts with the voice it has.
:voice
set "LIVE=Godot\voices\live"
set "WANT=" & set "HAVE="
for /f %%h in ('git rev-parse HEAD:native/chimera_voice') do set "WANT=%%h"
if not defined WANT (set "VOICE_MSG=git cannot tell which native/chimera_voice this is, see above." & goto voice_fail)
if exist "%LIVE%\voice-source.txt" set /p HAVE=<"%LIVE%\voice-source.txt"
if "!HAVE!"=="!WANT!" exit /b 0
echo Downloading the live voice...
set "VOICE_ZIP=%TEMP%\live-voice-windows.zip"
curl.exe -fsSL -o "!VOICE_ZIP!" "%VOICE_URL%" || (set "VOICE_MSG=the download of %VOICE_URL% failed, see above." & goto voice_fail)
rem Windows' own tar: Git's, if it is on the PATH, reads no zip.
"%SystemRoot%\System32\tar.exe" -xf "!VOICE_ZIP!" -C "%LIVE%" || (set "VOICE_MSG=cannot unzip it into %LIVE%. If the Godot editor is open, close it: it holds the voice library." & goto voice_fail)
del "!VOICE_ZIP!"
set "HAVE="
set /p HAVE=<"%LIVE%\voice-source.txt"
if not "!HAVE!"=="!WANT!" (set "VOICE_MSG=the one on GitHub was built from another native/chimera_voice. CI uploads a new one after the push that changes it; try again once the godot-ci run is done." & goto voice_fail)
exit /b 0
:voice_fail
echo.
echo WARNING: no up-to-date live voice: !VOICE_MSG!
echo The game starts with the live voice it has, or else the rendered voices.
pause
exit /b 0

:fail
echo.
echo ERROR: !MSG!
pause
exit /b 1
