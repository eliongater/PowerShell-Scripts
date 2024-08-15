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




        .NOTES
        AUTHOR: Elijah Smart
        LASTEDIT: Aug 16, 2024
        VERSION: 1.0


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
try
{
    "Logging in to Azure"
    Connect-AzAccount -Identity
    "Logged in to Azure"
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

#Initialise Global variables
$Global:MailTo = "elijah.smart@datacom.com"
$Global:MailFrom = "elijah.smart@now4you.nz"


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



#Potential for webhooks to be added later?
#https://github.com/bwya77/PSAlerts/blob/main/Azure/AppSecretExpiration_SendtoTeams.ps1

#Functions end
#**************************************************************************************

#Initialise variables
$ReportMailTo = "elijah.smart@datacom.com"

$Expirations = @()

$ExpirationThreshold = 60
$ExpirationDateToCheck = (get-date).AddDays($ExpirationThreshold)
$AlertingInterval = 30
$AlertDate = (get-date).AddDays(-1*$AlertingInterval)
$Today = get-date

$PriorAlerts = @{}
#ID and Date last alerted on
#$PriorAlerts.add('71078dec-d452-4c8a-9251-97f070faa3a6','16/08/2024')
try{
    $PriorAlerts = Get-AutomationVariable -name "PriorAlerts"
}
catch [System.ArgumentNullException]{
    Write-Warning "Prior Alerts is currently null"
    Write-Warning -Message $_.Exception
    try{
        "Attempting to initialise Prior Alerts"
        Set-AutomationVariable -Name "PriorAlerts" -Value $PriorAlerts
    }
    catch {
        Write-Error "Failed to initialise prior alerts"
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}
finally{
    try{
        $PriorAlerts = Get-AutomationVariable -name "PriorAlerts"
    }
    catch {
        Write-Error "Failed to retrive prior alerts"
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}



#Test email functionality
#Send-Email -MsgBody "It works?"

#Remove old prior alerts from prior alert list
$AlertsToRemove = @()
foreach ($PriorAlert in $PriorAlerts.GetEnumerator()){
    $DateToCompare = get-date $PriorAlert.value
    if ($DateToCompare -lt $AlertDate) {
        $AlertsToRemove += $PriorAlert.key
    }
}
#Note, cannot modify a hashtable whilst it is being enumerated. 
foreach ($AlertToRemove in $AlertsToRemove){
    $PriorAlerts.Remove($AlertToRemove)
}

#Get expiring App registraion (Get-MgApplication -all) certs and secrets
$Applications = Get-MgApplication -All
$Count = 0
foreach ($EnterpriseApp in $EnterpriseApps) {
    $Completed = ($count/$Applications.count) * 100
    $count ++
    # Use Write-Progress to output a progress bar.
    # The Activity and Status parameters create the first and second lines of the progress bar
    # heading, respectively.
    Write-Progress -Activity "Getting App registrations" -Status "Progress:" -PercentComplete $Completed
    $AppName = $App.DisplayName
    $ObjectID   = $App.Id
    $AppID  = $App.AppId

    $AppCreds = Get-MgApplication -ServicePrincipalId $ObjectID |
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
    if($EndDates[0] -lt $ExpirationDateToCheck){
        ############################################
        $Expirations += [PSCustomObject]@{
            'AppName'                = $AppName
            'ID'                     = $ObjectID
            'ApplicationID'          = $AppID
            'Date'                   = $EndDates[0]
        }
        ############################################
    }
    
}




#Get expiring Enterprise (Get-MgServicePrincipal -all) app certs
$EnterpriseApps = Get-MgServicePrincipal -all
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
    if($EndDates[0] -lt $ExpirationDateToCheck){
        ############################################
        $Expirations += [PSCustomObject]@{
            'AppName'                = $AppName
            'ID'                     = $ObjectID
            'ApplicationID'          = $AppID
            'Date'                   = $EndDates[0]
        }
        ############################################
    }
    
}



#Send email/alert per expiring cert/secret
foreach ($Expiration in $Expirations){
    if($PriorAlerts.ContainsKey($($Expiration.ID))){
        "$($Expiration.ID): Alert already sent within the last $AlertingInterval days, not sending"
    } else {
        $EmailBody = "$($Expiration.ObjectID),$($Expiration.AppName),$($Expiration.Date)"
        Send-Email -MsgBody $EmailBody -Subject $EmailBody
        $PriorAlerts.Add($($Expiration.ObjectID),$Today)
    }
}


#Update Prior Alerts
"Updating PriorAlerts variable"
try
{
    Set-AutomationVariable -Name "PriorAlerts" -Value $PriorAlerts
}
catch {
    Write-Error "Failed to update prior alerts"
    Write-Error -Message $_.Exception
    throw $_.Exception
}


#Send report email
$ReportEmailBody
foreach ($Expiration in $Expirations){
    $ReportEmailBody = "$($Expiration.ObjectID),$($Expiration.AppName),$($Expiration.Date)`n"
}
#Remove last new line
$ReportEmailBody = $ReportEmailBody -replace ".$"

#Send report email
Send-Email -MsgBody $ReportEmailBody -MailTo $ReportMailTo