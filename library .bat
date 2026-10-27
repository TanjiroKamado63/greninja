@echo off
setlocal EnableExtensions
chcp 65001 >nul
title STUDENT QUESTION LIBRARY
color 0B
set "LIB_HOME=%LOCALAPPDATA%\StudentQuestionLibrary"
if not exist "%LIB_HOME%" mkdir "%LIB_HOME%"
set "ENGINE=%LIB_HOME%\engine.ps1"
set "SOURCE=%~f0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$s=Get-Content -LiteralPath $env:SOURCE -Raw; $p=$s.IndexOf('# POWERSHELL ENGINE START'); if($p -lt 0){throw 'Missing engine'}; [IO.File]::WriteAllText($env:ENGINE,$s.Substring($p),[Text.UTF8Encoding]::new($false))"
if errorlevel 1 (echo Failed to initialize library.& pause & exit /b 1)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%"
exit /b %errorlevel%
# POWERSHELL ENGINE START
$ErrorActionPreference = 'Stop'
$owner = 'TanjiroKamado63'
$repo = 'greninja'
$branch = 'main'
$homeDir = Join-Path $env:LOCALAPPDATA 'StudentQuestionLibrary'
$cache = Join-Path $homeDir 'PDFs'
New-Item -ItemType Directory -Force -Path $cache | Out-Null
$headers = @{ 'User-Agent' = 'StudentQuestionLibrary'; 'Accept' = 'application/vnd.github+json' }
function Pause-Library { [void](Read-Host 'Press Enter to continue') }
function Banner {
    Clear-Host
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '                  STUDENT QUESTION LIBRARY' -ForegroundColor Green
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '       Search questions  |  Browse PDFs  |  Open files' -ForegroundColor Gray
    Write-Host ''
}
function Load-Pdfs {
    $uri = "https://api.github.com/repos/$owner/$repo/git/trees/$branch`?recursive=1"
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 40
    if ($response.truncated) { Write-Host 'Warning: GitHub returned an incomplete file list.' -ForegroundColor Yellow }
    return @($response.tree | Where-Object { $_.type -eq 'blob' -and $_.path -match '(?i)\.pdf$' } | Sort-Object path)
}
function Open-Pdf($entry) {
    $encoded = (($entry.path -split '/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    $url = "https://raw.githubusercontent.com/$owner/$repo/$branch/$encoded"
    $localFile = Join-Path $cache ($entry.sha + '.pdf')
    if (-not (Test-Path -LiteralPath $localFile)) {
        Write-Host 'Downloading PDF...' -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $url -OutFile $localFile -UseBasicParsing -TimeoutSec 120
        } catch {
            Remove-Item -LiteralPath $localFile -ErrorAction SilentlyContinue
            Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
            Pause-Library
            return
        }
    }
    Write-Host "Opening $($entry.path)" -ForegroundColor Green
    try { Start-Process -FilePath $localFile } catch { Write-Host "Could not open PDF: $($_.Exception.Message)" -ForegroundColor Red }
    Pause-Library
}
function Show-Results($items) {
    $items = @($items)
    if ($items.Count -eq 0) { Write-Host 'No matching PDFs found.' -ForegroundColor Yellow; Pause-Library; return }
    $page = 0
    $pageSize = 12
    while ($true) {
        Banner
        $pages = [math]::Ceiling($items.Count / $pageSize)
        Write-Host "Matches: $($items.Count)  |  Page $($page + 1) of $pages" -ForegroundColor Yellow
        Write-Host ''
        $start = $page * $pageSize
        $end = [math]::Min($start + $pageSize, $items.Count)
        for ($i = $start; $i -lt $end; $i++) { Write-Host ('[{0}] {1}' -f ($i + 1), $items[$i].path) }
        Write-Host ''
        Write-Host '[N] Next   [P] Previous   [0] Main menu' -ForegroundColor Cyan
        $choice = (Read-Host 'Choose a PDF number').Trim()
        if ($choice -eq '0') { return }
        if ($choice -eq 'n') { if ($end -lt $items.Count) { $page++ }; continue }
        if ($choice -eq 'p') { if ($page -gt 0) { $page-- }; continue }
        $number = 0
        if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $items.Count) {
            Open-Pdf $items[$number - 1]
        } else { Write-Host 'Invalid selection.' -ForegroundColor Red; Pause-Library }
    }
}
try { $files = @(Load-Pdfs) } catch {
    Banner
    Write-Host "Unable to load PDFs: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Check internet access and that the GitHub repository is public.'
    Pause-Library
    exit 1
}
while ($true) {
    Banner
    Write-Host "GitHub: $owner/$repo" -ForegroundColor Gray
    Write-Host "PDFs available: $($files.Count)" -ForegroundColor Yellow
    Write-Host ''
    Write-Host ' [1] Search by question keywords / filename'
    Write-Host ' [2] Browse all PDF files'
    Write-Host ' [3] Search by subject or folder'
