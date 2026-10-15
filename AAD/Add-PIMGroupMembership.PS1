#Connect to Microsoft Graph
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All", "PrivilegedAccess.ReadWrite.AzureADGroup"

#Ticket Number
$ticketNumber = "SCTASK"

#List of users to add to the PIM groups
$users = @("john.smith@test.com")

#Groups to which the users will be added
$groups = @(
    "PIM-Group-1",
    "PIM-Group-2"
)

#Start Time
$startTime = Get-Date

#Iterate through each user and group to add the user to the group
foreach ($user in $users) {
    #Get the user object using their UPN
    try {
        $userObject = Get-MgUser -filter "userPrincipalName eq '$user'" -ErrorAction Stop
    } catch {
        Write-Warning "Failed to retrieve user object for $user. Error: $_"
        continue
    }

    foreach ($group in $groups) {
        #Get the group object using the group display name
        try {
            $groupObject = Get-MgGroup -filter "displayName eq '$group'" -ErrorAction Stop
        } catch {
            Write-Warning "Failed to retrieve group object for $group. Error: $_"
            continue
        }

        $params = @{
            accessId = "member"
            principalId = "$($userObject.Id)"
            groupId = "$($groupObject.Id)"
            action = "AdminAssign"
            ticketInfo = @{
                ticketNumber = "$ticketNumber"
            }
            scheduleInfo = @{
                startDateTime = $startTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                expiration = @{
                    type = "noExpiration"
                }
                <#expiration = @{
                    type = "AfterDateTime"
                    endDateTime = [System.DateTime]::Parse("2023-02-07T19:56:00.000Z")
                }#>
            }
            justification = "Adding $user as eligble to $group for ticket number $ticketNumber"
        }

        #Add the user to the group using the Microsoft Graph API
        try {
            New-MgIdentityGovernancePrivilegedAccessGroupEligibilityScheduleRequest -BodyParameter $params -ErrorAction Stop
            Write-Host "Successfully added $user to $group"
        } catch {
            if ($_.Exception.Message -like "*already exists*") {
                Write-Warning "$user is already a member of $group"
            } else {
                Write-Error "Failed to add $user to $group. Error: $_"
            }
        }

    }
}