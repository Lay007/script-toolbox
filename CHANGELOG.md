# Changelog

All notable repository-level changes are summarized here.

This project follows a lightweight, practical changelog style rather than a strict release process. Dates use ISO format.

## Unreleased

### Added

- PowerShell AST syntax checker: `tools/test-powershell-syntax.ps1`.
- Markdown relative link checker: `tools/test-markdown-links.ps1`.
- PSScriptAnalyzer repository settings: `PSScriptAnalyzerSettings.psd1`.
- GitHub Actions workflow dispatch support for manual PowerShell lint runs.
- CI quality-gate documentation in the README.

### Changed

- PowerShell lint workflow now runs syntax checks before PSScriptAnalyzer.
- PSScriptAnalyzer now fails CI on error-level findings while keeping warnings visible in the job log.
- PSScriptAnalyzer uses repository settings to reduce naming-only warning noise for idempotent helper functions.

### Fixed

- Avoided failing CI on warning-only PSScriptAnalyzer diagnostics.
- Added a documentation link check to catch stale relative links in README and docs files.
