[CmdletBinding()]
param([string]$SkillRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'skill\codex-guardian'))

$ErrorActionPreference = 'Stop'
$required = @(
    'SKILL.md',
    'agents\openai.yaml',
    'scripts\detect-environment.ps1',
    'scripts\install-guardian.ps1',
    'scripts\diagnose-guardian.ps1',
    'scripts\repair-guardian.ps1',
    'scripts\uninstall-guide.ps1'
)
foreach ($relative in $required) {
    $path = Join-Path $SkillRoot $relative
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing required Skill file: $relative" }
}

$skill = Get-Content -Raw -Encoding UTF8 (Join-Path $SkillRoot 'SKILL.md')
if ($skill -notmatch '(?s)^---\s*\r?\nname:\s*codex-guardian\s*\r?\ndescription:\s*.+?\r?\n---') {
    throw 'SKILL.md front matter is invalid.'
}
$yaml = Get-Content -Raw -Encoding UTF8 (Join-Path $SkillRoot 'agents\openai.yaml')
foreach ($field in @('display_name:', 'short_description:', 'default_prompt:')) {
    if ($yaml -notmatch [regex]::Escape($field)) { throw "agents/openai.yaml is missing $field" }
}

$parseErrors = @()
Get-ChildItem (Join-Path $SkillRoot 'scripts') -Filter '*.ps1' | ForEach-Object {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    $parseErrors += $errors
}
if ($parseErrors.Count -gt 0) { throw "Skill scripts contain $($parseErrors.Count) PowerShell parse error(s)." }

[pscustomobject]@{ status = 'valid'; root = $SkillRoot; required_files = $required.Count } | ConvertTo-Json
