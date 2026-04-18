## AllKQLtoHTML
This script will read Sentinel JSON files containing Analytics rules and create a single page HTML output for easy search and reference.
    
    Usage: AllKQLtoHTML <file1.json> <file2.json> <outfile.html> <-merge>


| File | Default filename | Notes |
|------|------------------|-------|
|File1 defaults to:|Azure_Sentinel_analytics_rules.json|This is the Sentinel UI export default filename.|
|Outfile detaults to:|AllSentinelRules.html|As with all the files, a user-provided name can be provided, instead.|
|File2 defaults to:|All_Azure_Sentinel_rules.json|More details on this filename are provided below.|

## Azure Webshell JSON export (PowerShell version):
If you wish to use an export from the Azure Webshell in our environment, you will need to run PowerShell from portal.azure.com and enter the following commmand:

    az sentinel alert-rule list --resource-group 'RG-<env>-<region>-<service>' --workspace-name 'LAW-<env>-<region>-<workload>' --subscription 'ffffffff-ffff-ffff-ffff-ffffffffffff' -o json > All_Azure_Sentinel_rules.json

To acquire your **Subscription ID**, you can run the following command in Azure Cloudshell:

		az account show --query id -o tsv
To acquire your **Resource Group** and **Workspace** names, navigate in Sentinel to the Overview page.
Once you have these values you can add them to the PSD1 file for future reference.

## Using the -merge switch:
If you provide the -merge switch, you should also provide a second JSON file.
Without the -merge switch, the second JSON file is ignored.

When merging, the two files can be any combination of an Azure WebShell export or Sentinel UI export, because the script is designed to handle both JSON formats, interchangeably.
If you need to merge more than 2 files, it is best that you merge the files of similar JSON format manually first, and then run the script to complete the remaining tasks.
