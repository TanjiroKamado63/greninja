@echo off
setlocal EnableExtensions DisableDelayedExpansion
title STUDENT QUESTION LIBRARY - GRENINJA
color 0A
set "OWNER=TanjiroKamado63"
set "REPO=greninja"
set "BRANCH=main"
set "WORK=%LOCALAPPDATA%\StudentQuestionLibrary"
set "INDEX=%WORK%\pdf_index.txt"
set "JSON=%WORK%\github_tree.json"
set "PDFDIR=%WORK%\PDFs"
set "RESULTS=%WORK%\results.txt"
if not exist "%WORK%" mkdir "%WORK%"
if not exist "%PDFDIR%" mkdir "%PDFDIR%"
if not exist "%INDEX%" call :refresh
:menu
cls
echo ========================================================
echo                STUDENT QUESTION LIBRARY
echo ========================================================
echo   GitHub: %OWNER%/%REPO%
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
if "%choice%"=="4" goto update
if "%choice%"=="0" exit /b 0
echo Invalid option.
pause
goto menu
:update
call :refresh
pause
goto menu
:refresh
echo Loading PDF list from GitHub...
curl.exe -fsSL --retry 2 -H "User-Agent: StudentQuestionLibrary" "https://api.github.com/repos/%OWNER%/%REPO%/git/trees/%BRANCH%?recursive=1" -o "%JSON%"
if errorlevel 1 (
 echo ERROR: GitHub request failed.
 exit /b 1
)
powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; $j=Get-Content -LiteralPath '%JSON%' -Raw | ConvertFrom-Json; if(-not $j.tree){throw 'No GitHub tree returned'}; if($j.truncated){Write-Host 'WARNING: Incomplete GitHub tree'}; @($j.tree | Where-Object { $_.type -eq 'blob' -and $_.path -match '\.pdf$' } | ForEach-Object { $_.path }) | Set-Content -LiteralPath '%INDEX%' -Encoding UTF8"
if errorlevel 1 (
 echo ERROR: Could not parse GitHub file list.
 exit /b 1
)
for /f %%C in ('find /c /v "" ^< "%INDEX%"') do set "COUNT=%%C"
echo Found %COUNT% PDF files.
exit /b 0
:search
cls
echo ================= SEARCH QUESTION =================
set "term="
set /p "term=Enter keyword or PDF filename: "
if not defined term goto menu
goto filter
:subject
cls
echo ================= SEARCH SUBJECT =================
set "term="
set /p "term=Enter folder or subject keyword: "
if not defined term goto menu
goto filter
:filter
if not exist "%INDEX%" (
 echo No PDF index. Refresh the library first.
 pause
 goto menu
)
set "SEARCH_TERM=%term%"
powershell.exe -NoProfile -Command "$q=$env:SEARCH_TERM; Get-Content -LiteralPath '%INDEX%' -Encoding UTF8 | Where-Object { $_.IndexOf($q,[StringComparison]::OrdinalIgnoreCase) -ge 0 } | Set-Content -LiteralPath '%RESULTS%' -Encoding UTF8"
if errorlevel 1 goto failed
goto show
:browse
cls
echo ================= ALL PDF FILES =================
if not exist "%INDEX%" (
 echo No PDF index. Refresh the library first.
 pause
 goto menu
)
copy /y "%INDEX%" "%RESULTS%" >nul
goto show
:show
set "N=0"
for /f "usebackq delims=" %%F in ("%RESULTS%") do call :printitem "%%F"
if "%N%"=="0" (
 echo No matching PDFs found. Search matches filenames and folders only.
