@echo off
rem Imports every model and sound from Content\ImportSource into the project (one time, a few minutes).
rem Close the Unreal Editor first. Change UE if your engine is installed somewhere else.
set UE=C:\Program Files\Epic Games\UE_5.6
set PROJ=%~dp0DarkSouls\DarkSouls.uproject
set SCRIPT=%~dp0tools\import_assets.py

if not exist "%UE%\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" (
  echo Engine not found at %UE%  - edit the UE line at the top of this file.
  pause
  exit /b 1
)

"%UE%\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" "%PROJ%" -run=pythonscript -script="%SCRIPT%" -unattended -nosplash
echo.
echo Done. Open DarkSouls.uproject and press Play.
pause
