@echo off
setlocal
title Student Question Library

set "BASE=https://raw.githubusercontent.com/TanjiroKamado63/greninja/main"
set "DIR=%LOCALAPPDATA%\StudentQuestionLibrary"

if not exist "%DIR%" mkdir "%DIR%"

echo Starting Student Question Library...
echo Downloading search engine...

curl.exe -fLsS --retry 2 -o "%DIR%\search_engine.ps1" "%BASE%/search_engine.ps1"

if errorlevel 1 (
    echo Failed to download search engine.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%DIR%\search_engine.ps1"

if errorlevel 1 (
    echo Search engine stopped with an error.
    pause
)
