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
$AzureContext = $null
#Connect using a Managed Service Identity
try {
    $AzureContext = (Connect-AzAccount -Identity -ErrorAction Stop).context
}
catch{
    Write-Output "There is no system-assigned user identity. Aborting."; 
    Write-Error -Message $_.Exception
    throw $_.Exception
}

#Initialise Global variables
$Global:MailTo = "elijah.smart@datacom.com"
#$Global:MailTo = "nhcazurecertautomation@datacom.com"
$Global:MailFrom = "elijah.smart@now4you.nz"
#$Global:MailFrom = "azurecertautomation@naturalhazards.govt.nz"


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


#Functions end
#**************************************************************************************

#Initialise variables
$UserCSV = "user.csv"
$PosCSV = "pos.csv"

$CombinedCSV = "HRData.csv"
$PendingCSV = "HRData-Pending.csv"

# Set the maximum number of automatic updates. If there are more than this, results are sent to Service Desk for approval.
$AutomaticUpdateLimit = 20

#Storage Account
$StorageAccount = "gp01sasftpprdsa01"
$StorageContainer = "fusion5jadestaradprod"

#Set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
$StorageAccountContext = New-AzStorageContext -StorageAccountName $StorageAccount -UseConnectedAccount


#Get Blob content
try {
    $BlobFolderContent = Get-AzStorageBlob -Container $StorageContainer -Context $StorageAccountContext
    Write-Log " Retrieved Blob content."
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}


#Get the user.csv and pos.csv files
$UserFile = $null
$PosFile = $null
<#
try{
    $UserFile = $BlobFolderContent | Where-Object Name -EQ $UserCSV
}
catch {
    Write-Error -Message "User CSV file not found in the blob storage."
    throw $_.Exception
}
try{
    $PosFile = $BlobFolderContent | Where-Object Name -EQ $PosCSV
}
catch {
    Write-Error -Message "Position CSV file not found in the blob storage."
    throw $_.Exception
}
#>

try{
    $UserFile = Get-AzStorageBlob -Container $StorageContainer -Context $StorageAccountContext -Blob $UserCSV
    if ($null -eq $UserFile) {
        throw "User CSV file not found in the blob storage."
    }
}
catch {
    Write-Error -Message "User CSV file not found in the blob storage."
    Write-Error -Message $_.Exception
    throw $_.Exception
}

try{
    $PosFile = Get-AzStorageBlob -Container $StorageContainer -Context $StorageAccountContext -Blob $PosCSV
    if ($null -eq $PosFile) {
        throw "POS CSV file not found in the blob storage."
    }
}
catch {
    Write-Error -Message "POS CSV file not found in the blob storage."
    Write-Error -Message $_.Exception
    throw $_.Exception
}

#Convert the blob content to text
#User CSV
try {
    $UserFileContent = $UserFile.ICloudBlob.DownloadText()
    Write-Output "User CSV file content downloaded."
}
catch {
    Write-Error -Message "Failed to download User CSV file content."
    Write-Error -Message $_.Exception
    throw $_.Exception
}

#POS CSV
try {
    $PosFileContent = $PosFile.ICloudBlob.DownloadText()
    Write-Output "POS CSV file content downloaded."
}
catch {
    Write-Error -Message "Failed to download POS CSV file content."
    Write-Error -Message $_.Exception
    throw $_.Exception
}

#Convert the CSV text to objects
try {
    $UserData = $UserFileContent | ConvertFrom-Csv
    Write-Output "User CSV content converted to objects."
}
catch {
    Write-Error -Message "Failed to convert User CSV content to objects."
    Write-Error -Message $_.Exception
    throw $_.Exception
}
try {
    $PosData = $PosFileContent | ConvertFrom-Csv
    Write-Output "POS CSV content converted to objects."
}
catch {
    Write-Error -Message "Failed to convert POS CSV content to objects."
    Write-Error -Message $_.Exception
    throw $_.Exception
}

#Combine the data based on a common field, posidnumber in user.csv and idnumber in pos.csv
try {
    $CombinedData = foreach ($user in $UserData) {
        $pos = $PosData | Where-Object { $_.EmployeeID -eq $user.posidnumber }
        if ($pos) {
            # Create a new object combining user and pos data
            [PSCustomObject]@{
                WorkerID     = $user.idnumber
                WorkerStatus = "Active"
                City         = $pos.Description
                CountryCode  = if($null -eq $pos.Country -or $pos.Country -eq "") {"NZ"} else {$pos.Country}
                Department   = $pos.customfield_emphrdivision
                FullName     = "$($user.FirstName) $($user.LastName)"
                FirstName    = $user.FirstName
                JobTitle     = $pos.fullname
                Email        = $user.Email
                ManagerID    = $user.manageridnumber
                LastName     = $user.LastName
                UserID       = $user.username
                Company      = $user.customfield_emphrdepartment
                WorkerType   = $user.customfield_empstatus
                HireDate     = $user.customfield_empstartdate
                Division     = $user.customfield_emphrdivision
                HasChanges   = $false
            }
        } else {
            Write-Output "No matching position found for posidnumber: $($user.posidnumber), idnumber: $($user.idnumber)"
        }
    }
    Write-Output "Data combined successfully."
}
catch {
    Write-Error -Message "Failed to combine User and POS data."
    Write-Error -Message $_.Exception
    throw $_.Exception
}

