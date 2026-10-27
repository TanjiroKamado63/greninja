@echo off
setlocal EnableExtensions EnableDelayedExpansion
title STUDENT QUESTION LIBRARY
color 0A
mode con: cols=76 lines=35 >nul 2>&1
set "OWNER=TanjiroKamado63"
set "REPO=greninja"
set "BRANCH=main"
set "WORK=%LOCALAPPDATA%\StudentQuestionLibrary"
set "INDEX=%WORK%\pdf_index.txt"
set "RESULTS=%WORK%\results.txt"
set "JSON=%WORK%\github_tree.json"
set "PDFDIR=%WORK%\PDFs"
set "PAGE_SIZE=10"
if not exist "%WORK%" mkdir "%WORK%"
if not exist "%PDFDIR%" mkdir "%PDFDIR%"
if not exist "%INDEX%" call :refresh

:menu
cls
call :header
echo.
echo   [1] Search Question Words
echo   [2] Browse All PDFs
echo   [3] Search by Subject
echo   [4] Refresh PDF List
echo   [0] Exit
echo.
echo ============================================================
echo.
set "choice="
set /p "choice=Choose an option: "
if "%choice%"=="1" goto search
if "%choice%"=="2" goto browse
if "%choice%"=="3" goto subject
if "%choice%"=="4" goto update
if "%choice%"=="0" exit /b 0
goto menu

:header
echo ============================================================
echo.
echo                  STUDENT QUESTION LIBRARY
echo.
echo ============================================================
exit /b 0

:update
call :refresh
pause
goto menu

:refresh
echo.
echo Loading PDF list...
curl.exe -fLsS --retry 2 -H "User-Agent: StudentQuestionLibrary" "https://api.github.com/repos/%OWNER%/%REPO%/git/trees/%BRANCH%?recursive=1" -o "%JSON%"
if errorlevel 1 (echo ERROR: Unable to retrieve PDF list. & exit /b 1)
powershell.exe -NoProfile -Command "try { $j=Get-Content -LiteralPath $env:JSON -Raw | ConvertFrom-Json; if(-not $j.tree){throw 'Missing file tree'}; $p=@($j.tree | Where-Object { $_.type -eq 'blob' -and $_.path -match '\.pdf$' } | ForEach-Object { $_.path }); [IO.File]::WriteAllLines($env:INDEX,[string[]]$p); Write-Host ('Found {0} PDF files.' -f $p.Count) } catch {Write-Host $_.Exception.Message; exit 1}"
if errorlevel 1 (echo ERROR: Unable to process PDF list. & exit /b 1)
exit /b 0

:search
cls
call :header
echo.
echo Type words from the PDF filename, e.g. factorial API
echo.
set "term="
set /p "term=Search: "
if not defined term goto menu
call :filter
if errorlevel 1 (pause & goto menu)
set /a page=1
goto showpage

:subject
cls
call :header
echo.
echo Enter subject, folder or topic words.
echo.
set "term="
set /p "term=Subject: "
if not defined term goto menu
call :filter
if errorlevel 1 (pause & goto menu)
set /a page=1
goto showpage

:filter
if not exist "%INDEX%" (echo No PDF list found. Choose Refresh PDF List. & exit /b 1)
powershell.exe -NoProfile -Command "try { $w=@($env:term -split '\s+' | Where-Object { $_ }); $r=@(Get-Content -LiteralPath $env:INDEX | Where-Object { $name=($_ -replace '[_\-]',' '); $ok=$true; foreach($x in $w){if($name.IndexOf($x,[StringComparison]::OrdinalIgnoreCase) -lt 0){$ok=$false;break}}; $ok }); [IO.File]::WriteAllLines($env:RESULTS,[string[]]$r) } catch { Write-Host $_.Exception.Message; exit 1 }"
if errorlevel 1 (echo Search failed. & exit /b 1)
exit /b 0

:browse
