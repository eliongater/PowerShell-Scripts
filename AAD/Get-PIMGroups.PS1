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
        #Check if the group member is a user, group or service principal

        $groupMemberObject = Get-MgDirectoryObject -DirectoryObjectId $groupmember.PrincipalId
        $groupMembertype = $groupMemberObject.AdditionalProperties["@odata.type"].Split(".")[-1]
        

        switch ($groupMembertype) {
            'Group' {
                Write-Host "Group: " $groupmember.PrincipalId
                $memberGroup = Get-MgGroup -GroupId $groupmember.PrincipalId
                $ObjGroupsData += New-Object PSObject -Property @{
                    'UserPrincipalName' = $memberGroup.Mail
                    'Display Name' = $memberGroup.DisplayName
                    'Job Title' = 'N/A'
                    'Company Name' = 'N/A'
                    'Department' = 'N/A'
                    'Type' = 'Group'
                    'Group Display Name' = $group.displayName
                }
            }
            'ServicePrincipal' {
                $serviceprincipal = Get-MgServicePrincipal -ServicePrincipalId $groupmember.PrincipalId
                Write-Host "Service Principal AppId: " $serviceprincipal.AppId
                $ObjGroupsData += New-Object PSObject -Property @{
                    'UserPrincipalName' = $serviceprincipal.AppId
                    'Display Name' = $serviceprincipal.DisplayName
                    'Job Title' = 'N/A'
                    'Company Name' = 'N/A'
                    'Department' = 'N/A'
                    'Type' = 'Service Principal'
                    'Group Display Name' = $group.displayName
                }
            }
            'user' {
                $user = Get-MgUser -UserId  $groupmember.PrincipalId
                write-host "User: " $user.UserPrincipalName
                    $ObjGroupsData += New-Object PSObject -Property @{
                    'UserPrincipalName' = $user.UserPrincipalName
                    'Display Name' = $user.DisplayName
                    'Job Title' = $user.JobTitle
                    'Company Name' = $user.CompanyName
                    'Department' = $user.Department
                    'Type' = 'User'
                    'Group Display Name' = $group.displayName
                }
            }
        }
            
    }
}
$ObjGroupsData | export-csv .\PIMGroupMembers.csv