function AllKQLtoHTML ([string]$InputFile = "Azure_Sentinel_analytics_rules.json", [string]$MergeInputFile = "All_Azure_Sentinel_rules.json", [string]$OutputFile = "AllSentinelRules.html", [switch]$Concat, [switch]$Merge, [switch]$Usage, [switch]$help) {#Convert Sentinel JSON exports to an HTML file for easy searching with CTRL+F.

# Load PSD1 configuration.
function loadconfiguration {$script:powershell = Split-Path $profile; $script:baseModulePath = "$powershell\Modules\AllKQLtoHTML"; $script:configPath = Join-Path $baseModulePath "AllKQLtoHTML.psd1"
if (!(Test-Path $configPath)) {throw "Config file not found at $configPath"}
$script:config = Import-PowerShellDataFile -Path $configPath

# Pull config values into variables
$script:resourcegroup = $config.privatedata.resourcegroup
$script:workspacename = $config.privatedata.workspacename
$script:subscription = $config.privatedata.subscription}
loadconfiguration

# Usage switch.
if ($usage -or (-not (Test-Path "Azure_Sentinel_analytics_rules.json") -and ($PSBoundParameters.Count -eq 0))) {Write-Host -f cyan "`nUsage: AllKQLtoHTML <file1.json> <file2.json> <outfile.html> <-concat> <-merge> <-usage> <-help>`n";return}

# Modify fields sent to it with proper word wrapping.
function wordwrap ($field, $maximumlinelength) {if ($null -eq $field) {return $null}
$breakchars = ',.;?!\/ '; $wrapped = @()
if (-not $maximumlinelength) {[int]$maximumlinelength = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($maximumlinelength -lt 60) {[int]$maximumlinelength = 60}
if ($maximumlinelength -gt $Host.UI.RawUI.BufferSize.Width) {[int]$maximumlinelength = $Host.UI.RawUI.BufferSize.Width}
foreach ($line in $field -split "`n", [System.StringSplitOptions]::None) {if ($line -eq "") {$wrapped += ""; continue}
$remaining = $line
while ($remaining.Length -gt $maximumlinelength) {$segment = $remaining.Substring(0, $maximumlinelength); $breakIndex = -1
foreach ($char in $breakchars.ToCharArray()) {$index = $segment.LastIndexOf($char)
if ($index -gt $breakIndex) {$breakIndex = $index}}
if ($breakIndex -lt 0) {$breakIndex = $maximumlinelength - 1}
$chunk = $segment.Substring(0, $breakIndex + 1); $wrapped += $chunk; $remaining = $remaining.Substring($breakIndex + 1)}
if ($remaining.Length -gt 0 -or $line -eq "") {$wrapped += $remaining}}
return ($wrapped -join "`n")}

# Display a horizontal line.
function line ($colour, $length, [switch]$pre, [switch]$post, [switch]$double) {if (-not $length) {[int]$length = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($length) {if ($length -lt 60) {[int]$length = 60}
if ($length -gt $Host.UI.RawUI.BufferSize.Width) {[int]$length = $Host.UI.RawUI.BufferSize.Width}}
if ($pre) {Write-Host ""}
$character = if ($double) {"="} else {"-"}
Write-Host -f $colour ($character * $length)
if ($post) {Write-Host ""}}

function help {# Inline help.
# Select content.
$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)"); $selection = $null; $lines = @(); $wrappedLines = @(); $position = 0; $pageSize = 30; $inputBuffer = ""

function scripthelp ($section) {$pattern = "(?ims)^## ($([regex]::Escape($section)).*?)(?=^##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; if ($lines.Count -gt 1) {$wrappedLines = (wordwrap $lines[1] 100) -split "`n", [System.StringSplitOptions]::None}
else {$wrappedLines = @()}
$position = 0}

# Display Table of Contents.
while ($true) {cls; Write-Host -f cyan "$(Get-ChildItem (Split-Path $PSCommandPath) | Where-Object {$_.FullName -ieq $PSCommandPath} | Select-Object -ExpandProperty BaseName) Help Sections:`n"

if ($sections.Count -gt 7) {$half = [Math]::Ceiling($sections.Count / 2)
for ($i = 0; $i -lt $half; $i++) {$leftIndex = $i; $rightIndex = $i + $half; $leftNumber = "{0,2}." -f ($leftIndex + 1); $leftLabel = " $($sections[$leftIndex].Groups[1].Value)"; $leftOutput = [string]::Empty

if ($rightIndex -lt $sections.Count) {$rightNumber = "{0,2}." -f ($rightIndex + 1); $rightLabel = " $($sections[$rightIndex].Groups[1].Value)"; Write-Host -f cyan $leftNumber -n; Write-Host -f white $leftLabel -n; $pad = 40 - ($leftNumber.Length + $leftLabel.Length)
if ($pad -gt 0) {Write-Host (" " * $pad) -n}; Write-Host -f cyan $rightNumber -n; Write-Host -f white $rightLabel}
else {Write-Host -f cyan $leftNumber -n; Write-Host -f white $leftLabel}}}

else {for ($i = 0; $i -lt $sections.Count; $i++) {Write-Host -f cyan ("{0,2}. " -f ($i + 1)) -n; Write-Host -f white "$($sections[$i].Groups[1].Value)"}}

# Display Header.
line yellow 100
if ($lines.Count -gt 0) {Write-Host -f yellow $lines[0]}
else {Write-Host "Choose a section to view." -f darkgray}
line yellow 100

# Display content.
$end = [Math]::Min($position + $pageSize, $wrappedLines.Count)
for ($i = $position; $i -lt $end; $i++) {Write-Host -f white $wrappedLines[$i]}

# Pad display section with blank lines.
for ($j = 0; $j -lt ($pageSize - ($end - $position)); $j++) {Write-Host ""}

# Display menu options.
line yellow 100; Write-Host -f white "[↑/↓] [PgUp/PgDn] [Home/End] | [#] Select section | [Q] Quit " -n; if ($inputBuffer.length -gt 0) {Write-Host -f cyan "section: $inputBuffer" -n}; $key = [System.Console]::ReadKey($true)

# Define interaction.
switch ($key.Key) {'UpArrow' {if ($position -gt 0) {$position--}; $inputBuffer = ""}
'DownArrow' {if ($position -lt ($wrappedLines.Count - $pageSize)) {$position++}; $inputBuffer = ""}
'PageUp' {$position -= 30; if ($position -lt 0) {$position = 0}; $inputBuffer = ""}
'PageDown' {$position += 30; $maxStart = [Math]::Max(0, $wrappedLines.Count - $pageSize); if ($position -gt $maxStart) {$position = $maxStart}; $inputBuffer = ""}
'Home' {$position = 0; $inputBuffer = ""}
'End' {$maxStart = [Math]::Max(0, $wrappedLines.Count - $pageSize); $position = $maxStart; $inputBuffer = ""}

'Enter' {if ($inputBuffer -eq "") {"`n"; return}
elseif ($inputBuffer -match '^\d+$') {$index = [int]$inputBuffer
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index; $pattern = "(?ims)^## ($([regex]::Escape($sections[$selection-1].Groups[1].Value)).*?)(?=^##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $block = $match.Groups[1].Value.TrimEnd(); $lines = $block -split "`r?`n", 2
if ($lines.Count -gt 1) {$wrappedLines = (wordwrap $lines[1] 100) -split "`n", [System.StringSplitOptions]::None}
else {$wrappedLines = @()}
$position = 0}}
$inputBuffer = ""}

default {$char = $key.KeyChar
if ($char -match '^[Qq]$') {"`n"; return}
elseif ($char -match '^\d$') {$inputBuffer += $char}
else {$inputBuffer = ""}}}}}

# External call to help.
if ($help) {help; return}

# Concat(enate).
if ($concat) {$directory = Split-Path $InputFile -Parent
if (-not $directory) {$directory = Get-Location}

$baseName = [IO.Path]::GetFileNameWithoutExtension($InputFile)
$extension = [IO.Path]::GetExtension($InputFile)

# Find Windows-style copies: file.json, file (1).json, etc.
$files = Get-ChildItem -Path $directory -File | Where-Object {$_.Name -match "^$([Regex]::Escape($baseName))(\s\(\d+\))?$([Regex]::Escape($extension))$"} | Sort-Object Name
if ($files.Count -lt 2) {Write-Host -f Cyan "`nNo files were found to concatenate.`n"
return}
$outFile = Join-Path $directory "$baseName`_combined$extension"
if (Test-Path $outFile) {Remove-Item $outFile -Force}

Write-Host -f Cyan "`nConcatenating $($files.Count) files:`n"

# Parse the first file to extract the header.
$firstTemplate = Get-Content $files[0].FullName -Raw | ConvertFrom-Json
if (-not $firstTemplate.resources) {throw "First file does not contain a resources array."}

# Create a clean ARM template shell
$combinedTemplate = [ordered]@{'$schema' = $firstTemplate.'$schema'
contentVersion = $firstTemplate.contentVersion
parameters = $firstTemplate.parameters
resources = @()}

# Collect resources from ALL files safely.
foreach ($file in $files) {Write-Host -f white "`tParsing`t$($file.Name)"
$template = Get-Content $file.FullName -Raw | ConvertFrom-Json
if (-not $template.resources) {throw "File '$($file.Name)' does not contain a resources array."}
foreach ($resource in $template.resources) {$combinedTemplate.resources += $resource}}

# Serialize final combined template.
$jsonOut = $combinedTemplate | ConvertTo-Json -Depth 100
Set-Content -Path $outFile -Value $jsonOut -Encoding UTF8

Write-Host -f Cyan "`n✅ Combined ARM template written:`n"
Write-Host -f white "`t$outFile"
$InputFile = $outFile}

function Escape-Html {param ([string]$Text)
if ($null -eq $Text) {return ""}
return $Text -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'}

function Normalize-UnicodeDecorations ([string]$text) {if ($null -eq $text) {return $text}
try {return [Text.Encoding]::UTF8.GetString([Text.Encoding]::GetEncoding(1252).GetBytes($text))}
catch {re}}

function Format-Properties {param ($Properties)
$exclude = @('displayName', 'query', 'description', 'enabled', 'severity', 'templateVersion')
$out = ""
foreach ($p in $Properties.PSObject.Properties) {if ($exclude -contains $p.Name) {continue}
$key = Escape-Html $p.Name
$val = $p.Value
if ($val -is [Array]) {$valText = ($val | ForEach-Object {Escape-Html "$_"}) -join ', '}
elseif ($val -is [psobject] -and -not ($val -is [string])) {$valText = Escape-Html ($val | ConvertTo-Json -Depth 5 -Compress)}
else {$valText = Escape-Html "$val"}
$out += "<div class='kv'><strong>$key :</strong><span class='val'> $valText</span></div>`n"}
return $out}

function Get-RuleUID {param ($r)
if (-not $r.id) {return $null}
# Match the GUID after /alertRules/
if ($r.id -match '/alertRules/([0-9a-fA-F-]{36})') {return $matches[1].ToLower()}
return $null}

# Load and normalize.
function loadandnormalize {if (-not (Test-Path $InputFile)) {Write-Host -f cyan "`nInput file not found: " -n; Write-Host -f white $InputFile; return}
$json = Get-Content $InputFile -Raw -Encoding UTF8 | ConvertFrom-Json

# Normalize
function Normalize-RuleObject {param ($r)
if ($r.properties) {return $r.properties | Add-Member -NotePropertyName id -NotePropertyValue $r.id -PassThru | Add-Member -NotePropertyName kind -NotePropertyValue $r.kind -PassThru}
return $r}

# Load Primary JSON
if (-not (Test-Path $InputFile)) {Write-Host -f Cyan "`nInput file not found: $InputFile`n"; return}
$json = Get-Content $InputFile -Raw -Encoding UTF8 | ConvertFrom-Json

# Load Merge JSON
if ($Merge) {if (-not $MergeInputFile) {throw "The -Merge switch was specified but -MergeInputFile was not provided."}
if (-not (Test-Path $MergeInputFile)) {throw "Merge input file not found: $MergeInputFile"}
$mergeJson = Get-Content $MergeInputFile -Raw -Encoding UTF8 | ConvertFrom-Json}

# Normalize rules
if ($json.resources) {$script:rules = $json.resources | ForEach-Object {Normalize-RuleObject $_}}
elseif ($json.value) {$script:rules = $json.value | ForEach-Object {Normalize-RuleObject $_}}
elseif ($json -is [Array]) {$script:rules = $json | ForEach-Object {Normalize-RuleObject $_}}
else {throw "Unsupported JSON format"}

# Normalize merge rules
if ($Merge) {if ($mergeJson.resources) {$mergeRules = $mergeJson.resources}
elseif ($mergeJson.value) {$mergeRules = $mergeJson.value}
elseif ($mergeJson -is [Array]) {$mergeRules = $mergeJson}
else {throw "Unsupported JSON format in merge file"}
$mergeRules = $mergeRules | ForEach-Object {Normalize-RuleObject $_}}}
loadandnormalize

# Merge using Sentinel rule GUID.
function mergedata {$ruleMap = @{}
foreach ($r in $script:rules) {$uid = Get-RuleUID $r
if ($uid) {$ruleMap[$uid] = $r}}

foreach ($r in $mergeRules) {$uid = Get-RuleUID $r
if ($uid -and -not $ruleMap.ContainsKey($uid)) {$ruleMap[$uid] = $r}}

$script:rules = $ruleMap.Values}
mergedata

# Generate Mitre ATT&CK Navigator JSON
function exportnavigatorlayer ([string]$OutputPath, [string]$LayerName = "KQL Coverage", [string]$Domain = "enterprise-attack") {$techniqueMap = @{}
foreach ($r in $script:rules) {$ruleName = $r.displayName
if ([string]::IsNullOrWhiteSpace($ruleName)) {continue}
$allTechniques = @()
if ($r.techniques) {$allTechniques += $r.techniques}
if ($r.subTechniques) {$allTechniques += $r.subTechniques}
foreach ($t in $allTechniques) {if ([string]::IsNullOrWhiteSpace($t)) {continue}
if (-not $techniqueMap.ContainsKey($t)) {$techniqueMap[$t] = @{Count = 0
Rules = New-Object System.Collections.Generic.HashSet[string]}}
$techniqueMap[$t].Count++
$null = $techniqueMap[$t].Rules.Add($ruleName)}}

# Defensive maxValue
$max = ($techniqueMap.Values | ForEach-Object {$_.Count} | Measure-Object -Maximum).Maximum
if ($null -eq $max) {$max = 1}

$layer = [ordered]@{version = "4.5"
name = $LayerName
description = "Generated by AllKQLtoHTML"
domain = $Domain
techniques = @()
gradient = @{colors = @("#ffffff", "#ffe766", "#ff8c00", "#d60000")
minValue = 0
maxValue = $max}}

foreach ($kv in $techniqueMap.GetEnumerator()) {$sortedRules = $kv.Value.Rules | Sort-Object
$ruleList = $sortedRules -join "`n"

$layer.techniques += @{techniqueID = $kv.Key
score = $kv.Value.Count
comment = "Detected by $($kv.Value.Count) rule(s)"
metadata = @(@{name = "Rules"
value = $ruleList})}}

$layer | ConvertTo-Json -Depth 100 | Set-Content -Encoding UTF8 $OutputPath}

# Calculate statistics.
function statistics {$script:ruleCount = $script:rules.Count
$script:disabledCount = ($script:rules | Where-Object {$_.enabled -eq $false}).Count
$script:nrtCount = ($script:rules | Where-Object {$_.kind -eq 'NRT'}).Count
$script:templateVersionCount = ($script:rules | Where-Object {$_.templateVersion}).Count

# Severity counts (case-insensitive, safe for missing values)
$script:severityInfo = ($script:rules | Where-Object {$_.severity -match '^Informational$'}).Count
$script:severityLow = ($script:rules | Where-Object {$_.severity -match '^Low$'}).Count
$script:severityMedium = ($script:rules | Where-Object {$_.severity -match '^Medium$'}).Count
$script:severityHigh = ($script:rules | Where-Object {$_.severity -match '^High$'}).Count}
statistics

# Donut chart math (degrees for conic-gradient)
function builddonut {$script:severityTotal = $severityInfo + $severityLow + $severityMedium + $severityHigh
if ($severityTotal -gt 0) {$degInfo = ($severityInfo / $severityTotal) * 360
$degLow = ($severityLow / $severityTotal) * 360
$degMedium = ($severityMedium / $severityTotal) * 360
$degHigh = ($severityHigh / $severityTotal) * 360}
else {$degInfo = $degLow = $degMedium = $degHigh = 0}

# Cumulative angles (required for conic-gradient)
$script:degInfoEnd = [Math]::Round($degInfo, 1)
$script:degLowEnd = [Math]::Round($degInfo + $degLow, 1)
$script:degMediumEnd = [Math]::Round($degInfo + $degLow + $degMedium, 1)}
builddonut

# Sort rules alphabetically.
$script:rules = $script:rules | Sort-Object -Property displayName -Culture en-US

# Build rows.
function buildrows {$script:rows = ""; $script:toc = ""
foreach ($r in $script:rules) {if (-not ($r.displayName -and $r.query)) {continue}
$name = Escape-Html $r.displayName
$id = ($r.displayName -replace '[^a-zA-Z0-9_-]', '_')
$qry = Escape-Html (Normalize-UnicodeDecorations $r.query)
$desc = Escape-Html (Normalize-UnicodeDecorations $r.description)

$enabled = $r.enabled
if ($enabled -eq $true) {$enabledText = "<span class='enabled-true'>✅ true</span>"}
else {$enabledText = "<span class='enabled-false'>❌ false (Disabled)</span>"}

$severity = $r.severity
switch -Regex ($severity) {'^Informational$' {$severityHtml = "<span>Severity:</span> <span class='sev-info'><strong>⚪ Informational</strong></span>"}
'^Low$' {$severityHtml = "<span>Severity:</span> <span class='sev-low'><strong>🟠 Low</strong></span>"}
'^Medium$' {$severityHtml = "<span>Severity:</span> <span class='sev-medium'><strong>🟡 Medium</strong></span>"}
'^High$' {$severityHtml = "<span>Severity:</span> <span class='sev-high'><strong>🔴 High</strong></span>"}
default {$severityHtml = "<span>Severity:</span> <span class='sev-info'><strong>⚪ Unknown</strong></span>"}}
$props = Format-Properties $r

if ($r.enabled -eq $true) {$script:toc += "<li><a href='#$id'>$name</a></li>`n"}
else {$script:toc += "<li><a href='#$id' class='enabled-false'>$name</a></li>`n"}

$templateVersionHtml = ""
if ($r.templateVersion) {$tv = Escape-Html $r.templateVersion; $templateVersionHtml = "<br><span class='template-version'>Template Version: <strong>$tv</strong></span>"}

$script:rows += @"
<tr id="$id" data-enabled="$($r.enabled)" data-kind="$($r.kind)" data-severity="$($r.severity)" data-template-version="$($r.templateVersion)">
<td class="rulename"><strong>$name</strong><br><br>
<span class="description">$desc</span><br><br>
<span>Enabled: $enabledText</span><br>
$severityHtml
$templateVersionHtml
</td>
<td class="query"><pre>$qry</pre></td>
<td class="props">$props</td>
</tr>
"@}}
buildrows

# Final error check.
if (-not $script:rows) {Write-Host -f red "Nothing to write.`nExiting.`n";return}

# Build TOC statistics block
function buildstats {$script:statsBlock = @"
<table class="stats-table" aria-hidden="false">
<tr><td class="stats-left"><strong><span class="stats-header">Rule Overview:</span><br>
<span class="stat-green">Rule Count: $ruleCount</span><br>
<span class="stat-red toggle" data-filter="disabled">Disabled Rules: $disabledCount</span><br>
<span class="stat-yellow toggle" data-filter="nrt">NRT Rules: $nrtCount</span><br>
<span class="stat-gray toggle" data-filter="template">Built from templates: $templateVersionCount</span><br>

<span id="filterHeader" class="filter-header hidden">Filter Controls:</span>
<span id="reverseFilters" class="toggle reverse-filter hidden">🔄 Reverse Filters</span><br>
<span id="clearFilters" class="toggle clear-filters hidden">❎ Clear Filters</span></strong></td>

<td class="stats-middle"><strong><span class="stats-header">Severity Breakdown:</span><br>
<span class="sev-info toggle" data-filter="sev-informational">⚪ Informational: $severityInfo</span><br>
<span class="sev-low toggle" data-filter="sev-low">🟠 Low: $severityLow</span><br>
<span class="sev-medium toggle" data-filter="sev-medium">🟡 Medium: $severityMedium</span><br>
<span class="sev-high toggle" data-filter="sev-high">🔴 High: $severityHigh</span></strong><br>
<br><span id="visibleRuleCount" class="stat-muted"> Visible Rules: $ruleCount</span></td>

<td class="stats-right"><div class="severity-donut"><div class="donut"></div><div class="donut-label">$ruleCount<br>Rules</div></div></td></tr></table>
"@}
buildstats

# Generate HTML and write file
function writepage {$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Azure Sentinel Analytics Rules</title>

<style>
/* BASE FALLBACK (used before JS / old browsers) */
:root {--bg-main: #ffffff; --bg-panel: #f9f9f9; --bg-header: #f1f1f1; --bg-code: #f6f6f6; --border-main: #cccccc; --text-main: #222222; --text-muted: #555555; --green: #1b7f1b; --red: #c00000; --yellow: #b8860b; --row-even: #f0f0f0; --row-hover: #e6ecff; --link-normal: #995599; --link-hover: #ff0000; --link-visited: #6b84c4; --link-active: #44ff44;}

/* BASE STYLES */
body {font-family: Arial, sans-serif; margin: 20px; background: var(--bg-main); color: var(--text-main);}

#mitrePanel {position: fixed; top: 70px; right: -225px; width: 260px; height: auto; display: flex; align-items: center; z-index: 1000; transition: right 0.3s ease;}
#mitrePanel:hover {right: 0px; padding-right: 0px;}
#mitreTab {width: 44px; height: 44px; min-width: 44px; background: var(--bg-panel); border: 1px solid var(--border-main); border-radius: 50%; display: flex; align-items: center; justify-content: center; box-shadow: 0 4px 10px rgba(0,0,0,0.3); cursor: pointer;}
#mitreTab img {width: 24px; height: 24px; border-radius: 15%;}
#mitreContent {margin-left: 0px; padding: 10px 12px; background: var(--bg-panel); border: 1px solid var(--border-main); border-radius: 6px; box-shadow: 0 4px 10px rgba(0,0,0,0.3); font-size: 13px; line-height: 1.4;}
#mitreContent a {font-weight: bold; color: var(--link-normal);}
#mitreContent a:hover {color: var(--red); text-decoration: underline;}

table {width: 100%; border-collapse: collapse; table-layout: fixed; background: var(--bg-panel);}
th, td {border: 1px solid var(--border-main); padding: 8px; vertical-align: top;}
th {position: sticky; top: 0; z-index: 2; background: var(--bg-header); font-weight: bold;}
tr:nth-child(even) td {background: var(--row-even);}
tr:hover td {background: var(--row-hover);}
td.query pre {cursor: pointer; position: relative;}
td.query pre:hover {outline: 2px dashed var(--border-main); outline-offset: 2px;}
td.query pre::after {content: "Click to copy query"; position: absolute; top: 6px; right: 8px; font-size: 11px; color: var(--text-muted); opacity: 0; pointer-events: none;}
td.query pre:hover::after {opacity: 1;}
.copy-badge {position: absolute; bottom: 6px; right: 8px; font-size: 11px; font-weight: bold; color: var(--green); background: var(--bg-panel); border: 1px solid var(--border-main); border-radius: 4px; padding: 2px 6px; opacity: 0; transition: opacity 0.2s ease; pointer-events: none;}

pre {white-space: pre-wrap; word-break: break-word; overflow-wrap: anywhere; font-family: Consolas, monospace; font-size: 12px; background: var(--bg-code); padding: 10px; border: 1px solid var(--border-main); border-radius: 6px; color: inherit;}

.stats-table {width: auto; table-layout: auto; border-collapse: separate; background: none;}
.stats-table td {border: none; padding-right: 24px; vertical-align: top; white-space: nowrap;}
.stats-table tr:hover td {background: unset;}
.hidden {visibility: hidden; pointer-events: none;}

.stat-green {color: var(--green);}
.stat-red {color: var(--red);}
.stat-gray {color: #888;}
.stat-muted {color: var(--text-muted);}

.filter-header {font-weight: bold; margin-top: 20px; display: block; cursor: default;}
.reverse-filter {color: #666;}
.reverse-filter.active {font-weight: bold; font-style: italic; text-decoration: underline;}
.clear-filters {margin-top: 0px; display: block; color: var(--text-muted);}
.clear-filters:hover {color: var(--text-main);}

.sev-info {color: var(--text-main);}
.sev-low {color: #ff8c00;}
.sev-medium {color: var(--yellow);}
.sev-high {color: var(--red);}
.stat-yellow {color: var(--yellow);}

.toggle {cursor: pointer; user-select: none;}
.toggle:hover {text-decoration: underline; cursor: pointer;}
.toggle.active {font-weight: bold; font-style: italic; text-decoration: none;}
.toggle:hover.active {text-decoration: underline;}

.severity-donut {position: relative; width: 120px; height: 120px; margin-top: 6px;}
.donut {position: relative; width: 100%; height: 100%; border-radius: 50%; background: conic-gradient(#ffffff 0deg 45deg, #ff8c00 45deg 135deg,#ffd166 135deg 260deg, #d32f2f 260deg 360deg);}
.donut::before {content: ""; position: absolute; inset: 30%; background: var(--bg-panel); border-radius: 50%;}
.donut-label {position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: bold; text-align: center; color: var(--text-muted); pointer-events: none;}

.kv {margin-bottom: 4px;}
.kv .val {margin-left: 6px; color: var(--text-muted);}

.toc-toggle {cursor: pointer; user-select: none; display: inline-flex; align-items: center; gap: 6px;}
.toc-arrow {font-size: 0.9em; transition: transform 0.2s ease;}
.toc-collapsed .toc-arrow {transform: rotate(-900deg);}
.toc-collapsed #tocContent {display: none;}
.toc ul {column-count: 3; column-gap: 30px;}

.enabled-true {font-size: 16px; color: var(--green); font-weight: bold;}
.enabled-false {font-size: 16px; color: var(--red); font-weight: bold;}

.template-version {font-size: 13px; color: var(--text-muted);}

.description {font-size: 16px; color: var(--text-muted);}

/* BACK TO TOP */
#backToTop {position: fixed; bottom: 20px; right: 20px; padding: 10px 14px; background-color: #064; color: #fff; font-size: 12px; font-weight: bold; border-radius: 6px; cursor: pointer; display: none; box-shadow: 0 4px 10px rgba(0,0,0,0.6); z-index: 1000;}
#backToTop:hover {background-color: #0a6;}

/* LINKS (privacy-safe + status-safe) */
a {text-decoration: none;}
a:visited {color: var(--link-visited);}
a:hover {color: var(--red); text-decoration: underline;}
a:active {color: var(--link-active); text-decoration: underline;}

/* Force enabled-false to NEVER change */
a.enabled-false {text-decoration: none;}
a.enabled-false:visited {color: #bb4444}
a.enabled-false:hover {text-decoration: underline;}
a.enabled-false:active {color: var(--link-active); text-decoration: underline;}

/* Theme toggle */
#themeToggle {position: fixed; top: 20px; right: 20px; padding: 6px 10px; font-size: 16px; border-radius: 6px; border: 1px solid var(--border-main); background: var(--bg-panel); color: var(--text-main); cursor: pointer; z-index: 1001;}

/* Manual override beats system preference */
:root[data-theme="light"] {--bg-main: #ffffff; --bg-panel: #f9f9f9; --bg-header: #f1f1f1; --bg-code: #f6f6f6; --border-main: #cccccc; --text-main: #222222; --text-muted: #555555; --green: #1b7f1b; --red: #c00000; --yellow: #b8860b; --row-even: #f0f0f0; --row-hover: #e6ecff; --link-normal: #0000FF; --link-hover: #ff0000; --link-visited: #000088; --link-active: #009900; color-scheme: light;}

:root[data-theme="dark"] {--bg-main: #0e0e0e; --bg-panel: #141414; --bg-header: #1f1f1f; --bg-code: #161616; --border-main: #2a2a2a; --text-main: #e6e6e6; --text-muted: #aaa; --green: #6ddf7c; --red: #ff6b6b; --yellow: #ffd166; --row-even: #222222; --row-hover: #303055; --link-normal: #aabbee; --link-hover: #995599; --link-visited: #6666bb; --link-active: #ffff00; color-scheme: dark;}
</style>

<meta name="color-scheme" content="light dark">
</head>

<body>
<h1>Azure Sentinel Analytics Rules</h1>

<button id="themeToggle" title="Toggle light/dark mode">🌙</button>
<div id="mitrePanel"><div id="mitreTab"><img
src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAMAAABF0y+mAAAAZlBMVEUIWKUAU6MAVaRvkcEOXKddhbs9cbFLerX///+Rqs4AUaK5yd8ATaAAUKKLpcvr8PYARp6asdLe5vAASJ9VgLjx9fkASp/C0OPJ1ud5mMSpvNgATqH3+vzS3esAQpyAnsdwksEdYqql8pYrAAAA80lEQVR4AWIYQABojqwSJYRhAEjlLYNL1p37X/I1xW+w81OLDMEYM2+tMXb/6Jzz4878OXfYvtoUyPK49UBRbh6rGmjauO2AXjaPZUHgqMXkROC8eZSewOWsHVG2TUsi4UauKDez+hyAqKQ6yv2xPOY3eL5UKepc4bU2fdyhd6r0PoWHDzxX3fMLircqHYFvCvjFSJ5Qt8VYkbMBnJl9BiDNJ6t7KQ101ezjgEfS9tMnlhe4zkaq2Ms4Q/o2qTIVn32u46gNgTpPrGrNQu0J6tDjfAG0VzUPOuB5koa9PT5P8WepUagwIiI2aouUYyMRk/wg/29jDlzI7K5BAAAAAElFTkSuQmCC" alt="MITRE ATT&CK"/></div>

<div id="mitreContent"><p><a href="https://mitre-attack.github.io/attack-navigator/" target="_blank" rel="noopener noreferrer">MITRE ATT&amp;CK Navigator</a><br><br>
Copy path to: <a href="#" id="copyNavigatorPath">report_navigator.json</a><span id="copyStatus" style="margin-left:6px; color: var(--text-muted);"></span><br>
<span style="font-size:12px; color:var(--text-muted);">(Use in “Open Existing Layer”)</span></p></div></div>

$statsBlock

<div class="toc-wrapper"><h2 id="tocToggle" class="toc-toggle">Table of Contents <span class="toc-arrow">▼</span></h2>
<div id="tocContent" class="toc"><ul>$script:toc</ul></div></div><br>

<table id="rulesTable">
<colgroup><col style="width:15%;"><col style="width:42.5%;"><col style="width:42.5%;"></colgroup>

<thead>
<tr><th>Rule Name</th><th>Query Logic</th><th>Properties</th></tr>
</thead>

<tbody>
$script:rows
</tbody>
</table>

<div id="backToTop" onclick="scrollToTop()">↑ Back to top ↑</div>

<script>
function scrollToTop() {const duration = 400; const start = window.scrollY; const startTime = performance.now();

function animateScroll(currentTime) {const elapsed = currentTime - startTime; const progress = Math.min(elapsed / duration, 1);
const ease = 1 - Math.pow(1 - progress, 3);
window.scrollTo(0, start * (1 - ease));
if (progress < 1) {requestAnimationFrame(animateScroll);}}
requestAnimationFrame(animateScroll);}
window.addEventListener('scroll', function () {const btn = document.getElementById('backToTop');
if (window.scrollY > 300) {btn.style.display = 'block';}
else {btn.style.display = 'none';}});

(function () {const toggle = document.getElementById('themeToggle'); if (!toggle) return; // <-- prevents silent failure
const root = document.documentElement;
const stored = localStorage.getItem('theme'); if (stored === 'dark' || stored === 'light') {root.setAttribute('data-theme', stored);}
else {root.setAttribute('data-theme', 'dark');}

function updateIcon() {toggle.textContent = root.getAttribute('data-theme') === 'dark' ? '☀️' : '🌙';}

toggle.addEventListener('click', () => {const current = root.getAttribute('data-theme'); const next = current === 'dark' ? 'light' : 'dark'; root.setAttribute('data-theme', next); localStorage.setItem('theme', next); updateIcon();});
updateIcon();})();

(function () {const toggles = document.querySelectorAll('.toggle');
const severityToggles = document.querySelectorAll('.toggle[data-filter^="sev-"]');
const rows = document.querySelectorAll('#rulesTable tbody tr');
const clearBtn = document.getElementById('clearFilters');
const reverseBtn = document.getElementById('reverseFilters');
const filterHeader = document.getElementById('filterHeader');
const visibleCountEl = document.getElementById('visibleRuleCount');
const activeFilters = new Set();
let reverseMode = false;

function applyFilters() {const hasFilters = activeFilters.size > 0 || reverseMode;
if (!hasFilters) {rows.forEach(r => {r.style.display = '';});}
else {rows.forEach(row => {let visible = true;

activeFilters.forEach(filter => {switch (filter) {case 'disabled': if (row.dataset.enabled !== 'False') visible = false; break;
case 'nrt': if (row.dataset.kind !== 'NRT') visible = false; break;
case 'template': if (!row.dataset.templateVersion) visible = false; break;
case 'sev-informational': if (row.dataset.severity !== 'Informational') visible = false; break;
case 'sev-low': if (row.dataset.severity !== 'Low') visible = false; break;
case 'sev-medium': if (row.dataset.severity !== 'Medium') visible = false; break;
case 'sev-high': if (row.dataset.severity !== 'High') visible = false; break;}});

if (reverseMode) {visible = !visible;}
row.style.display = visible ? '' : 'none';});}

const showControls = activeFilters.size > 0; clearBtn.classList.toggle('hidden', !showControls); 
if (reverseBtn) reverseBtn.classList.toggle('hidden', !showControls);
if (filterHeader) filterHeader.classList.toggle('hidden', !showControls);
if (visibleCountEl) {const visibleRows = Array.from(rows)
.filter(r => r.style.display !== 'none')
.length;
visibleCountEl.textContent = 'Visible Rules: ' + visibleRows;}}

/* Filter toggle handlers */
toggles.forEach(t => {t.addEventListener('click', () => {const filter = t.dataset.filter;
if (!filter) return; const isSeverity = filter.indexOf('sev-') === 0;
if (activeFilters.has(filter)) {activeFilters.delete(filter); t.classList.remove('active');}
else {if (isSeverity) {severityToggles.forEach(st => {const sevFilter = st.dataset.filter;
if (activeFilters.has(sevFilter)) {activeFilters.delete(sevFilter); st.classList.remove('active');}});}
activeFilters.add(filter); t.classList.add('active');}
applyFilters();});});

/* Reverse Filters handler */
if (reverseBtn) {reverseBtn.addEventListener('click', () => {if (activeFilters.size === 0) return;
reverseMode = !reverseMode; reverseBtn.classList.toggle('active', reverseMode); applyFilters();});}

/* Clear Filters handler */
clearBtn.addEventListener('click', () => {activeFilters.clear(); reverseMode = false;
toggles.forEach(t => t.classList.remove('active'));
if (reverseBtn) reverseBtn.classList.remove('active'); rows.forEach(r => (r.style.display = '')); 

clearBtn.classList.add('hidden');
if (reverseBtn) reverseBtn.classList.add('hidden');
if (filterHeader) filterHeader.classList.add('hidden');
if (visibleCountEl) {visibleCountEl.textContent = 'Visible Rules: ' + rows.length;}});})();

(function () {const tocToggle = document.getElementById('tocToggle'); const tocWrapper = document.querySelector('.toc-wrapper');
if (!tocToggle || !tocWrapper) return;
tocToggle.addEventListener('click', () => {tocWrapper.classList.toggle('toc-collapsed');});})();

(function () {const link = document.getElementById('copyNavigatorPath');
const status = document.getElementById('copyStatus');
if (!link || !navigator.clipboard) return;
link.addEventListener('click', function (e) {e.preventDefault(); const url = new URL('report_navigator.json', window.location.href).href;
navigator.clipboard.writeText(url).then(() => {status.textContent = '✔ copied';
setTimeout(() => status.textContent = '', 2000);},
() => {status.textContent = '✖ failed';
setTimeout(() => status.textContent = '', 2000);});});})();

(function () {if (!navigator.clipboard) return;
document.addEventListener('click', function (e) {const pre = e.target.closest('td.query pre');
if (!pre) return; const text = pre.innerText.trim();
if (!text) return; navigator.clipboard.writeText(text).then(() => {showCopied(pre);});});

function showCopied(pre) {let badge = pre.querySelector('.copy-badge');
if (!badge) {badge = document.createElement('div'); badge.className = 'copy-badge'; badge.textContent = '✔ Copied'; pre.appendChild(badge);}

badge.style.opacity = '1';

setTimeout(() => {badge.style.opacity = '0';}, 1200);}})();
</script>
<br><span style="font-size: 11px;">AllKQLtoHTML is provided free for commercial and personal use, under the MIT License, Copyright © 2026 by Craig Plath. All rights reserved.</span>
</body></html>
"@

Set-Content -Path $OutputFile -Value $html -Encoding UTF8
Write-Host -f cyan "`n✅ Generated $OutputFile`n"}
writepage

exportnavigatorlayer -OutputPath "report_navigator.json"
Invoke-Item $OutputFile}

Set-Alias SentinelRules AllKQLtoHTML

Export-ModuleMember -Function allkqltohtml
Export-ModuleMember -Alias sentinelrules

# Helptext.
<#
## Overview
This script will read Sentinel JSON files containing Analytics rules and create a single page HTML output for easy search and reference.

Usage: AllKQLtoHTML <file1.json> <file2.json> <outfile.html> <-concat> <-merge> <-usage> <-help>

File1 defaults to: Azure_Sentinel_analytics_rules.json
This is the Sentinel UI export default filename.

Outfile detaults to:	AllSentinelRules.html
As with all of these files, a user-provided name can be provided, instead.

File2 defaults to:	 All_Azure_Sentinel_rules.json
This is the default name the script expects for a Webshell export.

## Azure Webshell JSON export
If you wish to use an export from the Azure Webshell, you will need to run PowerShell from portal.azure.com and enter the following commmand:

az sentinel alert-rule list --resource-group 'RG-<env>-<region>-<service>' --workspace-name 'LAW-<env>-<region>-<workload>' --subscription 'ffffffff-ffff-ffff-ffff-ffffffffffff' -o json > All_Azure_Sentinel_rules.json

To acquire your Subscription ID, you can run the following command in Azure Cloudshell:

az account show --query id -o tsv

To acquire your Resource Group and Workspace names, navigate in Sentinel to the Overview page. Once you have these values you can add them to the PSD1 file for future reference.
## Using the -merge switch
If you provide the -merge switch, you should also provide a second JSON file. Without the -merge switch, the second JSON file is ignored.

When merging, the two files can be any combination of an Azure WebShell export or Sentinel UI export, because the script is designed to handle both JSON formats, interchangeably. If you need to merge more than 2 files, it is best that you merge the files of similar JSON format manually first, and then run the script to complete the remaining tasks.
## Using the concat(enate) switch
Concatenation in this case is not the same as merge. It is used exclusively for Sentinel UI exports of the ARM formatted JSON files.

When using the Sentinel UI, you will only be able to export a maximum of 50 rules at a time. Using this feature you can combine multiple files into a single ARM JSON file with ease. Simply select all rules, export the contents, navigate to the next page and do the same. Do not change the file name. Let Windows append the usual suffix (1), (2), and so on, until you're done. This script is designed to read those file names and merge them for you, after which it will proceed with the remaining tasks and file generation.

Example:
Azure_Sentinel_analytics_rules .json	
Azure_Sentinel_analytics_rules (1).json	
Azure_Sentinel_analytics_rules (2).json	

Output:
Azure_Sentinel_analytics_rules_combined.json
## Webpage Statistics & Filtering
The webpage created by this tool provides the following features:

• A light and dark theme toggle is provided in the top right corner.

• Rules counts of: all rules, disabled rules, NRT rules, rules adapted from templates

• Severity breakdown counts: informational, low, medium, high

• Donut chart visualizing the breakdown of rules by Severity.

• By clicking options in the Rule Overview, the list of rules displayed can be filtered accumatively.

• By clicking rule severity levels, the list of rules displayed can be filtered exclusively.

• A live count of visible rules is displayed below the Severity counts.

• Clicking on an active filter undoes the filter.

• Whenever any filter is active two more options appear; one that allows you to invert the current filter, and a second to clear all filters. (Refreshing the page will also clear all filters.)
## Webpage Navigation
The main body of the webpage consists of the following components:

• A Table of Contents provides a three column list of all rules included, alphabetically. This table can be expanded and collapsed by clicking on the title and each rule is a hyperlink to the rule details in the table below.

• Keep in mind that if a rule is currently filtered out from being displayed, then clicking a link to that hidden rule will not allow you to navigate to it.

• The main body of the page is a three column table containing all of the details of each rule.

• Column one contains the rule name, description, enabled status, severity and template version number, if applicable.

• Column 2 provides the rule query logic.

• Clicking on a query in this second column will copy its contents to the clipboard, so that it can be used in Sentinel Advanced Hunting or Microsoft Defender, saving time.

• The third column provides all other rule configuration items, including the Mitre TTPs.

• Due to the large nature of the page a "Back to top" button is located in the bottom right corner of the screen once the page is scrolled down far enough.

## Mitre ATT&CK Mapping
• Rolling over the Mitre ATT&CK logo in the top, right side of the page will provide a pop-out menu that allows you to copy the path to the "report_navigator.json" file, which should be located in the same directory as the webpage into the clipboard.
• Additionally provided is a hyperlink to the Mitre ATT&CK Navigator, which will allow you to load the aforementioned file in order to see a heatmap of your current rule coverage.
## License
MIT License

Copyright (c) 2025 Craig Plath

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
##>
