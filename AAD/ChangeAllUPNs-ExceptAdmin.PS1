# Script to change UPN for all users except those with Entra ID roles
# Requires: Microsoft.Graph module and appropriate permissions

param(
    [Parameter(Mandatory=$true)]
    [string]$NewUPNSuffix,
    
    [Parameter(Mandatory=$false)]
    [string]$UserFilter = "accountEnabled eq true"
)

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "User.ReadWrite.All", "RoleManagement.Read.Directory"

# Get all users with role assignments
$usersWithRoles = @()
$roleAssignments = Get-MgRoleManagementDirectoryRoleAssignment -All

foreach ($assignment in $roleAssignments) {
    $usersWithRoles += $assignment.PrincipalId
}

# Get all users
$users = Get-MgUser -Filter $UserFilter -All

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
    
    try {
        $mailPrefix = $user.MailNickname
        $newUPN = "$mailPrefix@$NewUPNSuffix"
        
        Update-MgUser -UserId $user.Id -UserPrincipalName $newUPN
        Write-Host "Updated: $($user.UserPrincipalName) -> $newUPN" -ForegroundColor Green
        $updated++
    }
    catch {
        Write-Host "Failed: $($user.UserPrincipalName) - $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`nSummary: Updated=$updated, Skipped=$skipped, Failed=$failed"