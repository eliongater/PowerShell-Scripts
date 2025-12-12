<#
    .DESCRIPTION
        This PowerShell script is intended to be run via an Azure Automation account runbook. This script will query all Enterprise apps and App registrations and then send an email per expired certificate and secret to your ticketing system to generate a ticket.
        Note, you must import the Microsoft.Graph PowerShell module to your automation account first.
        This will also utilise Azure Automation (AA) variables to store a list of 30* days worth of by using a hash table. First we will retrive the AA variable containing the hash table, then any expiring app alert already in the hash table older than 30 days will be deleted, if it is newer than 30 days it will not be alerted on again. 


        You must also assign the system assigned identity of your automation account the relevant permissions, in this case mail.send and Application.Read.All

        .References:
        https://www.thelazyadministrator.com/2023/12/16/automated-alerts-on-azure-entra-id-application-secret-expirations/
        https://thesysadminchannel.com/graph-api-using-a-managed-identity-in-an-automation-runbook/

        Logic app and power automate approach:
        https://techcommunity.microsoft.com/t5/core-infrastructure-and-security/use-azure-logic-apps-to-notify-of-pending-aad-application-client/ba-p/3014603?fbclid=IwAR3ECopMRsitagEStKLC_yvAmFX4a1Ispn_a8ZFitapPquq9OZcZvQgKVOQ
        https://techcommunity.microsoft.com/t5/core-infrastructure-and-security/use-power-automate-to-notify-of-upcoming-azure-ad-app-client/ba-p/2406145

        Emailing from PowerShell:
        https://lazyadmin.nl/powershell/send-email-powershell/
        https://stackoverflow.com/questions/69080522/send-mail-via-microsoft-graph-as-application-any-user
        https://learn.microsoft.com/en-us/graph/permissions-reference
        https://woshub.com/send-email-microsoft-graph-api-powershell/
        https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.users.actions/send-mgusermail?view=graph-powershell-1.0

        Automation account variables:
        https://learn.microsoft.com/en-us/azure/automation/shared-resources/variables?tabs=azure-powershell
        https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-hashtable?view=powershell-7.4
        https://omgdebugging.com/2019/02/25/convert-a-psobject-to-a-hashtable-in-powershell/




        .NOTES
        AUTHOR: Elijah Smart
        LASTEDIT: Dec 12, 2025
        VERSION: 2.0


#>

"Please enable appropriate RBAC permissions to the system identity of this automation account. Otherwise, the runbook may fail..."


