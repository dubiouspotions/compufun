@echo off
setlocal enabledelayedexpansion
rem Pulls the latest main, imports the project and starts the game.
rem Godot: %GODOT%, else the path saved in godot-path.txt, else a search, else it asks.
set "VERSION=4.7"
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
		if not defined GODOT if exist "%%~d" for /f "delims=" %%f in ('dir /b /s "%%~d\Godot_v%VERSION%*_win64.exe" 2^>nul') do if not defined GODOT set "GODOT=%%f"
	)
)
if not defined GODOT (
	echo Cannot find Godot %VERSION%. Drag its Godot_v%VERSION%..._win64.exe into this window and press Enter:
	set /p "GODOT="
)
if not defined GODOT (set "MSG=No Godot given." & goto fail)
set "GODOT=!GODOT:"=!"
if not exist "!GODOT!" (set "MSG=Godot is not at: !GODOT!" & goto fail)
>godot-path.txt echo !GODOT!

echo Importing...
set "IMPORTER=!GODOT:.exe=_console.exe!"
if not exist "!IMPORTER!" set "IMPORTER=!GODOT!"
"!IMPORTER!" --headless --path Godot --import
if errorlevel 1 (set "MSG=The Godot import failed, see above." & goto fail)
start "" "!GODOT!" --path Godot
exit /b 0

:fail
echo.
echo ERROR: !MSG!
pause
exit /b 1
