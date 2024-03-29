function Get-RecursiveDirectReports {
    param (
        [String] $UPN
    )
    $DirectReports = Get-AzureADUserDirectReport -ObjectId $UPN
    $RecursiveDirectReports
    foreach ($DirectReport in $DirectReports){
        $RecursiveDirectReports = Get-RecursiveDirectReports($DirectReport)    
    }
    $DirectReports += $RecursiveDirectReports
    Return $DirectReports
}


$User = ""
$domain = ""
$UPN = "$User@$domain"
$Filename = "$User Reports.CSV"

Connect-AzureAD

$DirectReports = Get-RecursiveDirectReports($UPN)
$DirectReports | Export-csv $Filename
