<#################################################################################
DISCLAIMER:

This is not an official PowerShell Script. We designed it specifically for the situation you have
encountered right now.

Please do not modify or change any preset parameters.

Please note that we will not be able to support the script if it's changed or altered in any way
or used in a different situation for other means.

This code-sample is provided "AS IS" without warranty of any kind, either expressed or implied,
including but not limited to the implied warranties of merchantability and/or fitness for a
particular purpose.

This sample is not supported under any Microsoft standard support program or service.

Microsoft further disclaims all implied warranties including, without limitation, any implied
warranties of merchantability or of fitness for a particular purpose.

The entire risk arising out of the use or performance of the sample and documentation remains with
you.

In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or
delivery of the script be liable for any damages whatsoever (including, without limitation, damages
for loss of business profits, business interruption, loss of business information, or other
pecuniary loss) arising out of the use of or inability to use the sample or documentation, even if
Microsoft has been advised of the possibility of such damages.
#################################################################################>

Connect-MgGraph -Scopes 'Application.ReadWrite.All','Group.Read.All'

$Messages = @{
    DurationNotice = @{
        Info = @(
            'The operation is running and will take longer the more applications the tenant has...'
            'Please wait...'
        ) -join ' '
    }
    Export         = @{
        Info   = 'Where should the CSV file export to?'
        Prompt = 'Enter the full path in the format of <C:\Users\<USER>\Desktop\Users.csv>'
    }
}

Write-Host $Messages.DurationNotice.Info -ForegroundColor Yellow

$EnterpriseApps = Get-MgServicePrincipal -all
$Count = 0

$Logs = @()

