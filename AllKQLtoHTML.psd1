@{RootModule = 'AllKQLtoHTML.psm1'
ModuleVersion = '2.6'
GUID = '1717dd23-d91a-4ed2-bd4b-a03c847cc238'
Author = 'Craig Plath'
CompanyName = 'Plath Consulting Incorporated'
Copyright = '© Craig Plath. All rights reserved.'
Description = 'A tool to convert the JSON exports of Microsoft Sentinel rules to a single page HTML reference.'
PowerShellVersion = '5.1'
FunctionsToExport = @('AllKQLtoHTML')
CmdletsToExport = @()
VariablesToExport = @()
AliasesToExport = @('sentinelrules')
FileList = @('AllKQLtoHTML.psm1')

PrivateData = @{PSData = @{Tags = @('export', 'html', 'json', 'merge', 'siem', 'sentinel')
LicenseUri = 'https://github.com/Schvenn/AllKQLtoHTML/blob/main/license.txt'
ProjectUri = 'https://github.com/Schvenn/AllKQLtoHTML'
ReleaseNotes = 'Initial release.'}

subscription   = 'ffffffff-ffff-ffff-ffff-ffffffffffff'
workspacename = 'LAW-<env>-<region>-<workload>'
resourcegroup = 'RG-<env>-<region>-<service>'}}
