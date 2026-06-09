$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$scripts = Get-ChildItem -Path $root -Recurse -Filter '*.ps1' |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }

$failed = $false
foreach ($script in $scripts) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$errors) | Out-Null

    if ($errors.Count -gt 0) {
        $failed = $true
        Write-Host "Syntax errors in $($script.FullName):"
        foreach ($item in $errors) {
            Write-Host "  line $($item.Extent.StartLineNumber): $($item.Message)"
        }
    }
}

if ($failed) {
    throw 'PowerShell syntax check failed.'
}

Write-Host "PASS: parsed $($scripts.Count) PowerShell script(s)."
