[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$appRoot = Join-Path $root 'src\CodexGuardian.App'
$englishPath = Join-Path $appRoot 'Resources\Strings.en-US.xaml'
$chinesePath = Join-Path $appRoot 'Resources\Strings.zh-CN.xaml'

function Read-ResourceCatalog([string]$path) {
    $content = [string](Get-Content -Raw -Encoding UTF8 -LiteralPath $path)
    $catalog = @{}
    foreach ($match in [regex]::Matches($content, '<system:String x:Key="([^"]+)">(.*?)</system:String>', 'Singleline')) {
        $catalog[$match.Groups[1].Value] = $match.Groups[2].Value
    }
    return $catalog
}

$english = Read-ResourceCatalog $englishPath
$chinese = Read-ResourceCatalog $chinesePath
$missingChinese = @($english.Keys | Where-Object { -not $chinese.ContainsKey($_) } | Sort-Object)
$missingEnglish = @($chinese.Keys | Where-Object { -not $english.ContainsKey($_) } | Sort-Object)
if ($missingChinese.Count -gt 0 -or $missingEnglish.Count -gt 0) {
    throw "Localization resource keys differ. Missing zh-CN: $($missingChinese -join ', '); missing en-US: $($missingEnglish -join ', ')."
}

foreach ($key in $english.Keys) {
    $englishPlaceholders = @([regex]::Matches($english[$key], '\{(\d+)(?:[^}]*)\}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $chinesePlaceholders = @([regex]::Matches($chinese[$key], '\{(\d+)(?:[^}]*)\}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    if (($englishPlaceholders -join ',') -ne ($chinesePlaceholders -join ',')) {
        throw "Localization placeholders differ for '$key'."
    }
}

$referencedKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$localResourceKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($file in Get-ChildItem -LiteralPath $appRoot -Recurse -File -Include '*.xaml','*.cs') {
    if ($file.DirectoryName -like '*\Resources') { continue }
    $content = [string](Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName)
    foreach ($match in [regex]::Matches($content, '\{DynamicResource\s+([^}\s]+)\}')) {
        [void]$referencedKeys.Add($match.Groups[1].Value)
    }
    foreach ($match in [regex]::Matches($content, 'x:Key="([^"]+)"')) {
        [void]$localResourceKeys.Add($match.Groups[1].Value)
    }
    foreach ($match in [regex]::Matches($content, 'Localization\.Text\(\s*"([^"]+)"')) {
        [void]$referencedKeys.Add($match.Groups[1].Value)
    }
}
$missingReferences = @($referencedKeys | Where-Object { -not $english.ContainsKey($_) -and -not $localResourceKeys.Contains($_) } | Sort-Object)
if ($missingReferences.Count -gt 0) {
    throw "Missing localization resources: $($missingReferences -join ', ')."
}

$hardCoded = @()
$attributePattern = '(?<![\w.])(?:Text|Content|ToolTip|Title|AutomationProperties\.Name|AutomationProperties\.HelpText)="([^"]+)"'
foreach ($file in Get-ChildItem -LiteralPath $appRoot -File -Filter '*.xaml') {
    $content = [string](Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName)
    foreach ($match in [regex]::Matches($content, $attributePattern)) {
        $value = $match.Groups[1].Value
        if ($value -notmatch '^\{' -and $value -match '\p{L}') {
            $hardCoded += "$($file.Name): $value"
        }
    }
}
if ($hardCoded.Count -gt 0) {
    throw "Hard-coded user-facing XAML text found: $($hardCoded -join '; ')."
}

[pscustomobject]@{
    status = 'valid'
    languages = @('en-US', 'zh-CN')
    resource_keys = $english.Count
    referenced_keys = $referencedKeys.Count
    hard_coded_xaml_strings = 0
} | ConvertTo-Json
