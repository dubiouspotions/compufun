@echo off
setlocal enabledelayedexpansion
rem Pulls the latest main, imports the project and starts the game.
rem Godot (MIN_GODOT or newer, mono builds too): %GODOT%, else the path saved in godot-path.txt,
rem else a search, else it asks.
set "MIN_GODOT=40702"
set "MIN_NAME=4.7.2"
cd /d "%~dp0"

where git >nul 2>&1 || (set "MSG=Git is not installed: https://git-scm.com" & goto fail)
git lfs version >nul 2>&1 || (set "MSG=Git LFS is not installed: https://git-lfs.com, then run: git lfs install" & goto fail)
for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD') do set "BRANCH=%%b"
if not "!BRANCH!"=="main" (set "MSG=You are on the branch '!BRANCH!', not main. Switch to main first." & goto fail)
echo Pulling the latest main...
git pull --rebase --autostash || (set "MSG=git pull failed, see above." & goto fail)

if not defined GODOT if exist godot-path.txt set /p GODOT=<godot-path.txt
if not defined GODOT (
	for %%d in ("%USERPROFILE%\Desktop" "%USERPROFILE%\Downloads" "%ProgramFiles%\Godot" "%LOCALAPPDATA%\Programs\Godot" "%USERPROFILE%\Godot") do (
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
	echo Cannot find Godot %MIN_NAME% or newer. Drag its Godot_v..._win64.exe into this window and press Enter:
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

echo Importing...
"!CONSOLE!" --headless --path Godot --import
if errorlevel 1 (set "MSG=The Godot import failed, see above." & goto fail)
start "" "!GODOT!" --path Godot
exit /b 0

rem Sets GV to the version of the Godot console program %1 as a number: 4.7.2 is 40702, 0 if unknown.
:version
set "GV=0"
set "VA=" & set "VB=" & set "VC="
for /f "delims=" %%v in ('"%~1" --version 2^>nul') do set "VERSION_TEXT=%%v"
for /f "tokens=1-3 delims=." %%a in ("!VERSION_TEXT!") do (set "VA=%%a" & set "VB=%%b" & set "VC=%%c")
set /a "VA=VA, VB=VB, VC=VC" 2>nul
set /a "GV=VA*10000 + VB*100 + VC" 2>nul
exit /b 0

:fail
echo.
echo ERROR: !MSG!
pause
exit /b 1
