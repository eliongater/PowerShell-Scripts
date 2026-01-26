Connect-MgGraph -Scopes "PrivilegedAccess.Read.AzureADGroup","Group.Read.All"
 
$PimGroups = [array](
    (Invoke-MgGraphRequest -Method 'Get' -Uri 'https://graph.microsoft.com/beta/privilegedAccess/aadGroups/resources').'value'
)
 
$ObjGroupsData = @()
 
foreach ($group in $pimGroups) {
    $groupid = $group.id
    $groupmembers = Get-MgIdentityGovernancePrivilegedAccessGroupEligibilitySchedule -Filter "groupId eq '$groupid'"
    Write-Host "Group Display Name: $($group.DisplayName)"
    foreach ($groupmember in $groupmembers) {
        $user = Get-MgUser -UserId  $groupmember.PrincipalId
        write-host "User: " $user.UserPrincipalName
                $ObjGroupsData += New-Object PSObject -Property @{
                'UserPrincipalName' = $user.UserPrincipalName
                'Group Display Name' = $group.displayName
            }
    }
}
$ObjGroupsData | export-csv .\PIMGroupMembers.csv