foreach ($EnterpriseApp in $EnterpriseApps) {
    $Completed = ($count/$EnterpriseApps.count) * 100
    $count ++
    # Use Write-Progress to output a progress bar.
    # The Activity and Status parameters create the first and second lines of the progress bar
    # heading, respectively.
    Write-Progress -Activity "Getting App assignments" -Status "Progress:" -PercentComplete $Completed


    $AppName = $EnterpriseApp.DisplayName
    $AppID   = $EnterpriseApp.Id
    $ApplID  = $EnterpriseApp.AppId
    $ServicePrincipalType = $EnterpriseApp.ServicePrincipalType
    $assignments = Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $EnterpriseApp.Id -all
    $assignments = $assignments.PrincipalDisplayName
    $assignmentGroupMembers = $null
    foreach($assignment in $assignments){
        $assignment = $assignment.replace("'","''")
        $group = Get-MgGroup -Filter "DisplayName eq '$assignment'"
        if($null -ne $group){
            $groupMembers = Get-MgGroupMemberAsUser -GroupId $group.Id
            if($null -ne $groupMembers){
                $groupMembers = $groupMembers.DisplayName
                if($null -ne $assignmentGroupMembers){
                    $assignmentGroupMembers = $assignmentGroupMembers + [system.String]::Join("; ",$groupMembers)
                } else {
                    $assignmentGroupMembers = [system.String]::Join("; ",$groupMembers)
                }
                
            }
        }
    }
    if($null -ne $assignments){
        $assignments = [system.String]::Join("; ",$assignments)
    }
    $AssignmentRequired = $EnterpriseApp.AppRoleAssignmentRequired
    $NotificationEmailAddresses = $EnterpriseApp.NotificationEmailAddresses
    $NotificationEmailAddresses = [system.String]::Join("; ", $NotificationEmailAddresses)
    $LoginURL = $EnterpriseApp.LoginURL

    $AppCreds = Get-MgServicePrincipal -ServicePrincipalId $AppID |
        Select-Object PasswordCredentials, KeyCredentials

    $Secrets = $AppCreds.PasswordCredentials
    $Certs   = $AppCreds.KeyCredentials


    ############################################
    $Logs += [PSCustomObject]@{
        'ApplicationName'        = $AppName
        'ID'                     = $AppID
        'ApplicationID'          = $ApplID
        'ServicePrincipalType'   = $ServicePrincipalType
        'Secret Name'            = $Null
        'Secret Start Date'      = $Null
        'Secret End Date'        = $Null
        'Certificate Name'       = $Null
        'Certificate Start Date' = $Null
        'Certificate End Date'   = $Null
        'Owner'                  = $Null
        'Owner_ObjectID'         = $Null
        'NotificationEmailAddresses' = $Null
        'Assignments'            = $assignments
        'AssignmentRequired'     = $AssignmentRequired
        'Assignment Group Members' = $assignmentGroupMembers
        'LoginURL'               = $LoginURL
    }
    ############################################
    foreach ($Secret in $Secrets) {
        $StartDate = $Secret.StartDateTime
        $EndDate   = $Secret.EndDateTime

        $Owner    = Get-MgServicePrincipalOwner -ServicePrincipalId $EnterpriseApp.Id
        $Username = $Owner.AdditionalProperties.userPrincipalName -join ';'
        $OwnerID  = $Owner.Id -join ';'

        if ($null -eq $Owner.AdditionalProperties.userPrincipalName) {
            $Username = @(
                $Owner.AdditionalProperties.displayName
                '**<This is an Application>**'
            ) -join ' '
        }
        if ($null -eq $Owner.AdditionalProperties.displayName) {
            $Username = '<<No Owner>>'
        }

        $Logs += [PSCustomObject]@{
            'ApplicationName'        = $AppName
            'ID'                     = $AppID
            'ApplicationID'          = $ApplID
            'ServicePrincipalType'   = $ServicePrincipalType
            'Secret Name'            = $SecretName
            'Secret Start Date'      = $StartDate
            'Secret End Date'        = $EndDate
            'Certificate Name'       = $Null
            'Certificate Start Date' = $Null
            'Certificate End Date'   = $Null
            'Owner'                  = $Username
            'Owner_ObjectID'         = $OwnerID
            'NotificationEmailAddresses' = $Null
            'Assignments'            = $Null
            'AssignmentRequired'     = $Null
            'Assignment Group Members' = $Null
            'LoginURL'               = $Null
        }
    }

    foreach ($Cert in $Certs) {
        $StartDate = $Cert.StartDateTime
        $EndDate   = $Cert.EndDateTime
        $CertName  = $Cert.DisplayName

        $Owner    = Get-MgServicePrincipalOwner -ServicePrincipalId $EnterpriseApp.Id
        $Username = $Owner.AdditionalProperties.userPrincipalName -join ';'
        $OwnerID  = $Owner.Id -join ';'

        if ($null -eq $Owner.AdditionalProperties.userPrincipalName) {
            $Username = @(
                $Owner.AdditionalProperties.displayName
                '**<This is an Application>**'
            ) -join ' '
        }
        if ($null -eq $Owner.AdditionalProperties.displayName) {
            $Username = '<<No Owner>>'
        }

        $Logs += [PSCustomObject]@{
            'ApplicationName'        = $AppName
            'ID'                     = $AppID
            'ApplicationID'          = $ApplID
            'ServicePrincipalType'   = $ServicePrincipalType
            'Secret Name'            = $Null
            'Certificate Name'       = $CertName
            'Certificate Start Date' = $StartDate
            'Certificate End Date'   = $EndDate
            'Owner'                  = $Username
            'Owner_ObjectID'         = $OwnerID
            'NotificationEmailAddresses' = $NotificationEmailAddresses
            'Assignments'            = $Null
            'AssignmentRequired'     = $Null
            'Assignment Group Members' = $Null
            'LoginURL'               = $Null
        }
    }
}

$Applications = Get-MgApplication -All
$Count = 0

