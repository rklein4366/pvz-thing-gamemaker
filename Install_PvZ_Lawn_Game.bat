@echo off
setlocal
set "PROJECT_DIR=%~dp0"
if not exist "%PROJECT_DIR%PvZ.yyp" (
  echo ERROR: PvZ.yyp was not found in this folder.
  echo Copy this BAT file and both Python installer files into your extracted PvZ_GM_Stage0 project root, next to PvZ.yyp.
  pause
  exit /b 2
)
where py >nul 2>nul
if %errorlevel%==0 (
  py -3 "%PROJECT_DIR%install_pvz_lawn_game.py" "%PROJECT_DIR%"
) else (
  python "%PROJECT_DIR%install_pvz_lawn_game.py" "%PROJECT_DIR%"
)
if not %errorlevel%==0 (
  echo.
  echo Installer failed. Read the error above before running the game.
  pause
  exit /b 1
)
echo.
echo Finished. Open PvZ.yyp in GameMaker and press F5.
pause
