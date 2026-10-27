@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title STUDENT QUESTION LIBRARY
color 0B
set "OWNER=TanjiroKamado63"
set "REPO=greninja"
set "BRANCH=main"
set "ROOT=%~dp0"
set "CACHE=%LOCALAPPDATA%\StudentQuestionLibrary"
if not exist "%CACHE%" mkdir "%CACHE%" >nul 2>&1
set "PSFILE=%CACHE%\library_engine.ps1"
>"%PSFILE%" echo # Student Question Library engine
>>"%PSFILE%" echo $ErrorActionPreference = 'Stop'
>>"%PSFILE%" echo $owner = '%OWNER%'; $repo = '%REPO%'; $branch = '%BRANCH%'
>>"%PSFILE%" echo $cache = Join-Path $env:LOCALAPPDATA 'StudentQuestionLibrary\PDFs'
>>"%PSFILE%" echo New-Item -ItemType Directory -Force -Path $cache ^| Out-Null
>>"%PSFILE%" echo function Pause-Lib { Read-Host 'Press Enter to continue' ^| Out-Null }
>>"%PSFILE%" echo function Banner { Clear-Host; Write-Host '============================================================' -ForegroundColor Cyan; Write-Host '                  STUDENT QUESTION LIBRARY' -ForegroundColor Green; Write-Host '============================================================' -ForegroundColor Cyan; Write-Host '' }
>>"%PSFILE%" echo function Load-Files {
>>"%PSFILE%" echo   $headers = @{ 'User-Agent' = 'StudentQuestionLibrary'; 'Accept' = 'application/vnd.github+json' }
>>"%PSFILE%" echo   $uri = "https://api.github.com/repos/$owner/$repo/git/trees/$branch`?recursive=1"
>>"%PSFILE%" echo   $tree = Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 30
>>"%PSFILE%" echo   if ($tree.truncated) { Write-Host 'Warning: GitHub returned a truncated file list.' -ForegroundColor Yellow }
>>"%PSFILE%" echo   return @($tree.tree ^| Where-Object { $_.type -eq 'blob' -and $_.path -match '(?i)\.pdf$' } ^| Sort-Object path)
>>"%PSFILE%" echo }
>>"%PSFILE%" echo function Open-Pdf($entry) {
>>"%PSFILE%" echo   $parts = $entry.path -split '/'; $encoded = ($parts ^| ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
>>"%PSFILE%" echo   $url = "https://raw.githubusercontent.com/$owner/$repo/$branch/$encoded"
>>"%PSFILE%" echo   $file = Join-Path $cache ($entry.sha + '.pdf')
>>"%PSFILE%" echo   if (-not (Test-Path $file)) {
>>"%PSFILE%" echo     Write-Host 'Downloading PDF...' -ForegroundColor Yellow
>>"%PSFILE%" echo     try { Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing -TimeoutSec 90 } catch { Remove-Item $file -ErrorAction SilentlyContinue; Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red; Pause-Lib; return }
>>"%PSFILE%" echo   }
>>"%PSFILE%" echo   Write-Host "Opening: $($entry.path)" -ForegroundColor Green
>>"%PSFILE%" echo   Start-Process -FilePath $file
>>"%PSFILE%" echo   Pause-Lib
>>"%PSFILE%" echo }
>>"%PSFILE%" echo function Show-Results($items) {
>>"%PSFILE%" echo   if ($items.Count -eq 0) { Write-Host 'No matching PDF found.' -ForegroundColor Yellow; Pause-Lib; return }
>>"%PSFILE%" echo   $page = 0; $pageSize = 15
>>"%PSFILE%" echo   while ($true) {
>>"%PSFILE%" echo     Banner
>>"%PSFILE%" echo     Write-Host "Found $($items.Count) PDF file(s). Page $($page + 1) of $([math]::Ceiling($items.Count / $pageSize))" -ForegroundColor Yellow
>>"%PSFILE%" echo     Write-Host ''
>>"%PSFILE%" echo     $start = $page * $pageSize; $end = [math]::Min($start + $pageSize, $items.Count)
>>"%PSFILE%" echo     for ($i=$start; $i -lt $end; $i++) { Write-Host ('[{0}] {1}' -f ($i+1), $items[$i].path) }
>>"%PSFILE%" echo     Write-Host ''; Write-Host '[N] Next page   [P] Previous page   [0] Main menu' -ForegroundColor Cyan
>>"%PSFILE%" echo     $choice = (Read-Host 'Enter file number or option').Trim()
>>"%PSFILE%" echo     if ($choice -eq '0') { return }
>>"%PSFILE%" echo     if ($choice -match '^(?i)n$') { if ($end -lt $items.Count) { $page++ }; continue }
>>"%PSFILE%" echo     if ($choice -match '^(?i)p$') { if ($page -gt 0) { $page-- }; continue }
>>"%PSFILE%" echo     $number = 0
>>"%PSFILE%" echo     if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $items.Count) { Open-Pdf $items[$number-1] } else { Write-Host 'Invalid selection.' -ForegroundColor Red; Pause-Lib }
>>"%PSFILE%" echo   }
>>"%PSFILE%" echo }
>>"%PSFILE%" echo try { $files = @(Load-Files) } catch { Banner; Write-Host "Could not load PDFs from GitHub: $($_.Exception.Message)" -ForegroundColor Red; Write-Host 'Check that the repository is public, the branch is correct, and internet is available.'; Pause-Lib; exit 1 }
>>"%PSFILE%" echo while ($true) {
>>"%PSFILE%" echo   Banner
>>"%PSFILE%" echo   Write-Host "Repository: $owner/$repo" -ForegroundColor Gray
>>"%PSFILE%" echo   Write-Host "PDF files found: $($files.Count)" -ForegroundColor Yellow
>>"%PSFILE%" echo   Write-Host ''
>>"%PSFILE%" echo   Write-Host '  [1] Search PDF by question or keyword'
>>"%PSFILE%" echo   Write-Host '  [2] Browse all PDFs'
>>"%PSFILE%" echo   Write-Host '  [3] Browse by subject or folder'
>>"%PSFILE%" echo   Write-Host '  [4] Refresh PDF list from GitHub'
>>"%PSFILE%" echo   Write-Host '  [0] Exit'
>>"%PSFILE%" echo   Write-Host ''
>>"%PSFILE%" echo   $choice = (Read-Host 'Enter your choice').Trim()
>>"%PSFILE%" echo   switch ($choice) {
>>"%PSFILE%" echo     '1' { Banner; $query = (Read-Host 'Type question words or PDF filename').Trim(); if ($query) { $words = @($query -split '\s+' ^| Where-Object { $_ }); $matches = @($files ^| Where-Object { $path = $_.path; @($words ^| Where-Object { $path.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -lt 0 }).Count -eq 0 }); Show-Results $matches } }
>>"%PSFILE%" echo     '2' { Show-Results $files }
>>"%PSFILE%" echo     '3' { Banner; $query = (Read-Host 'Enter subject or folder name').Trim(); if ($query) { Show-Results @($files ^| Where-Object { $_.path.IndexOf($query, [StringComparison]::OrdinalIgnoreCase) -ge 0 }) } }
>>"%PSFILE%" echo     '4' { try { $files = @(Load-Files); Write-Host 'PDF list updated.' -ForegroundColor Green } catch { Write-Host "Refresh failed: $($_.Exception.Message)" -ForegroundColor Red }; Pause-Lib }
>>"%PSFILE%" echo     '0' { exit 0 }
>>"%PSFILE%" echo     default { Write-Host 'Invalid choice.' -ForegroundColor Red; Pause-Lib }
>>"%PSFILE%" echo   }
>>"%PSFILE%" echo }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PSFILE%"
endlocal