#Connecting to MgGraph
try
{
    "Logging in to Microsoft Graph"
    Connect-MgGraph -Identity
    "Logged into Microsoft Graph"
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

#Connecting to Azure
<#try
{
    "Logging in to Azure"
    Connect-AzAccount -Identity
    "Logged in to Azure"
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}#>

#Initialise Global variables
$Global:MailTo = "elijah.smart@datacom.com"
#$Global:MailTo = "nhcazurecertautomation@datacom.com"
$Global:MailFrom = "elijah.smart@now4you.nz"
#$Global:MailFrom = "azurecertautomation@naturalhazards.govt.nz"


#**************************************************************************************
#Define any functions
<#
.SYNOPSIS
Sends an email (optionally with a file attachment) using Microsoft Graph's Send-MgUserMail cmdlet.

.DESCRIPTION
Send-Email constructs a Microsoft Graph message payload and calls Send-MgUserMail to deliver mail from a specified sender to a recipient. If an Attachment path is provided, the file is read, base64-encoded and included as a fileAttachment. The message body is sent as HTML. The function writes a status message before calling the Graph API and throws on failure.

.PARAMETER MailTo
The recipient email address. Single address expected as a string (e.g. "user@example.com") or as string of semi colon seperated emails (e.g. "user@example.com;user2@example.com").

.PARAMETER MailFrom
The sender (user) id or email address for Send-MgUserMail -UserId parameter. The account used to send must be accessible with the authenticated Graph context and have appropriate Mail.Send permissions.

.PARAMETER Subject
Optional. The email subject. Defaults to an empty string.

.PARAMETER MsgBody
Optional. The email body content, treated as HTML. Defaults to an empty string.

.PARAMETER Attachment
Optional. A local filesystem path to a file to attach to the message. If provided, the file is read and included as a Base64-encoded fileAttachment. The file must be accessible to the process and should be of a size supported by the Graph API.

.EXAMPLE
Send-Email -MailTo "recipient@contoso.com" -MailFrom "sender@contoso.com" -Subject "Hello" -MsgBody "<p>This is a test</p>"
Sends a simple HTML email without attachments.

.EXAMPLE
Send-Email -MailTo "recipient@contoso.com" -MailFrom "sender@contoso.com" -Subject "Report" -MsgBody "<p>Please find the report attached.</p>" -Attachment "C:\temp\report.pdf"
Sends an email with report.pdf attached.

.OUTPUTS
None. On success, the function invokes Send-MgUserMail and does not return a value. On error, it writes an error and rethrows the exception.

.NOTES
- Prerequisites: Microsoft Graph PowerShell module (e.g. Microsoft.Graph or Microsoft.Graph.Users) and a valid Connect-MgGraph session.
- The authenticated context must have permission to send mail as the specified MailFrom (Mail.Send or equivalent delegated/application permissions).
- Body content type is HTML. Modify the function if you require plain text bodies or multipart content.
- Large attachments may be rejected by Graph; consider using upload session APIs for very large files.
- Attachment filename is derived from the provided file path (Split-Path -Leaf).
- The function logs a simple message before sending; consider replacing with Write-Verbose/Write-Information for advanced scenarios.

.LINK
https://learn.microsoft.com/graph/api/user-sendmail
#>
function Send-Email {
    param (
        [system.string]$MailTo,
        [system.string]$MailFrom,
        [system.string]$Subject = "",
        [system.string]$MsgBody ="",
        [system.string]$Attachment
    )
    #Initialise Variables
    $Message

    #E.g. $Attachment = "C:\logs\mytestapp.log"
    #If a file path to an attachment is passed as a parameter, then send with an attachment, else send without one
    if ($PSBoundParameters.ContainsKey('Attachment')) {
        $AttachmentContentBytes = [System.IO.File]::ReadAllBytes($Attachment)
        $AttachmentBase64 = [System.Convert]::ToBase64String($AttachmentContentBytes)
        $Message = @{
            Subject = "$Subject"
            Body = @{
                ContentType = "HTML"
                Content = $MsgBody
                }
            ToRecipients = @(
                @{
                    EmailAddress = @{
                    Address = $MailTo
                    }
                }
                )
                Attachments = @(
            @{
                "@odata.type" = "#microsoft.graph.fileAttachment"
                Name = (Split-Path $Attachment -Leaf)
                ContentType = "application/octet-stream"
                ContentBytes = $AttachmentBase64
                }
            )
        }
    } else {
        $Message = @{
            Subject = "$Subject"
            Body = @{
                ContentType = "HTML"
                Content = $msgBody
                }
            ToRecipients = @(
                @{
                    EmailAddress = @{
                    Address = $MailTo
                    }
                }
            )
        }

    }

    #Send email
    try
    {
        "Sending email from $MailFrom to $MailTo, with the subject $Subject"
        Send-MgUserMail -UserId $MailFrom -Message $Message
    }
    catch {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
    
}

function ConvertTo-HashtableFromPsCustomObject { 
    param ( 
        [Parameter(  
            Position = 0,   
            Mandatory = $true,   
            ValueFromPipeline = $true,  
            ValueFromPipelineByPropertyName = $true  
        )] [object] $psCustomObject 
    );
    Write-Verbose "[Start]:: ConvertTo-HashtableFromPsCustomObject"

    $output = @{}; 
    $psCustomObject | Get-Member -MemberType *Property | ForEach-Object {
        $output.($_.name) = $psCustomObject.($_.name); 
    } 
    
    Write-Verbose "[Exit]:: ConvertTo-HashtableFromPsCustomObject"

    return  $output;
}

<#
.SYNOPSIS
    Extracts email addresses from a list of tags based on a specified tag name and delimiter.

.DESCRIPTION
    The Get-EmailFromTags function scans through an array of tag strings, searching for tags that start with a specified tag name followed by a delimiter (default is "owner:").
    When a matching tag is found, it extracts the value after the delimiter (assumed to be an email address), trims it, and collects all such emails into a semicolon-separated string.
    Returns $null if no matching tags are found.

.PARAMETER Tags
    An array of tag strings to search for email addresses.

.PARAMETER TagName
    The tag name to look for (default is "owner").

.PARAMETER Delimiter
    The delimiter separating the tag name and value (default is ":").

.EXAMPLE
    Get-EmailFromTags -Tags @("owner:someone@example.com", "env:prod")
    # Returns "someone@example.com"
#>
function Get-EmailFromTags {
    param (
        [Parameter(
            Mandatory = $true,   
            ValueFromPipeline = $true
        )] [string[]] $Tags,
        [string] $TagName = "owner",
        [string] $Delimiter = ":"
    );
    $emails = @()
    foreach ($Tag in $Tags){
        if ($Tag.ToLower().StartsWith($TagName.ToLower() + $Delimiter)){
            $email = $Tag.Split($Delimiter)[1].Trim()
            $emails += $email
        }
    }
    if ($emails.Count -gt 0){
        return $emails -join ";"
    } else {
        return $null
    }
}

#Potential for webhooks to be added later?
#https://github.com/bwya77/PSAlerts/blob/main/Azure/AppSecretExpiration_SendtoTeams.ps1

#Functions end
#**************************************************************************************

#Initialise variables
$ReportMailTo = "elijah.smart@datacom.com"
#$ReportMailTo = "Security@eqc.govt.nz;sysops_reports@naturalhazards.govt.nz"

$Expirations = @()

$ExpirationThreshold = 60
$ExpirationDateToCheck = (get-date).AddDays($ExpirationThreshold)
$AlertingInterval = 60
$AlertDate = (get-date).AddDays(-1*$AlertingInterval)
$Today = get-date

$AutomationVariableName = "PriorAlerts"
#$AutomationVariableName = "EntraID-EntAppCert-RPT-PriorAlerts"

#Should probably make this an automation variable later
$ApplicationsToIgnore = @(
    "Office 365 Exchange Online"
)

[hashtable]$PriorAlerts = @{}
#ID and Date last alerted on
#$PriorAlerts.add('71078dec-d452-4c8a-9251-97f070faa3a6','16/08/2024')
try{
    $PriorAlerts = Get-AutomationVariable -name $AutomationVariableName
}
catch [System.ArgumentNullException]{
    Write-Verbose "Prior Alerts is currently null"
    Write-Verbose -Message $_.Exception
    try{
        "Attempting to initialise Prior Alerts"
        Set-AutomationVariable -Name $AutomationVariableName -Value $PriorAlerts
    }
    catch {
        Write-Error "Failed to initialise prior alerts"
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}
catch [System.Management.Automation.ArgumentTransformationMetadataException]{
    Write-Verbose "Problem retrieving prior alerts as a hash table, will attempt to convert."
    Write-Verbose -Message $_.Exception
    try{
        $PSObjectPriorAlerts = Get-AutomationVariable -name $AutomationVariableName
        $PriorAlerts = ConvertTo-HashtableFromPsCustomObject -psCustomObject $PSObjectPriorAlerts
    }
    catch {
        Write-Error "Failed to convert prior alerts from powershell custom object"
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}
catch {
    Write-Error "Failed to retrive prior alerts"
    Write-Error -Message $_.Exception
    throw $_.Exception
}



#Test email functionality
#Send-Email -MsgBody "It works?"

#Remove old prior alerts from prior alert list
$AlertsToRemove = @()
try{
    foreach ($PriorAlert in $PriorAlerts.GetEnumerator()){
        $DateToCompare = get-date $PriorAlert.value
        if ($DateToCompare -lt $AlertDate) {
            $AlertsToRemove += $PriorAlert.key
        }
    }
}
catch{
    Write-Error "Failed to enumerate Prior Alerts, check that it is indeed a hash table"
    Write-Error -Message $_.Exception
    throw $_.Exception
}
#Note, cannot modify a hashtable whilst it is being enumerated. 
foreach ($AlertToRemove in $AlertsToRemove){
    $PriorAlerts.Remove($AlertToRemove)
}

#Get expiring App registraion (Get-MgApplication -all) certs and secrets
$Applications
try {
    $Applications = Get-MgApplication -All
}
catch {
    Write-Error "Failed to run Get-MgApplication, check you have the correct modules installed."
    Write-Error -Message $_.Exception
    throw $_.Exception
}

$Count = 0
foreach ($App in $Applications) {
    $Completed = ($count/$Applications.count) * 100
    $count ++
    # Use Write-Progress to output a progress bar.
    # The Activity and Status parameters create the first and second lines of the progress bar
    # heading, respectively.
    Write-Progress -Activity "Getting App registrations" -Status "Progress:" -PercentComplete $Completed
    $AppName = $App.DisplayName
    $ObjectID   = $App.Id
    $AppID  = $App.AppId
    $ownersList = Get-MgApplicationOwner -ApplicationId $app.Id
    $owners = $ownersList.AdditionalProperties.mail -join ';'
    $Tags = $App.Tags
    $ManifestOwners = $null

    if ($Tags -ne $null){
        $ManifestOwners = Get-EmailFromTags -Tags $Tags
        if ($ManifestOwners -ne $null){
            if ($owners.Length -gt 0){
                $owners += ";$ManifestOwners"
            } else {
                $owners = $ManifestOwners
            }
        }
    }

    $AppCreds = Get-MgApplication -ApplicationId $ObjectID |
        Select-Object PasswordCredentials, KeyCredentials

    $Secrets = $AppCreds.PasswordCredentials
    $Certs   = $AppCreds.KeyCredentials

    [DateTime[]]$EndDates = @()

    foreach ($Cert in $Certs){
        $EndDate   = $Cert.EndDateTime
        $EndDates += $EndDate
    }
    foreach ($Secret in $Secrets){
        $EndDate    = $Secret.EndDateTime
        $EndDates += $EndDate
    }

    #Sort end dates to soonest first
    [Array]::Sort($EndDates)

    #Check if app is in ignore list
    if( $ApplicationsToIgnore -contains $AppName){
        Write-Information "Ignoring $AppName as it is in the ignore list"
        continue
    }
    #If closest expiration is in the x day period we care about
    if($EndDates[0] -lt $ExpirationDateToCheck -and $EndDates.Length -gt 0){
        ############################################
        $Expirations += [PSCustomObject]@{
            'AppName'                = $AppName
            'ObjectID'               = $ObjectID
            'ApplicationID'          = $AppID
            'Date'                   = $EndDates[0]
            'Owners'                 = $owners
        }
        ############################################
    }
    
}




#Get expiring Enterprise (Get-MgServicePrincipal -all) app certs
$EnterpriseApps
try {
    $EnterpriseApps = Get-MgServicePrincipal -all
}
catch {
    Write-Error "Failed to run Get-MgServicePrincipal, check you have the correct modules installed."
    Write-Error -Message $_.Exception
    throw $_.Exception
}

$Count = 0

foreach ($EnterpriseApp in $EnterpriseApps) {
    $Completed = ($count/$EnterpriseApps.count) * 100
    $count ++
    # Use Write-Progress to output a progress bar.
    # The Activity and Status parameters create the first and second lines of the progress bar
    # heading, respectively.
    Write-Progress -Activity "Getting Enterprise apps" -Status "Progress:" -PercentComplete $Completed

    $AppName = $EnterpriseApp.DisplayName
    $ObjectID   = $EnterpriseApp.Id
    $AppID  = $EnterpriseApp.AppId
    $AppType = $EnterpriseApp.ServicePrincipalType
    $ownersList = Get-MgServicePrincipalOwner -ServicePrincipalId  $EnterpriseApp.Id
    $owners = $ownersList.AdditionalProperties.mail -join ';'
    $Tags = $EnterpriseApp.Tags
    $ManifestOwners = $null

    if ($Tags -ne $null){
        $ManifestOwners = Get-EmailFromTags -Tags $Tags
        if ($ManifestOwners -ne $null){
            if ($owners.Length -gt 0){
                $owners += ";$ManifestOwners"
            } else {
                $owners = $ManifestOwners
            }
        }
    }
    

    $AppCreds = Get-MgServicePrincipal -ServicePrincipalId $ObjectID |
        Select-Object PasswordCredentials, KeyCredentials

    $Secrets = $AppCreds.PasswordCredentials
    $Certs   = $AppCreds.KeyCredentials

    [DateTime[]]$EndDates = @()

    foreach ($Cert in $Certs){
        $EndDate   = $Cert.EndDateTime
        $EndDates += $EndDate
    }
    foreach ($Secret in $Secrets){
        $EndDate    = $Secret.EndDateTime
        $EndDates += $EndDate
    }

    #Sort end dates to soonest first
    [Array]::Sort($EndDates)

    #Check if app is in ignore list
    if( $ApplicationsToIgnore -contains $AppName){
        Write-Information "Ignoring $AppName as it is in the ignore list"
        continue
    }

    #If closest expiration is in the x day period we care about
    if($EndDates[0] -lt $ExpirationDateToCheck -and $EndDates.Length -gt 0 -and $AppType -eq "Application"){
        ############################################
        $Expirations += [PSCustomObject]@{
            'AppName'                = $AppName
            'ObjectID'               = $ObjectID
            'ApplicationID'          = $AppID
            'Date'                   = $EndDates[0]
            'Owners'                 = $owners
        }
        ############################################
    }
    
}




#Send email/alert per expiring cert/secret
foreach ($Expiration in $Expirations){
    if($PriorAlerts.ContainsKey($($Expiration.ObjectID))){
        "$($Expiration.ObjectID): Alert already sent within the last $AlertingInterval days, not sending"
    } else {
        $recipients = $Global:MailTo
        if ($Expiration.Owners.Length -gt 0){
            $recipients += ";$($Expiration.Owners)"
        }
        $EmailSubject = "Upcoming Enterprise App/App Registration Expiry: $($Expiration.AppName)"
        $EmailBody = "The following Enterprise App or App registration has an upcoming cert/secret expiry.<br />ObjectID: $($Expiration.ObjectID)<br />AppName: #$($Expiration.AppName)/#<br />ExpirationDate: $($Expiration.Date)<br />Enterprise App Link: https://portal.azure.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($Expiration.ObjectID)<br />App registration Link: https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$($Expiration.ObjectID)"
        Send-Email -MsgBody $EmailBody -Subject $EmailSubject -MailTo $recipients
        $PriorAlerts.Add($($Expiration.ObjectID),$Today)
    }
}


#Update Prior Alerts
"Updating PriorAlerts variable"
try
{
    Set-AutomationVariable -Name $AutomationVariableName -Value $PriorAlerts
}
catch {
    Write-Error "Failed to update prior alerts"
    Write-Error -Message $_.Exception
    throw $_.Exception
}


#Send report email
$ReportEmailBody = "<table><tr><th>ObjectID</th><th>AppName</th><th>Owner(s)</th><th>ExpirationDate</th></tr>"
foreach ($Expiration in $Expirations){
    $ReportEmailBody += "<tr><td>$($Expiration.ObjectID)</td><td>$($Expiration.AppName)</td><td>$($Expiration.Owners)</td><td>$($Expiration.Date)</td></tr>"
}
$ReportEmailBody += "</table>"
#Remove last new line
#$ReportEmailBody = $ReportEmailBody -replace ".$"

#Send report email
$SendReportAlways = $True
$ReportSubject = "Report of Expired/Expiring Enterprise app and App registraion Certs/Secrets"
#If it's the first of the month or $SendReportAlways = $True, send a list of all upcoming expirations
if(((Get-Date).Day -eq 1) -or $SendReportAlways){
    Send-Email -MsgBody $ReportEmailBody -MailTo $ReportMailTo -Subject $ReportSubject
}
