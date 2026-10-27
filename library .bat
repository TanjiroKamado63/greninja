@echo off
setlocal EnableExtensions DisableDelayedExpansion
title STUDENT QUESTION LIBRARY - GRENINJA
color 0A

rem GitHub repository configuration
set "OWNER=TanjiroKamado63"
set "REPO=greninja"
set "BRANCH=main"
set "WORK=%LOCALAPPDATA%\StudentQuestionLibrary"
set "INDEX=%WORK%\pdf_index.txt"
set "JSON=%WORK%\github_tree.json"
set "PDFDIR=%WORK%\PDFs"
if not exist "%WORK%" mkdir "%WORK%"
if not exist "%PDFDIR%" mkdir "%PDFDIR%"

if not exist "%INDEX%" call :refresh

:menu
cls
echo ========================================================
echo                 STUDENT QUESTION LIBRARY
echo ========================================================
echo   Repository: %OWNER%/%REPO%
echo.
echo   [1] Search PDF by keyword or filename
echo   [2] Browse all PDF files
echo   [3] Search by subject or folder
echo   [4] Refresh list from GitHub
echo   [0] Exit
echo ========================================================
set "choice="
set /p "choice=Enter your choice: "
if "%choice%"=="1" goto search
if "%choice%"=="2" goto browse
if "%choice%"=="3" goto subject
if "%choice%"=="4" (call :refresh & pause & goto menu)
if "%choice%"=="0" exit /b 0
echo Invalid option.
pause
goto menu

:refresh
echo.
echo Loading PDF list from GitHub...
curl.exe -fsSL --retry 2 "https://api.github.com/repos/%OWNER%/%REPO%/git/trees/%BRANCH%?recursive=1" -o "%JSON%"
if errorlevel 1 (
  echo ERROR: GitHub could not be reached. Check internet and repository visibility.
  exit /b 1
)
powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; $j=Get-Content -LiteralPath $env:JSON -Raw | ConvertFrom-Json; if($j.truncated){Write-Host 'WARNING: GitHub returned an incomplete file list'}; $i=0; @($j.tree | Where-Object { $_.type -eq 'blob' -and $_.path -match '\.pdf$' } | ForEach-Object { $i++; '{0}|{1}' -f $i,$_.path }) | Set-Content -LiteralPath $env:INDEX -Encoding Default"
if errorlevel 1 (
  echo ERROR: Could not read GitHub PDF list.
  exit /b 1
)
for /f %%C in ('find /c /v "" ^< "%INDEX%"') do set "COUNT=%%C"
echo Found %COUNT% PDF files.
exit /b 0

:search
cls
echo ================= SEARCH PDFs =================
set "term="
set /p "term=Enter question keyword or filename: "
if not defined term goto menu
call :results
if errorlevel 1 goto menu
goto choose

:subject
cls
echo ================ SEARCH SUBJECT ================
set "term="
set /p "term=Enter subject or folder name: "
if not defined term goto menu
call :results
if errorlevel 1 goto menu
goto choose

:results
if not exist "%INDEX%" (echo No index available. Select Refresh first. & pause & exit /b 1)
echo.
echo Matching PDF files:
findstr /i /l /c:"%term%" "%INDEX%"
if errorlevel 1 (
  echo No matching filenames or folders found.
  echo Note: Search does not read text inside PDFs.
  pause
  exit /b 1
)
exit /b 0

:browse
cls
echo ================= ALL PDF FILES =================
if not exist "%INDEX%" (echo No index available. & pause & goto menu)
