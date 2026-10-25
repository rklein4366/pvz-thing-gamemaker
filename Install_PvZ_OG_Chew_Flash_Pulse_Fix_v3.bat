@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply_PvZ_OG_Chew_Flash_Pulse_Fix_v3.ps1"
if errorlevel 1 (
  echo.
  echo Fix was not applied. Read the message above for the reason.
) else (
  echo.
  echo Press any key to close this window.
)
pause >nul
