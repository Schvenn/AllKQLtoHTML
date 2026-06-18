function AllKQLtoHTML ([string]$InputFile = "Azure_Sentinel_analytics_rules.json", [string]$MergeInputFile = "All_Azure_Sentinel_rules.json", [string]$OutputFile = "AllSentinelRules.html", [switch]$Concat, [switch]$Merge, [switch]$PreserveIds, [switch]$CreateCSV, [switch]$CreateLinks, [switch]$Usage, [switch]$GetAZCommand, [switch]$help) {#Convert Sentinel JSON exports to an HTML file for easy searching with CTRL+F.

# -------------------------- HELPER FUNCTIONS -----------------------------------------------------

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

# Inline help.
function help {# Select content.
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

# Ensure HTML code is displayable.
function Escape-Html {param ([string]$Text)
if ($null -eq $Text) {return ""}
return $Text -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'}

# Ensure Unicode characaters are displayable.
function Normalize-UnicodeDecorations ([string]$text) {if ($null -eq $text) {return $text}
try {return [Text.Encoding]::UTF8.GetString([Text.Encoding]::GetEncoding(1252).GetBytes($text))}
catch {return $text}}

# Colourize KQL logic.
function Highlight-KqlComments {param([string]$text);
# Store Comment lines.
$comments = @{}; $text = [regex]::Replace($text, '(?m)(?<!:)\/\/.*$', {param($m); $key = "###CMT_{0}###" -f $m.Index; $comments[$key] = $m.Value; return $key})
# Operators
$text = $text -replace '([\w\s])(\>=?|\<=?|\!(~|=)|=~|={1,3})', '$1 <span class="kql-operators">$2</span> '
# Tables (with optional predecates)
$text = $text -replace '(?im)(^(find|join|lookup|materialize|search|union)?)(\x28?\s*)(\w+)(\s*\r?\n)', '<span class="kql-data">$1</span>$3<span class="kql-table">$4</span>$5'
# Serialize
$text = $text -replace '(?im)(^\x28?\s*)(serialize)(\s*\r?\n)', '$1<span class="kql-structure">$2</span>$3'
# Structure (always followed by a space)
$text = $text -replace '(?im)(\s*\x7C?\s*)(case|evaluate|extend|facet|fork|invoke|isfuzzy|join( kind=\w+)?|let|limit|lookup|mv-(apply|expand)|parse-where|partition|project(-\w+)?|range|reduce|render|scan|search|sample(-distinct)?|serialize|step|summarize|(sort|order)\sby|take|top(-hitters|nested)?|union|where)\s', '$1<span class="kql-structure">$2</span> '
# Filters (followed by a space, but sometimes a bracket)
$text = $text -replace '(?im)(\W)(and( not)?|as|between|by|contains|distinct|(ends|starts)with|has(_any|prefix|suffix)?|!?in~?|matches regex|not|on|or|with)([\s\x28])', '$1<span class="kql-filters">$2</span>$6'
# Data (always followed by a bracket)
$text = $text -replace '(?im)(\s*)(ago|arg_(max|min)|array_(\w+)?|avg(if)?|bag_unpack|bin|coalesce|column_ifexists|d?count(if)?|datatable|datetime_diff|(end|start)ofday|(to)?dynamic|externaldata|extract|extract(_all)?|format_datetime|_getwatchlist|iff|iif|indexof|is(not)?(empty|null)|make_(list|set)|max(if)?|min(if)?|now|pack(_all|_array)|parse(_\w+)?|partition|percentiles?|rand|repeat|replace(_regex|_string)?|reverse|round|row_number|session_count|set_has_element|split|stdev|strcat(_array|_delim)?|strlen|substring|sum(if)?|take_any(if)?|to(bool|date|guid|dynamic|double|int|long|lower|real|scalar|string|time|upper)|translate|trim|unixtime_milliseconds_todatetime|url_(de|en)code|variance|zip)(\s*\x28)', '$1<span class="kql-data">$2</span>('
# Brackets
$text = $text -replace '([\x28\x29\x5B\x5D\x7B\x7D]|@[\x22\x27]|[\x22\x27]@)', '<span class="kql-brackets">$1</span>'
# Pipes (Conditional)
$lines = $text -split "`r?`n"
$text = ($lines | ForEach-Object {$line = $_
$regexMatch = [regex]::Match($line, '(?i)(regex|replace)')
$hasRegex = $regexMatch.Success
$regexPos = if ($hasRegex) {$regexMatch.Index} else {[int]::MaxValue}
if ($line -match '\|') {$line = [regex]::Replace($line, '\|', {param($m)
if ($hasRegex -and $m.Index -gt $regexPos) {'<span class="kql-brackets">|</span>'}
else {'<span class="kql-pipe">|</span>'}})}
$line}) -join "`r`n"
# Restore Comment lines and then highlight them.
foreach ($key in $comments.Keys) {$text = $text -replace [regex]::Escape($key), "<span class='kql-comment'>$($comments[$key].TrimEnd("`r","`n"))</span>"}
$text = $text -replace '  ',' '
return $text;}

# Get valid or generate unique GUIDs for each rule.
function Get-RuleUID {param ($r)
if ($PreserveIds) {if ($r.name -and $r.name -match '([0-9a-fA-F-]{36})') {return $matches[1].ToLower()}
if ($r.id -and $r.id -match '/alertRules/([0-9a-fA-F-]{36})') {return $matches[1].ToLower()}}
return ([guid]::NewGuid().ToString()).ToLower()}

# Convert Description URLs to clickable links for column 1.
function Convert-UrlsToLinks {param ([string]$Text)
if ([string]::IsNullOrWhiteSpace($Text)) {return $Text}
$urlPattern = '(https?:\/\/[^\s<]+)'
return ($Text -replace $urlPattern, '<a href="$1" target="_blank">$1</a>')}

# Get or build Wiki/KB article links for column 1.
function Get-RuleWikiLink ([string]$DisplayName, [string]$RuleGuid) {if (-not $CreateLinks) {return $null}
if ($RuleGuid) {$lookupGuid = $RuleGuid.ToString().Trim().Trim('{}').ToLower()
if ($script:wikiLinks.ContainsKey($lookupGuid)) {$link = $script:wikiLinks[$lookupGuid]
if (-not [string]::IsNullOrWhiteSpace($link)) {return $link}}}
if (-not $config.PrivateData.WikiIntegration.Fallback) {return $null}
if (-not $config.PrivateData.WikiIntegration.BaseUrl) {return $null}

$name = $DisplayName.Trim()

switch ($config.PrivateData.WikiIntegration.Separator) {"underscore" {$name = $name -replace '\s+', '_'}
"dash" {$name = $name -replace '\s+', '-'}
"html" {$name = [uri]::EscapeDataString($name)}
"slug" {$name = $name.ToLower()
$name = $name -replace '[^a-z0-9\s-]', ''
$name = $name -replace '\s+', '-'
$name = $name -replace '-+', '-'}
default {$name = [uri]::EscapeDataString($name)}}
$base = $config.PrivateData.WikiIntegration.BaseUrl
$suffix = $config.PrivateData.WikiIntegration.Suffix
return "$base$name$suffix"}

# Recursively expand JSON values deep enough to see all levels.
function Expand-PropertyValue {param($Value, [int]$Depth = 0)
if ($null -eq $Value) {return "{null}"}
if ($Value -is [string]) {if ([string]::IsNullOrWhiteSpace($Value)) {return "{null}"}
return $Value}
if ($Value -is [array]) {if ($Value.Count -eq 0) {return "{null}"}
return ($Value | ForEach-Object {Expand-PropertyValue $_ ($Depth + 1)}) -join "`n"}
if ($Value -is [psobject]) {$pairs = foreach ($p in $Value.PSObject.Properties) {$expanded = Expand-PropertyValue $p.Value ($Depth + 1)
if ([string]::IsNullOrWhiteSpace($expanded)) {"$($p.Name): {null}"}
else {"$($p.Name): $expanded"}}
if (-not $pairs -or $pairs.Count -eq 0) {return "{null}"}
return ($pairs -join "`n")}
return "$Value"}

# Create key/value pairs for column 3 and provide special formatting instructions for specific rows.
function Format-Properties {param ($Properties)
$exclude = @('displayName', 'query', 'description', 'enabled', 'severity', 'templateVersion'); $out = ""

foreach ($p in $Properties.PSObject.Properties) {if ($exclude -contains $p.Name) {continue}
$key = Escape-Html $p.Name; $val = $p.Value

# ---------------- ALERTDETAILS MAPPINGS ----------------------------------------------------------
if ($p.Name -eq "alertDetailsOverride") {$lines = foreach ($item in $val.PSObject.Properties) {$k = Escape-Html $item.Name; $v = $item.Value
if ($null -eq $v -or [string]::IsNullOrWhiteSpace("$v")) {$v = "{null}"}
if ($v -is [array]) {$v = ($v | ForEach-Object {"$_"}) -join ', '}
elseif ($v -is [psobject] -and -not ($v -is [string])) {$v = Expand-PropertyValue $v}
if ($k -match 'Severity|ColumnName|Field|Property' -and $v -ne "{null}") {$v = "<span class='ent-col'>$v</span>"}
$v = $v -replace '{{([^}]+)}}', "{{<span class='ent-col'>`$1</span>}}"; 
if ($v -ne "{null}") {"$k`: <span class='alert-col'>$v</span>"}
else {"$k`: $v"}}
$valText = $lines -join "`n"}

# ---------------- ENTITY MAPPINGS ----------------------------------------------------------------
elseif ($p.Name -eq "entityMappings") {$lines = foreach ($mapping in $val) {$entityType = Escape-Html $mapping.entityType
foreach ($field in $mapping.fieldMappings) {$identifier = Escape-Html $field.identifier; $column = Escape-Html $field.columnName; "$entityType`: $identifier`: <span class='ent-col'>$column</span>"}}
$valText = $lines -join "`n"}

# ---------------- CUSTOM DETAILS -----------------------------------------------------------------
elseif ($p.Name -eq "customDetails") {$lines = foreach ($item in $val.PSObject.Properties) {$k = Escape-Html $item.Name; $v = Escape-Html $item.Value; "$k : <span class='ent-col'>$v</span>"}
$valText = $lines -join "`n"}

#----------------- INCIDENT CONFIGURATION ---------------------------------------------------------
elseif ($p.Name -eq "incidentConfiguration") {$lines = foreach ($item in $val.PSObject.Properties) {if ($item.Name -ne "groupingConfiguration") {"$($item.Name): $(Expand-PropertyValue $item.Value)"
continue}
foreach ($g in $item.Value.PSObject.Properties) {if ($g.Name -in @("groupByEntities","groupByAlertDetails","groupByCustomDetails")) {$items = @($g.Value)
$itemList = @($items | ForEach-Object {"<span class='ent-col'>$(Escape-Html $_)</span>"}) -join ', '
"$($g.Name): $itemList"}
else {"$($g.Name): $(Expand-PropertyValue $g.Value)"}}}
$valText = $lines -join "`n"}

# ---------------- MITRE ENRICHMENT ---------------------------------------------------------------
elseif ($p.Name -in @('techniques','subTechniques')) {if ($val -is [Array]) {$valText = ($val | ForEach-Object {if ($_ -match '\bT\d{4}(?:\.\d{3})?\b') {Convert-MitreToLinks $_} 
else {Escape-Html "$_"}}) -join ', '}
else {$valText = Escape-Html "$val"}}

# ---------------- SIMPLE ARRAY HANDLING (TACTICS ETC) --------------------------------------------
elseif ($p.Name -in @('tactics','techniques','subTechniques')) {$valText = ($val | ForEach-Object {$_.ToString()}) -join ', '}

# ---------------- COMPLEX OBJECT HANDLING --------------------------------------------------------
elseif ($val -is [array] -or ($val -is [psobject] -and -not ($val -is [string]))) {$valText = Escape-Html (Expand-PropertyValue $val)}

# ---------------- SCALAR -------------------------------------------------------------------------
else {$valText = Escape-Html "$val"}
$out += "<div class='kv'><strong>$key`: </strong><span class='val'>$valText</span></div> "}
return $out}

# Cleans and reshapes one rule object into a consistent schema.
function Normalize-RuleObject {param ($r)
$rawDisplayName = $r.displayName
if (-not $rawDisplayName -and $r.properties) {$rawDisplayName = $r.properties.displayName}

$topName = $r.name
if ($topName -and $topName -match '([0-9a-fA-F-]{36})') {$topName = $matches[1].ToLower()}
if (-not $topName -and $r.properties -and $r.properties.name) {$topName = $r.properties.name
if ($topName -match '([0-9a-fA-F-]{36})') {$topName = $matches[1].ToLower()}}

$topId = $null
if ($r.id -and $r.id -match '/alertRules/([0-9a-fA-F-]{36})') {$topId = $matches[1].ToLower()}
elseif ($r.id -and $r.id -match '([0-9a-fA-F-]{36})') {$topId = $matches[1].ToLower()}
if ($topId) {$topId = "/Microsoft.SecurityInsights/alertRules/$topId"}

$topKind = $r.kind

# Build MITRE properties for each rule (single-pass safe merge)
$tactics = @(@($r.tactics; $r.properties.tactics) | Where-Object {$_})
$techniques = @($r.techniques, $r.properties.techniques) | Where-Object {$_} | ForEach-Object {$_}
$subTechniques = @($r.subTechniques, $r.properties.subTechniques) | Where-Object {$_} | ForEach-Object {$_}

# HARD FORCE ARRAY TYPE
$tactics = @($tactics)
$techniques = @($techniques)
$subTechniques = @($subTechniques)

if ($r.properties -and $r.properties -is [psobject]) {foreach ($p in $r.properties.PSObject.Properties) {if (-not $r.PSObject.Properties[$p.Name]) {Add-Member -InputObject $r -NotePropertyName $p.Name -NotePropertyValue $p.Value}}}

# Sentinel ARM resource
return [pscustomobject]@{name = $topName
displayName = $rawDisplayName
description = $r.description
enabled = $r.enabled
severity = $r.severity
templateVersion = $r.templateVersion
# Query logic
query = $r.query
# Detection schedule (execution cadence)
queryFrequency = "$($r.queryFrequency)"
queryPeriod = "$($r.queryPeriod)"
# Trigger logic
triggerOperator = $r.triggerOperator
triggerThreshold = $r.triggerThreshold
# Suppression logic
suppressionDuration = "$($r.suppressionDuration)"
suppressionEnabled = $r.suppressionEnabled
startTimeUtc = $r.startTimeUtc
# MITRE mapping
tactics = $tactics
techniques = $techniques
subTechniques = $subTechniques
alertRuleTemplateName = $r.alertRuleTemplateName
# Incident behavior
incidentConfiguration = $r.incidentConfiguration
eventGroupingSettings = $r.eventGroupingSettings
alertDetailsOverride = $r.alertDetailsOverride
customDetails = $r.customDetails
# Entity enrichment
sentinelEntitiesMappings = $r.sentinelEntitiesMappings
entityMappings = $r.entityMappings
id = $topId
kind = $topKind}}

# Merges rules when required.
function Merge-Rules {param ($rules)
$gui = $rules | Where-Object {$_.templateVersion -or $_.incidentConfiguration} | Select-Object -First 1
$api = $rules | Where-Object {$_ -ne $gui} | Select-Object -First 1
if (-not $gui) {return $rules[0]}
if (-not $api) {return $gui}
Write-Host -f Cyan -n "Results merged for rule: "; Write-Host -f White -n $gui.displayName; Write-Host -f DarkGray " (GUID:" $gui.name ")"
$merged = [pscustomobject]@{}
foreach ($prop in $gui.PSObject.Properties.Name) {$guiVal = $gui.$prop; $apiVal = $api.$prop
if ($guiVal -ne $apiVal -and $guiVal -and $apiVal) {Write-Host -f Yellow -n "   Difference:"; Write-Host -f DarkGray $prop}
$value = $null
if ($null -ne $guiVal -and $guiVal -ne "") {$value = $guiVal}
else {$value = $apiVal}
$merged | Add-Member -NotePropertyName $prop -NotePropertyValue $value}
return $merged}

# -------------------------- MITRE ATT&CK Functions -----------------------------------------------

# Generate Mitre ATT&CK Navigator JSON.
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

$layer | ConvertTo-Json -Depth 10 -Compress | Set-Content -Encoding UTF8 $OutputPath}

# Get MITRE ATT&CK TTP tooltip.
function Get-MitreTitle {param($id)
if ($script:MitreLookup.ContainsKey($id)) {$obj = $script:MitreLookup[$id]; $name = $obj.name; $desc = Get-FirstSentence $obj.description
if ($desc) {return "$name`:`n$desc"}
return $name}
return "MITRE ATT&CK Technique $id"}

# Get first sentence of MITRE ATT&CK TTP description.
function Get-FirstSentence {param([string]$text)
if ([string]::IsNullOrWhiteSpace($text)) {return ""}
$match = [regex]::Match($text, '^(.*?\.)[\s\x28]')
if ($match.Success) {$text = $match.Groups[1].Value.Trim(); $text = $text -replace '\x5b([^\x5d]+)\x5d\x28[^\x29+]+\x29', '$1'; $text = $text -replace '\x28[Citation^\x29]+\x29\s', ' '; return $text}
return $text.Trim()}

# Convert Mitre TTPs to clickable links for column 3.
function Convert-MitreToLinks {param ([string]$Text)
if ([string]::IsNullOrWhiteSpace($Text)) {return $Text}
$items = ($Text -split '\s*,\s*') | Where-Object {$_ -and $_.Trim() -ne ''};
$items = $items | ForEach-Object {$id = $_.Trim()
if ($id -match '\bT\d{4}(?:\.\d{3})?\b') {if ($id -match '\.') {$parts = $id -split '\.'; $url = "https://attack.mitre.org/techniques/$($parts[0])/$($parts[1])"}
else {$url = "https://attack.mitre.org/techniques/$id"}
$title = Get-MitreTitle $id
"<a href='$url' target='_blank' title='$title'>$id</a>"}
else {Escape-Html $id}}
return ($items -join ', ')}

# Download the latest MITRE dataset if a TTP is unrecognized and the cache is at least a day old.
function Refresh-MitreLookup {if ($script:MitreLookupRefreshAttempted) {return}
$script:MitreLookupRefreshAttempted = $true; Write-Host -f Yellow "Refreshing MITRE STIX dataset..."
Invoke-RestMethod -Uri $script:MitreUri -Method Get | Set-Content -Path $script:MitreCacheFile -Encoding UTF8
Load-MitreLookup}

# Create MITRE matrix structure.
function Initialize-MitreMatrix {$script:mitreMatrix = [ordered]@{Reconnaissance = @{}
ResourceDevelopment = @{}
InitialAccess = @{}
Execution = @{}
Persistence = @{}
PrivilegeEscalation = @{}
Stealth = @{}
DefenseImpairment = @{}
CredentialAccess = @{}
Discovery = @{}
LateralMovement = @{}
Collection = @{}
CommandAndControl = @{}
Exfiltration = @{}
Impact = @{}}}

# Built MITRE matrix output.
function Build-MitreMiniColumn {if (-not $script:mitreMatrix -or $script:mitreMatrix.Count -eq 0) {return ""}
$preferredOrder = @("Reconnaissance", "ResourceDevelopment", "InitialAccess", "Execution", "Persistence", "PrivilegeEscalation", "Stealth", "DefenseImpairment", "CredentialAccess", "Discovery", "LateralMovement",  "Collection", "CommandAndControl", "Exfiltration", "Impact")

$tactics = $preferredOrder | Where-Object {$script:mitreMatrix[$_]}
$tactics = $preferredOrder | Where-Object {$script:mitreMatrix[$_]}
$height = if ($script:mitreMaxHeight) {" style='max-height:$($script:mitreMaxHeight)px;'"}
else {""}
$html = "<div class='mitre-scroll'$height><table class='mitre-inner'><tr>"

foreach ($t in $tactics) {$header = $t -creplace '(?<!^)([A-Z])',' $1'
$header = $header.Trim()
$header = $header -replace '\s+And\s+',' & '
$count = if ($script:mitreTacticCounts.ContainsKey($t)) {$script:mitreTacticCounts[$t]}
else {0}

# Account for v19 conversion, wherein Defense Evasion has been split into Stealth and Defense Impairment.
$count = if ($header -eq "Stealth" -and $count -le 0 -and $script:mitreTacticCounts["DefenseEvasion"] -gt 0) {$script:mitreTacticCounts["DefenseEvasion"]; $qualifier = "~"}
elseif ($header -eq "Defense Impairment" -and $count -le 0 -and $script:mitreTacticCounts["DefenseEvasion"] -gt 0) {$script:mitreTacticCounts["DefenseEvasion"]; $qualifier = "~"}
else {$script:mitreTacticCounts[$t]; $qualifier = ""}
$count = if ($count -lt 0) {0}
else {$count}
$plural = if ($count -eq 1) {""}
else {"s"}

# Heatmap colouring.
if ($ruleCount -le 0) {$percent = 0}
else {$percent = ($count / $ruleCount) * 100}
if ($percent -le 10) {$weightclass = "low"; $prefix = "🔴"}
elseif ($percent -lt 30) {$weightclass = "mid"; $prefix = "🟡"}
else {$weightclass = "high"; $prefix = "🟢"}

# Write Header.
$html += "<th class='mitre-th'>$header<br><span class='mitre-traffic-light'>$prefix</span><span class='mitre-tactic-count $weightclass'>$qualifier$count Rule$plural</span></th>"}
$html += "</tr><tr>"

foreach ($t in $tactics) {$html += "<td class='mitre-td' data-tactic='$t'>"
$bucket = $script:mitreMatrix[$t]
if (-not $bucket) {continue}

foreach ($tech in ($bucket.Keys | Sort-Object)) {$lookup = $script:MitreLookup[$tech]; $title = if ($lookup) {Get-MitreTitle $tech} else {""}
if ($tech -match '\.') {$parts = $tech -split '\.'; $url = "https://attack.mitre.org/techniques/$($parts[0])/$($parts[1])"}
else {$url = "https://attack.mitre.org/techniques/$tech"}
$display = Escape-Html $tech; $coverage = $bucket[$tech]; $class = "mitre-tech"
if (-not $coverage.Enabled -and $coverage.Disabled) {$class += " mitre-disabled-only"}
if ($lookup) {$html += "<div class='$class' data-mitre='$display'><a href='$url' target='_blank' title='$title'>$display</a></div>"}
else {$html += "<div class='$class' data-mitre='$display'>$display</div>"}}
$html += "</td>"}
$html += "</tr></table></div>"; return $html}

# -------------------------- PRE-PROCESSING -------------------------------------------------------

# Load PSD1 configuration.
function loadconfiguration {$script:powershell = Split-Path $profile; $script:baseModulePath = "$powershell\Modules\AllKQLtoHTML"; $script:configPath = Join-Path $baseModulePath "AllKQLtoHTML.psd1"
if (!(Test-Path $configPath)) {throw "Config file not found at $configPath"}
$script:config = Import-PowerShellDataFile -Path $configPath

# Pull config values into variables.
$script:resourcegroup = $config.privatedata.resourcegroup
$script:workspacename = $config.privatedata.workspacename
$script:subscription = $config.privatedata.subscription
$script:version = $config.moduleversion}
loadconfiguration

# Load MITRE ATT&CK TTPs.
function Load-MitreLookup {if ($script:MitreLookup) {return}
$script:MitreLookup = @{}; $script:MitreLookupLastLoadTime = $null; $script:MitreLookupRefreshAttempted = $false; $script:MitreUri = "https://raw.githubusercontent.com/mitre/cti/master/enterprise-attack/enterprise-attack.json"; $cacheDir = Join-Path $baseModulePath "cache"; $script:MitreCacheFile = Join-Path $baseModulePath "cache\enterprise-attack.json"; $download = $true
if (-not (Test-Path $cacheDir)) {New-Item -ItemType Directory -Path $cacheDir | Out-Null}
if (Test-Path $script:MitreCacheFile) {$age = (Get-Date) - (Get-Item $script:MitreCacheFile).LastWriteTime
if ($age.Days -lt 30) {$download = $false}}
if ($download) {Write-Host -f Cyan "Downloading MITRE ATT&CK STIX dataset..."; Invoke-RestMethod -Uri $script:MitreUri -Method Get | Set-Content -Path $cacheFile -Encoding UTF8}
else {Write-Host -f DarkGray "Using the cached MITRE dataset."}
$data = Get-Content $script:MitreCacheFile -Raw | ConvertFrom-Json
$script:MitreLookupLastLoadTime = [datetime](Get-Item $script:MitreCacheFile).LastWriteTime; $script:MitreLookup = @{}
foreach ($obj in $data.objects) {if ($obj.type -ne "attack-pattern") {continue}
if (-not $obj.external_references) {continue}
$ref = $obj.external_references | Where-Object {$_.source_name -eq "mitre-attack"} | Select-Object -First 1
if (-not $ref.external_id) {continue}
$id = $ref.external_id; 
$script:MitreLookup[$id] = [pscustomobject]@{name = $obj.name;
description = if ($obj.description) {$obj.description.Trim()} else {""}}}
Write-Host -f Green "MITRE lookup ready: $($script:MitreLookup.Count) techniques"}
Load-MitreLookup

# -------------------------- SWITCHES -------------------------------------------------------------

# External call to help.
if ($help) {help; return}

# Enable PreserveIds when CreateLinks or CreateCSV is chosen.
if ($CreateLinks -or $CreateCSV) {$csvPath = Join-Path $baseModulePath "AllKQLtoHTML.csv"; $PreserveIds = $true}

# Add Knowledgebase Links.
if ($CreateLinks) {$script:wikiLinks = @{}
if (Test-Path $csvPath) {try {$csv = Import-Csv $csvPath
foreach ($entry in $csv) {if ([string]::IsNullOrWhiteSpace($entry.uid)) {continue}
$csvGuid = $entry.uid.ToString().Trim().Trim('{}').ToLower()
if (-not $script:wikiLinks.ContainsKey($csvGuid)) {$script:wikiLinks[$csvGuid] = $entry.link}}
Write-Host -f green -n "`nLoaded $($script:wikiLinks.Count) wiki links from "; Write-Host -f White $csvPath}
catch {Write-Host -f red "Failed to load AllKQLtoHTML.csv"; Write-Host -f darkgray $_.Exception.Message}}}

# GetAZCommand.
if ($GetAZCommand) {Write-Host -f white "`nRun the following command in the Azure Web Shell:"; Write-host -f cyan "`naz sentinel alert-rule list --resource-group '$script:resourcegroup' --workspace-name '$script:workspacename' --subscription '$script:subscription' -o json > All_Azure_Sentinel_rules.json"; Write-Host -f white -n "`nThen download the newly created '"; Write-Host -f yellow -n "All_Azure_Sentinel_rules.json"; Write-Host -f white "' file and run AllKQLtoHTML again to process the results.`n";return}

# Usage switch.
if ($usage -or (-not (Test-Path "Azure_Sentinel_analytics_rules.json") -and ($PSBoundParameters.Count -eq 0))) {Write-Host -f cyan "`nUsage: AllKQLtoHTML <file1.json> <file2.json> <outfile.html> <-concat> <-merge><-preserveids>  <-createcsv> <-createlinks> <-usage> <-getazcommand> <-help>`n";return}

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
$jsonOut = $combinedTemplate | ConvertTo-Json -Depth 10 -Compress
Set-Content -Path $outFile -Value $jsonOut -Encoding UTF8

Write-Host -f Cyan "`n✅ Combined ARM template written:`n"
Write-Host -f white "`t$outFile"
$InputFile = $outFile}

# -------------------------- GENERATE FILES -------------------------------------------------------

# Load and normalize.
function loadandnormalize {if (-not (Test-Path $InputFile)) {Write-Host -f cyan "`nInput file not found: " -n; Write-Host -f white $InputFile; return}
$json = Get-Content $InputFile -Raw -Encoding UTF8 | ConvertFrom-Json

# Normalize primary rules
if ($json -is [array]) {$rawRules = $json | Where-Object {$_ -ne $null}}
elseif ($json.value) {$rawRules = $json.value | Where-Object {$_ -ne $null}}
elseif ($json.resources) {$rawRules = $json.resources | Where-Object {$_ -ne $null}}
else {throw "Unsupported JSON format"}

$script:rules = @()
foreach ($rule in $rawRules) {$n = Normalize-RuleObject $rule
$ruleId = if ($n.displayName) {$n.displayName -replace '[^a-zA-Z0-9_-]', '_'}
else {"rule_" + [guid]::NewGuid().ToString("N")}
$n | Add-Member -NotePropertyName RuleId -NotePropertyValue $ruleId -Force
if (-not $n.displayName) {Write-Host -f r "BROKEN RULE (no displayName)"; continue}
if ([string]::IsNullOrWhiteSpace($n.query)) {Write-Host "SKIPPED NO QUERY: $($n.displayName)"; continue}
$script:rules += $n}

if (-not $script:rules) {$script:rules = @()}

# Merge JSON (only if requested)
$script:mergeRules = @()
if ($Merge) {if (-not $MergeInputFile) {throw "The -Merge switch was specified but -MergeInputFile was not provided."}
if (-not (Test-Path $MergeInputFile)) {throw "Merge input file not found: $MergeInputFile"}
$mergemessage = "`nThe merge feature was invoked, which combines the results from the Sentinel GUI export (ARM Template) and the Azure Rest API export. If there are overlaps of field data, the ARM template version is given preference.`n"
Write-Host (wordwrap $mergemessage) -f yellow
$mergeJson = Get-Content $MergeInputFile -Raw -Encoding UTF8 | ConvertFrom-Json
if ($mergeJson -is [array]) {$mergeRaw = $mergeJson | Where-Object {$_ -ne $null}}
elseif ($mergeJson.value) {$mergeRaw = $mergeJson.value | Where-Object {$_ -ne $null}}
elseif ($mergeJson.resources) {$mergeRaw = $mergeJson.resources | Where-Object {$_ -ne $null}}
else {throw "Unsupported JSON format in merge file"}

$script:mergeRules = @()
foreach ($rule in $mergeRaw) {$n = Normalize-RuleObject $rule
$ruleId = if ($n.displayName) {$n.displayName -replace '[^a-zA-Z0-9_-]', '_'}
else {"rule_" + [guid]::NewGuid().ToString("N")}
$n | Add-Member -NotePropertyName RuleId -NotePropertyValue $ruleId -Force
if (-not $n.displayName) {Write-Host -f red "BROKEN RULE (no displayName)"; continue}
if ([string]::IsNullOrWhiteSpace($n.query)) {Write-Host "SKIPPED NO QUERY (MERGE): $($n.displayName)"; continue}
$script:mergeRules += $n}}}
loadandnormalize

$script:rules = $script:rules + $script:mergeRules

# Build rule to MITRE mapping.
function Build-RuleMitreMap {$script:ruleMitreMap = @{}
foreach ($r in $script:rules) {$ruleId = if ($r.displayName) {$r.displayName -replace '[^a-zA-Z0-9_-]', '_'}
else {"rule_" + [guid]::NewGuid().ToString("N")}
if (-not $r.PSObject.Properties['RuleId']) {continue}
$script:ruleMitreMap[$r.RuleId] = [pscustomobject]@{RuleName = $r.displayName
Tactics = @($r.tactics)
Techniques = @($r.techniques)
SubTechniques = @($r.subTechniques)}}}
Build-RuleMitreMap

# Merge files.
$script:rules = $script:rules | Group-Object name | ForEach-Object {if ($_.Count -eq 1) {$_.Group[0]}
else {Merge-Rules $_.Group}}

# Calculate statistics.
function statistics {$script:ruleCount = $script:rules.Count
$script:disabledCount = @($script:rules | Where-Object {$_.enabled -eq $false}).Count
$script:nrtCount = @($script:rules | Where-Object {$_.kind -eq 'NRT'}).Count
$script:templateVersionCount = @($script:rules | Where-Object {$_.templateVersion}).Count

# Severity counts (case-insensitive, safe for missing values)
$script:severityInfo = @($script:rules | Where-Object {$_.severity -match '^Informational$'}).Count
$script:severityLow = @($script:rules | Where-Object {$_.severity -match '^Low$'}).Count
$script:severityMedium = @($script:rules | Where-Object {$_.severity -match '^Medium$'}).Count
$script:severityHigh = @($script:rules | Where-Object {$_.severity -match '^High$'}).Count}
statistics

# Sort rules alphabetically.
$script:rules = $script:rules | Sort-Object displayName

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
$script:degMediumEnd = [Math]::Round($degInfo + $degLow + $degMedium, 1)

$script:donutGradient = "conic-gradient(" + "#ffffff 0deg $($degInfoEnd)deg, " + "#ff8c00 $($degInfoEnd)deg $($degLowEnd)deg, " + "#ffd166 $($degLowEnd)deg $($degMediumEnd)deg, " + "#d32f2f $($degMediumEnd)deg 360deg" + ")"}
builddonut

