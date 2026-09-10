# Script to change UPN for all users except those with Entra ID roles
# Requires: Microsoft.Graph module and appropriate permissions

param(
    [Parameter(Mandatory=$true)]
    [string]$NewUPNSuffix,
    
    [Parameter(Mandatory=$false)]
    [string]$UserFilter = "accountEnabled eq true"
)

$NewUPNSuffix = "selwynwater.co.nz"

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "User.ReadWrite.All", "RoleManagement.Read.Directory"

# Get all users with role assignments
$usersWithRoles = @()
$roleAssignments = Get-MgRoleManagementDirectoryRoleAssignment -All

foreach ($assignment in $roleAssignments) {
    $usersWithRoles += $assignment.PrincipalId
}

$AdditionalProperties = "Id","employeeId","IsSoftDeleted","accountEnabled","streetAddress","city","state","postalCode","country","department","displayName","facsimileTelephoneNumber","givenName","jobTitle","mail","mailNickname","manager","mobile","physicalDeliveryOfficeName","preferredLanguage","surname","telephoneNumber","userPrincipalName","otherMails","companyName"


# Get all users
$users = Get-MgUser -Filter $UserFilter -All -Property $AdditionalProperties

$skipped = 0
$updated = 0
$failed = 0

foreach ($user in $users) {
    # Skip if user has a role assignment
    if ($user.Id -in $usersWithRoles) {
        Write-Host "Skipped: $($user.UserPrincipalName) (has Entra ID role)" -ForegroundColor Yellow
        $skipped++
        continue
    }
    if ($user.companyName -eq "Datacom"){
        Write-Host "Skipped: $($user.UserPrincipalName) (companyName is Datacom)" -ForegroundColor Yellow
        $skipped++
        continue
    }
    
    try {
        $mailPrefix = $user.MailNickname
        $newUPN = "$mailPrefix@$NewUPNSuffix"
        $newMail = "$mailPrefix@$NewUPNSuffix"
        
        Update-MgUser -UserId $user.Id -UserPrincipalName $newUPN -Mail $newMail
        Write-Host "Updated: $($user.UserPrincipalName) -> $newUPN, Mail -> $newMail" -ForegroundColor Green
        $updated++
    }
    catch {
        Write-Host "Failed: $($user.UserPrincipalName) - $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`nSummary: Updated=$updated, Skipped=$skipped, Failed=$failed"