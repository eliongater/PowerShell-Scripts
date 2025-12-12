<#
.SYNOPSIS
Sends an email using Microsoft Graph for a specified user, with optional single or multiple file attachments.

.DESCRIPTION
Send-Email constructs a Microsoft Graph message payload and calls Send-MgUserMail to deliver an HTML email from the specified sender (user) to one or more recipients.
- If the Attachment parameter is provided, a single file is read from disk, Base64-encoded and added as a fileAttachment.
- If the Attachments parameter is provided (and Attachment is not), each file path in the array is read, Base64-encoded and appended as a fileAttachment.
- If neither Attachment nor Attachments is provided, the message is sent without attachments.
- The MailTo parameter accepts a semicolon (;) separated list of recipient email addresses.
- The default Subject and default MailTo/MailFrom fallback to corresponding global variables if not supplied.

.PARAMETER MailTo
String of recipient email addresses. Multiple addresses may be provided separated by semicolons (;). Default: $Global:MailTo.

.PARAMETER MailFrom
Email address (or user id) of the sender to use as the -UserId argument to Send-MgUserMail. Default: $Global:MailFrom.

.PARAMETER Subject
Subject line for the email. Default: "App Secret Expiration Notice".

.PARAMETER MsgBody
HTML content to use as the message body. The function sets the message ContentType to "HTML".

.PARAMETER Attachment
Single file path to attach to the message. If present, this takes precedence over Attachments. The file is read from disk and Base64-encoded into a Microsoft Graph fileAttachment with ContentType "application/octet-stream".

.PARAMETER Attachments
Array of file paths to attach to the message. Each file path is read from disk and Base64-encoded into an individual Microsoft Graph fileAttachment. Ignored if Attachment is provided.

.EXAMPLE
Send-Email -MailTo "alice@example.com" -MailFrom "sender@example.com" -Subject "Hello" -MsgBody "<p>Test</p>"

Sends a simple HTML email with no attachments.

.EXAMPLE
Send-Email -MailTo "bob@example.com;carol@example.com" -Attachment "C:\logs\report.pdf"

Sends an email to Bob and Carol with a single attachment named report.pdf.

.EXAMPLE
Send-Email -MailTo "team@example.com" -Attachments @("C:\a.txt","C:\b.png")

Sends an email with multiple attachments.

.INPUTS
None from the pipeline. All parameters are passed explicitly.

.OUTPUTS
This function primarily performs a side-effect (sending an email). It writes progress messages with Write-Output/Write-Error. Any output returned by the underlying Send-MgUserMail call (if returned) will be passed through. Errors encountered while reading files or sending mail are thrown.

.NOTES
- Requires the Microsoft Graph PowerShell module (Send-MgUserMail) and an authenticated context with appropriate permissions to send mail on behalf of the specified user (e.g., Mail.Send or equivalent application/delegated permissions).
- Files specified in Attachment(s) must be accessible to the running process; large attachments may fail or be rejected by tenant/Graph size limits.
- Attachments are added with ContentType "application/octet-stream" and named using the file name from the supplied path; adjust if a specific MIME type is required.
- If both Attachment and Attachments are supplied, Attachment is used and Attachments is ignored.
#>
function Send-Email {
    param (
        [system.string]$MailTo = $Global:MailTo,
        [system.string]$MailFrom = $Global:MailFrom,
        [system.string]$Subject = "App Secret Expiration Notice",
        [system.string]$MsgBody ="",
        [system.string]$Attachment,
        [system.array]$Attachments
    )
    #Initialise Variables
    $Message = $null

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
    } elseif ($PSBoundParameters.ContainsKey('Attachments')) {
        $Message = @{
            Subject = "$Subject"
            Body = @{
                ContentType = "HTML"
                Content = $MsgBody
                }
            ToRecipients = @()
                Attachments = @()
        }
        foreach ($ThisAttachment in $Attachments) {
            $AttachmentContentBytes = [System.IO.File]::ReadAllBytes($ThisAttachment)
            $AttachmentBase64 = [System.Convert]::ToBase64String($AttachmentContentBytes)
            $Message.Attachments += @{
                "@odata.type" = "#microsoft.graph.fileAttachment"
                Name = (Split-Path $ThisAttachment -Leaf)
                ContentType = "application/octet-stream"
                ContentBytes = $AttachmentBase64
            }
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
        Write-Output "Sending email from $MailFrom to $MailTo, with the subject $Subject"
        Send-MgUserMail -UserId $MailFrom -Message $Message
    }
    catch {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
    
}