# Build rows.
function buildrows {$script:rows = ""; $script:toc = ""; $usedMitre = @{}
foreach ($r in $script:rules) {$qry = $r.query
if (-not $qry -and $r.properties) {$qry = $r.properties.query}
if (-not $qry -and $r.value) {$qry = $r.value.query}
if ([string]::IsNullOrWhiteSpace($qry)) {Write-Host "SKIPPED NO QUERY: $($r.displayName)";continue}

foreach ($t in @($r.techniques + $r.subTechniques)) {if (-not $t) {continue}
if ($usedMitre.ContainsKey($t)) {continue}
if ($script:MitreLookup.ContainsKey($t)) {$obj = $script:MitreLookup[$t]
$usedMitre[$t] = @{name = $obj.name
description = Get-FirstSentence $obj.description}}}

# Build export-safe rule object
$guid = Get-RuleUID $r
$ruleExportObject = [ordered]@{name = $guid
location = "global"
kind = if ($r.kind) {$r.kind} else {"Scheduled"}
properties = [ordered]@{}}

$ruleDisplayObject = [ordered]@{}
foreach ($prop in $r.PSObject.Properties) {if ($prop.Name -eq "name") {if ($PreserveIds -and $prop.Value) {$ruleExportObject.name = $prop.Value; $ruleDisplayObject.name = $prop.Value}
else {$ruleExportObject.name = $guid; $ruleDisplayObject.name = $guid}
continue}

if ($prop.Name -eq "id") {if ($PreserveIds -and $prop.Value) {$ruleExportObject.properties.id = $prop.Value; $ruleDisplayObject.id = $prop.Value}
else {$ruleExportObject.properties.id = "/Microsoft.SecurityInsights/alertRules/$guid"; $ruleDisplayObject.id = "/Microsoft.SecurityInsights/alertRules/$guid"}
continue}

$ruleDisplayObject[$prop.Name] = $prop.Value

if ($null -eq $prop.Value) {continue}
if ($prop.Value -is [array] -and $prop.Value.Count -eq 0) {$valText = "{null}"}
if ($prop.Value -is [string] -and [string]::IsNullOrWhiteSpace($prop.Value)) {continue}
$ruleExportObject.properties[$prop.Name] = $prop.Value}
$ruleJson = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($ruleExportObject | ConvertTo-Json -Depth 10 -Compress)))
$name = Escape-Html $r.displayName
$id = $r.RuleId
$qry = Escape-Html (Normalize-UnicodeDecorations $qry); $qry = Highlight-KqlComments $qry
$descRaw = Normalize-UnicodeDecorations $r.description; $descEscaped = Escape-Html $descRaw; $desc = Convert-UrlsToLinks $descEscaped

