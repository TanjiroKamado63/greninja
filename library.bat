    Write-Host 'Fetching PDF list...'
    try {
        $uri = "https://api.github.com/repos/$owner/$repo/git/trees/$branch`?recursive=1"
        $tree = Invoke-RestMethod -Uri $uri -Headers @{ 'User-Agent'='StudentQuestionLibrary' } -TimeoutSec 35
        $paths = @($tree.tree | Where-Object { $_.type -eq 'blob' -and $_.path -match '\.pdf$' } | ForEach-Object { $_.path })
        $catalog = @()
        foreach ($path in $paths) {
            $name = [IO.Path]::GetFileNameWithoutExtension($path) -replace '[_-]', ' '
            $catalog += [pscustomobject]@{ question = $name; path = $path }
        }
        $questionIndexUrl = "https://raw.githubusercontent.com/$owner/$repo/$branch/questions_index.txt"
        try {
            $lines = (Invoke-WebRequest -UseBasicParsing -Uri $questionIndexUrl -TimeoutSec 15).Content -split "`r?`n"
            foreach ($line in $lines) {
                $parts = $line -split '\|', 2
                if ($parts.Count -eq 2 -and $paths -contains $parts[1].Trim()) {
                    $catalog += [pscustomobject]@{ question = $parts[0].Trim(); path = $parts[1].Trim() }
                }
            }
        } catch { }
        $catalog | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $indexFile -Encoding UTF8
        $script:entries = @($catalog)
        Write-Host ("Loaded {0} searchable entries." -f $entries.Count)
        return $true
    } catch {
        Write-Host ("Could not refresh: {0}" -f $_.Exception.Message)
        return $false
    }
}
function Rank-Entries([string]$query) {
    $words = @($query.ToLowerInvariant() -split '\W+' | Where-Object { $_.Length -gt 1 })
    if ($words.Count -eq 0) { return @() }
    $ranked = foreach ($entry in $script:entries) {
        $q = [string]$entry.question
        $hay = ($q + ' ' + $entry.path).ToLowerInvariant() -replace '[_-]', ' '
        $score = 0
        foreach ($w in $words) {
            if ($hay.Contains($w)) { $score += 10 }
            elseif ($w.Length -ge 4 -and $hay.Contains($w.Substring(0, $w.Length - 1))) { $score += 4 }
        }
        if ($hay.Contains($query.ToLowerInvariant())) { $score += 30 }
        if ($score -gt 0) { [pscustomobject]@{ item=$entry; score=$score } }
    }
    return @($ranked | Sort-Object -Property @{Expression='score';Descending=$true}, @{Expression={$_.item.question};Descending=$false})
}
function Open-Pdf($entry) {
    $remote = [string]$entry.path
    $encoded = (($remote -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
    $sha = [Security.Cryptography.SHA256]::Create()
    $bytes = [Text.Encoding]::UTF8.GetBytes($remote)
    $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').Substring(0,20)
    $local = Join-Path $pdfDir ($hash + '.pdf')
    if (-not (Test-Path -LiteralPath $local)) {
        Write-Host 'Downloading PDF...'
        try {
            Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/$owner/$repo/$branch/$encoded" -OutFile $local -TimeoutSec 60
        } catch {
            Remove-Item -LiteralPath $local -ErrorAction SilentlyContinue
            Write-Host ("Download failed: {0}" -f $_.Exception.Message)
            return
        }
    }
    Start-Process -FilePath $local
}
function Results-Menu([object[]]$matches) {
    if ($matches.Count -eq 0) { Write-Host 'No matches found.'; [void][Console]::ReadKey($true); return }
    $page = 0
    while ($true) {
        Clear-Host
        Write-Host '========== SEARCH RESULTS =========='
        $pages = [int][Math]::Ceiling($matches.Count / 10.0)
        Write-Host ("Total: {0}  Page: {1} of {2}" -f $matches.Count,($page+1),$pages)
        Write-Host ''
        $start = $page * 10
        $end = [Math]::Min($start+9,$matches.Count-1)
        for ($i=$start; $i -le $end; $i++) { Write-Host ("[{0}] {1}" -f ($i+1),$matches[$i].item.question) }
        Write-Host ''
        $answer = Read-Host 'Number = Open PDF, N = Next, P = Previous, M = Menu'
        if ($answer -match '^(?i:m)$') { return }
        if ($answer -match '^(?i:n)$') { if ($page+1 -lt $pages) { $page++ }; continue }
        if ($answer -match '^(?i:p)$') { if ($page -gt 0) { $page-- }; continue }
        $number = 0
        if ([int]::TryParse($answer,[ref]$number) -and $number -ge ($start+1) -and $number -le ($end+1)) {
            Open-Pdf $matches[$number-1].item
            Write-Host 'Press any key to return to results...'
            [void][Console]::ReadKey($true)
        }
    }
}
function Live-Search {
    $query = ''
    while ($true) {
        Clear-Host
        Write-Host '========== SEARCH QUESTION =========='
        Write-Host 'Type to see suggestions. Enter = results. Esc = menu.'
        Write-Host ''
        Write-Host ('Search: ' + $query)
        Write-Host ''
        $matches = @(Rank-Entries $query)
        if ($query.Length -gt 0) {
            Write-Host 'SUGGESTIONS'
            $limit = [Math]::Min(6,$matches.Count)
            for ($i=0; $i -lt $limit; $i++) { Write-Host ("  {0}. {1}" -f ($i+1),$matches[$i].item.question) }
            if ($limit -eq 0) { Write-Host '  No suggestions yet.' }
        }
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq 'Escape') { return }
        if ($key.Key -eq 'Enter') { if ($matches.Count -gt 0) { Results-Menu $matches }; return }
        if ($key.Key -eq 'Backspace') { if ($query.Length -gt 0) { $query=$query.Substring(0,$query.Length-1) }; continue }
        if (-not [char]::IsControl($key.KeyChar)) { $query += $key.KeyChar }
    }
}
Load-Catalog
if ($entries.Count -eq 0) { [void](Refresh-Catalog); Start-Sleep -Seconds 1 }
while ($true) {
    Clear-Host
    Write-Host '========================================'
    Write-Host '        STUDENT QUESTION LIBRARY'
    Write-Host '========================================'
    Write-Host ''
    Write-Host '[1] Search with live suggestions'
    Write-Host '[2] Browse all PDFs'
    Write-Host '[3] Refresh question and PDF list'
    Write-Host '[0] Exit'
    Write-Host ''
    $choice = Read-Host 'Choose'
    switch ($choice) {
        '1' { Live-Search }
