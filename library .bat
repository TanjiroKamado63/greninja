@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title STUDENT QUESTION LIBRARY
color 0A
set "OWNER=TanjiroKamado63"
set "REPO=greninja"
set "BRANCH=main"
set "WORK=%LOCALAPPDATA%\StudentQuestionLibrary"
set "INDEX=%WORK%\index.txt"
set "PDFDIR=%WORK%\PDFs"
if not exist "%PDFDIR%" mkdir "%PDFDIR%"

:menu
cls
echo ======================================================
echo                 STUDENT QUESTION LIBRARY
echo ======================================================
echo  GitHub: %OWNER%/%REPO%
echo.
echo  [1] Search PDF by question keyword / filename
echo  [2] Browse all PDFs
echo  [3] Search by subject / folder
echo  [4] Refresh list from GitHub
echo  [0] Exit
echo ======================================================
set "opt="
set /p "opt=Enter choice: "
if "%opt%"=="0" exit /b 0
if "%opt%"=="4" goto refresh
if not exist "%INDEX%" call :fetch
if not exist "%INDEX%" (echo Unable to load PDF list.& pause& goto menu)
if "%opt%"=="1" goto search
if "%opt%"=="2" goto browse
if "%opt%"=="3" goto search
goto menu

:refresh
if exist "%INDEX%" del /q "%INDEX%"
call :fetch
pause
goto menu

:fetch
echo.
echo Loading PDF list from GitHub...
set "API=https://api.github.com/repos/%OWNER%/%REPO%/git/trees/%BRANCH%?recursive=1"
curl.exe -fsSL --max-time 30 -H "User-Agent: StudentQuestionLibrary" -o "%WORK%\tree.json" "%API%"
if errorlevel 1 (echo ERROR: Could not connect to GitHub.& exit /b 1)
powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; $j=Get-Content -Raw -LiteralPath '%WORK%\tree.json' | ConvertFrom-Json; if($j.truncated){throw 'GitHub tree truncated'}; $lines=@($j.tree | Where-Object { $_.type -eq 'blob' -and $_.path -match '\.pdf$' } | ForEach-Object { $p=$_.path; $u='https://raw.githubusercontent.com/%OWNER%/%REPO%/%BRANCH%/' + ((($p -split '/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'); $p + '|' + $u }); [IO.File]::WriteAllLines('%INDEX%', [string[]]$lines, (New-Object System.Text.UTF8Encoding($false)))"
if errorlevel 1 (
  echo ERROR: Could not build PDF index.
  if exist "%INDEX%" del /q "%INDEX%"
  exit /b 1
)
echo PDF list ready.
exit /b 0

:search
cls
echo ================= SEARCH PDFs =================
set "term="
set /p "term=Enter question keyword or subject: "
if not defined term goto menu
set "RESULTS=%WORK%\results.txt"
findstr /i /l /c:"!term!" "%INDEX%" > "%RESULTS%"
goto show

:browse
copy /y "%INDEX%" "%WORK%\results.txt" >nul
set "RESULTS=%WORK%\results.txt"
goto show

:show
cls
echo ================= MATCHING PDFs =================
set /a n=0
for /f "usebackq tokens=1 delims=|" %%A in ("%RESULTS%") do (
  set /a n+=1
  echo  [!n!] %%A
)
if !n! EQU 0 (echo No matching PDF found.& pause& goto menu)
echo.
echo  [0] Back to main menu
echo ==================================================
set "pick="
set /p "pick=Enter PDF number: "
if "!pick!"=="0" goto menu
set "valid="
for /l %%N in (1,1,!n!) do if "!pick!"=="%%N" set "valid=1"
if not defined valid (echo Invalid number.& pause& goto show)
set /a row=0
set "URL="
set "FILENAME="
for /f "usebackq tokens=1,2 delims=|" %%A in ("%RESULTS%") do (
  set /a row+=1
  if !row! EQU !pick! (
    set "FILENAME=%%~nxA"
    set "URL=%%B"
  )
)
if not defined URL (echo PDF not found.& pause& goto menu)
set "TARGET=%PDFDIR%\!pick!_!FILENAME!"
echo Downloading !FILENAME! ...
curl.exe -fLsS --max-time 120 -o "!TARGET!" "!URL!"
if errorlevel 1 (echo Download failed.& pause& goto menu)
start "" "!TARGET!"
echo PDF opened in your default viewer.
pause
goto menu