$enabled = $r.enabled
if ($enabled -eq $true) {$enabledText = "<span class='enabled-true'>✅ true</span>"}
else {$enabledText = "<span class='enabled-false'>❌ false (Disabled)</span>"}

$severity = $r.severity
switch -Regex ($severity) {'^Informational$' {$severityHtml = "<span>Severity:</span> <span class='sev-info'><strong>⚪ Informational</strong></span>"}
'^Low$' {$severityHtml = "<span>Severity:</span> <span class='sev-low'><strong>🟠 Low</strong></span>"}
'^Medium$' {$severityHtml = "<span>Severity:</span> <span class='sev-medium'><strong>🟡 Medium</strong></span>"}
'^High$' {$severityHtml = "<span>Severity:</span> <span class='sev-high'><strong>🔴 High</strong></span>"}
default {$severityHtml = "<span>Severity:</span> <span class='sev-info'><strong>⚪ Unknown</strong></span>"}}
$props = Format-Properties ([pscustomobject]$ruleDisplayObject)

if ($r.enabled -eq $true) {$script:toc += "<li data-target='$id'><a href='#$id'>$name</a></li>`n"}
else {$script:toc += "<li data-target='$id'><a href='#$id' class='enabled-false'>$name</a></li>`n"}

$templateVersionHtml = ""
if ($r.templateVersion) {$tv = Escape-Html $r.templateVersion; $templateVersionHtml = "<br><span class='template-version'>Template Version: <strong>$tv</strong></span>"}

