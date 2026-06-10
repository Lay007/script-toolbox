$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$markdownFiles = Get-ChildItem -Path $root -Recurse -Include '*.md' -File |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }

$failed = $false
foreach ($file in $markdownFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $matches = [regex]::Matches($content, '\[[^\]]+\]\(([^)]+)\)')

    foreach ($match in $matches) {
        $target = $match.Groups[1].Value.Trim()
        if ([string]::IsNullOrWhiteSpace($target)) {
            continue
        }
        if ($target -match '^(https?:|mailto:|#)') {
            continue
        }
        if ($target.StartsWith('<') -and $target.EndsWith('>')) {
            $target = $target.Trim('<', '>')
        }

        $targetWithoutAnchor = ($target -split '#', 2)[0]
        if ([string]::IsNullOrWhiteSpace($targetWithoutAnchor)) {
            continue
        }

        $resolved = Join-Path $file.DirectoryName $targetWithoutAnchor
        if (-not (Test-Path -LiteralPath $resolved)) {
            $failed = $true
            Write-Host "Broken link in $($file.FullName): $target"
        }
    }
}

if ($failed) {
    throw 'Markdown relative link check failed.'
}

Write-Host "PASS: checked $($markdownFiles.Count) Markdown file(s)."
