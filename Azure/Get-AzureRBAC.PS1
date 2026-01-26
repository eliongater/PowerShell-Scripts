<#
.SYNOPSIS
    A script to retrieve all role assignments within an Azure subscription using Azure Resource Graph.

.DESCRIPTION
    "Get-AzActiveRoleAssignments.ps1" is designed PowerShell script that leverages the Azure Resource Graph and Microsoft Graph to fetch all Azure role assignments

.PARAMETER subscriptionId
    The ID of the Azure subscription for which you want to retrieve role assignments.

.OUTPUTS
    CSV file named "AzureRoleAssignments.csv". This file contains detailed information about each role assignment, including the role name, principal name, assignment scope, and more.

.EXAMPLE
    PS> .\Get-AzActiveRoleAssignments.ps1 -SubscriptionId "your-subscription-id-here"

    Executes the script to get all role assignments for the specified subscription and exports the results to "AzureRoleAssignments.csv".

.NOTES
    Author: Hasan Gural, Elijah Smart
    Version: BETAv2
    Requires : 
     - Az.Graph
     - Az.Accounts
     - Az.Resources
     - Microsoft.Graph.DirectoryObjects

.LINK
    https://hasangural.com/retrieving-role-assignments-with-powershell
#>
<#
[CmdletBinding()]
param (

    [Parameter(Mandatory = $true)]
    [ValidatePattern("^\{?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}?$")]
    [string]$subscriptionId
)#>

#Connect to Azure Account
Connect-AzAccount -ErrorAction Stop

#Connect to Microsoft Graph
Connect-MgGraph -Scopes "Directory.Read.All" -ErrorAction Stop


$fileName       = ($Script:MyInvocation.MyCommand.Name).Replace(".ps1",("-Report-")+(Get-Date -Format "yyyyMMdd-HHmmss") + ".csv")
#Write-Output "INFO: Fetching Role Assignments for Subscription: $subscriptionId"

<#
$query = @"
authorizationresources
| where type =~ "microsoft.authorization/roleassignments"
| where id startswith "/subscriptions/$($subscriptionId)"
| extend RoleDefinitionId             = tolower(tostring(properties.roleDefinitionId))
| extend PrincipalId                  = tolower(properties.principalId)
| extend RoleDefinitionId_PrincipalId = strcat(RoleDefinitionId, "_", PrincipalId)
| join kind                           = leftouter (
    authorizationresources
    | where type                =~ "microsoft.authorization/roledefinitions"
    | extend RoleDefinitionName = tostring(properties.roleName)
    | extend rdId               = tolower(id)
    | project RoleDefinitionName, rdId
    )
    on `$left.RoleDefinitionId == `$right.rdId
| extend scope             = properties.scope
| extend createdOn         = properties.createdOn
| extend updatedOn         = properties.updatedOn
| project RoleDefinitionId = split(RoleDefinitionId_PrincipalId, "_", 0)[0], RoleDefinitionName, PrincipalId = split(RoleDefinitionId_PrincipalId, "_", 1)[0], scope, createdOn, updatedOn
"@
#>

$query = @"
authorizationresources
| where type =~ "microsoft.authorization/roleassignments"
| extend RoleDefinitionId             = tolower(tostring(properties.roleDefinitionId))
| extend PrincipalId                  = tolower(properties.principalId)
| extend RoleDefinitionId_PrincipalId = strcat(RoleDefinitionId, "_", PrincipalId)
| join kind                           = leftouter (
    authorizationresources
    | where type                =~ "microsoft.authorization/roledefinitions"
    | extend RoleDefinitionName = tostring(properties.roleName)
    | extend rdId               = tolower(id)
    | project RoleDefinitionName, rdId
    )
    on `$left.RoleDefinitionId == `$right.rdId
| extend scope             = properties.scope
| extend createdOn         = properties.createdOn
| extend updatedOn         = properties.updatedOn
| project RoleDefinitionId = split(RoleDefinitionId_PrincipalId, "_", 0)[0], RoleDefinitionName, PrincipalId = split(RoleDefinitionId_PrincipalId, "_", 1)[0], scope, createdOn, updatedOn
"@

$result = Search-AzGraph -Query $query

$listAssignments = @()

ForEach($assigment in $result){ 

   $getPrincipalDisplayName  = (Get-MgDirectoryObject -DirectoryObjectId $assigment.PrincipalId -ErrorAction SilentlyContinue | `
                                Select-Object -ExpandProperty AdditionalProperties).displayName

    $obj = [PSCustomObject]@{


        roleDefinitionName = $assigment.RoleDefinitionName
        roleDefinitionId   = $assigment.RoleDefinitionId
        principalId        = $assigment.PrincipalId
        displayName        = $getPrincipalDisplayName
        createdOn          = $assigment.createdOn
        updatedOn          = $assigment.updatedOn
        scope              = $assigment.scope

    }

    $listAssignments += $obj
}

Write-Output "INFO: Exporting Role Assignments to CSV file: $fileName"

$listAssignments | Export-Csv -Path $fileName -NoTypeInformation -Force