$wikiHtml = ""
$wikiLink = Get-RuleWikiLink $r.displayName $r.name

if ($wikiLink) {$wikiText = $config.PrivateData.WikiIntegration.LinkText
if (-not $wikiText) {$wikiText = "📘 Playbook"}
$wikiHtml = "<br><a href='$wikiLink' target='_blank'>$wikiText</a>"}

$mitreList = @()
if ($r.techniques) {$mitreList += $r.techniques}
if ($r.subTechniques) {$mitreList += $r.subTechniques}
$mitreList = $mitreList | Where-Object {$_} | ForEach-Object {$_.Trim()} | Select-Object -Unique
$mitreAttr = $mitreList -join ','
$tacticAttr = @($r.tactics | Where-Object {$_}) -join ','

$script:rows += @"
<tr id="$id" data-enabled="$($r.enabled)" data-kind="$($r.kind)" data-severity="$($r.severity)" data-template-version="$($r.templateVersion)" data-tactics="$tacticAttr" data-mitre="$mitreAttr" data-rule-json="$ruleJson">

<td class="rulename"><strong>$name</strong><br><br>
<span class="description">$desc</span><br><br>
<span>Enabled: $enabledText</span><br>
$severityHtml
$templateVersionHtml<br>
$wikiHtml
</td>
<td class="query"><pre>$qry</pre></td>
<td class="props"><div class="props-content">$props</div><button class="export-rule-btn" title="Export rule as Sentinel JSON"> ⬇️</button></td>
</tr>
"@}
$mitreJson = $usedMitre | ConvertTo-Json -Depth 5 -Compress}
buildrows

