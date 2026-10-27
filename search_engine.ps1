$ErrorActionPreference = 'Stop'
$owner = 'TanjiroKamado63'
$repo = 'greninja'
$branch = 'main'
$homeDir = Join-Path $env:LOCALAPPDATA 'StudentQuestionLibrary'
$pdfDir = Join-Path $homeDir 'PDFs'
$indexFile = Join-Path $homeDir 'question_catalog.json'
New-Item -ItemType Directory -Force -Path $pdfDir | Out-Null
$entries = @()
function Load-Catalog {
    $script:entries = @()
    if (Test-Path -LiteralPath $indexFile) {
        try { $script:entries = @(Get-Content -LiteralPath $indexFile -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { $script:entries = @() }
    }
}
function Refresh-Catalog {
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
                if ($parts.Count -eq 2) {
                    $requested = $parts[1].Trim()
                    $resolved = $null
                    if ($paths -contains $requested) { $resolved = $requested }
                    elseif ($requested -match '^Q[0-9]{3}$') {
                        $prefix = $requested + '_'
                        $candidates = @($paths | Where-Object { [IO.Path]::GetFileName($_).StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) })
                        if ($candidates.Count -eq 1) { $resolved = $candidates[0] }
                    }
                    if ($resolved -and $parts[0].Trim()) {
                        $catalog += [pscustomobject]@{ question = $parts[0].Trim(); path = $resolved }
                    }
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
