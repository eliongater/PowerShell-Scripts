param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,

    [switch]$SkipCreate
)

$CsvPath  = "C:\users\elijah.smart\downloads\swlusers.csv"

if (-not (Test-Path $CsvPath)) {
    Write-Error "CSV file not found: $CsvPath"
    exit 1
}


function Get-RowValue {
    param(
        [Parameter(Mandatory = $true)] [psobject]$Row,
        [Parameter(Mandatory = $true)] [string[]]$Headers
    )

    foreach ($header in $Headers) {
        if ($Row.PSObject.Properties.Name -contains $header) {
            $value = $Row.$header
            if ($null -ne $value -and $value -ne '') {
                return $value
            }
        }
    }

    return $null
}

function Find-User {
    param(
        [Parameter(Mandatory = $true)] [string]$Key
    )

    $users = @()

    try {
        $escapedKey = $Key.Replace("'", "''")
        $escapedKeyOnMicrosoft = $escapedKey.split('@')[0] + "@selwynwater.onmicrosoft.com" # In case the key is an email, search by the part before @ to increase chances of a match
        $filter = "userPrincipalName eq '$escapedKey' or mail eq '$escapedKey' or userPrincipalName eq '$escapedKeyOnMicrosoft' or mail eq '$escapedKeyOnMicrosoft'"
        $users += Get-MgUser -Filter $filter -ConsistencyLevel eventual -ErrorAction Stop
        if ($users) {
            Write-host "Found user for key '$Key': $($users[0].UserPrincipalName) ($($users[0].Id))"
            return $users[0]
        }
    } catch {
        Write-Error "Error finding user for key '$Key': $_"
        return $null
    }

    Write-Host "No user found for key '$Key'"
    return $null
}

function Resolve-ManagerId {
    param(
        [Parameter(Mandatory = $true)] [string]$ManagerEmail
)
    $manager = @()
    try {
        $escapedEmail = $ManagerEmail.Replace("'", "''")
        $manager += Get-MgUser -Filter "userPrincipalName eq '$escapedEmail' or mail eq '$escapedEmail'" -ErrorAction Stop
        return $manager[0].Id
    } catch {
        return $null
    }
}

function Resolve-ManagerIdByName {
    param(
        [Parameter(Mandatory = $true)] [string]$ManagerName
    )

    $manager = @()
    try {
        $escapedName = $ManagerName.Replace("'", "''")
        $manager += Get-MgUser -Filter "displayName eq '$escapedName'" -ErrorAction Stop
        return $manager[0].Id
    } catch {
        return $null
    }
}

try {
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "User.ReadWrite.All","Directory.ReadWrite.All" -ErrorAction Stop
    }
} catch {
    Write-Error "Unable to connect to Microsoft Graph. $_"
    exit 1
}

$rows = Import-Csv -Path $CsvPath
$summary = [ordered]@{
    Processed = 0
    Updated = 0
    Created = 0
    Skipped = 0
    Errors = @()
}

