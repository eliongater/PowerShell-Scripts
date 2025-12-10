<#
.NAME
    Get-ConditionalAccessAssignments.ps1
    
.SYNOPSIS
    This script uses PowerShell and Microsoft Graph to automatically generate an Excel report containing Conditional Access assignments in Azure AD.

.DESCRIPTION
    The script uses Microsoft Graph to fetch all Conditional Access policy assignments, both group- and user assignments (for now, it doesn't support role assignments). It exports them to Excel in a nicely formatted report for your filtering and analysing needs. If you include the -GetGroupMembers parameter, members of assigned groups will be included in the report as well (of course, this can produce very large reports if you have included large groups in your policy assignments).

    The purpose of the report is to give you an overview of how Conditional Access policies are currently applied in an Azure AD tenant, and which users are targeted by which policies.

    The following Microsoft Graph API permissions are required for this script to work:
        Policy.Read.ConditionalAccess
        Policy.Read.All
        Directory.Read.All
        Group.Read.All

    Make sure you change the $ClientID and $ClientSecret variables under Declarations before running.

    More information can be found here: https://danielchronlund.com/2020/10/20/export-your-conditional-access-policy-assignments-to-excel/
    
.PARAMETERS
    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).
    
.INPUTS
    None

.OUTPUTS
    None

.NOTES
    Version:        1.0
    Author:         Daniel Chronlund
    Creation Date:  2020-10-20
  
.EXAMPLE
    .\Get-ConditionalAccessAssignments.ps1 -GetGroupMembers
#>



# ----- [Initialisations] -----

# Script parameters.
param (
    [parameter(Mandatory = $false)]
    [switch]$GetGroupMembers
)


# Set Error Action - Possible choices: Stop, SilentlyContinue
$ErrorActionPreference = "Stop"



# ----- [Declarations] -----

# Client ID for the Azure AD application with Microsoft Graph permissions.
$ClientID = ''

# Client secret for the Azure AD application with Microsoft Graph permissions.
$ClientSecret = ''



# ----- [Functions] -----

# Connect to Microsoft Graph with delegated credentials (interactive login will popup).
function Connect-MsGraphAsDelegated {
    param (
        [string]$ClientID,
        [string]$ClientSecret
    )


    # Declarations.
    $Resource = "https://graph.microsoft.com"
    $RedirectUri = "https://login.microsoftonline.com/common/oauth2/nativeclient"


    # Force TLS 1.2.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


    # UrlEncode the ClientID and ClientSecret and URL's for special characters.
    Add-Type -AssemblyName System.Web
    $ClientIDEncoded = [System.Web.HttpUtility]::UrlEncode($ClientID)
    $ClientSecretEncoded = [System.Web.HttpUtility]::UrlEncode($ClientSecret)
    $ResourceEncoded = [System.Web.HttpUtility]::UrlEncode($Resource)
    $RedirectUriEncoded = [System.Web.HttpUtility]::UrlEncode($RedirectUri)


    # Function to popup Auth Dialog Windows Form.
    function Get-AuthCode {
        Add-Type -AssemblyName System.Windows.Forms
        $Form = New-Object -TypeName System.Windows.Forms.Form -Property @{Width = 440; Height = 640 }
        $Web = New-Object -TypeName System.Windows.Forms.WebBrowser -Property @{Width = 420; Height = 600; Url = ($Url -f ($Scope -join "%20")) }
        $DocComp = {
            $Global:uri = $Web.Url.AbsoluteUri        
            if ($Global:uri -match "error=[^&]*|code=[^&]*") { $Form.Close() }
        }

        $Web.ScriptErrorsSuppressed = $true
        $Web.Add_DocumentCompleted($DocComp)
        $Form.Controls.Add($Web)
        $Form.Add_Shown( { $Form.Activate() })
        $Form.ShowDialog() | Out-Null
        $QueryOutput = [System.Web.HttpUtility]::ParseQueryString($Web.Url.Query)
        $Output = @{ }

        foreach ($Key in $QueryOutput.Keys) {
            $Output["$Key"] = $QueryOutput[$Key]
        }

        #$Output
    }


    # Get AuthCode.
    $Url = "https://login.microsoftonline.com/common/oauth2/authorize?response_type=code&redirect_uri=$RedirectUriEncoded&client_id=$ClientID&resource=$ResourceEncoded&prompt=admin_consent&scope=$ScopeEncoded"
    Get-AuthCode


    # Extract Access token from the returned URI.
    $Regex = '(?<=code=)(.*)(?=&)'
    $AuthCode = ($Uri | Select-string -pattern $Regex).Matches[0].Value


    # Get Access Token.
    $Body = "grant_type=authorization_code&redirect_uri=$RedirectUri&client_id=$ClientId&client_secret=$ClientSecretEncoded&code=$AuthCode&resource=$Resource"
    $TokenResponse = Invoke-RestMethod https://login.microsoftonline.com/common/oauth2/token -Method Post -ContentType "application/x-www-form-urlencoded" -Body $Body -ErrorAction "Stop"


    $TokenResponse.access_token
}


