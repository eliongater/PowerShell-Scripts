# Import the CSV file
$groups = Import-Csv -Path C:\groups.csv

$NewDomain = ""

# Loop through each group in the file and update their SMTP

$WhatIf = $true

foreach ($group in $groups) {
    $Name = $group.mail.split("@")[0]
    # Construct the new UPN
    $newSMTP = $Name + "@" + $NewDomain

    Write-Host "Changing $($group.mail) to $newSMTP"
    if(!$WhatIf){
        # Update the group's SMTP
        Set-UnifiedGroup -Identity $group.displayName -PrimarySmtpAddress  $newSMTP
    }
    
}
