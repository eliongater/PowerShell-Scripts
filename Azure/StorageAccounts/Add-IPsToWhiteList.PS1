#Login to Azure
Connect-AzAccount

#Set variables
$StorageAccount = "gd01sasftpprdsa01"
$ResourceGroupName = "generalprod01-prd-sasftp-ae-rg"
$SubscriptionName = "PAYG-AW"

#IPs to add to the whitelist
$IPsToAdd = "13.75.149.4","104.210.91.55","104.210.90.241","52.187.227.245","52.187.226.96","52.187.231.184","52.187.229.130","52.187.226.139","20.53.93.188","20.53.72.170","20.53.107.208","20.53.106.182","20.11.76.122","20.11.77.49","4.200.57.71","20.11.77.107","4.198.187.22","4.198.185.90","4.198.185.246","4.200.58.227"

#Add connector IPs to the whitelist
#Connector IPs as of 2024-06-06

$IPsToAdd += "52.237.214.72", "13.72.243.10", "20.213.202.84", "20.213.202.51"

$IPRangesToAdd = "13.70.72.192/28", "13.70.78.224/27", "20.70.220.224/28", "20.70.220.192/27"

#Set and store context
$AzureContext = Set-AzContext -SubscriptionName $SubscriptionName
Write-Output "Current Azure Context: $($AzureContext.Subscription.Name)"
#Get the storage account
$StorageAccountContext = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccount 
Write-Output "Managing Storage Account: $($StorageAccountContext.StorageAccountName) in Resource Group: $($StorageAccountContext.ResourceGroupName)"
#Get the current network rules
$NetworkRules = Get-AzStorageAccountNetworkRuleSet -ResourceGroupName $ResourceGroupName -Name $StorageAccount 

#Add the IPs to the whitelist if they are not already present
foreach ($IP in $IPsToAdd) {
    if ($NetworkRules.IpRules.IpAddressOrRange -notcontains $IP) {
        Write-Output "Adding IP $IP to the whitelist."
        Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -Name $StorageAccount -IpAddressOrRange $IP
    } else {
        Write-Output "IP $IP is already in the whitelist."
    }
}

#Add the IP ranges to the whitelist if they are not already present
foreach ($IPRange in $IPRangesToAdd) {
    if ($NetworkRules.IpRules.IpAddressOrRange -notcontains $IPRange) {
        Write-Output "Adding IP Range $IPRange to the whitelist."
        Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -Name $StorageAccount -IpAddressOrRange $IPRange
    } else {
        Write-Output "IP Range $IPRange is already in the whitelist."
    }
}