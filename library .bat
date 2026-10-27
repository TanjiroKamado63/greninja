@echo off
setlocal EnableExtensions DisableDelayedExpansion
title STUDENT QUESTION LIBRARY
color 0A
set "OWNER=TanjiroKamado63"
set "REPO=greninja"
set "BRANCH=main"
set "WORK=%LOCALAPPDATA%\StudentQuestionLibrary"
if not exist "%WORK%" mkdir "%WORK%"
set "PSFILE=%WORK%\library_engine_%RANDOM%.ps1"
set "SELF=%~f0"
rem Extract the embedded PowerShell section from this single batch file.
powershell.exe -NoProfile -Command "$s=[IO.File]::ReadAllText($env:SELF); $tag='# POWERSHELL_START'; $i=$s.IndexOf($tag); if($i -lt 0){exit 1}; [IO.File]::WriteAllText($env:PSFILE,$s.Substring($i+$tag.Length),[Text.UTF8Encoding]::new($false))"
if errorlevel 1 (echo Failed to prepare library engine. & pause & exit /b 1)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PSFILE%" -Owner "%OWNER%" -Repo "%REPO%" -Branch "%BRANCH%" -Work "%WORK%"
set "RC=%ERRORLEVEL%"
del /q "%PSFILE%" >nul 2>&1
if not "%RC%"=="0" pause
exit /b %RC%
# POWERSHELL_START
param([string]$Owner,[string]$Repo,[string]$Branch,[string]$Work)
$ErrorActionPreference='Stop'
$cache=Join-Path $Work 'pdf_index.json'
$pdfDir=Join-Path $Work 'PDFs'
New-Item -ItemType Directory -Force -Path $pdfDir | Out-Null
$script:files=@()
function Header($heading) {
 Clear-Host
 Write-Host '========================================================' -ForegroundColor Green
 Write-Host '                STUDENT QUESTION LIBRARY' -ForegroundColor Green
 Write-Host '========================================================' -ForegroundColor Green
 Write-Host " Repository: $Owner/$Repo" -ForegroundColor Gray
 Write-Host " $heading" -ForegroundColor Cyan
 Write-Host '--------------------------------------------------------' -ForegroundColor DarkGray
}
function Load-Index([bool]$refresh=$false) {
 if (!$refresh -and (Test-Path $cache)) {
  try { $script:files=@(Get-Content -LiteralPath $cache -Raw | ConvertFrom-Json); return } catch {}
 }
 Header 'Loading PDF list from GitHub...'
 $url="https://api.github.com/repos/$Owner/$Repo/git/trees/$Branch`?recursive=1"
 try {
  $data=Invoke-RestMethod -Uri $url -Headers @{'User-Agent'='StudentQuestionLibrary';'Accept'='application/vnd.github+json'} -TimeoutSec 30
  if ($data.truncated) { Write-Host 'Warning: GitHub returned a truncated file list.' -ForegroundColor Yellow }
  $script:files=@($data.tree | Where-Object { $_.type -eq 'blob' -and $_.path -match '(?i)\.pdf$' } | Sort-Object path | ForEach-Object { $_.path })
  ConvertTo-Json -InputObject @($script:files) -Compress | Set-Content -LiteralPath $cache -Encoding UTF8
 } catch {
  Write-Host "Unable to load GitHub PDFs: $($_.Exception.Message)" -ForegroundColor Red
  if (Test-Path $cache) { try {$script:files=@(Get-Content $cache -Raw | ConvertFrom-Json)} catch {} }
  if (!$script:files.Count) { Read-Host 'Press Enter to exit'; exit 1 }
 }
}
function Show-Results($results) {
 $results=@($results)
 if (!$results.Count) { Write-Host 'No matching PDF filenames found.' -ForegroundColor Yellow; Read-Host 'Press Enter'; return }
 $page=0; $pageSize=15
 while ($true) {
  Header "Found $($results.Count) PDFs - Page $($page+1) of $([math]::Ceiling($results.Count/$pageSize))"
  $start=$page*$pageSize; $end=[math]::Min($start+$pageSize,$results.Count)
  for($i=$start;$i -lt $end;$i++) { Write-Host (' [{0}] {1}' -f ($i+1),$results[$i]) }
  Write-Host ''
  Write-Host 'N = next page  P = previous page  0 = menu' -ForegroundColor DarkCyan
  $pick=(Read-Host 'Enter PDF number').Trim()
  if ($pick -eq '0') { return }
  if ($pick -match '^[nN]$') { if($end -lt $results.Count){$page++}; continue }
  if ($pick -match '^[pP]$') { if($page -gt 0){$page--}; continue }
  $num=0
  if ([int]::TryParse($pick,[ref]$num) -and $num -ge 1 -and $num -le $results.Count) { Open-Pdf $results[$num-1] }
  else { Write-Host 'Invalid selection.' -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
 }
}
function Open-Pdf([string]$path) {
 $segments=$path -split '/'
 $escaped=($segments | ForEach-Object {[uri]::EscapeDataString($_)}) -join '/'
 $url="https://raw.githubusercontent.com/$Owner/$Repo/$Branch/$escaped"
 $local=Join-Path $pdfDir (($path -replace '[\\/:*?"<>|]','_'))
 try {
  if (!(Test-Path -LiteralPath $local)) {
   Write-Host 'Downloading PDF...' -ForegroundColor Cyan
   Invoke-WebRequest -Uri $url -OutFile $local -TimeoutSec 90
  }
  Write-Host 'Opening PDF...' -ForegroundColor Green
  Start-Process -FilePath $local
 } catch { Write-Host "Could not open PDF: $($_.Exception.Message)" -ForegroundColor Red; Read-Host 'Press Enter' }
}
Load-Index
while ($true) {
 Header "$($script:files.Count) PDFs available"
 Write-Host ' [1] Search by question keywords / filename'
 Write-Host ' [2] Browse all PDF files'
 Write-Host ' [3] Search by subject / folder'
 Write-Host ' [4] Refresh PDF list from GitHub'
 Write-Host ' [0] Exit'
 Write-Host ''
 $choice=(Read-Host 'Enter your choice').Trim()
 switch ($choice) {
  '1' { Header 'SEARCH PDF'; $term=(Read-Host 'Enter question words').Trim(); if($term){$terms=@($term -split '\s+' | Where-Object {$_}); $matches=@($script:files | Where-Object { $path=$_; @($terms | Where-Object {$path.IndexOf($_,[StringComparison]::OrdinalIgnoreCase) -lt 0}).Count -eq 0 }); Show-Results $matches} }
  '2' { Show-Results $script:files }
  '3' { Header 'SEARCH SUBJECT'; $term=(Read-Host 'Enter subject or folder').Trim(); if($term){Show-Results @($script:files | Where-Object {$_.IndexOf($term,[StringComparison]::OrdinalIgnoreCase) -ge 0})} }
  '4' { Load-Index $true; Write-Host "Loaded $($script:files.Count) PDFs."; Read-Host 'Press Enter' }
  '0' { exit 0 }
  default { Write-Host 'Invalid choice.'; Start-Sleep -Seconds 1 }
 }
}
