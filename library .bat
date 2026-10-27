@echo off
setlocal EnableExtensions EnableDelayedExpansion
title STUDENT QUESTION LIBRARY
color 0A

rem Configuration is already included. No editing needed.
set "OWNER=TanjiroKamado63"
set "REPO=greninja"
set "BRANCH=main"
set "WORK=%LOCALAPPDATA%\StudentQuestionLibrary"
set "INDEX=%WORK%\pdf_index.txt"
set "RESULTS=%WORK%\results.txt"
set "JSON=%WORK%\github_tree.json"
set "PDFDIR=%WORK%\PDFs"
set "PAGESIZE=10"
if not exist "%WORK%" mkdir "%WORK%"
if not exist "%PDFDIR%" mkdir "%PDFDIR%"
if not exist "%INDEX%" call :refresh

goto menu

:menu
cls
echo ============================================================
echo                   STUDENT QUESTION LIBRARY
echo ============================================================
echo.
echo     [1] Search question keywords
echo     [2] Browse all PDF files
echo     [3] Search subject or topic
echo     [4] Refresh PDF list
echo     [0] Exit
echo.
echo ============================================================
set "choice="
set /p "choice=Choose an option: "
if "%choice%"=="1" goto search
if "%choice%"=="2" goto browse
if "%choice%"=="3" goto search
if "%choice%"=="4" goto refreshmenu
if "%choice%"=="0" exit /b 0
goto menu

:refreshmenu
call :refresh
pause
goto menu

:refresh
echo.
echo Updating PDF list from GitHub...
curl.exe -fLsS --retry 2 --connect-timeout 15 -H "User-Agent: StudentQuestionLibrary" "https://api.github.com/repos/%OWNER%/%REPO%/git/trees/%BRANCH%?recursive=1" -o "%JSON%"
if errorlevel 1 (
 echo ERROR: Could not contact GitHub. Check your internet connection.
 exit /b 1
)
rem Batch SET variables are inherited by PowerShell as environment variables.
powershell.exe -NoProfile -NonInteractive -Command "try { $j=Get-Content -LiteralPath $env:JSON -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop; if(-not $j.tree){throw 'No files returned by GitHub'}; $a=@($j.tree | Where-Object { $_.type -eq 'blob' -and $_.path -match '\.pdf$' } | ForEach-Object { $_.path }); [System.IO.File]::WriteAllLines($env:INDEX,[string[]]$a,[System.Text.Encoding]::UTF8); Write-Host ('Loaded {0} PDF files.' -f $a.Count); if($j.truncated){Write-Host 'WARNING: GitHub returned a partial file list.'} } catch { Write-Host ('ERROR: ' + $_.Exception.Message); exit 1 }"
if errorlevel 1 (
 echo Could not update the index.
 exit /b 1
)
exit /b 0

:search
cls
echo =================== SEARCH QUESTIONS ===================
echo Type a few words from the question, e.g. factorial API
set "term="
set /p "term=Search: "
if not defined term goto menu
if not exist "%INDEX%" (
 echo No PDF list available. Refresh first.
 pause
 goto menu
)
rem Match ALL typed words anywhere in PDF filenames and folders.
powershell.exe -NoProfile -NonInteractive -Command "try { $words=@($env:term -split '\s+' | Where-Object { $_ }); $a=@(Get-Content -LiteralPath $env:INDEX -Encoding UTF8 | Where-Object { $s=($_ -replace '[_-]',' '); $ok=$true; foreach($w in $words){if($s.IndexOf($w,[StringComparison]::OrdinalIgnoreCase) -lt 0){$ok=$false;break}}; $ok }); [System.IO.File]::WriteAllLines($env:RESULTS,[string[]]$a,[System.Text.Encoding]::UTF8) } catch { Write-Host $_.Exception.Message; exit 1 }"
if errorlevel 1 (
 echo Search failed.
 pause
 goto menu
)
set /a PAGE=0
goto showpage

:browse
if not exist "%INDEX%" (
 echo No PDF list available. Refresh first.
 pause
 goto menu
)
copy /y "%INDEX%" "%RESULTS%" >nul
set /a PAGE=0
goto showpage
