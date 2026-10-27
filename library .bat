@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Student Question Library
set "LIB_FILE=%~f0"
set "LIB_HOME=%LOCALAPPDATA%\StudentQuestionLibrary"
if not exist "%LIB_HOME%" mkdir "%LIB_HOME%"
set "LIB_ENGINE=%LIB_HOME%\search_engine.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $lines=[IO.File]::ReadAllLines($env:LIB_FILE); $start=[Array]::IndexOf($lines,'# BEGIN_LIBRARY_ENGINE'); $end=[Array]::IndexOf($lines,'# END_LIBRARY_ENGINE'); if($start -lt 0 -or $end -le $start+1){throw 'Engine markers missing or empty'}; $code=$lines[($start+1)..($end-1)]; [IO.File]::WriteAllLines($env:LIB_ENGINE,[string[]]$code,(New-Object Text.UTF8Encoding($false))); $tokens=$null; $errors=$null; [Management.Automation.Language.Parser]::ParseFile($env:LIB_ENGINE,[ref]$tokens,[ref]$errors) | Out-Null; if($errors.Count){$errors | ForEach-Object { Write-Host $_.Message }; exit 1}"
if errorlevel 1 (
 echo Search engine extraction or syntax validation failed.
 pause
 exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%LIB_ENGINE%"
if errorlevel 1 pause
exit /b
# BEGIN_LIBRARY_ENGINE
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'Student Question Library'
$owner = 'TanjiroKamado63'
$repo = 'greninja'
$branch = 'main'
$base = Join-Path $env:LOCALAPPDATA 'StudentQuestionLibrary'
$pdfdir = Join-Path $base 'PDFs'
New-Item -ItemType Directory -Force -Path $base,$pdfdir | Out-Null
$indexPath = Join-Path $base 'pdf_index.json'
$questionPath = Join-Path $base 'questions_index.txt'
$script:entries = @()
function Refresh-Index {
  Write-Host 'Downloading PDF list...'
  $uri = 'https://api.github.com/repos/' + $owner + '/' + $repo + '/git/trees/' + $branch + '?recursive=1'
  $tree = Invoke-RestMethod -Uri $uri -Headers @{ 'User-Agent'='StudentQuestionLibrary' } -TimeoutSec 30
  if ($tree.truncated) { throw 'Repository tree is too large to list completely.' }
  $pdfs = @($tree.tree | Where-Object { $_.type -eq 'blob' -and $_.path -match '\.pdf$' } | ForEach-Object { $_.path })
  if ($pdfs.Count -eq 0) { Write-Host 'No PDF files found in the repository.' }
  $pdfs | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $indexPath -Encoding UTF8
  $qurl = 'https://raw.githubusercontent.com/' + $owner + '/' + $repo + '/' + $branch + '/questions_index.txt'
  try { Invoke-WebRequest -Uri $qurl -OutFile $questionPath -UseBasicParsing -TimeoutSec 15 } catch { if (Test-Path $questionPath) { Remove-Item $questionPath -Force } }
  Load-Index
  Write-Host ('Loaded {0} PDFs and {1} question mappings.' -f $script:pdfs.Count, $script:questions.Count)
}
function Load-Index {
  $script:pdfs = @()
  $script:questions = @()
  if (Test-Path $indexPath) {
    $raw = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8
    if ($raw.Trim()) { $script:pdfs = @(ConvertFrom-Json -InputObject $raw) }
  }
  if (Test-Path $questionPath) {
    foreach ($line in @(Get-Content -LiteralPath $questionPath -Encoding UTF8)) {
      $parts = $line -split '\|',2
      if ($parts.Count -eq 2 -and $parts[0].Trim() -and $parts[1].Trim()) {
        $script:questions += [pscustomobject]@{ Title=$parts[0].Trim(); Path=$parts[1].Trim() }
      }
    }
  }
  $script:entries = @()
  foreach ($p in $script:pdfs) {
    $title = [IO.Path]::GetFileNameWithoutExtension([string]$p) -replace '[_-]',' '
    $script:entries += [pscustomobject]@{Title=$title;Path=[string]$p}
  }
  foreach ($q in $script:questions) {
    if ($script:pdfs -contains $q.Path) { $script:entries += $q }
  }
}
function Rank-Entries([string]$query) {
  $q = $query.Trim().ToLowerInvariant()
  if (-not $q) { return @() }
  $words = @($q -split '[^a-z0-9]+' | Where-Object { $_.Length -gt 1 -and $_ -notin @('the','and','for','with','write','program','create','using','demonstrate','a','an','to','in','of') })
  if ($words.Count -eq 0) { $words = @($q) }
  $ranked = foreach ($item in $script:entries) {
    $title = $item.Title.ToLowerInvariant()
    $path = $item.Path.ToLowerInvariant()
    $score = 0
    if ($title -eq $q) { $score += 100 }
    if ($title.Contains($q)) { $score += 45 }
    if ($path.Contains($q)) { $score += 20 }
    foreach ($w in $words) {
      if ($title.Contains($w)) { $score += 12 }
      elseif ($path.Contains($w)) { $score += 4 }
      elseif ($w.Length -ge 4) {
        $prefix = $w.Substring(0,[Math]::Min(4,$w.Length))
        if ($title.Contains($prefix)) { $score += 2 }
      }
    }
    if ($score -gt 0) { [pscustomobject]@{Title=$item.Title;Path=$item.Path;Score=$score} }
  }
  return @($ranked | Sort-Object -Property @{Expression='Score';Descending=$true},@{Expression='Title';Descending=$false} | Group-Object Path | ForEach-Object { $_.Group[0] })
}
function Open-Pdf([string]$path) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try { $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($path))).Replace('-','').Substring(0,20) } finally { $sha.Dispose() }
  $local = Join-Path $pdfdir ($hash + '.pdf')
  if (-not (Test-Path $local) -or (Get-Item $local).Length -eq 0) {
    $segments = @($path.Split('/') | ForEach-Object { [Uri]::EscapeDataString($_) })
    $url = 'https://raw.githubusercontent.com/' + $owner + '/' + $repo + '/' + $branch + '/' + ($segments -join '/')
