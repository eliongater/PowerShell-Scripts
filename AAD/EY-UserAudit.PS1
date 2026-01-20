<#
.SYNOPSIS
 Export Entra ID (Azure AD) users with sign-in and group membership details to CSV.

.DESCRIPTION
 Connects to Microsoft Graph, enumerates users and exports:
    - DisplayName, GivenName, Surname, UserPrincipalName, Mail, EmployeeId
    - LastInteractiveLogin (most recent interactive sign-in)
    - LastNonInteractiveLogin (most recent non-interactive sign-in)
    - AccountEnabled, CreatedDateTime
    - GroupMembership (semicolon-separated display names)

.REQUIREMENTS
 - Microsoft.Graph PowerShell module (will install if missing)
 - Graph permissions: User.Read.All, AuditLog.Read.All, Group.Read.All (admin consent typically required)
#>

param(
        [string]$OutputPath = ".\EY-UserAudit.csv"
)

function Ensure-GraphModule {
        if (-not (Get-Module -ListAvailable -Name "Microsoft.Graph")) {
                Write-Host "Microsoft.Graph module not found. Installing..."
                Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber
        }
        Import-Module Microsoft.Graph -ErrorAction Stop
}

function Connect-GraphInteractive {
        # scopes required to read users, groups and sign-in logs
        $scopes = @("User.Read.All","AuditLog.Read.All","Group.Read.All","Directory.Read.All")
        Connect-MgGraph -Scopes $scopes
}

#Ensure-GraphModule
Connect-GraphInteractive

# fetch users with needed properties
$selectProps = "id,displayName,givenName,surname,userPrincipalName,mail,employeeId,accountEnabled,createdDateTime"
Write-Host "Retrieving users..."
$users = Get-MgUser -All -Property $selectProps

$results = @()
$total = $users.Count
$i = 0

foreach ($u in $users) {
        $i++
        Write-Progress -Activity "Processing users" -Status "$i of $total : $($u.DisplayName)" -PercentComplete (($i / $total) * 100)

        # Retrieve sign-ins for this user (may be large depending on retention). We only need the latest interactive / non-interactive.
        # Get-MgAuditLogSignIn returns SignIn objects with isInteractive and createdDateTime
        try {
                $signins = Get-MgAuditLogSignIn -Filter "userId eq '$($u.Id)'" -All -ErrorAction Stop
        } catch {
                # If retrieving sign-ins fails (permissions/empty), set null and continue
                $signins = @()
        }

        $lastInteractive = $signins | Where-Object { $_.isInteractive -eq $true } | Sort-Object createdDateTime -Descending | Select-Object -First 1
        $lastNonInteractive = $signins | Where-Object { ($_.isInteractive -ne $true) -or ($_.isInteractive -eq $false) } | Sort-Object createdDateTime -Descending | Select-Object -First 1

        # Get group membership (direct membership). Use TransitiveMemberOf if you prefer nested membership.
        try {
                $members = Get-MgUserMemberOf -UserId $u.Id -All -ErrorAction Stop
                $groupNames = $members | ForEach-Object {
                        # many returned objects have DisplayName; fallback to AdditionalProperties
                        if ($null -ne $_.DisplayName) { $_.DisplayName } elseif ($_.AdditionalProperties.ContainsKey("displayName")) { $_.AdditionalProperties["displayName"] } else { $null }
                } | Where-Object { $_ } | Sort-Object -Unique
                $groupString = $groupNames -join "; "
        } catch {
                $groupString = ""
        }

        $results += [PSCustomObject]@{
                DisplayName            = $u.DisplayName
                GivenName              = $u.GivenName
                Surname                = $u.Surname
                UserPrincipalName      = $u.UserPrincipalName
                Mail                   = $u.Mail
                EmployeeId             = $u.EmployeeId
                LastInteractiveLogin   = if ($lastInteractive) { $lastInteractive.createdDateTime } else { $null }
                LastNonInteractiveLogin= if ($lastNonInteractive) { $lastNonInteractive.createdDateTime } else { $null }
                AccountEnabled         = $u.AccountEnabled
                CreatedDateTime        = $u.CreatedDateTime
                GroupMembership        = $groupString
        }
}

# Export to CSV
$results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
Write-Host "Export complete: $OutputPath"