# GET data from Microsoft Graph.
function Get-MsGraph {

    param (
        [parameter(Mandatory = $true)]
        $AccessToken,

        [parameter(Mandatory = $true)]
        $Uri
    )

    # Check if authentication was successfull.
    if ($AccessToken) {
        # Format headers.
        $HeaderParams = @{
            'Content-Type'  = "application\json"
            'Authorization' = "Bearer $AccessToken"
        }


        # Create an empty array to store the result.
        $QueryResults = @()


        # Invoke REST method and fetch data until there are no pages left.
        $Results = ""
        $StatusCode = ""

        # Invoke REST method and fetch data until there are no pages left.
        do {
            $Results = ""
            $StatusCode = ""

            do {
                try {
                    $Results = Invoke-RestMethod -Headers $HeaderParams -Uri $Uri -UseBasicParsing -Method "GET" -ContentType "application/json"

                    $StatusCode = $Results.StatusCode
                } catch {
                    $StatusCode = $_.Exception.Response.StatusCode.value__

                    if ($StatusCode -eq 429) {
                        Write-Warning "Got throttled by Microsoft. Sleeping for 45 seconds..."
                        Start-Sleep -Seconds 45
                    }
                    else {
                        Write-Error $_.Exception
                    }
                }
            } while ($StatusCode -eq 429)

            if ($Results.value) {
                $QueryResults += $Results.value
            }
            else {
                $QueryResults += $Results
            }

            $uri = $Results.'@odata.nextlink'
        } until (!($uri))


        # Return the result.
        $QueryResults
    }
    else {
        Write-Error "No Access Token"
    }
}



# ----- [Execution] -----

# Connect to Microsoft Graph.
Write-Verbose -Verbose -Message "Connecting to Microsoft Graph..."
$AccessToken = Connect-MsGraphAsDelegated -ClientID $ClientID -ClientSecret $ClientSecret


# Get all Conditional Access policies.
Write-Verbose -Verbose -Message "Getting all Conditional Access policies..."
$Uri = 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies'
$CAPolicies = @(Get-MsGraph -AccessToken $AccessToken -Uri $Uri)
Write-Verbose -Verbose -Message "Found $(($CAPolicies).Count) policies..."


