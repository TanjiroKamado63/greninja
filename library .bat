@echo off
setlocal EnableExtensions EnableDelayedExpansion
title STUDENT QUESTION LIBRARY - GRENINJA
color 0A
set "OWNER=TanjiroKamado63"
set "REPO=greninja"
set "BRANCH=main"
set "WORK=%LOCALAPPDATA%\StudentQuestionLibrary"
set "INDEX=%WORK%\pdf_index.txt"
set "RESULTS=%WORK%\results.txt"
set "JSON=%WORK%\github_tree.json"
set "PDFDIR=%WORK%\PDFs"
if not exist "%WORK%" mkdir "%WORK%"
if not exist "%PDFDIR%" mkdir "%PDFDIR%"
if not exist "%INDEX%" call :refresh
:menu
cls
echo ============================================================
echo                  STUDENT QUESTION LIBRARY
echo ============================================================
echo   Search question words, not just exact PDF filenames.
echo.
echo   [1] Search questions / keywords
echo   [2] Browse all PDFs
echo   [3] Search by subject or topic
echo   [4] Refresh from GitHub
echo   [0] Exit
echo ============================================================
set "choice="
set /p "choice=Enter choice: "
if "%choice%"=="1" goto search
if "%choice%"=="2" goto browse
if "%choice%"=="3" goto search
if "%choice%"=="4" (call :refresh & pause & goto menu)
if "%choice%"=="0" exit /b 0
goto menu
:refresh
echo Loading PDF list from GitHub...
curl.exe -fLsS --retry 2 "https://api.github.com/repos/%OWNER%/%REPO%/git/trees/%BRANCH%?recursive=1" -o "%JSON%"
if errorlevel 1 (echo ERROR: Could not download GitHub file list.& exit /b 1)
powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; $j=Get-Content -LiteralPath $env:JSON -Raw | ConvertFrom-Json; if(-not $j.tree){throw 'No GitHub tree returned'}; @($j.tree | Where-Object { $_.type -eq 'blob' -and $_.path -match '(?i)\.pdf$' } | ForEach-Object { $_.path }) | Set-Content -LiteralPath $env:INDEX -Encoding Default"
if errorlevel 1 (echo ERROR: Could not parse GitHub PDF list.& exit /b 1)
for /f %%C in ('find /c /v "" ^< "%INDEX%"') do set "COUNT=%%C"
echo Found !COUNT! PDF files.
exit /b 0
:search
cls
echo ================== SEARCH QUESTIONS ==================
echo Example: inheritance, factorial, registration, PWA
set "term="
set /p "term=Enter question words: "
if not defined term goto menu
if not exist "%INDEX%" (echo No PDF list. Refresh first.& pause & goto menu)
rem Convert each search word into a separate match; any word can match.
rem For multiple words, show matches containing ALL entered words.
powershell.exe -NoProfile -Command "$words=($env:term -split '\s+' | Where-Object { $_ }); $files=Get-Content -LiteralPath $env:INDEX; @($files | Where-Object { $name=($_ -replace '_',' '); $ok=$true; foreach($w in $words){if($name.IndexOf($w,[StringComparison]::OrdinalIgnoreCase) -lt 0){$ok=$false;break}}; $ok }) | Set-Content -LiteralPath $env:RESULTS -Encoding Default"
if errorlevel 1 (echo Search failed.& pause & goto menu)
goto showresults
:browse
if not exist "%INDEX%" (echo No PDF list. Refresh first.& pause & goto menu)
copy /y "%INDEX%" "%RESULTS%" >nul
goto showresults
:showresults
cls
echo =================== MATCHING PDFs ===================
set /a n=0
for /f "usebackq delims=" %%F in ("%RESULTS%") do (
 set /a n+=1
 set "label=%%~nF"
 echo   [!n!] %%~nF
)
echo -----------------------------------------------------
if !n! EQU 0 (echo No matches. Try fewer or different words.& pause & goto menu)
echo Found !n! PDFs.
echo Enter 0 to return to the menu.
set "pick="
set /p "pick=PDF number: "
if "!pick!"=="0" goto menu
set "valid="
for /l %%N in (1,1,!n!) do if "!pick!"=="%%N" set "valid=1"
if not defined valid (echo Invalid number.& pause & goto showresults)
set "selected="
set /a line=0
for /f "usebackq delims=" %%F in ("%RESULTS%") do (
 set /a line+=1
 if !line! EQU !pick! set "selected=%%F"
)
if not defined selected (echo Selection failed.& pause & goto menu)
for %%F in ("!selected!") do set "filename=%%~nxF"
echo.
echo Downloading !filename! ...
rem GitHub filenames in this repository use URL-safe ASCII names.
curl.exe -fLsS --retry 2 -o "%PDFDIR%\!filename!" "https://raw.githubusercontent.com/%OWNER%/%REPO%/%BRANCH%/!selected!"
if errorlevel 1 (echo Download failed. Check repository and filename.& pause & goto menu)
start "" "%PDFDIR%\!filename!"
echo PDF opened in your default viewer.
pause
goto menu
