# Script to export Entra ID groups and their members categorized by type
# Requires: Microsoft.Graph PowerShell module

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "directory.Read.All"

$results = @()

# Get all groups
$groups = Get-MgGroup -All

foreach ($group in $groups) {
    $groupMembers = Get-MgGroupMember -GroupId $group.Id -All
    
    $users = @()
    $memberGroups = @()
    $devices = @()
    $servicePrincipals = @()
    
    # Categorize members by type
    foreach ($member in $groupMembers) {
        $memberType = $member.AdditionalProperties["@odata.type"]
        
        switch ($memberType) {
            "#microsoft.graph.user" { $users += $member.Id }
            "#microsoft.graph.group" { $memberGroups += $member.Id }
            "#microsoft.graph.device" { $devices += $member.Id }
            "#microsoft.graph.servicePrincipal" { $servicePrincipals += $member.Id }
        }
    }
    
    $results += [PSCustomObject]@{
        GroupId              = $group.Id
        GroupDisplayName     = $group.DisplayName
        GroupMail            = $group.Mail
        UserCount            = $users.Count
        Users                = ($users -join ";")
        GroupCount           = $memberGroups.Count
        Groups               = ($memberGroups -join ";")
        DeviceCount          = $devices.Count
        Devices              = ($devices -join ";")
        ServicePrincipalCount = $servicePrincipals.Count
        ServicePrincipals    = ($servicePrincipals -join ";")
    }
}

# Export to CSV
$results | Export-Csv -Path "EntraID_GroupMembership.csv" -NoTypeInformation -Encoding UTF8

Write-Host "Export completed: EntraID_GroupMembership.csv"