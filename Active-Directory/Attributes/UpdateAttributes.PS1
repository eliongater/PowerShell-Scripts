# Import the Active Directory module
Import-Module ActiveDirectory

# Path to the CSV file
$csvPath = "C:\Temp\UserAccounts.csv"

# Import the CSV file
$users = Import-Csv -Path $csvPath

foreach ($user in $users) {
    # Get the user from Active Directory
    $UPN = $user.userPrincipalName
    $adUser = Get-ADUser -Filter "userPrincipalName -eq '$UPN'" -Properties *

    if ($adUser) {
        # Update the user attributes
        if ($user.jobTitle){Set-ADUser -Identity $adUser -Title $user.jobTitle}
        if ($user.department){Set-ADUser -Identity $adUser -Department $user.department}
        if ($user.manager){
            $ManagerUPN = $user.manager
            $Manager = Get-ADUser -Filter "userPrincipalName -eq '$ManagerUPN'" -Properties *
            $ManagerSAM = $Manager.SAMaccountName
            Set-ADUser -Identity $adUser -Manager $ManagerSAM
        }
        if ($user.streetAddress){Set-ADUser -Identity $adUser -StreetAddress $user.streetAddress}
        if ($user.State){Set-ADUser -Identity $adUser -State $user.state}
        if ($user.country){Set-ADUser -Identity $adUser -Country $user.country}
        if ($user.officeLocation){Set-ADUser -Identity $adUser -Office $user.officeLocation}
        if ($user.city){Set-ADUser -Identity $adUser -City $user.city}
        if ($user.postalCode){Set-ADUser -Identity $adUser -PostalCode $user.postalCode}
        if ($user.companyName){Set-ADUser -Identity $adUser -Company $user.companyName}

    } else {
        Write-Host "User with userPrincipalName $($user.userPrincipalName) not found in Active Directory."
    }
}