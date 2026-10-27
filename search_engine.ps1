# Student Question Library - PowerShell 5.1 compatible
# This file is downloaded and run by library.bat.
$ErrorActionPreference = 'Stop'
$owner = 'TanjiroKamado63'
$repo = 'greninja'
$branch = 'main'
$base = "https://raw.githubusercontent.com/$owner/$repo/$branch"
$cache = Join-Path $env:LOCALAPPDATA 'StudentQuestionLibrary'
$pdfDir = Join-Path $cache 'PDFs'
New-Item -ItemType Directory -Force -Path $cache, $pdfDir | Out-Null
$indexPath = Join-Path $cache 'questions_index.txt'
$treePath = Join-Path $cache 'pdf_paths.json'

function Get-Entries {
    $entries = New-Object 'System.Collections.Generic.List[object]'
    $seen = @{}
    try {
        $api = "https://api.github.com/repos/$owner/$repo/git/trees/$branch`?recursive=1"
        $tree = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent'='StudentQuestionLibrary' } -TimeoutSec 25
        if ($tree.truncated) { Write-Host 'Warning: Repository list was truncated.' }
        foreach ($item in @($tree.tree)) {
            if ($item.type -ne 'blob' -or $item.path -notmatch '(?i)\.pdf$') { continue }
            $path = [string]$item.path
            $name = [IO.Path]::GetFileNameWithoutExtension($path) -replace '[_\-]+',' '
            $entries.Add([pscustomobject]@{ Question=$name; Path=$path })
            $seen[$path.ToLowerInvariant()] = $true
        }
        $entries | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $treePath -Encoding UTF8
    } catch {
        if (Test-Path -LiteralPath $treePath) {
            Write-Host 'Using saved PDF list (network unavailable).'
            $saved = Get-Content -LiteralPath $treePath -Raw | ConvertFrom-Json
            foreach ($entry in @($saved)) {
                $entries.Add([pscustomobject]@{ Question=[string]$entry.Question; Path=[string]$entry.Path })
            }
        } else { Write-Host "Cannot load PDF list: $($_.Exception.Message)" }
    }
    try {
        Invoke-WebRequest -Uri "$base/questions_index.txt" -OutFile $indexPath -UseBasicParsing -TimeoutSec 15 | Out-Null
    } catch { }
    if (Test-Path -LiteralPath $indexPath) {
        foreach ($line in @(Get-Content -LiteralPath $indexPath -Encoding UTF8)) {
            $parts = $line -split '\|',2
            if ($parts.Count -ne 2) { continue }
            $q = $parts[0].Trim(); $p = $parts[1].Trim().TrimStart('/')
            if (!$q -or !$p -or $p -notmatch '(?i)\.pdf$') { continue }
            if (!$seen.ContainsKey($p.ToLowerInvariant())) { continue }
            $entries.Add([pscustomobject]@{ Question=$q; Path=$p })
        }
    }
    return $entries.ToArray()
}

function Get-Ranked([object[]]$items, [string]$query) {
    if ([string]::IsNullOrWhiteSpace($query)) { return @() }
    $words = @($query.ToLowerInvariant() -split '[^a-z0-9]+' | Where-Object { $_.Length -gt 1 })
    if ($words.Count -eq 0) { return @() }
    $ranked = foreach ($item in $items) {
        $target = (([string]$item.Question + ' ' + [string]$item.Path) -replace '[_\-]',' ').ToLowerInvariant()
        $score = 0
        foreach ($word in $words) {
            if ($target.Contains($word)) { $score += 10 }
            elseif ($word.Length -ge 4 -and $target.Contains($word.Substring(0,3))) { $score += 2 }
        }
        if ($target.Contains($query.Trim().ToLowerInvariant())) { $score += 25 }
        if ($score -gt 0) { [pscustomobject]@{ Question=$item.Question; Path=$item.Path; Score=$score } }
    }
    return @($ranked | Sort-Object -Property @{Expression='Score';Descending=$true}, @{Expression='Question';Descending=$false})
}

