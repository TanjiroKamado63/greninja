@echo off
setlocal EnableExtensions EnableDelayedExpansion
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
set "PAGE_SIZE=10"
if not exist "%WORK%" mkdir "%WORK%"
if not exist "%PDFDIR%" mkdir "%PDFDIR%"
if not exist "%INDEX%" call :refresh
:menu
cls
call :header
echo.
echo    [1] Search Question Words
echo    [2] Browse All PDFs
echo    [3] Search by Subject
echo    [4] Refresh PDF List
echo    [0] Exit
echo.
echo ============================================================
set "choice="
set /p "choice=Choose an option: "
if "!choice!"=="1" goto search
if "!choice!"=="2" goto browse
if "!choice!"=="3" goto subject
if "!choice!"=="4" (call :refresh & pause & goto menu)
if "!choice!"=="0" exit /b 0
goto menu
:header
echo ============================================================
echo                  STUDENT QUESTION LIBRARY
echo ============================================================
exit /b
:refresh
echo Loading PDF list from GitHub...
curl.exe -fLsS --retry 2 -H "User-Agent: StudentQuestionLibrary" "https://api.github.com/repos/%OWNER%/%REPO%/git/trees/%BRANCH%?recursive=1" -o "%JSON%"
if errorlevel 1 (echo ERROR: Could not retrieve file list. & exit /b 1)
powershell.exe -NoProfile -Command "try { $j=Get-Content -LiteralPath $env:JSON -Raw | ConvertFrom-Json; if(-not $j.tree){throw 'No file tree returned'}; $p=@($j.tree | Where-Object { $_.type -eq 'blob' -and $_.path -match '\.pdf$' } | ForEach-Object { $_.path }); [IO.File]::WriteAllLines($env:INDEX,[string[]]$p); Write-Host ('Found {0} PDF files.' -f $p.Count) } catch { Write-Host $_.Exception.Message; exit 1 }"
if errorlevel 1 (echo ERROR: Could not read file list. & exit /b 1)
exit /b 0
:search
cls
call :header
echo.
echo Type question words, e.g. factorial API
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
set "term="
set /p "term=Subject or topic: "
if not defined term goto menu
call :filter
if errorlevel 1 (pause & goto menu)
set /a page=1
goto showpage
:filter
if not exist "%INDEX%" (echo No index. Refresh the PDF list first. & exit /b 1)
powershell.exe -NoProfile -Command "$w=@($env:term -split '\s+' | Where-Object { $_ }); $r=@(Get-Content -LiteralPath $env:INDEX | Where-Object { $name=($_ -replace '[_-]',' '); $ok=$true; foreach($x in $w){if($name.IndexOf($x,[StringComparison]::OrdinalIgnoreCase) -lt 0){$ok=$false;break}}; $ok }); [IO.File]::WriteAllLines($env:RESULTS,[string[]]$r)"
if errorlevel 1 (echo Search failed. & exit /b 1)
exit /b 0
:browse
if not exist "%INDEX%" (echo No index. Refresh the PDF list first. & pause & goto menu)
copy /y "%INDEX%" "%RESULTS%" >nul
set /a page=1
goto showpage
:showpage
cls
call :header
echo.
echo ==================== SEARCH RESULTS ====================
if not exist "%RESULTS%" (echo No results available. & pause & goto menu)
set /a total=0
for /f "usebackq delims=" %%F in ("%RESULTS%") do set /a total+=1
if !total! EQU 0 (echo No matches. Try fewer keywords. & pause & goto menu)
set /a pages=(total+PAGE_SIZE-1)/PAGE_SIZE
if !page! GTR !pages! set /a page=pages
if !page! LSS 1 set /a page=1
set /a first=(page-1)*PAGE_SIZE+1
set /a last=page*PAGE_SIZE
if !last! GTR !total! set /a last=total
echo Total: !total!     Page: !page! of !pages!
