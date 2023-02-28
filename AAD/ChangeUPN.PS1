# Import the CSV file
$users = Import-Csv -Path C:\Users.csv

$NewDomain = ""

# Loop through each user in the file and update their UPN

$WhatIf = $true

foreach ($user in $users) {
    $FirstDotLast = $user.UPN.split("@")[0]
    # Construct the new UPN
    $newUpn = $FirstDotLast + "@" + $NewDomain

    Write-Host "Changing $($user.UPN) to $newUpn"
    if(!$WhatIf){
        # Update the user's UPN
        Set-AzureADUser -ObjectId $user.UPN -UserPrincipalName  $newUPN
    }
    
}
