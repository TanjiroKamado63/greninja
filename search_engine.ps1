        try {
            Download-File $url $temp
            $rows = New-Object 'System.Collections.Generic.List[object]'
            foreach ($line in (Get-Content -LiteralPath $temp -Encoding UTF8)) {
                if ($line -match '^\s*(Q\d+)\s*\|\s*(.*?)\s*\|\s*(\S+\.pdf)\s*$') {
                    $rows.Add([pscustomobject]@{ ID=$matches[1]; Question=$matches[2]; File=$matches[3] })
                }
            }
            if ($rows.Count -gt 0) { return $rows.ToArray() }
            $errors.Add("No valid Q001 | Question | filename.pdf entries in $location")
        } catch { $errors.Add("$location : $($_.Exception.Message)") }
    }
    throw "Could not load questions_index.txt.`n$($errors -join "`n")"
}
function Get-Pdf([string]$filename) {
    # Prevent filenames from the index escaping the intended PDF folder.
    if ($filename -notmatch '^Q\d+_[A-Za-z0-9_.-]+\.pdf$' -and $filename -notmatch '^Q\d+\.pdf$') {
        throw "Unexpected PDF filename in index: $filename"
    }
    $target = Join-Path $pdfDir $filename
    if ((Test-Path -LiteralPath $target) -and (Get-Item -LiteralPath $target).Length -gt 0) { return $target }
    $errors = New-Object 'System.Collections.Generic.List[string]'
    foreach ($path in @($filename, "DotNet_Separate_Question_PDFs/$filename")) {
        try {
            Download-File (Get-RawUrl $path) $target
            if ((Get-Item -LiteralPath $target).Length -gt 0) { return $target }
        } catch {
            $errors.Add("$path : $($_.Exception.Message)")
            Remove-Item -LiteralPath $target -ErrorAction SilentlyContinue
        }
    }
    throw "PDF download failed. Confirm the PDF is uploaded individually and its name matches the index.`n$($errors -join "`n")"
}

try { $items = @(Load-Index) }
catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    Read-Host 'Press Enter to exit' | Out-Null
    exit 1
}
while ($true) {
    Clear-Host
    Write-Host '=== STUDENT QUESTION LIBRARY ===' -ForegroundColor Cyan
    Write-Host "Indexed questions: $($items.Count)"
    Write-Host 'Search Q001 or keywords; R = refresh; 0 = exit.'
    $query = (Read-Host 'Search').Trim()
    if ($query -eq '0') { break }
    if ($query -eq 'R') {
        try { $items = @(Load-Index); Write-Host 'Index refreshed.' -ForegroundColor Green }
        catch { Write-Host $_.Exception.Message -ForegroundColor Red }
        Read-Host 'Press Enter' | Out-Null
        continue
    }
    if ([string]::IsNullOrWhiteSpace($query)) { continue }
    $found = @($items | Where-Object { $_.ID.IndexOf($query, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or $_.Question.IndexOf($query, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
    if ($found.Count -eq 0) {
        Write-Host 'No matching questions.' -ForegroundColor Yellow
        Read-Host 'Press Enter' | Out-Null
        continue
    }
    for ($i = 0; $i -lt $found.Count; $i++) {
        Write-Host ('{0}. [{1}] {2}' -f ($i+1), $found[$i].ID, $found[$i].Question)
    }
    $selection = Read-Host 'Enter result number (0 = back)'
    $chosen = 0
    if (-not [int]::TryParse($selection, [ref]$chosen) -or $chosen -lt 1 -or $chosen -gt $found.Count) { continue }
    try {
        $pdf = Get-Pdf $found[$chosen-1].File
        Start-Process -FilePath $pdf -ErrorAction Stop
        Write-Host "Opened: $pdf" -ForegroundColor Green
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host 'If access is denied, check Windows security settings or ask the computer administrator.' -ForegroundColor Yellow
    }
    Read-Host 'Press Enter to search again' | Out-Null
}