foreach ($row in $rows) {
    $summary.Processed++

    $currentEmail = Get-RowValue $row @(
        'UPN/email',
        'UPN Email',
        'Current Email Address (Parent Company)',
        'CurrentEmail'
    )
    $primaryKey = $currentEmail

    if (-not $primaryKey) {
        $summary.Errors += "Row $($summary.Processed): missing a primary email value (UPN/email)."
        $summary.Skipped++
        continue
    }

    $user = Find-User -Key $primaryKey
    $isNewUser = $false

    if (-not $user) {
        if ($SkipCreate) {
            $summary.Errors += "Row $($summary.Processed): user not found and creation skipped: $primaryKey"
            $summary.Skipped++
            continue
        }

        $mailNickname = ($primaryKey.Split('@')[0] -replace '[^a-zA-Z0-9]', '')
        if (-not $mailNickname) { $mailNickname = "user$($summary.Processed)" }

        <#
        $password = [System.Web.Security.Membership]::GeneratePassword(16, 3)
        $passwordProfile = @{
            ForceChangePasswordNextSignIn = $true
            Password = $password
        }
        #>

        $createBody = [ordered]@{
            AccountEnabled = $true
            DisplayName = Get-RowValue $row @('Display Name', 'DisplayName')
            UserPrincipalName = $primaryKey
            MailNickname = $mailNickname
            PasswordProfile = $passwordProfile
        }

        if ($createBody.DisplayName -eq $null) {
            $createBody.DisplayName = Get-RowValue $row @('Preferred First Name', 'PreferredFirstName', 'Preferred F') + ' ' + Get-RowValue $row @('Preferred Last Name', 'PreferredLastName', 'Preferred L')
        }

        try {
            $user = New-MgUser -BodyParameter $createBody -ErrorAction Stop
            $isNewUser = $true
            $summary.Created++
        } catch {
            $summary.Errors += "Row $($summary.Processed): failed to create user $primaryKey - $_"
            continue
        }
    }

    $patchBody = [ordered]@{}
    $displayName = Get-RowValue $row @('Display Name', 'DisplayName')
    $givenName = Get-RowValue $row @('Preferred First Name', 'PreferredFirstName', 'Preferred F')
    $surname = Get-RowValue $row @('Preferred Last Name', 'PreferredLastName', 'Preferred L')
    $jobTitle = Get-RowValue $row @('Current Role', 'Job Title', 'Title', 'Current Role / Job Title')
    $department = Get-RowValue $row @('Business Unit', 'Department', 'Business Unit / Team')
    $company = Get-RowValue $row @('Company', 'Company Name')
    $officeLocation = Get-RowValue $row @('Primary Work Location', 'OfficeLocation', 'Office Location')
    $employeeType = Get-RowValue $row @('Employee Type', 'EmployeeType')
    $employeeId = Get-RowValue $row @('Employee ID', 'Current Employee ID')
    $street = Get-RowValue $row @('Street Add', 'Street Address')
    $city = Get-RowValue $row @('City')
    $state = Get-RowValue $row @('Province', 'State')
    $postalCode = Get-RowValue $row @('Post code', 'PostalCode', 'Postal Code')
    $country = Get-RowValue $row @('Country')
    $phone = Get-RowValue $row @('Primary Work Phone', 'Primary Phone')
    $managerEmail = Get-RowValue $row @('Manager Email', 'Manager E')
    $managerName = Get-RowValue $row @('Manager Name', 'ManagerName')

    if ($displayName) { $patchBody.DisplayName = $displayName }
    if ($givenName) { $patchBody.GivenName = $givenName }
    if ($surname) { $patchBody.Surname = $surname }
    if ($jobTitle) { $patchBody.JobTitle = $jobTitle }
    if ($department) { $patchBody.Department = $department }
    if ($company) { $patchBody.CompanyName = $company }
    if ($officeLocation) { $patchBody.OfficeLocation = $officeLocation }
    if ($employeeId) { $patchBody.EmployeeId = $employeeId }
    if ($street) { $patchBody.StreetAddress = $street }
    if ($city) { $patchBody.City = $city }
    if ($state) { $patchBody.State = $state }
    if ($postalCode) { $patchBody.PostalCode = $postalCode }
    if ($country) { $patchBody.Country = $country }
    if ($phone) { $patchBody.BusinessPhones = @($phone) }
    if ($employeeType) { $patchBody.EmployeeType = $employeeType }



    try {
        if ($patchBody.Count -gt 0) {
            Update-MgUser -UserId $user.Id -BodyParameter $patchBody -ErrorAction Stop | Out-Null
        }

        if ($managerEmail -or $managerName) {
            if ($managerEmail) {
                $managerId = Resolve-ManagerId -ManagerEmail $managerEmail
            } else {
                $managerId = Resolve-ManagerIdByName -ManagerName $managerName
            }

            if ($managerId) {
                $newManager = @{
                    "@odata.id" = "https://graph.microsoft.com/v1.0/users/$managerId"
                }
                Set-MgUserManagerByRef -UserId $user.Id -BodyParameter $newManager -ErrorAction Stop
            } else {
                $summary.Errors += "Row $($summary.Processed): manager not found for $managerEmail $managerName"
            }
        }

        if (-not $isNewUser) {
            $summary.Updated++
        }
    } catch {
        $summary.Errors += "Row $($summary.Processed): failed to update user $primaryKey - $_"
    }
}

Write-Host "Bulk update complete. Processed: $($summary.Processed). Created: $($summary.Created). Updated: $($summary.Updated). Skipped: $($summary.Skipped)."
if ($summary.Errors.Count -gt 0) {
    Write-Host "Errors:"
    $summary.Errors | ForEach-Object { Write-Host " - $_" }
}
