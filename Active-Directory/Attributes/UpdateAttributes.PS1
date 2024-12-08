# Import the Active Directory module
Import-Module ActiveDirectory

# Path to the CSV file
$csvPath = "C:\path\to\your\file.csv"

# Import the CSV file
$users = Import-Csv -Path $csvPath

foreach ($user in $users) {
    # Get the user from Active Directory
    $adUser = Get-ADUser -Filter { userPrincipalName -eq $user.userPrincipalName }

    if ($adUser) {
        # Update the user attributes
        Set-ADUser -Identity $adUser -Title $user.jobTitle `
                   -Department $user.department `
                   -Manager $user.manager `
                   -StreetAddress $user.streetAddress `
                   -State $user.state `
                   -Country $user.country `
                   -Office $user.officeLocation `
                   -City $user.city `
                   -PostalCode $user.postalCode `
                   -Company $user.companyName
    } else {
        Write-Host "User with userPrincipalName $($user.userPrincipalName) not found in Active Directory."
    }
}