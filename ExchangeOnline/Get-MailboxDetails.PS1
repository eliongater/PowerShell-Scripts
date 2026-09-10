# Connect to Exchange Online
Connect-ExchangeOnline -ShowProgress $false
 
$Report = @()
 
# Get All shared mailboxes
$Mailboxes = Get-EXOMailbox -ResultSize Unlimited -RecipientTypeDetails SharedMailbox -Properties GrantSendOnBehalfTo
$TotalMailboxes = $Mailboxes.Count
 
# Iterate through each shared mailbox
Foreach ($Mailbox in $Mailboxes) {
   Write-Host -f Cyan "Processing mailbox $($Mailbox.PrimarySmtpAddress) ($($Mailboxes.IndexOf($Mailbox) + 1) of $TotalMailboxes)..."   
   # Get Full Access permissions
   $FullAccessPermissions = Get-EXOMailboxPermission -identity $Mailbox.Guid  | Where-Object{ $_.User -like '*@*' }
    if ($FullAccessPermissions) {
        foreach ($Permission in $FullAccessPermissions) {
                $curpermission = [PSCustomObject]@{
                    SharedMailboxDisplayName  = $Mailbox.DisplayName
                    SharedMailboxEmailAddress = $Mailbox.PrimarySmtpAddress
                    UserEmail                 = $Permission.User
                    UserPermission            = ($Permission.AccessRights | out-string).trim()
                } 
                $Report += $curpermission
        }
    }
    # Get Send As permissions
    $SendAsPermissions = Get-EXORecipientPermission -Identity $Mailbox.Identity | Where-Object { $_.Trustee -like '*@*' -and $_.AccessRights -contains "SendAs" }
      if ($SendAsPermissions) {
         foreach ($Permission in $SendAsPermissions) {
                  $curpermission = [PSCustomObject]@{
                     SharedMailboxDisplayName  = $Mailbox.DisplayName
                     SharedMailboxEmailAddress = $Mailbox.PrimarySmtpAddress
                     UserEmail                 = $Permission.Trustee
                     UserPermission            = ($Permission.AccessRights | out-string).trim()
                  } 
                  $Report += $curpermission
         }
      }
 
   # Get Send On Behalf permissions
   $SendOnBehalfPermissions = $Mailbox.GrantSendOnBehalfTo
      if ($SendOnBehalfPermissions) {
         foreach ($Permission in $SendOnBehalfPermissions) {
            $Recipient = (Get-ExoRecipient -Identity $Permission).PrimarySmtpAddress
                  $curpermission = [PSCustomObject]@{
                     SharedMailboxDisplayName  = $Mailbox.DisplayName
                     SharedMailboxEmailAddress = $Mailbox.PrimarySmtpAddress
                     UserEmail                 = $Recipient
                     UserPermission            = "SendOnBehalf"
                  } 
                  $Report += $curpermission
         }
      }
}
# Display the report
$Report | Format-Table -AutoSize
 
# Export to CSV (optional)
$Report | Export-Csv -Path "C:\Temp\SharedMailboxPermissions.csv" -NoTypeInformation