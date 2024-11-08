# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Application.ReadWrite.All"

# Define the email address to add
$emailToAdd = "Products@eqcnz.onmicrosoft.com"

# List of application names to search for
$appNames = @(
    "App1",
    "App2",
    "App3"
)

foreach ($appName in $appNames) {
    # Get the application by name
    $app = Get-MgApplication -Filter "displayName eq '$appName'"

    if ($app) {
        # Get the current owners of the application
        $owners = Get-MgApplicationOwner -ApplicationId $app.Id

        # Check if the email address is already an owner
        $ownerExists = $owners | Where-Object { $_.UserPrincipalName -eq $emailToAdd }
        $addOwnerAnyway = $true

        if (-not $ownerExists -or $addOwnerAnyway) {
            # Get the user object for the email address
            $user = Get-MgUser -Filter "userPrincipalName eq '$emailToAdd'"
            $userID = $user.ID
            $params = @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/{$userID}"
            }

            if ($user) {
                # Add the user as an owner of the application
                New-MgApplicationOwnerByRef -ApplicationId $app.Id -BodyParameter $params
                Write-Output "Added $emailToAdd as an owner to application $($app.DisplayName)"
            } else {
                Write-Output "User $emailToAdd not found in Azure AD"
            }
        } else {
            Write-Output "$emailToAdd is already an owner of application $($app.DisplayName)"
        }
    } else {
        Write-Output "Application $appName not found"
    }
}

foreach ($appName in $appNames) {
    # Get the application by name
    $app = Get-MgServicePrincipal -Filter "displayName eq '$appName'"

    if ($app) {
        # Get the current owners of the application
        $owners = Get-MgServicePrincipalOwner -ServicePrincipalId  $app.Id

        # Check if the email address is already an owner
        $ownerExists = $owners | Where-Object { $_.UserPrincipalName -eq $emailToAdd }
        $addOwnerAnyway = $true

        if (-not $ownerExists -or $addOwnerAnyway) {
            # Get the user object for the email address
            $user = Get-MgUser -Filter "userPrincipalName eq '$emailToAdd'"
            $userID = $user.ID
            $params = @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/{$userID}"
            }

            if ($user) {
                # Add the user as an owner of the application
                New-MgServicePrincipalOwnerByRef -ServicePrincipalId $app.Id -BodyParameter $params
                Write-Output "Added $emailToAdd as an owner to application $($app.DisplayName)"
            } else {
                Write-Output "User $emailToAdd not found in Azure AD"
            }
        } else {
            Write-Output "$emailToAdd is already an owner of application $($app.DisplayName)"
        }
    } else {
        Write-Output "Application $appName not found"
    }
}