# Final error check.
if (-not $script:rows) {Write-Host -f red "Nothing to write.`nExiting.`n";return}

# Snapshot Date.
$script:snapshotDate = (Get-Date).ToString('MM/dd/yyyy @ hh:mm:ss tt (zzz') + ' ' + (Get-TimeZone).StandardName + ')'

# Get TTPS information from MITRE cache.
function Load-MitreTacticLookup {if ($script:MitreTacticLookup) {return}
$data = Get-Content $script:MitreCacheFile -Raw | ConvertFrom-Json
$script:MitreTacticLookup = @{}
foreach ($obj in $data.objects) {if ($obj.type -ne "attack-pattern") {continue}
if (-not $obj.external_references) {continue}
$ref = $obj.external_references | Where-Object {$_.source_name -eq "mitre-attack"} | Select-Object -First 1
if (-not $ref.external_id) {continue}
$id = $ref.external_id; $tactics = @()
foreach ($phase in @($obj.kill_chain_phases)) {if ($phase.kill_chain_name -ne "mitre-attack") {continue}
$tactics += (($phase.phase_name -replace '-',' ') -split ' ' | ForEach-Object {if ($_){$_.Substring(0,1).ToUpper() + $_.Substring(1)}}) -join ''}
$script:MitreTacticLookup[$id] = $tactics | Select-Object -Unique}}
Load-MitreTacticLookup

