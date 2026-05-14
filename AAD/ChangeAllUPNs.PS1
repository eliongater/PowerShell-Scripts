# Connect to Microsoft Graph
Connect-MgGraph -Scopes "User.ReadWrite.All"

# Define the new UPN domain
$newDomain = "selwynwater.nz"

# Get all users from Entra ID
$users = Get-MgUser -All

# Update UPN for each user
foreach ($user in $users) {
    $currentUpn = $user.UserPrincipalName
    $mailNickname = $currentUpn.Split("@")[0]
    $newUpn = "$mailNickname@$newDomain"
    
    try {
        Update-MgUser -UserId $user.Id -UserPrincipalName $newUpn
        Write-Host "Updated: $currentUpn -> $newUpn" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to update $currentUpn : $_" -ForegroundColor Red
    }
}

Write-Host "UPN update completed." -ForegroundColor Cyan
