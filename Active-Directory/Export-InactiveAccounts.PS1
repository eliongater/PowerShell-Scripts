# Set the number of days for inactivity
$DaysInactive = 90

# Define the path for the CSV file
$CSVPath = "C:\temp\InactiveUsers.csv"

# Import the Active Directory module
Import-Module ActiveDirectory

# Get the date for comparison
$Date = (Get-Date).AddDays(-$DaysInactive)

# Find inactive users
$InactiveUsers = Get-ADUser -Filter {LastLogonDate -lt $Date -and Enabled -eq $true} -Properties LastLogonDate, UserPrincipalName, SamAccountName | 
    Select-Object Name, UserPrincipalName, SamAccountName, @{Name="LastLogonDate";Expression={[datetime]::FromFileTime($_.LastLogonDate)}}

# Export to CSV
$InactiveUsers | Export-Csv -Path $CSVPath -NoTypeInformation

Write-Output "Inactive users have been exported to $CSVPath"
