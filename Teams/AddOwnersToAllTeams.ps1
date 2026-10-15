# Connect to Microsoft Teams and add owners to every team

if (-not (Get-Module -Name MicrosoftTeams -ListAvailable)) {
    Install-Module -Name MicrosoftTeams -Force -Scope CurrentUser
}

Import-Module MicrosoftTeams -ErrorAction Stop
Connect-MicrosoftTeams

$owners = @(
    'john.smith@test.com'
)

$teams = Get-Team
foreach ($team in $teams) {
    Write-Output "Processing team: $($team.DisplayName) ($($team.GroupId))"
    foreach ($owner in $owners) {
        try {
            Add-TeamUser -GroupId $team.GroupId -User $owner -Role Owner -ErrorAction Stop
            Write-Output "Added owner $owner to team $($team.DisplayName)"
        } catch {
            $message = $_.Exception.Message
            if ($message -match 'already a member|already an owner|already exists') {
                Write-Output "User $owner is already a member or owner of $($team.DisplayName)"
            } else {
                Write-Warning "Failed to add $owner to $($team.DisplayName): $message"
            }
        }
    }
}
