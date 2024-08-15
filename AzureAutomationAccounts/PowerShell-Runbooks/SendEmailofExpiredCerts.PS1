<#
    .DESCRIPTION
        This PowerShell script is intended to be run via an Azure Automation account runbook. This script will query all Enterprise apps and App registrations and then send an email per expired certificate and secret to your ticketing system to generate a ticket.
        Note, you must import the Microsoft.Graph PowerShell module to your automation account first.
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




        .NOTES
        AUTHOR: Elijah Smart
        LASTEDIT: Aug 16, 2024
        VERSION: 0.2


#>

"Please enable appropriate RBAC permissions to the system identity of this automation account. Otherwise, the runbook may fail..."


#Connecting to MgGraph and Azure (this may be surplus to requirements)
try
{
    "Logging in to Microsoft Graph"
    Connect-MgGraph -scopes 'Application.Read.All','mail.send' -Identity
    "Logged into Microsoft Graph"
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}
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
    Send-MgUserMail -UserId $MailFrom -Message $Message
}


#Functions end
#**************************************************************************************
#Initialise variables

#Test email functionality
Send-Email -MsgBody "It works?"

#Get expiring App registraion (Get-MgApplication -all) certs and secrets

#Get expiring Enterprise (Get-MgServicePrincipal -all) app certs

#Send email per expiring cert/secret

#Send-Email -MsgBody

#Send report email
#For later...