# Student Question Library - Windows PowerShell 5.1
# Uses questions_index.txt (no INDEX.csv required)
$ErrorActionPreference = 'Stop'

# GitHub repository configuration.
$owner = 'TanjiroKamado63'
$repo = 'greninja'
$branch = 'main'

$cache = Join-Path $env:LOCALAPPDATA 'StudentQuestionLibrary'
$pdfDir = Join-Path $cache 'PDFs'
New-Item -ItemType Directory -Path $pdfDir -Force | Out-Null

function Get-RawUrl([string]$path) {
    $parts = $path -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }
    return "https://raw.githubusercontent.com/$owner/$repo/$branch/$($parts -join '/')"
}
function Download([string]$url, [string]$path) {
    Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing -TimeoutSec 45
}
function Load-Index {
    $locations = @('questions_index.txt', 'DotNet_Separate_Question_PDFs/questions_index.txt')
    foreach ($location in $locations) {
        try {
            $temp = Join-Path $cache 'questions_index.txt'
            Download (Get-RawUrl $location) $temp
            $rows = New-Object 'System.Collections.Generic.List[object]'
            foreach ($line in (Get-Content -LiteralPath $temp -Encoding UTF8)) {
                if ($line -match '^\s*(Q\d+)\s*\|\s*(.*?)\s*\|\s*(\S+\.pdf)\s*$') {
                    $rows.Add([pscustomobject]@{ ID=$matches[1]; Question=$matches[2]; File=$matches[3] })
                }
            }
            if ($rows.Count -gt 0) { return @($rows.ToArray()) }
        } catch { }
    }
    throw 'Could not read questions_index.txt. Check the repository name, branch and file location.'
}
function Get-Pdf([string]$file) {
    $target = Join-Path $pdfDir $file
    if (Test-Path -LiteralPath $target) { return $target }
    foreach ($path in @($file, "DotNet_Separate_Question_PDFs/$file")) {
        try {
            Download (Get-RawUrl $path) $target
            if ((Get-Item -LiteralPath $target).Length -gt 0) { return $target }
        } catch {
            Remove-Item -LiteralPath $target -ErrorAction SilentlyContinue
        }
    }
    throw "PDF not found: $file. Upload the individual PDF files (not only the ZIP)."
}

if ($owner -eq 'YOUR_GITHUB_USERNAME' -or $repo -eq 'YOUR_REPOSITORY_NAME') {
    Write-Host 'First edit $owner and $repo in this script.' -ForegroundColor Yellow
    Read-Host 'Press Enter to exit' | Out-Null
    exit 1
}
try { $items = @(Load-Index) }
catch { Write-Host $_.Exception.Message -ForegroundColor Red; Read-Host 'Press Enter to exit' | Out-Null; exit 1 }

while ($true) {
    Clear-Host
    Write-Host '=== STUDENT QUESTION LIBRARY ===' -ForegroundColor Cyan
    Write-Host "Indexed questions: $($items.Count)"
    Write-Host 'Search by Q001, question keyword, or type R to refresh. Type 0 to exit.'
    $query = (Read-Host 'Search').Trim()
    if ($query -eq '0') { break }
    if ($query -eq 'R') {
        try { $items = @(Load-Index); Write-Host 'Index refreshed.' -ForegroundColor Green }
        catch { Write-Host $_.Exception.Message -ForegroundColor Red }
        Read-Host 'Press Enter' | Out-Null
        continue
    }
    if ([string]::IsNullOrWhiteSpace($query)) { continue }
    $found = @($items | Where-Object { $_.ID -like "*$query*" -or $_.Question -like "*$query*" })
    if ($found.Count -eq 0) {
        Write-Host 'No matching questions.' -ForegroundColor Yellow
        Read-Host 'Press Enter' | Out-Null
        continue
    }
    $number = 1
    foreach ($item in $found) {
        Write-Host ("{0}. [{1}] {2}" -f $number, $item.ID, $item.Question)
        $number++
    }
    $selection = Read-Host 'Enter result number to open PDF (0 to search again)'
    $chosen = 0
    if (-not [int]::TryParse($selection, [ref]$chosen) -or $chosen -lt 1 -or $chosen -gt $found.Count) { continue }
    try {
        $pdf = Get-Pdf $found[$chosen - 1].File
        Start-Process -FilePath $pdf
        Write-Host "Opened: $pdf" -ForegroundColor Green
    } catch { Write-Host $_.Exception.Message -ForegroundColor Red }
    Read-Host 'Press Enter to search again' | Out-Null
}
