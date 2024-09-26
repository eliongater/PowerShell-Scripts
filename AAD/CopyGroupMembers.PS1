# PowerShell script to copy users from one Entra ID group to another Entra ID group

# Connect to Graph
Connect-MgGraph

# Define the source and destination group names
$sourceGroupName = "Azure_SMX_Archiving"
$destinationGroupName = "zSMX-365-M-P-Archiving"

# Get the source and destination group IDs
$sourceGroup = Get-MgGroup -Filter "displayName eq '$sourceGroupName'"
$destinationGroup = Get-MgGroup -Filter "displayName eq '$destinationGroupName'"

# Get the members of the source group
$members = Get-MgGroupMember -GroupId $sourceGroup.Id

# Add each member to the destination group
foreach ($member in $members) {
    New-MgGroupMember -GroupId $destinationGroup.Id -DirectoryObjectId $member.Id
}
Write-Output "Users have been copied from the source group to the destination group."

$members = $null