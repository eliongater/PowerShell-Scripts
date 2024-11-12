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
        LASTEDIT: Nov 8, 2024
        VERSION: 1.9


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
#$Global:MailTo = "elijah.smart@datacom.com;nzemmtest@datacom.com"
$Global:MailTo = "nhcazurecertautomation@datacom.com"
#$Global:MailFrom = "elijah.smart@now4you.nz"
$Global:MailFrom = "azurecertautomation@naturalhazards.govt.nz"


#Define any functions
function Send-Email {
    param (
        [system.string]$MailTo = $Global:MailTo,
        [system.string]$MailFrom = $Global:MailFrom,
        [system.string]$Subject = "App Secret Expiration Notice",
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
            ToRecipients = @()
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
            ToRecipients = @()
        }

    }

    $EmailAddresses = $MailTo.split(";")
    foreach ($EmailAddress in $EmailAddresses){
        Write-Output "Adding $EmailAddress to recipients"
        $Message.ToRecipients += @{
            EmailAddress = @{
                Address = $EmailAddress
            }
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
    $psCustomObject | Get-Member -MemberType *Property | % {
        $output.($_.name) = $psCustomObject.($_.name); 
    } 
    
    Write-Verbose "[Exit]:: ConvertTo-HashtableFromPsCustomObject"

    return  $output;
}


#Potential for webhooks to be added later?
#https://github.com/bwya77/PSAlerts/blob/main/Azure/AppSecretExpiration_SendtoTeams.ps1

#Functions end
#**************************************************************************************

#Initialise variables
#$ReportMailTo = "elijah.smart@datacom.com"
$ReportMailTo = "Security@eqc.govt.nz;sysops_reports@naturalhazards.govt.nz"

$Expirations = @()

$ExpirationThreshold = 60
$ExpirationDateToCheck = (get-date).AddDays($ExpirationThreshold)
$AlertingInterval = 60
$AlertDate = (get-date).AddDays(-1*$AlertingInterval)
$Today = get-date

#$AutomationVariableName = "PriorAlerts"
$AutomationVariableName = "EntraID-EntAppCert-RPT-PriorAlerts"

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

    #If closest expiration is in the x day period we care about
    if($EndDates[-1] -lt $ExpirationDateToCheck -and $EndDates.Length -gt 0){
        ############################################
        $Expirations += [PSCustomObject]@{
            'AppName'                = $AppName
            'ObjectID'               = $ObjectID
            'ApplicationID'          = $AppID
            'Date'                   = $EndDates[-1]
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

    #If closest expiration is in the x day period we care about
    if($EndDates[-1] -lt $ExpirationDateToCheck -and $EndDates.Length -gt 0 -and $AppType -eq "Application"){
        ############################################
        $Expirations += [PSCustomObject]@{
            'AppName'                = $AppName
            'ObjectID'               = $ObjectID
            'ApplicationID'          = $AppID
            'Date'                   = $EndDates[-1]
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
$SendReportAlways = $False
$ReportSubject = "Report of Expired/Expiring Enterprise app and App registraion Certs/Secrets"
#If it's the first of the month or $SendReportAlways = $True, send a list of all upcoming expirations
if(((Get-Date).Day -eq 1) -or $SendReportAlways){
    Send-Email -MsgBody $ReportEmailBody -MailTo $ReportMailTo -Subject $ReportSubject
}
