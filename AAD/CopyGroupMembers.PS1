# PowerShell script to copy users from one Entra ID group to another Entra ID group

# Connect to Azure AD
Connect-AzureAD

# Source and destination group IDs
$sourceGroupId = "source-group-id"
$destinationGroupId = "destination-group-id"

# Get members of the source group
$sourceGroupMembers = Get-AzureADGroupMember -ObjectId $sourceGroupId

# Add each member to the destination group
foreach ($member in $sourceGroupMembers) {
    Add-AzureADGroupMember -ObjectId $destinationGroupId -RefObjectId $member.ObjectId
}

Write-Output "Users have been copied from the source group to the destination group."