foreach ($App in $Applications) {
    $Completed = ($count/$Applications.count) * 100
    $count ++
    # Use Write-Progress to output a progress bar.
    # The Activity and Status parameters create the first and second lines of the progress bar
    # heading, respectively.
    Write-Progress -Activity "Getting App registrations" -Status "Progress:" -PercentComplete $Completed
    $AppName = $App.DisplayName
    $AppID   = $App.Id
    $ApplID  = $App.AppId

    $ServicePrincipalType = "App Registraion"

    $AppCreds = Get-MgApplication -ApplicationId $AppID |
        Select-Object PasswordCredentials, KeyCredentials

    $Secrets = $AppCreds.PasswordCredentials
    $Certs   = $AppCreds.KeyCredentials

    ############################################
    $Logs += [PSCustomObject]@{
        'ApplicationName'        = $AppName
        'ID'                     = $AppID
        'ApplicationID'          = $ApplID
        'ServicePrincipalType'   = $ServicePrincipalType
        'Secret Name'            = $Null
        'Secret Start Date'      = $Null
        'Secret End Date'        = $Null
        'Certificate Name'       = $Null
        'Certificate Start Date' = $Null
        'Certificate End Date'   = $Null
        'Owner'                  = $Null
        'Owner_ObjectID'         = $Null
        'NotificationEmailAddresses' = $Null
        'Assignments'            = $Null
        'AssignmentRequired'     = $Null
        'Assignment Group Members' = $Null
        'LoginURL'               = $Null
    }
    ############################################
    foreach ($Secret in $Secrets) {
        $StartDate  = $Secret.StartDateTime
        $EndDate    = $Secret.EndDateTime
        $SecretName = $Secret.DisplayName

        $Owner    = Get-MgApplicationOwner -ApplicationId $App.Id
        $Username = $Owner.AdditionalProperties.userPrincipalName -join ';'
        $OwnerID  = $Owner.Id -join ';'

        if ($null -eq $Owner.AdditionalProperties.userPrincipalName) {
            $Username = @(
                $Owner.AdditionalProperties.displayName
                '**<This is an Application>**'
            ) -join ' '
        }
        if ($null -eq $Owner.AdditionalProperties.displayName) {
            $Username = '<<No Owner>>'
        }

        $Logs += [PSCustomObject]@{
            'ApplicationName'        = $AppName
            'ID'                     = $AppID
            'ApplicationID'          = $ApplID
            'ServicePrincipalType'   = $ServicePrincipalType
            'Secret Name'            = $SecretName
            'Secret Start Date'      = $StartDate
            'Secret End Date'        = $EndDate
            'Certificate Name'       = $Null
            'Certificate Start Date' = $Null
            'Certificate End Date'   = $Null
            'Owner'                  = $Username
            'Owner_ObjectID'         = $OwnerID
            'NotificationEmailAddresses' = $Null
            'Assignments'            = $Null
            'AssignmentRequired'     = $Null
            'Assignment Group Members' = $Null
            'LoginURL'               = $Null
        }
    }

    foreach ($Cert in $Certs) {
        $StartDate = $Cert.StartDateTime
        $EndDate   = $Cert.EndDateTime
        $CertName  = $Cert.DisplayName

        $Owner    = Get-MgApplicationOwner -ApplicationId $App.Id
        $Username = $Owner.AdditionalProperties.userPrincipalName -join ';'
        $OwnerID  = $Owner.Id -join ';'

        if ($null -eq $Owner.AdditionalProperties.userPrincipalName) {
            $Username = @(
                $Owner.AdditionalProperties.displayName
                '**<This is an Application>**'
            ) -join ' '
        }
        if ($null -eq $Owner.AdditionalProperties.displayName) {
            $Username = '<<No Owner>>'
        }

        $Logs += [PSCustomObject]@{
            'ApplicationName'        = $AppName
            'ID'                     = $AppID
            'ApplicationID'          = $ApplID
            'ServicePrincipalType'   = $ServicePrincipalType
            'Secret Name'            = $Null
            'Certificate Name'       = $CertName
            'Certificate Start Date' = $StartDate
            'Certificate End Date'   = $EndDate
            'Owner'                  = $Username
            'Owner_ObjectID'         = $OwnerID
            'NotificationEmailAddresses' = $Null
            'Assignments'            = $Null
            'AssignmentRequired'     = $Null
            'Assignment Group Members' = $Null
            'LoginURL'               = $Null
        }
    }
}

Write-Host $Messages.Export.Info -ForegroundColor Green
$Path = Read-Host -Prompt $Messages.Export.Prompt
$Logs | Export-Csv $Path -NoTypeInformation -Encoding UTF8
