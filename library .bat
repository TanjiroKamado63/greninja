@echo off
setlocal EnableExtensions
title Student Question Library
set "LIB_SOURCE=%~f0"
set "LIB_HOME=%LOCALAPPDATA%\StudentQuestionLibrary"
if not exist "%LIB_HOME%" mkdir "%LIB_HOME%"
set "LIB_ENGINE=%LIB_HOME%\search_engine.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:LIB_SOURCE; $out=$env:LIB_ENGINE; $lines=Get-Content -LiteralPath $p; $code=@($lines | Where-Object { $_.StartsWith('REM#PS#') } | ForEach-Object { $_.Substring(7) }); [IO.File]::WriteAllLines($out,[string[]]$code,[Text.UTF8Encoding]::new($false))"
if errorlevel 1 (echo Unable to initialize search engine. & pause & exit /b 1)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:LIB_ENGINE; $tokens=$null; $errors=$null; [void][Management.Automation.Language.Parser]::ParseFile($p,[ref]$tokens,[ref]$errors); if($errors.Count -gt 0) { $errors | ForEach-Object { Write-Host ('Script error on line ' + $_.Extent.StartLineNumber + ': ' + $_.Message) }; exit 1 }"
if errorlevel 1 (echo Embedded search engine is incomplete. Replace the entire GitHub file. & pause & exit /b 1)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%LIB_ENGINE%"
if errorlevel 1 (echo. & echo Search engine stopped with an error. & pause)
exit /b
REM#PS#$ErrorActionPreference = 'Stop'
REM#PS#$owner = 'TanjiroKamado63'
REM#PS#$repo = 'greninja'
REM#PS#$branch = 'main'
REM#PS#$homeDir = Join-Path $env:LOCALAPPDATA 'StudentQuestionLibrary'
REM#PS#$pdfDir = Join-Path $homeDir 'PDFs'
REM#PS#$indexFile = Join-Path $homeDir 'pdf_paths.txt'
REM#PS#$questionFile = Join-Path $homeDir 'questions_index.txt'
REM#PS#New-Item -ItemType Directory -Path $pdfDir -Force | Out-Null
REM#PS#try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}
REM#PS#function Heading {
REM#PS#    Clear-Host
REM#PS#    Write-Host '==============================================================='
REM#PS#    Write-Host '                   STUDENT QUESTION LIBRARY'
REM#PS#    Write-Host '==============================================================='
REM#PS#    Write-Host '  Search full questions  |  Live suggestions  |  Open PDFs'
REM#PS#    Write-Host ''
REM#PS#}
REM#PS#function Pause-Library { Write-Host ''; [void](Read-Host 'Press Enter to continue') }
REM#PS#function Refresh-Library {
REM#PS#    Heading
REM#PS#    Write-Host 'Refreshing PDF list and question index...'
REM#PS#    try {
REM#PS#        $uri = 'https://api.github.com/repos/' + $owner + '/' + $repo + '/git/trees/' + $branch + '?recursive=1'
REM#PS#        $tree = Invoke-RestMethod -Uri $uri -Headers @{ 'User-Agent' = 'StudentQuestionLibrary' } -TimeoutSec 30
REM#PS#        $paths = @($tree.tree | Where-Object { $_.type -eq 'blob' -and $_.path -match '(?i)\.pdf$' } | ForEach-Object { $_.path } | Sort-Object -Unique)
REM#PS#        [IO.File]::WriteAllLines($indexFile, [string[]]$paths, [Text.UTF8Encoding]::new($false))
REM#PS#        $indexPath = @($tree.tree | Where-Object { $_.type -eq 'blob' -and $_.path -ieq 'questions_index.txt' } | Select-Object -First 1)
REM#PS#        if ($indexPath.Count -gt 0) {
REM#PS#            $url = 'https://raw.githubusercontent.com/' + $owner + '/' + $repo + '/' + $branch + '/questions_index.txt'
REM#PS#            Invoke-WebRequest -Uri $url -OutFile $questionFile -TimeoutSec 30
REM#PS#        } elseif (Test-Path $questionFile) { Remove-Item $questionFile -Force }
REM#PS#        Write-Host ('Loaded ' + $paths.Count + ' PDF files.')
REM#PS#        if (Test-Path $questionFile) { Write-Host 'Full-question index loaded.' }
REM#PS#        else { Write-Host 'No questions_index.txt found: suggestions use PDF names.' }
REM#PS#        return $true
REM#PS#    } catch { Write-Host ('Refresh failed: ' + $_.Exception.Message); return $false }
REM#PS#}
REM#PS#function Get-Entries {
REM#PS#    $items = [Collections.Generic.List[object]]::new()
REM#PS#    $paths = @()
REM#PS#    if (Test-Path $indexFile) { $paths = @(Get-Content -LiteralPath $indexFile | Where-Object { $_.Trim() }) }
REM#PS#    $lookup = @{}
REM#PS#    foreach ($p in $paths) { $lookup[$p.ToLowerInvariant()] = $p }
REM#PS#    if (Test-Path $questionFile) {
REM#PS#        foreach ($line in (Get-Content -LiteralPath $questionFile -Encoding UTF8)) {
REM#PS#            if ($line.Trim().StartsWith('#') -or -not $line.Contains('|')) { continue }
REM#PS#            $pair = $line.Split(@('|'), 2)
REM#PS#            $q = $pair[0].Trim(); $p = $pair[1].Trim().Replace('\','/')
REM#PS#            if ($q -and $lookup.ContainsKey($p.ToLowerInvariant())) {
REM#PS#                $items.Add([pscustomobject]@{ Question=$q; Path=$lookup[$p.ToLowerInvariant()] })
REM#PS#            }
REM#PS#        }
REM#PS#    }
REM#PS#    foreach ($p in $paths) {
REM#PS#        $label = [IO.Path]::GetFileNameWithoutExtension($p) -replace '[_-]', ' '
REM#PS#        $items.Add([pscustomobject]@{ Question=$label; Path=$p })
REM#PS#    }
REM#PS#    return $items.ToArray()
REM#PS#}
REM#PS#function Score-Entry([string]$query, [string]$label, [string]$path) {
REM#PS#    $q = $query.ToLowerInvariant().Trim(); if (-not $q) { return 0 }
REM#PS#    $s = $label.ToLowerInvariant(); $p = $path.ToLowerInvariant()
REM#PS#    if ($s -eq $q) { return 1000 }
REM#PS#    $score = 0
REM#PS#    if ($s.Contains($q)) { $score += 400 }
REM#PS#    if ($p.Contains($q)) { $score += 100 }
REM#PS#    $words = @($q -split '[^a-z0-9]+' | Where-Object { $_.Length -ge 2 -and $_ -notin @('write','program','using','create','demonstrate','the','and','for','with','that','from','show','implement','to','in','of','a','an') } | Select-Object -Unique)
REM#PS#    if ($words.Count -eq 0) { $words = @($q) }
REM#PS#    $hits = 0
REM#PS#    foreach ($word in $words) {
REM#PS#        if ($s.Contains($word)) { $score += 60; $hits++ }
REM#PS#        elseif ($p.Contains($word)) { $score += 25; $hits++ }
REM#PS#        elseif ($word.Length -ge 5 -and $s.Contains($word.Substring(0, [Math]::Min(5,$word.Length)))) { $score += 10 }
REM#PS#    }
REM#PS#    if ($hits -eq $words.Count) { $score += 100 }
REM#PS#    return $score
REM#PS#}
REM#PS#function Search-Entries([string]$query, [object[]]$entries) {
REM#PS#    $found = @()
REM#PS#    foreach ($entry in $entries) {
REM#PS#        $rank = Score-Entry $query $entry.Question $entry.Path
