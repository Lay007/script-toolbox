[CmdletBinding()]
param(
    [string]$RootPath = (Join-Path $PSScriptRoot '..')
)
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $RootPath).Path
$markdownFiles = Get-ChildItem -Path $root -Recurse -Filter '*.md' -File |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }

$failed = $false
foreach ($file in $markdownFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    # Allow one parenthesized section in a destination, for example spec(v2).md.
    $links = [regex]::Matches($content, '\[[^\]]+\]\((?<target>(?:[^()]|\([^()]*\))*)\)')

    foreach ($link in $links) {
        $target = $link.Groups['target'].Value.Trim()
        if ([string]::IsNullOrWhiteSpace($target) -or
            $target -match '^(https?:|mailto:|tel:|data:|#|//)') {
            continue
        }

        if ($target.StartsWith('<')) {
            $end = $target.IndexOf('>')
            if ($end -lt 0) {
                $failed = $true
                Write-Host "Invalid Markdown link in $($file.FullName): $target"
                continue
            }
            $target = $target.Substring(1, $end - 1)
        }
        else {
            $match = [regex]::Match($target, '^(?<path>\S+)(?:\s+["''].*["''])?$')
            if (-not $match.Success) {
                $failed = $true
                Write-Host "Invalid Markdown link in $($file.FullName): $target"
                continue
            }
            $target = $match.Groups['path'].Value
        }

        $pathPart = ($target -split '[?#]', 2)[0]
        if ([string]::IsNullOrWhiteSpace($pathPart)) {
            continue
        }

        try {
            $decoded = [System.Uri]::UnescapeDataString($pathPart)
            $resolved = [System.IO.Path]::GetFullPath((Join-Path $file.DirectoryName $decoded))
            $relative = [System.IO.Path]::GetRelativePath($root, $resolved)
            $separator = [System.IO.Path]::DirectorySeparatorChar
            if ($relative -eq '..' -or $relative.StartsWith("..$separator")) {
                $failed = $true
                Write-Host "Link escapes repository in $($file.FullName): $target"
                continue
            }
            if (-not (Test-Path -LiteralPath $resolved)) {
                $failed = $true
                Write-Host "Broken link in $($file.FullName): $target"
            }
        }
        catch {
            $failed = $true
            Write-Host "Invalid link in $($file.FullName): $target ($($_.Exception.Message))"
        }
    }
}

if ($failed) {
    throw 'Markdown relative link check failed.'
}
Write-Host "PASS: checked $($markdownFiles.Count) Markdown file(s)."
