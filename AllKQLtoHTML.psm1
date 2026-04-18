function AllKQLtoHTML ([string]$InputFile  = "Azure_Sentinel_analytics_rules.json", [string]$MergeInputFile = "All_Azure_Sentinel_rules.json", [string]$OutputFile = "AllSentinelRules.html", [switch]$Merge, [switch]$help) {#Convert Sentinel JSON exports to an HTML file for easy searching with CTRL+F

function loadconfiguration {$script:powershell = Split-Path $profile; $script:baseModulePath = "$powershell\Modules\AllKQLtoHTML"; $script:configPath = Join-Path $baseModulePath "AllKQLtoHTML.psd1"
if (!(Test-Path $configPath)) {throw "Config file not found at $configPath"}
$script:config = Import-PowerShellDataFile -Path $configPath

# Pull config values into variables
$script:resourcegroup = $config.privatedata.resourcegroup
$script:workspacename = $config.privatedata.workspacename
$script:subscription = $config.privatedata.subscription}
loadconfiguration

if ($help) {Write-Host -f darkcyan "`nThis script will read Sentinel JSON files containing Analytics rules and create a single page HTML output for easy search and reference."
Write-Host -f cyan "`nUsage: AllKQLtoHTML <file1.json> <file2.json> <outfile.html> <-merge>"
Write-Host -f yellow "`nFile1 defaults to:`t" -n; Write-Host -f white "Azure_Sentinel_analytics_rules.json" -n; Write-Host -f cyan "`tThis is the Sentinel UI export default filename."
Write-Host -f yellow "Outfile detaults to:`t" -n; Write-Host -f white "AllSentinelRules.html" -n; Write-Host -f cyan "`t`t`tAs with all the files, a user-provided name can be provided, instead."
Write-Host -f yellow "File2 defaults to:`t" -n; Write-Host -f white "All_Azure_Sentinel_rules.json" -n; Write-Host -f cyan "`t`tMore details on this filename are provided below."
Write-Host -f darkcyan "`nAzure Webshell JSON export (PowerShell version):"
Write-Host -f cyan "If you wish to use an export from the Azure Webshell, you will need to run PowerShell from " -n; Write-Host -f blue "portal.azure.com" -n; Write-Host -f cyan " and enter the following commmand:"
Write-Host -f darkgreen "az sentinel alert-rule list --resource-group '$script:resourcegroup' --workspace-name '$script:workspacename' --subscription '$script:subscription' -o json > All_Azure_Sentinel_rules.json"
Write-Host -f yellow "`nTo acquire your Subscription ID for this command, you can run the following command in Azure Cloudshell:"
Write-Host -f darkgreen "az account show --query id -o tsv"
Write-Host -f yellow "To acquire your Resource Group and Workspace names, navigate in Sentinel to the Overview page.`nOnce you have these values you can add them to the PSD1 file for future reference."
Write-Host -f darkcyan "`nUsing the -merge switch:"
Write-Host -f cyan "If you provide the -merge switch, you should also provide a second JSON file.`nWithout the -merge switch, the second JSON file is ignored."
Write-Host -f cyan "`nWhen merging, the two files can be any combination of an Azure WebShell export or Sentinel UI export, because the script is designed to handle both JSON formats, interchangeably.`nIf you need to merge more than 2 files, it is best that you merge the files of similar JSON format manually first, and then run the script to complete the remaining tasks.`n"
return}

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

<# ----------------- Load JSON ----------------- #>

if (-not (Test-Path $InputFile)) {Write-Host -f cyan "`nInput file not found in the current directory: $InputFile`n"; return}
$json = Get-Content $InputFile -Raw -Encoding UTF8 | ConvertFrom-Json

<# ----------------- Normalize ----------------- #>

function Normalize-RuleObject {param ($r)
if ($r.properties) {return $r.properties | Add-Member -NotePropertyName id -NotePropertyValue $r.id -PassThru | Add-Member -NotePropertyName kind -NotePropertyValue $r.kind -PassThru}
return $r}

# ----------------- Load Primary JSON -----------------

if (-not (Test-Path $InputFile)) {Write-Host -ForegroundColor Cyan "`nInput file not found: $InputFile`n"; return}
$json = Get-Content $InputFile -Raw -Encoding UTF8 | ConvertFrom-Json

# ----------------- Load Merge JSON -----------------

if ($Merge) {if (-not $MergeInputFile) {throw "The -Merge switch was specified but -MergeInputFile was not provided."}
if (-not (Test-Path $MergeInputFile)) {throw "Merge input file not found: $MergeInputFile"}
$mergeJson = Get-Content $MergeInputFile -Raw -Encoding UTF8 | ConvertFrom-Json}

# ---- Normalize rules ----
if ($json.resources) {$rules = $json.resources | ForEach-Object {Normalize-RuleObject $_}}
elseif ($json.value) {$rules = $json.value | ForEach-Object {Normalize-RuleObject $_}}
elseif ($json -is [Array]) {$rules = $json | ForEach-Object {Normalize-RuleObject $_}}
else {throw "Unsupported JSON format"}

# ---- Normalize merge rules ----
if ($mergeJson.resources) {$mergeRules = $mergeJson.resources | ForEach-Object {Normalize-RuleObject $_}}
elseif ($mergeJson.value) {$mergeRules = $mergeJson.value | ForEach-Object {Normalize-RuleObject $_}}
elseif ($mergeJson -is [Array]) {$mergeRules = $mergeJson | ForEach-Object {Normalize-RuleObject $_}}
else {throw "Unsupported JSON format in merge file"}

# ---- Merge using Sentinel rule GUID ----
$ruleMap = @{}

foreach ($r in $rules) {$uid = Get-RuleUID $r
if ($uid) {$ruleMap[$uid] = $r}}

foreach ($r in $mergeRules) {$uid = Get-RuleUID $r
if ($uid -and -not $ruleMap.ContainsKey($uid)) {$ruleMap[$uid] = $r}}

$rules = $ruleMap.Values

<# ----------------- Sort rules alphabetically ----------------- #>

$rules = $rules | Sort-Object -Property displayName -Culture en-US

<# ----------------- Build rows ----------------- #>
$rows = ""
$toc = ""
foreach ($r in $rules) {if (-not ($r.displayName -and $r.query)) {continue}
$name = Escape-Html $r.displayName
$id   = ($r.displayName -replace '[^a-zA-Z0-9_-]', '_')
$qry  = Escape-Html $r.query
$desc = Escape-Html $r.description
$enabled = $r.enabled
if ($enabled -eq $true) {$enabledText = "<span class='enabled-true'>true</span>"}
else {$enabledText = "<span class='enabled-false'>false (Disabled)</span>"}
$props = Format-Properties $r
if ($r.enabled -eq $true) {$toc += "<li><a href='#$id'>$name</a></li>`n"}
else {$toc += "<li><a href='#$id' class='enabled-false'>$name</a></li>`n"}
$rows += @"
<tr id="$id">
<td class="rulename"><strong>$name</strong><br><br>
<span class="description">$desc</span><br><br>
<span>Enabled: $enabledText</span>
</td>
<td class="query"><pre>$qry</pre></td>
<td class="props">$props</td>
</tr>
"@}

<# ----------------- HTML ----------------- #>

$html = @"
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
<div class="toc"><ul>$toc</ul></div>

<br>

<table>
<colgroup><col style="width:15%;"><col style="width:42.5%;"><col style="width:42.5%;"></colgroup>

<thead>
<tr><th>Rule Name</th><th>Query Logic</th><th>Properties</th></tr>
</thead>

<tbody>
$rows
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
Write-Host -f cyan "`n✅ Generated $OutputFile`n"
Invoke-Item $OutputFile}

Set-Alias SentinelRules AllKQLtoHTML
