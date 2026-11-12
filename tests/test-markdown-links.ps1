$ErrorActionPreference = 'Stop'
$checker = Join-Path $PSScriptRoot '../tools/test-markdown-links.ps1'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("markdown-links-" + [guid]::NewGuid())
try {
    $docs = Join-Path $root 'docs'
    New-Item -ItemType Directory -Path $docs -Force | Out-Null
    foreach ($name in @('guide one.md', 'spec(v2).md', 'readme.md')) {
        Set-Content -LiteralPath (Join-Path $docs $name) -Value '# Example'
    }
    @'
[encoded](<docs/guide%20one.md> "title")
[parentheses](docs/spec(v2).md)
[title](docs/readme.md "description")
[fragment](docs/readme.md#section)
[external](https://example.com)
'@ | Set-Content -LiteralPath (Join-Path $root 'links.md')
    & $checker -RootPath $root

    Set-Content -LiteralPath (Join-Path $root 'links.md') -Value '[missing](docs/missing.md)'
    $rejectedMissing = $false
    try { & $checker -RootPath $root } catch { $rejectedMissing = $true }
    if (-not $rejectedMissing) { throw 'Missing target was not rejected.' }

    Set-Content -LiteralPath (Join-Path $root 'links.md') -Value '[outside](../../outside.md)'
    $rejectedOutside = $false
    try { & $checker -RootPath $root } catch { $rejectedOutside = $true }
    if (-not $rejectedOutside) { throw 'Out-of-repository target was not rejected.' }

    Write-Host 'PASS: Markdown link checker positive and negative regressions.'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