# Rebuild the MITRE TTP mappings.
function buildmitrematrix {Initialize-MitreMatrix; $script:mitreTacticCounts = @{};
foreach ($r in $script:rules) {$techniques = @($r.techniques) + @($r.subTechniques); $ruleTacticsSeen = @{}
foreach ($tech in $techniques) {if ([string]::IsNullOrWhiteSpace($tech)) {continue}
$tactics = $script:MitreTacticLookup[$tech]
if (-not $tactics) {continue}
$tacticList = @($r.tactics | Select-Object -Unique)
foreach ($tactic in $tacticList) {if (-not $script:mitreTacticCounts.ContainsKey($tactic)) {$script:mitreTacticCounts[$tactic] = 0}
if (-not $ruleTacticsSeen.ContainsKey($tactic)) {$ruleTacticsSeen[$tactic] = $true
if (-not $script:mitreTacticCounts.ContainsKey($tactic)) {$script:mitreTacticCounts[$tactic] = 0}
$script:mitreTacticCounts[$tactic]++}}
foreach ($tactic in ($tactics | Select-Object -Unique)) {if ([string]::IsNullOrWhiteSpace($tactic)) {continue}
if (-not $script:mitreMatrix.Contains($tactic)) {continue}
$bucket = $script:mitreMatrix[$tactic]
if (-not $bucket.Contains($tech)) {$bucket[$tech] = @{
Enabled  = $false
Disabled = $false}}
if ($r.enabled -eq $true) {$bucket[$tech].Enabled = $true}
else {$bucket[$tech].Disabled = $true}}}}

# ---------------- MAX MITRE COLUMN HEIGHT CALCULATION ----------------
$rowHeight = 22.7; $maxRows = 0
foreach ($tactic in $script:mitreMatrix.Keys) {$rowCount = $script:mitreMatrix[$tactic].Count
if ($rowCount -gt $maxRows) {$maxRows = $rowCount}}
$script:mitreMaxHeight = ($maxRows * $rowHeight) + 85}
buildmitrematrix

