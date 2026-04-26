## Overview
This script will read Sentinel JSON files containing Analytics rules and create a single page HTML output for easy search and reference, as well as a report_navigator.json file for use with the Mitre ATT&CK Navigator heatmap.

The webpage features statistics about the rules, filtering, the ability to copy queries to the clipboard and more. Check out the screenshots to see some of what it can do.

	Usage: AllKQLtoHTML <file1.json> <file2.json> <outfile.html> <-concat> <-merge> <-usage> <-help>

| File | Default filename | Notes |
|------|------------------|-------|
|File1 defaults to:|Azure_Sentinel_analytics_rules.json|This is the Sentinel UI export default filename.|
|Outfile detaults to:|AllSentinelRules.html|As with all the files, a user-provided name can be provided, instead.|
|File2 defaults to:|All_Azure_Sentinel_rules.json|More details on this filename are provided below.|

## Azure Webshell JSON export (PowerShell version)
If you wish to use an export from the Azure Webshell, you will need to run PowerShell from portal.azure.com and enter the following commmand:

	az sentinel alert-rule list --resource-group 'RG-<env>-<region>-<service>' --workspace-name 'LAW-<env>-<region>-<workload>' --subscription 'ffffffff-ffff-ffff-ffff-ffffffffffff' -o json > All_Azure_Sentinel_rules.json

To acquire your Subscription ID, you can run the following command in Azure Cloudshell:

	az account show --query id -o tsv

To acquire your Resource Group and Workspace names, navigate in Sentinel to the Overview page. Once you have these values you can add them to the PSD1 file for future reference.
## Using the -merge switch
If you provide the -merge switch, you should also provide a second JSON file. Without the -merge switch, the second JSON file is ignored.

When merging, the two files can be any combination of an Azure WebShell export or Sentinel UI export, because the script is designed to handle both JSON formats, interchangeably. If you need to merge more than 2 files, it is best that you merge the files of similar JSON format manually first, and then run the script to complete the remaining tasks.
## Using the -concat(enate) switch
Concatenation in this case is not the same as merge. It is used exclusively for Sentinel UI exports of the ARM formatted JSON files.

When using the Sentinel UI, you will only be able to export a maximum of 50 rules at a time. Using this feature you can combine multiple files into a single ARM JSON file with ease. Simply select all rules, export the contents, navigate to the next page and do the same. Do not change the file name. Let Windows append the usual suffix (1), (2), and so on, until you're done. This script is designed to read those file names and merge them for you, after which it will proceed with the remaining tasks and file generation.

	Example:
	Azure_Sentinel_analytics_rules .json	
	Azure_Sentinel_analytics_rules (1).json	
	Azure_Sentinel_analytics_rules (2).json	

	Output:
	Azure_Sentinel_analytics_rules_combined.json