function Open-Pdf([object]$entry) {
    $remote = [string]$entry.Path
    $bytes = [Text.Encoding]::UTF8.GetBytes($remote)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-','').Substring(0,20) }
    finally { $sha.Dispose() }
    $local = Join-Path $pdfDir "$hash.pdf"
    if (!(Test-Path -LiteralPath $local)) {
        $segments = @($remote.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) })
        $url = "$base/$($segments -join '/')"
        Write-Host 'Downloading PDF...'
        try {
            Invoke-WebRequest -Uri $url -OutFile $local -UseBasicParsing -TimeoutSec 60 | Out-Null
        } catch {
            Remove-Item -LiteralPath $local -Force -ErrorAction SilentlyContinue
            Write-Host "Download failed: $($_.Exception.Message)"
            return
        }
    }
    Start-Process -FilePath $local
    Write-Host 'Opened PDF in your default viewer.'
}

function Read-LiveQuery([object[]]$items) {
    $query = ''
    while ($true) {
        Clear-Host
        Write-Host '============================================================'
        Write-Host '                   STUDENT QUESTION LIBRARY'
        Write-Host '============================================================'
        Write-Host 'Type a question. Enter = results, Esc = menu, Backspace = delete'
        Write-Host "Search: $query"
        Write-Host ''
        Write-Host 'Suggestions:'
        $suggestions = @(Get-Ranked $items $query | Select-Object -First 7)
        if ($suggestions.Count -eq 0) { Write-Host '  Start typing to see suggestions.' }
        else {
            $n=0
            foreach ($s in $suggestions) { $n++; Write-Host ("  {0}. {1}" -f $n, $s.Question) }
        }
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [ConsoleKey]::Escape) { return $null }
        if ($key.Key -eq [ConsoleKey]::Enter) { return $query }
        if ($key.Key -eq [ConsoleKey]::Backspace) {
            if ($query.Length -gt 0) { $query = $query.Substring(0,$query.Length-1) }
        } elseif (![char]::IsControl($key.KeyChar) -and $query.Length -lt 180) {
            $query += $key.KeyChar
        }
    }
}

function Show-Results([object[]]$matches) {
    if ($matches.Count -eq 0) { Write-Host 'No matching PDFs found.'; Read-Host 'Press Enter to continue' | Out-Null; return }
    $page=0
    $perPage=10
    while ($true) {
        $pages=[int][Math]::Ceiling($matches.Count / [double]$perPage)
        Clear-Host
        Write-Host '====================== SEARCH RESULTS ======================'
        Write-Host ("Matches: {0}    Page: {1}/{2}" -f $matches.Count,($page+1),$pages)
        Write-Host ''
        $start=$page*$perPage
        $end=[Math]::Min($start+$perPage,$matches.Count)
        for ($i=$start; $i -lt $end; $i++) {
            Write-Host ("[{0}] {1}" -f ($i+1),$matches[$i].Question)
        }
        Write-Host ''
        Write-Host 'Enter result number to open PDF. N = Next, P = Previous, M = Menu'
        $choice=(Read-Host 'Choice').Trim()
        if ($choice -ieq 'M') { return }
        if ($choice -ieq 'N') { if ($page -lt $pages-1) { $page++ }; continue }
        if ($choice -ieq 'P') { if ($page -gt 0) { $page-- }; continue }
        $number=0
        if ([int]::TryParse($choice,[ref]$number) -and $number -ge 1 -and $number -le $matches.Count) {
            Open-Pdf $matches[$number-1]
            Read-Host 'Press Enter to return to results' | Out-Null
        }
    }
}

try {
    Write-Host 'Loading PDF library...'
    $entries = @(Get-Entries)
    while ($true) {
        Clear-Host
        Write-Host '============================================================'
        Write-Host '                   STUDENT QUESTION LIBRARY'
        Write-Host '============================================================'
        Write-Host ("Available entries: {0}" -f $entries.Count)
        Write-Host ''
        Write-Host '[1] Search question (live suggestions)'
        Write-Host '[2] Browse all PDFs'
        Write-Host '[3] Refresh PDF list'
        Write-Host '[4] Exit'
        $choice=(Read-Host 'Choose').Trim()
        switch ($choice) {
            '1' {
                $query=Read-LiveQuery $entries
                if (![string]::IsNullOrWhiteSpace($query)) { Show-Results @(Get-Ranked $entries $query) }
            }
            '2' { Show-Results @($entries | Sort-Object Question) }
            '3' { $entries=@(Get-Entries); Write-Host 'Refreshed.'; Start-Sleep -Milliseconds 500 }
            '4' { exit 0 }
        }
    }
} catch {
    Write-Host "Search engine error: $($_.Exception.Message)"
    Read-Host 'Press Enter to exit' | Out-Null
    exit 1
}
