[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputCsv = "users.csv",

    [Parameter(Mandatory = $true)]
    [string]$OutputCsv = "reset-passwords.csv",

    [int]$PasswordLength = 16
)

function New-TemporaryPassword {
    param(
        [int]$Length = 16
    )

    $chars = @(
        'abcdefghijklmnopqrstuvwxyz',
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
        '0123456789',
        '!@#$%^&*()-_+=[]{};:,.<>?'
    ) -join ''

    $passwordChars = ""
    while ($passwordChars.Length -lt $Length) {
         $passwordChars += $chars[(Get-Random -Minimum 0 -Maximum $chars.Length)]
    }

    return $passwordChars
}

function Get-UserKey {
    param(
        [psobject]$Row
    )

    if ($Row.PSObject.Properties.Match('UserPrincipalName')) { return $Row.UserPrincipalName }
    if ($Row.PSObject.Properties.Match('Email')) { return $Row.Email }
    if ($Row.PSObject.Properties.Match('Mail')) { return $Row.Mail }
    if ($Row.PSObject.Properties.Match('UserName')) { return $Row.UserName }
    if ($Row.PSObject.Properties.Match('UPN')) { return $Row.UPN }

    throw "Input CSV must contain a UserPrincipalName, Email, Mail, UserName, or UPN column."
}

try {
    Import-Module Microsoft.Graph.Users -ErrorAction Stop
} catch {
    Write-Host "Microsoft.Graph.Users module is not installed. Installing module..."
    Install-Module -Name Microsoft.Graph.Users -Scope CurrentUser -Force -AllowClobber
    Import-Module Microsoft.Graph.Users -ErrorAction Stop
}

Connect-MgGraph -Scopes "User.ReadWrite.All" | Out-Null

$InputCsv = "C:\users\elijah.smart\downloads\swlusers.csv"
$OutputCsv = "C:\users\elijah.smart\downloads\reset-passwords.csv"
$PasswordLength = 12

$users = Import-Csv -Path $InputCsv
$results = [System.Collections.Generic.List[psobject]]::new()

foreach ($row in $users) {
    $userKey = $row.UPN
    $tempPassword = New-TemporaryPassword -Length $PasswordLength

    $status = 'Success'
    $errorMessage = ''

    try {
        Update-MgUser -UserId $userKey -PasswordProfile @{ Password = $tempPassword; ForceChangePasswordNextSignIn = $true } -ErrorAction Stop
    } catch {
        $status = 'Failed'
        $errorMessage = $_.Exception.Message
    }

    $results.Add([pscustomobject]@{
        UserPrincipalName = $userKey
        TemporaryPassword   = $tempPassword
        Status             = $status
        ErrorMessage       = $errorMessage
    })
}

$results | Export-Csv -Path $OutputCsv -NoTypeInformation
Write-Host "Temporary passwords exported to $OutputCsv"new