# Get all group and user conditions from the policies.
$CAPolicies = foreach ($Policy in $CAPolicies) {
    Write-Verbose -Verbose -Message "Getting assignments for policy $($Policy.displayName)..."
    $CustomObject = New-Object -TypeName psobject


    $CustomObject | Add-Member -MemberType NoteProperty -Name "displayName" -Value $Policy.displayName
    $CustomObject | Add-Member -MemberType NoteProperty -Name "state" -Value $Policy.state


    Write-Verbose -Verbose -Message "Getting include groups for policy $($Policy.displayName)..."
    $includeGroupsDisplayName = foreach ($Object in $Policy.conditions.users.includeGroups) {
        $Uri = "https://graph.microsoft.com/v1.0/groups/$Object"
        (Get-MsGraph -AccessToken $AccessToken -Uri $Uri).displayName
    }
    
    $CustomObject | Add-Member -MemberType NoteProperty -Name "includeGroupsDisplayName" -Value $includeGroupsDisplayName
    $CustomObject | Add-Member -MemberType NoteProperty -Name "includeGroupsId" -Value $Policy.conditions.users.includeGroups


    Write-Verbose -Verbose -Message "Getting exclude groups for policy $($Policy.displayName)..."
    $excludeGroupsDisplayName = foreach ($Object in $Policy.conditions.users.excludeGroups) {
        $Uri = "https://graph.microsoft.com/v1.0/groups/$Object"
        (Get-MsGraph -AccessToken $AccessToken -Uri $Uri).displayName
    }

    $CustomObject | Add-Member -MemberType NoteProperty -Name "excludeGroupsDisplayName" -Value $excludeGroupsDisplayName
    $CustomObject | Add-Member -MemberType NoteProperty -Name "excludeGroupsId" -Value $Policy.conditions.users.excludeGroups


    Write-Verbose -Verbose -Message "Getting include users for policy $($Policy.displayName)..."
    $includeUsersUserPrincipalName = foreach ($Object in $Policy.conditions.users.includeUsers) {
        if ($Object -ne "All" -and $Object -ne "GuestsOrExternalUsers") {
            $Uri = "https://graph.microsoft.com/v1.0/users/$Object"
            (Get-MsGraph -AccessToken $AccessToken -Uri $Uri).userPrincipalName
        } else {
            $Object
        }
    }

    if ($Policy.conditions.users.includeUsers -ne "All" -and $Policy.conditions.users.includeUsers -ne "GuestsOrExternalUsers") {
        $CustomObject | Add-Member -MemberType NoteProperty -Name "includeUsersUserPrincipalName" -Value $includeUsersUserPrincipalName
        $CustomObject | Add-Member -MemberType NoteProperty -Name "includeUsersId" -Value $Policy.conditions.users.includeUsers
    } else {
        $CustomObject | Add-Member -MemberType NoteProperty -Name "includeUsersUserPrincipalName" -Value $Policy.conditions.users.includeUsers
        $CustomObject | Add-Member -MemberType NoteProperty -Name "includeUsersId" -Value $Policy.conditions.users.includeUsers
    }


    Write-Verbose -Verbose -Message "Getting exclude groups for policy $($Policy.displayName)..."
    $excludeUsersUserPrincipalName = foreach ($Object in $Policy.conditions.users.excludeUsers) {
        if ($Object -ne "All" -and $Object -ne "GuestsOrExternalUsers") {
            $Uri = "https://graph.microsoft.com/v1.0/users/$Object"
            (Get-MsGraph -AccessToken $AccessToken -Uri $Uri).userPrincipalName
        } else {
            $Object
        }
    }

    $CustomObject | Add-Member -MemberType NoteProperty -Name "excludeUsersUserPrincipalName" -Value $excludeUsersUserPrincipalName
    $CustomObject | Add-Member -MemberType NoteProperty -Name "excludeUsersId" -Value $Policy.conditions.users.exludeUsers

    $CustomObject
}


# Fetch include group members from Azure AD:
$IncludeGroupMembers = @()
if ($GetGroupMembers) {
    $IncludeGroupMembers = foreach ($Group in ($CAPolicies.includeGroupsId | Select-Object -Unique)) {
        Write-Verbose -Verbose -Message "Getting include group members for policy $($Policy.displayName)..."

        $Uri = "https://graph.microsoft.com/v1.0/groups/$Group"
        $GroupName = (Get-MsGraph -AccessToken $AccessToken -Uri $Uri).displayName

        $Uri = "https://graph.microsoft.com/v1.0/groups/$Group/members"
        $Members = (Get-MsGraph -AccessToken $AccessToken -Uri $Uri).userPrincipalName | Sort-Object userPrincipalName

        $CustomObject = New-Object -TypeName psobject
        $CustomObject | Add-Member -MemberType NoteProperty -Name "Group" -Value $GroupName
        $CustomObject | Add-Member -MemberType NoteProperty -Name "Members" -Value $Members
        $CustomObject
    }
}


