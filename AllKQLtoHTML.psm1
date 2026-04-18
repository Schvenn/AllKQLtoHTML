function AllKQLtoHTML ([string]$InputFile  = "Azure_Sentinel_analytics_rules.json", [string]$MergeInputFile = "All_Azure_Sentinel_rules.json", [string]$OutputFile = "AllSentinelRules.html", [switch]$Concat, [switch]$Merge, [switch]$Usage, [switch]$help) {#Convert Sentinel JSON exports to an HTML file for easy searching with CTRL+F

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
if ($usage) {Write-Host -f cyan "`nUsage: AllKQLtoHTML <file1.json> <file2.json> <outfile.html> <-concat> <-merge> <-usage> <-help>`n";return}

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
while ($true) {cls; Write-Host -f cyan "$(Get-ChildItem (Split-Path $PSCommandPath) | Where-Object { $_.FullName -ieq $PSCommandPath } | Select-Object -ExpandProperty BaseName) Help Sections:`n"

if ($sections.Count -gt 7) {$half = [Math]::Ceiling($sections.Count / 2)
for ($i = 0; $i -lt $half; $i++) {$leftIndex = $i; $rightIndex = $i + $half; $leftNumber  = "{0,2}." -f ($leftIndex + 1); $leftLabel   = " $($sections[$leftIndex].Groups[1].Value)"; $leftOutput  = [string]::Empty

if ($rightIndex -lt $sections.Count) {$rightNumber = "{0,2}." -f ($rightIndex + 1); $rightLabel  = " $($sections[$rightIndex].Groups[1].Value)"; Write-Host -f cyan $leftNumber -n; Write-Host -f white $leftLabel -n; $pad = 40 - ($leftNumber.Length + $leftLabel.Length)
if ($pad -gt 0) {Write-Host (" " * $pad) -n}; Write-Host -f cyan $rightNumber -n; Write-Host -f white $rightLabel}
else {Write-Host -f cyan $leftNumber -n; Write-Host -f white $leftLabel}}}

else {for ($i = 0; $i -lt $sections.Count; $i++) {Write-Host -f cyan ("{0,2}. " -f ($i + 1)) -n; Write-Host -f white "$($sections[$i].Groups[1].Value)"}}

# Display Header.
line yellow 100
if ($lines.Count -gt 0) {Write-Host  -f yellow $lines[0]}
else {Write-Host "Choose a section to view." -f darkgray}
line yellow 100

# Display content.
$end = [Math]::Min($position + $pageSize, $wrappedLines.Count)
for ($i = $position; $i -lt $end; $i++) {Write-Host -f white $wrappedLines[$i]}

# Pad display section with blank lines.
for ($j = 0; $j -lt ($pageSize - ($end - $position)); $j++) {Write-Host ""}

# Display menu options.
line yellow 100; Write-Host -f white "[↑/↓]  [PgUp/PgDn]  [Home/End]  |  [#] Select section  |  [Q] Quit  " -n; if ($inputBuffer.length -gt 0) {Write-Host -f cyan "section: $inputBuffer" -n}; $key = [System.Console]::ReadKey($true)

# Define interaction.
switch ($key.Key) {'UpArrow' {if ($position -gt 0) { $position-- }; $inputBuffer = ""}
'DownArrow' {if ($position -lt ($wrappedLines.Count - $pageSize)) { $position++ }; $inputBuffer = ""}
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
if (-not $directory) { $directory = Get-Location }

$baseName  = [IO.Path]::GetFileNameWithoutExtension($InputFile)
$extension = [IO.Path]::GetExtension($InputFile)

# Find Windows-style copies: file.json, file (1).json, etc.
$files = Get-ChildItem -Path $directory -File | Where-Object {$_.Name -match "^$([Regex]::Escape($baseName))(\s\(\d+\))?$([Regex]::Escape($extension))$"} | Sort-Object Name
if ($files.Count -lt 2) {Write-Host -f Cyan "`nNo files were found to concatenate.`n"
return}
$outFile = Join-Path $directory "$baseName`_combined$extension"
if (Test-Path $outFile) { Remove-Item $outFile -Force }

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

function Format-Properties {param ($Properties)
$exclude = @('displayName', 'query', 'description', 'enabled')
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
$mergeRules = $mergeRules | ForEach-Object { Normalize-RuleObject $_ }}}
loadandnormalize

# Merge using Sentinel rule GUID.
function mergedata {$ruleMap = @{}
foreach ($r in $script:rules) {$uid = Get-RuleUID $r
if ($uid) {$ruleMap[$uid] = $r}}

foreach ($r in $mergeRules) {$uid = Get-RuleUID $r
if ($uid -and -not $ruleMap.ContainsKey($uid)) {$ruleMap[$uid] = $r}}

$script:rules = $ruleMap.Values}
mergedata

# Caclulate statistics.
function statistics {$script:ruleCount = $script:rules.Count
$script:disabledCount = ($script:rules | Where-Object { $_.enabled -eq $false }).Count
$script:nrtCount      = ($script:rules | Where-Object { $_.kind -eq 'NRT' }).Count}
statistics

# Sort rules alphabetically.
$script:rules = $script:rules | Sort-Object -Property displayName -Culture en-US

# Build rows.
function buildrows {$script:rows = ""; $script:toc = ""
foreach ($r in $script:rules) {if (-not ($r.displayName -and $r.query)) {continue}
$name = Escape-Html $r.displayName
$id   = ($r.displayName -replace '[^a-zA-Z0-9_-]', '_')
$qry  = Escape-Html $r.query
$desc = Escape-Html $r.description
$enabled = $r.enabled
if ($enabled -eq $true) {$enabledText = "<span class='enabled-true'>true</span>"}
else {$enabledText = "<span class='enabled-false'>false (Disabled)</span>"}
$props = Format-Properties $r
if ($r.enabled -eq $true) {$script:toc += "<li><a href='#$id'>$name</a></li>`n"}
else {$script:toc += "<li><a href='#$id' class='enabled-false'>$name</a></li>`n"}
$script:rows += @"
<tr id="$id">
<td class="rulename"><strong>$name</strong><br><br>
<span class="description">$desc</span><br><br>
<span>Enabled: $enabledText</span>
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
<div class="toc-stats"><strong><span class="stat-green">Rule Count: $ruleCount</span><br>
<span class="stat-red">Disabled Rules: $disabledCount</span><br>
<span class="stat-yellow">NRT Rules: $nrtCount</span></strong><br></div>
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
body {font-family: Arial, sans-serif; margin: 20px;}
table {width: 100%; border-collapse: collapse; table-layout: fixed;}
th, td {border: 1px solid #ccc; padding: 8px; vertical-align: top;}
th {background: #f4f4f4;}
pre {white-space: pre-wrap; word-break: break-word; overflow-wrap: anywhere; font-family: Consolas, monospace; font-size: 12px; background: #fafafa; padding: 8px; border: 1px solid #eee;}
.stat-green {color: #1b7f1b;}
.stat-red {color: #c00000;}
.stat-yellow {color: #b8860b;}
.kv {margin-bottom: 4px;}
.kv .val {margin-left: 6px;}
.toc ul {column-count: 3; column-gap: 30px;}
.enabled-true {font-size: 16px; color: green; font-weight: bold;}
.enabled-false {font-size: 16px; color: red; font-weight: bold;}
.description {font-size: 16px; color: #555;}
#backToTop {position: fixed; bottom: 20px; right: 20px; padding: 10px 14px; background-color: #050; color: #fff; font-size: 12px; font-weight: bold; border-radius: 6px; cursor: pointer; display: none; box-shadow: 0 2px 6px rgba(0,0,0,0.3); z-index: 1000;}
#backToTop:hover {background-color: #3A3;}
</style>
</head>

<body>
<h1>Azure Sentinel Analytics Rules</h1>

<h2>Table of Contents</h2>

$statsBlock

<div class="toc"><ul>$script:toc</ul></div>

<br>

<table>
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
</script>

</body></html>
"@

Set-Content -Path $OutputFile -Value $html -Encoding UTF8
Write-Host -f cyan "`n✅ Generated $OutputFile`n"}
writepage

Invoke-Item $OutputFile}

Set-Alias SentinelRules AllKQLtoHTML

# Helptext.
<#
## Overview
This script will read Sentinel JSON files containing Analytics rules and create a single page HTML output for easy search and reference.

Usage: AllKQLtoHTML <file1.json> <file2.json> <outfile.html> <-concat> <-merge> <-usage> <-help>

File1 defaults to:      Azure_Sentinel_analytics_rules.json
This is the Sentinel UI export default filename.

Outfile detaults to:	AllSentinelRules.html
As with all of these files, a user-provided name can be provided, instead.

File2 defaults to:	    All_Azure_Sentinel_rules.json
This is the default name the script expects for a Webshell export.

## Azure Webshell JSON export (PowerShell version)
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