#Enumerate the combined data and compare the data with Entra ID, for each user with differences, increment $UpdateCount, then log the differences and update $HasChanges to $true
$CombinedandComparedData =@{}
$UpdateCount = 0
foreach ($entry in $CombinedData) {
    try {
        $user = Get-MgUser -UserId $entry.UserID -ErrorAction Stop
        if ($null -ne $user) {
            #Compare fields and log differences
            $differences = @()
            if ($user.DisplayName -ne $entry.FullName) {
                $differences += "DisplayName: '$($user.DisplayName)' -> '$($entry.FullName)'"
            }
            if ($user.GivenName -ne $entry.FirstName) {
                $differences += "GivenName: '$($user.GivenName)' -> '$($entry.FirstName)'"
            }
            if ($user.Surname -ne $entry.LastName) {
                $differences += "Surname: '$($user.Surname)' -> '$($entry.LastName)'"
            }
            if ($user.JobTitle -ne $entry.JobTitle) {
                $differences += "JobTitle: '$($user.JobTitle)' -> '$($entry.JobTitle)'"
            }
            if ($user.Mail -ne $entry.Email) {
                $differences += "Mail: '$($user.Mail)' -> '$($entry.Email)'"
            }
            if ($user.Department -ne $entry.Department) {
                $differences += "Department: '$($user.Department)' -> '$($entry.Department)'"
            }
            if ($user.CompanyName -ne $entry.Company) {
                $differences += "CompanyName: '$($user.CompanyName)' -> '$($entry.Company)'"
            }
            if ($user.CountryLetterCode -ne $entry.CountryCode) {
                $differences += "CountryLetterCode: '$($user.CountryLetterCode)' -> '$($entry.CountryCode)'"
            }
            if ($user.City -ne $entry.City) {
                $differences += "City: '$($user.City)' -> '$($entry.City)'"
            }

            #If there are differences, increment the update count and log the differences
            if ($differences.Count -gt 0) {
                $UpdateCount++
                $entry.HasChanges = $true
                Write-Output "Differences for UserID $($entry.UserID):"
                foreach ($diff in $differences) {
                    Write-Output "  - $diff"
                }
            }
            #add the entry to the combined and compared data
            $CombinedandComparedData += $entry
        } else {
            Write-Output "User with UserID $($entry.UserID) not found in Entra ID."
        }
    }
    catch {
        Write-Error -Message "Error retrieving user with UserID $($entry.UserID): $_"
    }
}

#Export the combined and compared data to a CSV file
$TempCSVFilePath = "$env:TEMP\$CombinedCSV"
try {
    $CombinedandComparedData | Export-Csv -NoTypeInformation -Delimiter ',' -Encoding UTF8 -Force -Path $TempCSVFilePath
    Write-Output "Combined and compared data exported to $CombinedCSV."
}
catch {
    Write-Error -Message "Failed to export combined and compared data to CSV."
    Write-Error -Message $_.Exception
    throw $_.Exception
}

#If $UpdateCount is greater than $AutomaticUpdateLimit, send the CSV to Service Desk and HR for approval, change the filename from $CombinedCSV to $PendingCSV, else proceed
$AzureShareFileName = $CombinedCSV
if ($UpdateCount -gt $AutomaticUpdateLimit) {
    $MsgBody = "<p>Hello,</p><p>The number of changes detected in the HR data exceeds the automatic update limit of $AutomaticUpdateLimit. There are a total of $UpdateCount changes that require your approval before they can be applied to Entra ID.</p><p>Please review the attached CSV file containing the proposed changes and approve or reject them as necessary.</p><p>Thank you,<br/>Entra ID Provisioning Automation</p>"
    Send-Email -MailTo $Global:MailTo -Subject "HR Data Changes Pending Approval" -MsgBody $MsgBody -Attachment $TempCSVFilePath -MailFrom $Global:MailFrom
    $AzureShareFileName = $PendingCSV
    Write-Output "Update count $UpdateCount exceeds automatic update limit of $AutomaticUpdateLimit. Changes sent for approval."
}


#Upload the combined CSV back to Azure file share
try {
    Set-AzStorageFileContent -ShareName $StorageContainer -Path $AzureShareFileName -Source $TempCSVFilePath -Context $StorageAccountContext -Force
    Write-Output "Combined CSV uploaded successfully to Azure File Share."
} 
catch {
    Write-Error -Message "Failed to upload combined CSV to Azure File Share."
    Write-Error -Message $_.Exception
    throw $_.Exception
}