# Fetch exclude group members from Azure AD:
$ExcludeGroupMembers = @()
if ($GetGroupMembers) {
    $ExcludeGroupMembers = foreach ($Group in ($CAPolicies.excludeGroupsId | Select-Object -Unique)) {
        Write-Verbose -Verbose -Message "Getting exclude group members for policy $($Policy.displayName)..."

        $Uri = "https://graph.microsoft.com/v1.0/groups/$Group"
        $GroupName = (Get-MsGraph -AccessToken $AccessToken -Uri $Uri).displayName

        $Uri = "https://graph.microsoft.com/v1.0/groups/$Group/members"
        $Members = (Get-MsGraph -AccessToken $AccessToken -Uri $Uri).userPrincipalName | Sort-Object userPrincipalName

        $CustomObject = New-Object -TypeName psobject
        $CustomObject | Add-Member -MemberType NoteProperty -Name "Group" -Value $GroupName
        $CustomObject | Add-Member -MemberType NoteProperty -Name "Members" -Value $Members
        $CustomObject
    }
}


# Get all group and user conditions from the policies.
$Result = foreach ($Policy in $CAPolicies) {
    # Initiate custom object.
    $CustomObject = New-Object -TypeName psobject

    
    $CustomObject | Add-Member -MemberType NoteProperty -Name "displayName" -Value $Policy.displayName
    $CustomObject | Add-Member -MemberType NoteProperty -Name "state" -Value $Policy.state


    # Format include groups.
    [string]$includeGroups = foreach ($Group in ($Policy.includeGroupsDisplayName | Sort-Object)) {
        "$Group`r`n"
    }

    if ($includeGroups.Length -gt 1) {
        $includeGroups = $includeGroups.Substring(0, "$includeGroups".Length-1)
    }

    [string]$includeGroups = [string]$includeGroups -replace "`r`n ", "`r`n"

    $CustomObject | Add-Member -MemberType NoteProperty -Name "includeGroups" -Value $includeGroups


    # Format include users.
    [string]$includeUsers = $Policy.includeUsersUserPrincipalName -replace " ", "`r`n"
    if ($includeUsers) { [string]$includeUsers += "`r`n" }

    if ($GetGroupMembers) {
        [string]$includeUsers += foreach ($Group in $Policy.includeGroupsDisplayName) {
            [string](($includeGroupMembers | Where-Object { $_.Group -eq $Group }).Members | Sort-Object) -replace " ", "`r`n"
        }
    }

    $includeUsers = $includeUsers -replace " ", "`r`n"

    $CustomObject | Add-Member -MemberType NoteProperty -Name "includeUsers" -Value $includeUsers

    foreach ($User in ($Policy.includeUsersUserPrincipalName | Sort-Object)) {
        $includeUsers = "$includeUsers`r`n$User"
    }


    # Format exclude groups.
    [string]$excludeGroups = foreach ($Group in ($Policy.excludeGroupsDisplayName | Sort-Object)) {
        "$Group`r`n"
    }

    if ($excludeGroups.Length -gt 1) {
        $excludeGroups = $excludeGroups.Substring(0, "$excludeGroups".Length-1)
    }

    [string]$excludeGroups = [string]$excludeGroups -replace "`r`n ", "`r`n"

    $CustomObject | Add-Member -MemberType NoteProperty -Name "excludeGroups" -Value $excludeGroups


    # Format exclude users.
    [string]$excludeUsers = $Policy.excludeUsersUserPrincipalName -replace " ", "`r`n"
    if ($excludeUsers) { [string]$excludeUsers += "`r`n" }

    if ($GetGroupMembers) {
        [string]$excludeUsers += foreach ($Group in $Policy.excludeGroupsDisplayName) {
            [string](($ExcludeGroupMembers | Where-Object { $_.Group -eq $Group }).Members | Sort-Object) -replace " ", "`r`n"
        }
    }

    $excludeUsers = $excludeUsers -replace " ", "`r`n"

    $CustomObject | Add-Member -MemberType NoteProperty -Name "excludeUsers" -Value $excludeUsers

    foreach ($User in ($Policy.excludeUsersUserPrincipalName | Sort-Object)) {
        $excludeUsers = "$excludeUsers`r`n$User"
    }


    # Output the result.
    $CustomObject
}


# Export the result to Excel.
Write-Verbose -Verbose -Message "Exporting report to Excel..."
$Result | Export-Excel -Path "ConditonalAccessAssignments.xlsx" -WorksheetName "Conditional Access Assignments" -BoldTopRow -FreezeTopRow -AutoFilter -AutoSize -ClearSheet -Show


Write-Verbose -Verbose -Message "Done!"


# ----- [End] -----