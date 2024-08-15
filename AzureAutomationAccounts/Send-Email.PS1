function Send-Email {
    param (
        [system.string]$MailTo,
        [system.string]$MailFrom,
        [system.string]$Subject = "",
        [system.string]$Body ="",
        [system.string]$Attachment
    )
    #Initialise Variables
    $Message

    #If a file path to an attachment is passed as a parameter, then send with an attachment, else send without one
    if ($PSBoundParameters.ContainsKey('Attachment')) {
        $AttachmentContentBytes = [System.IO.File]::ReadAllBytes($Attachment)
        $AttachmentBase64 = [System.Convert]::ToBase64String($AttachmentContentBytes)
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