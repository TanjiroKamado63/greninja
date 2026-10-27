@echo off
setlocal EnableExtensions
set "LIB_SOURCE=%~f0"
set "LIB_HOME=%LOCALAPPDATA%\StudentQuestionLibrary"
if not exist "%LIB_HOME%" mkdir "%LIB_HOME%"
set "LIB_ENGINE=%LIB_HOME%\search_engine.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$lines = Get-Content -LiteralPath $env:LIB_SOURCE; $code = @($lines | Where-Object { $_.StartsWith('::PS ') } | ForEach-Object { $_.Substring(5) }); if ($code.Count -ne 155) { throw 'Embedded engine incomplete' }; [IO.File]::WriteAllLines($env:LIB_ENGINE, [string[]]$code, (New-Object Text.UTF8Encoding($false))); $tokens=$null; $errors=$null; [void][Management.Automation.Language.Parser]::ParseFile($env:LIB_ENGINE,[ref]$tokens,[ref]$errors); if ($errors.Count) { $errors | ForEach-Object { Write-Host $_.Message }; exit 1 }"
if errorlevel 1 (
  echo Search engine extraction failed. Check that the entire batch file was uploaded.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%LIB_ENGINE%"
if errorlevel 1 pause
exit /b
::PS $ErrorActionPreference = 'Stop'
::PS $owner = 'TanjiroKamado63'
::PS $repo = 'greninja'
::PS $branch = 'main'
::PS $work = Join-Path $env:LOCALAPPDATA 'StudentQuestionLibrary'
::PS $pdfDir = Join-Path $work 'PDFs'
::PS $cache = Join-Path $work 'question_entries.json'
::PS New-Item -ItemType Directory -Force -Path $pdfDir | Out-Null
::PS $script:entries = @()
::PS function Load-Entries {
::PS     param([bool]$Refresh = $false)
::PS     if ((-not $Refresh) -and (Test-Path -LiteralPath $cache)) {
::PS         try { $script:entries = @(Get-Content -LiteralPath $cache -Raw | ConvertFrom-Json); if ($script:entries.Count -gt 0) { return } } catch {}
::PS     }
::PS     Write-Host 'Loading PDF list...'
::PS     $uri = 'https://api.github.com/repos/' + $owner + '/' + $repo + '/git/trees/' + $branch + '?recursive=1'
::PS     $tree = Invoke-RestMethod -Uri $uri -Headers @{ 'User-Agent' = 'StudentQuestionLibrary' } -TimeoutSec 30
::PS     if ($tree.truncated) { Write-Host 'Warning: GitHub file list is truncated.' }
::PS     $paths = @($tree.tree | Where-Object { $_.type -eq 'blob' -and $_.path -match '(?i)\.pdf$' } | ForEach-Object { [string]$_.path })
::PS     $all = New-Object System.Collections.ArrayList
::PS     foreach ($path in $paths) {
::PS         $title = [IO.Path]::GetFileNameWithoutExtension($path) -replace '[_\-]+', ' '
::PS         [void]$all.Add([pscustomobject]@{Title=$title; Path=$path; Source='PDF filename'})
::PS     }
::PS     $indexPath = @($tree.tree | Where-Object { $_.path -ieq 'questions_index.txt' -and $_.type -eq 'blob' } | Select-Object -First 1)
::PS     if ($indexPath.Count -gt 0) {
::PS         try {
::PS             $indexUri = 'https://raw.githubusercontent.com/' + $owner + '/' + $repo + '/' + $branch + '/questions_index.txt'
::PS             $content = (Invoke-WebRequest -Uri $indexUri -UseBasicParsing -TimeoutSec 30).Content
::PS             foreach ($line in ($content -split "`r?`n")) {
::PS                 $parts = $line -split '\|', 2
::PS                 if ($parts.Count -eq 2) {
::PS                     $question = $parts[0].Trim(); $path = $parts[1].Trim()
::PS                     if ($question -and ($paths -contains $path)) { [void]$all.Add([pscustomobject]@{Title=$question; Path=$path; Source='Question index'}) }
::PS                 }
::PS             }
::PS         } catch { Write-Host 'Question index unavailable; using PDF filenames.' }
::PS     }
::PS     $script:entries = @($all.ToArray())
::PS     $script:entries | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $cache -Encoding UTF8
::PS }
::PS function Search-Entries {
::PS     param([string]$Query, [object[]]$Entries)
::PS     $words = @($Query.ToLowerInvariant() -split '[^a-z0-9]+' | Where-Object { $_.Length -gt 0 })
::PS     if ($words.Count -eq 0) { return @($Entries | Select-Object -First 10) }
::PS     $scored = foreach ($item in $Entries) {
::PS         $title = [string]$item.Title
::PS         $hay = ($title + ' ' + [string]$item.Path).ToLowerInvariant() -replace '[_\-]', ' '
::PS         $score = 0
::PS         foreach ($word in $words) {
::PS             if ($hay.Contains($word)) { $score += 10 }
::PS             elseif ($word.Length -ge 3) {
::PS                 $prefix = $word.Substring(0, [Math]::Max(2, $word.Length - 2))
::PS                 if ($hay.Contains($prefix)) { $score += 3 }
::PS             }
::PS         }
::PS         if ($hay.Contains($Query.ToLowerInvariant())) { $score += 25 }
::PS         if ($item.Source -eq 'Question index') { $score += 2 }
::PS         if ($score -gt 0) { [pscustomobject]@{Title=$title; Path=[string]$item.Path; Score=$score} }
::PS     }
::PS     return @($scored | Sort-Object -Property @{Expression='Score';Descending=$true}, @{Expression='Title';Descending=$false})
::PS }
::PS function Download-Pdf {
::PS     param([string]$Path)
::PS     $bytes = [Text.Encoding]::UTF8.GetBytes($Path)
::PS     $sha = [Security.Cryptography.SHA256]::Create()
::PS     try { $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').Substring(0,16) } finally { $sha.Dispose() }
::PS     $local = Join-Path $pdfDir ($hash + '.pdf')
::PS     if (-not (Test-Path -LiteralPath $local)) {
::PS         $encoded = (($Path -split '/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
::PS         $url = 'https://raw.githubusercontent.com/' + $owner + '/' + $repo + '/' + $branch + '/' + $encoded
::PS         Write-Host 'Downloading PDF...'
::PS         try { Invoke-WebRequest -Uri $url -OutFile $local -UseBasicParsing -TimeoutSec 90 }
::PS         catch { Remove-Item -LiteralPath $local -Force -ErrorAction SilentlyContinue; throw }
::PS     }
::PS     Start-Process -FilePath $local
::PS     Write-Host 'PDF opened in your default viewer.'
::PS }
::PS function Choose-Results {
::PS     param([object[]]$Items)
::PS     if ($Items.Count -eq 0) { Write-Host 'No matching PDFs. Try different words.'; [void][Console]::ReadKey($true); return }
