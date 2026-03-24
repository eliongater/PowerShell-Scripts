# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All"

# Read CSV file
$csvPath = Read-Host "Enter the path to your CSV file"
$groups = Import-Csv -Path $csvPath

foreach ($group in $groups) {
    $groupName = $group.groupName
    $groupDescription = $group.groupDescription
    $membersList = $group.members -split ";" | ForEach-Object { $_.Trim() }

    # Check if group exists
    $existingGroup = Get-MgGroup -Filter "displayName eq '$groupName'" -ErrorAction SilentlyContinue

    if ($null -eq $existingGroup) {
        Write-Host "Creating group: $groupName"
        $newGroup = New-MgGroup -DisplayName $groupName -Description $groupDescription -MailEnabled $false -SecurityEnabled $true
        $existingGroup = $newGroup
    } else {
        Write-Host "Group already exists: $groupName"
    }

    # Add members to the group
    foreach ($member in $membersList) {
        $user = Get-MgUser -Filter "userPrincipalName eq '$member'" -ErrorAction SilentlyContinue

        if ($null -eq $user) {
            $user = Get-MgUser -Filter "mail eq '$member'" -ErrorAction SilentlyContinue
        }

        if ($null -ne $user) {
            New-MgGroupMember -GroupId $existingGroup.Id -DirectoryObjectId $user.Id -ErrorAction SilentlyContinue
            Write-Host "Added member: $member"
        } else {
            Write-Host "Member not found: $member"
        }
    }
}

Write-Host "Script completed"