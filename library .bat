@echo off
setlocal EnableExtensions DisableDelayedExpansion
title STUDENT QUESTION LIBRARY
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
echo ========================================================
echo                STUDENT QUESTION LIBRARY
echo ========================================================
echo.
echo    [1] Search questions by keywords
echo    [2] Browse all PDF files
echo    [3] Search by subject or topic
echo    [4] Refresh PDF list
echo    [0] Exit
echo.
echo ========================================================
set "choice="
set /p "choice=Choose an option: "
if "%choice%"=="1" goto search
if "%choice%"=="2" goto browse
if "%choice%"=="3" goto subject
if "%choice%"=="4" goto update
if "%choice%"=="0" exit /b 0
goto menu
:update
call :refresh
pause
goto menu
:refresh
echo.
echo Loading PDF list...
curl.exe -fLsS --retry 2 -H "User-Agent: StudentQuestionLibrary" "https://api.github.com/repos/%OWNER%/%REPO%/git/trees/%BRANCH%?recursive=1" -o "%JSON%"
if errorlevel 1 (
 echo ERROR: Could not download the file list.
 exit /b 1
)
powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; $j=Get-Content -LiteralPath $env:JSON -Raw | ConvertFrom-Json; if(-not $j.tree){throw 'No file tree in GitHub response'}; if($j.truncated){Write-Host 'Warning: file list may be incomplete'}; @($j.tree | Where-Object { $_.type -eq 'blob' -and $_.path -match '\.pdf$' } | ForEach-Object { $_.path }) | Set-Content -LiteralPath $env:INDEX -Encoding Default"
if errorlevel 1 (
 echo ERROR: Cannot parse the file list.
 exit /b 1
)
for /f %%C in ('find /c /v "" ^< "%INDEX%"') do set "COUNT=%%C"
echo Found %COUNT% PDF files.
exit /b 0
:search
cls
echo ================= SEARCH QUESTIONS =================
echo Type a few words, e.g. factorial API
set "term="
set /p "term=Search: "
if not defined term goto menu
call :filter
if errorlevel 1 goto menu
set "PAGE=1"
goto showpage
:subject
cls
echo ================= SEARCH SUBJECT =================
set "term="
set /p "term=Subject or topic: "
if not defined term goto menu
call :filter
if errorlevel 1 goto menu
set "PAGE=1"
goto showpage
:filter
if not exist "%INDEX%" (
 echo No PDF list found. Refresh first.
 pause
 exit /b 1
)
powershell.exe -NoProfile -Command "$words=@($env:term -split '\s+' | Where-Object { $_ }); $paths=@(Get-Content -LiteralPath $env:INDEX); $matches=@($paths | Where-Object { $name=($_ -replace '[_-]',' '); $ok=$true; foreach($w in $words){if($name.IndexOf($w,[StringComparison]::OrdinalIgnoreCase) -lt 0){$ok=$false;break}}; $ok }); $matches | Set-Content -LiteralPath $env:RESULTS -Encoding Default"
if errorlevel 1 (
 echo Search failed.
 pause
 exit /b 1
)
exit /b 0
:browse
if not exist "%INDEX%" (
 echo No PDF list found. Refresh first.
 pause
 goto menu
)