# Build TOC statistics block
function buildstats {if ($script:mitreMatrix.Keys.Count -eq 0) {$mitreColumn = ""}
else {$mitreColumn = Build-MitreMiniColumn}

$script:statsBlock = @"
<table class="stats-table" aria-hidden="false">
<tr><td class="stats-left"><strong><span class="stats-header">Rule Overview:</span><br>
<span class="stat-green">Rule Count: $ruleCount</span><br>
<span class="stat-red toggle" data-filter="disabled">Disabled Rules: $disabledCount</span><br>
<span class="stat-yellow toggle" data-filter="nrt">NRT Rules: $nrtCount</span><br>
<span class="stat-gray toggle" data-filter="template">Built from templates: $templateVersionCount</span><br><br>
<span id="regexFilterBtn" class="text-filter toggle" title="Filter by Text">🔍 Filter by Text <span style="display:inline; font-size:9px; opacity:0.7; text-decoration: none;">(CTRL+X)</span></span></td>

<td class="stats-middle"><strong><span class="stats-header">Severity Breakdown:</span><br>
<span class="sev-info toggle" data-filter="sev-informational">⚪ Informational: $severityInfo</span><br>
<span class="sev-low toggle" data-filter="sev-low">🟠 Low: $severityLow</span><br>
<span class="sev-medium toggle" data-filter="sev-medium">🟡 Medium: $severityMedium</span><br>
<span class="sev-high toggle" data-filter="sev-high">🔴 High: $severityHigh</span></strong><br><br>
<span id="visibleRuleCount" class="stat-muted"> Visible Rules: $ruleCount</span> <button id="exportVisibleRules" title="Export visible rules as Sentinel JSON" style="margin-left:6px; opacity:0.6; cursor:pointer;">⬇️</button></td>
<td class="stats-right"><div class="severity-donut"><div class="donut"></div><div class="donut-label">$ruleCount<br>Rules</div></div></td>


<td class="stats-right">
<span id="filterHeader" class="filter-header hidden">Filter Controls:</span>
<span id="reverseFilters" class="toggle reverse-filter hidden">🔄 Reverse Filters</span><br>
<span id="clearFilters" class="toggle clear-filters hidden">❎ Clear Filters <span style="display:inline; font-size:9px; opacity:0.7; text-decoration: none;">(CTRL+Z)</span></span></strong><br>

<div id="searchCriteriaBlock" style="font-size: 13px;" class="hidden">Search terms:<br><strong id="searchCriteriaValue" class="stat-muted"></strong></div>
</td>

<td class="stats-mitre">$mitreColumn</td>
</tr></table>
"@}
buildstats

# Generate HTML and write file
function writepage {$templatePath = Join-Path $PSScriptRoot "AllKQLtoHTML.html"; $html = Get-Content $templatePath -Raw; 

$mitreDataLines = foreach ($r in $script:rules) {$ruleName = $r.displayName -replace '[^a-zA-Z0-9_-]', '_'; $techniques = @($r.techniques) + @($r.subTechniques)
foreach ($tech in $techniques) {if (-not $tech) {continue}
$lookup = $script:MitreLookup[$tech]
$name = if ($lookup) {$lookup.name}
else {$tech}
$desc = if ($lookup) {Get-FirstSentence $lookup.description}
else {""}
$tactics = $script:MitreTacticLookup[$tech]
$tacticsText = if ($tactics) {($tactics | Sort-Object) -join ", "}
else {""}
"$ruleName|$tacticsText|$tech|$name|$desc"}}

$mitreDataBlock = $mitreDataLines -join "`n"
$mitreBlock = Build-MitreMiniColumn

$html = $html.Replace("{{DONUTGRADIENT}}", [string]$script:donutGradient).
Replace("{{SNAPSHOTDATE}}", [string]$snapshotDate).
Replace("{{VERSION}}", [string]$script:version).
Replace("{{STATSBLOCK}}", [string]$statsBlock).
Replace("{{TOC}}", [string]$script:toc).
Replace("{{MITREDATA}}", $mitreDataBlock).
Replace("{{MITREBLOCK}}", $mitreBlock).
Replace("{{ROWS}}", [string]$script:rows).
Replace("{{KQL_COMMENT}}", $script:KqlTheme.Comment).
Replace("{{KQL_COMMENT_BG}}", $script:KqlTheme.CommentBg).
Replace("{{KQL_TABLE}}", $script:KqlTheme.Table).
Replace("{{KQL_STRUCTURE}}", $script:KqlTheme.Structure).
Replace("{{KQL_FUNCTION}}", $script:KqlTheme.Function)

# One last swing at the bat to replace garbage UTF encoded characters and empty spans.
$html = [string]$html -replace '(â€“|â€”)', '-' -replace '[“”]', '"' -replace '(â€˜|â€™)', "'" -replace 'â€¦', '...';
$html = [string]$html -replace '\x3Cspan class=[\x22\x27][\w\s\-]+[\x22\x27]\x3E\x3C\x2Fspan\x3E','';

Set-Content -Path $OutputFile -Value $html -Encoding UTF8; Write-Host -f cyan "`n✅ Generated $OutputFile`n"}
writepage

# Create CSV file.
if ($CreateCSV) {Write-Host -f Cyan -n "`nGenerating CSV file: "; Write-Host -f White " AllKQLtoHTML.csv"; $csvOutput = @(); $seen = @{}
foreach ($r in $script:rules) {if (-not $r.displayName) {continue}
$uid = Get-RuleUID $r
if ([string]::IsNullOrWhiteSpace($uid)) {continue}
$uidNormalized = $uid.ToString().Trim().Trim('{}').ToLower()
if ($seen.ContainsKey($uidNormalized)) {continue}
$seen[$uidNormalized] = $true
$csvOutput += [pscustomobject]@{rulename = $r.displayName
uid = $uidNormalized
link = ""}}

try {$csvOutput | Sort-Object rulename | Export-Csv -Path "AllKQLtoHTML.csv" -NoTypeInformation -Encoding UTF8; Write-Host -f Green "✅ CSV created with $($csvOutput.Count) rules."}
catch {Write-Host -f Red "❌ Failed to create CSV file"; Write-Host -f DarkGray $_.Exception.Message}}

exportnavigatorlayer -OutputPath "report_navigator.json" 
Invoke-Item $OutputFile}

Set-Alias SentinelRules AllKQLtoHTML

Export-ModuleMember -Function allkqltohtml
Export-ModuleMember -Alias sentinelrules

# Helptext.
<#
## Overview
This script will read Sentinel JSON files containing Analytics rules and create a single page HTML output for easy search and reference.

Usage: AllKQLtoHTML <file1.json> <file2.json> <outfile.html> <-concat> <-merge> <-preserveids> <-createlinks> <-createcsv> <-usage> <-getazcommand> <-help>

File1 defaults to: Azure_Sentinel_analytics_rules.json
This is the Sentinel UI export default filename.

Outfile detaults to:	AllSentinelRules.html
As with all of these files, a user-provided name can be provided, instead.

File2 defaults to:	 All_Azure_Sentinel_rules.json
This is the default name the script expects for a Webshell export.

By default, a new GUID is assigned to every rule, unless the -preserveid switch is chosen, in order to retain the original information. Using the -createlinks or -createcsv switches will also enable the -preserveids switch.

