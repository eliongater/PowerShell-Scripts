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