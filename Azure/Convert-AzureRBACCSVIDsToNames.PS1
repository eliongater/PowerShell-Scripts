Param(
    [Parameter(Mandatory=$true)]
    [string]$InputCsvPath = ".\downloads\AzureResourceGraphResults-New_query_1.csv",

    [Parameter(Mandatory=$true)]
    [string]$OutputCsvPath = ".\downloads\AzureResourceGraphResults-New_query_1-WithNames.csv"
)

if ($null -eq $InputCsvPath -or -not (Test-Path -Path $InputCsvPath)) {
    $InputCsvPath = ".\downloads\AzureResourceGraphResults-New_query_1.csv"
}
if ($null -eq $OutputCsvPath) {
    $OutputCsvPath = ".\downloads\AzureResourceGraphResults-New_query_1-WithNames.csv"
}

# Requires Microsoft Graph PowerShell SDK: Install-Module Microsoft.Graph -Scope CurrentUser
# Recommended scopes: Directory.Read.All (for users, groups, service principals). Consent required for app or delegated auth.
if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {
    Throw "Microsoft.Graph module not found. Install with: Install-Module Microsoft.Graph -Scope CurrentUser"
}

# Connect to Microsoft Graph if not already connected
if (-not (Get-MgContext -ErrorAction SilentlyContinue)) {
    Connect-MgGraph -Scopes "Directory.Read.All" | Out-Null
}

$rows = Import-Csv -Path $InputCsvPath

# cache to avoid repeated requests: key -> displayName
$cache = @{}

function Get-DisplayNameFromGraph {
    param(
        [string]$Id,
        [string]$Type
    )

    if ([string]::IsNullOrWhiteSpace($Id)) { return $null }

    if ($cache.ContainsKey($Id)) { return $cache[$Id] }

    $display = $null
    switch ($Type.ToLower()) {
        'user' {
            try {
                $u = Get-MgUser -UserId $Id -ErrorAction Stop -Select 'displayName'
                $display = $u.DisplayName
            } catch {
                $display = $null
            }
        }
        'group' {
            try {
                $g = Get-MgGroup -GroupId $Id -ErrorAction Stop -Select 'displayName'
                $display = $g.DisplayName
            } catch {
                $display = $null
            }
        }
        'serviceprincipal' {
            try {
                $sp = Get-MgServicePrincipal -ServicePrincipalId $Id -ErrorAction Stop -Select 'displayName'
                $display = $sp.DisplayName
            } catch {
                $display = $null
            }
        }
        default {
            # attempt best-effort: check user, then service principal, then group
            try {
                $u = Get-MgUser -UserId $Id -ErrorAction Stop -Select 'displayName'
                $display = $u.DisplayName
            } catch {
                try {
                    $sp = Get-MgServicePrincipal -ServicePrincipalId $Id -ErrorAction Stop -Select 'displayName'
                    $display = $sp.DisplayName
                } catch {
                    try {
                        $g = Get-MgGroup -GroupId $Id -ErrorAction Stop -Select 'displayName'
                        $display = $g.DisplayName
                    } catch {
                        $display = $null
                    }
                }
            }
        }
    }

    if (-not $display) { $display = $null } # normalize empty to $null
    $cache[$Id] = $display
    return $display
}

$output = foreach ($row in $rows) {
    $ptype = ($row.principalType -as [string])
    $id = ($row.principalId -as [string])

    $displayName = Get-DisplayNameFromGraph -Id $id -Type $ptype

    # preserve original columns and add DisplayName column
    [PSCustomObject]@{
        createdOn       = $row.createdOn
        updatedOn       = $row.updatedOn
        principalId     = $row.principalId
        principalType   = $row.principalType
        scope           = $row.scope
        roleName        = $row.roleName
        roleDefinitionId= $row.roleDefinitionId
        Details         = $row.Details
        displayname     = $displayName
    }
}

$output | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8