## Azure Webshell JSON export
If you wish to use an export from the Azure Webshell, you will need to run PowerShell from portal.azure.com and enter the following commmand:

az sentinel alert-rule list --resource-group 'RG-<env>-<region>-<service>' --workspace-name 'LAW-<env>-<region>-<workload>' --subscription 'ffffffff-ffff-ffff-ffff-ffffffffffff' -o json > All_Azure_Sentinel_rules.json

Since this will need to be run periodically, the GetAZCommand switch has been created to provide you with the specific command required to run within the Azure Web Shell in order to create the All_Azure_Sentinels_rules.json for download. The Sentinel subscription variables will need to be added to the PSD1 file for this to work.

To acquire your Subscription ID, you can run the following command in Azure Cloudshell:

az account show --query id -o tsv

To acquire your Resource Group and Workspace names, navigate in Sentinel to the Overview page. Once you have these values you can add them to the PSD1 file for future reference.
## Using the -merge switch
If you provide the -merge switch, you should also provide a second JSON file. Without the -merge switch, the second JSON file is ignored.

When merging, the two files can be any combination of an Azure WebShell export or Sentinel UI export, because the script is designed to handle both JSON formats, interchangeably. If you need to merge more than 2 files, it is best that you merge the files of similar JSON format manually first, and then run the script to complete the remaining tasks.

It is important to note that the script will show preference to the ARM template version of a rule, the one exported from the Sentinel GUI interface, over the Azure Rest API exported versions, because the ARM template versions are more verbose. When overlaps occur, output will be written to the screen, not as an error message, but as an indication that field data between to two formats will be combined.
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

• Versioning information.

• Rules counts of: all rules, disabled rules, NRT rules, rules adapted from templates.

• Severity breakdown counts: informational, low, medium, high

• Donut chart visualizing the breakdown of rules by Severity.

• By clicking options in the Rule Overview, the list of rules displayed can be filtered accumatively.

• A text/Regex filter.

• By clicking rule severity levels, the list of rules displayed can be filtered exclusively.

• A live count of visible rules is displayed below the Severity counts.

• The ability to export the JSON of all currently visible rules for selective bulk import of rules into an environment.

• Clicking on an active filter undoes the filter.

• Whenever any filter is active two more options appear; one that allows you to invert the current filter, and a second to clear all filters. (Refreshing the page will also clear all filters.)
## Webpage Navigation
The main body of the webpage consists of the following components:

• A Table of Contents provides a three column list of all rules included, alphabetically. This table can be expanded and collapsed by clicking on the title and each rule is a hyperlink to the rule details in the table below.

• Keep in mind that if a rule is currently filtered out from being displayed, then clicking a link to that hidden rule will not allow you to navigate to it.

• The main body of the page is a three column table containing all of the details of each rule.

• Column one contains the rule name, description, enabled status, severity and template version number, if applicable.

• Clicking on a query in the first column copies the entire row in markdown format for use in wiki, knowledgebase and gitlab resources.

• Column two provides the rule query logic.

• Clicking on a query in this second column will copy its contents to the clipboard, so that it can be used in Sentinel Advanced Hunting or Microsoft Defender, saving time.

• The third column provides all other rule configuration items, including the Mitre TTPs.

• Clicking on the properties in this third column will allow a rule to be exported to the original JSON format for individual rule import.

• Due to the large nature of the page a "Back to top" button is located in the bottom right corner of the screen once the page is scrolled down far enough.
## Mitre ATT&CK Mapping
• Rolling over the Mitre ATT&CK logo in the top, right side of the page will provide a pop-out menu that allows you to copy the path to the "report_navigator.json" file, which should be located in the same directory as the webpage into the clipboard.
• Additionally provided is a hyperlink to the Mitre ATT&CK Navigator, which will allow you to load the aforementioned file in order to see a heatmap of your current rule coverage.
## Create Links
A limited knowledgebase or playbook link generator and import functionality has been added to the script using the -CreateLinks switch.

If no explicit link is provided in the accompanying CSV file, then dynamic links can be created from the rule's DisplayName and that makes this feature somewhat fragile, which is why I indicated this feature is limited.

In order to use it, you need to configure a few settings in the accompanying PSD1 file:

WikiIntegration = @{BaseUrl = "https://wiki.company.local/playbooks/"
Separator = "slug"
Suffix = ".html" 
LinkText = "📘 Playbook"
Fallback = "true"

The BaseURL defines the root location of the articles in question.

The Separator defines how the page names are created:
• "slug" will convert the name to lower case, remove all special characters and separate words with hyphens. This is the preferred naming convention for most modern knowledge base systems.
• "underscore" will replace spaces with underscores.
• "dash" will replace all spaces with hyphens.
• "html" will convert the name into HTML code, so spaces for example, would become %20.

Suffix is optional, depending on your specific knowledgebase requirements. This can be something like: ".html", ".aspx", or "/some_additional_url_requirement"

LinkText determines how your link will appear on the webpage, such as "Knowledgebase article", "Playbook" or "References".

Fallback determines the priority of link creation. If this is set to "true", the script will first try to import links from the accompanying csv file, based upon the rule's unique GUID. If no match is found, then a dynamic link will be generated based on preceding criteria, instead.

The CSV file should look like this:

rulename,uid,link
"Rule name","1ce4300f-9783-45ed-a417-1ba9e14b4555","https://wiki.company.local/playbooks/alternatelinkforrulename.html"

The first column is just for user reference and is not used by the script. All rules are instead referenced by their uid and it is the third column that represents the link of preference for the rule in question.

This means that you can use both the CSV file and the link generator, interchangeably. Some rules might need dynamic links, while others have pre-defined explicit links, allowing for greater flexibility.
## Create CSV
In order to simplify the link mapping process, the -CreateCSV switch has been added, which will create the AllKQLtoHTML.csv file with the following columns:

rulename, uid, link

The rulename and uid will be populated, but the link column will not be. This is intentionally left blank so that you can add explicit or manufactured links in this column, as required.
## Sample ARM JSON Entry
Save the data below as a file with a .JSON extension in order to test the script. These fields are the minimum required to demonstrate what an entry would look like within the generated HTML webpage and the Mitre ATT&CK Navigator.

{"resources": [{"kind": "Scheduled", "properties": {"displayName": "Rule name", "description": "description", "enabled": false, "severity": "Low", "query": "KQL logic", "queryFrequency": "PT1H", "queryPeriod": "PT1H", "triggerOperator": "GreaterThan", "triggerThreshold": 0, "suppressionDuration": "PT5H", "suppressionEnabled": false, "tactics": ["InitialAccess"], "techniques": ["T1078"], "incidentConfiguration": {"createIncident": false, "groupingConfiguration": {"enabled": false, "reopenClosedIncident": false, "lookbackDuration": "PT5H", "matchingMethod": "AllEntities", "groupByEntities": [], "groupByAlertDetails": [], "groupByCustomDetails": []}}, "eventGroupingSettings": {"aggregationKind": "SingleAlert"}, "entityMappings": [{"entityType": "Account", "fieldMappings": [{"identifier": "Name", "columnName": "Account"}]}], "kind": "Scheduled"}}]}
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
