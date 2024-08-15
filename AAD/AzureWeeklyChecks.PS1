#Region Functions
function Save-SectionToDisk {
    param (
        [object]$reportRow
    )
    $json = $reportRow | ConvertTo-Json -Depth 32 -Compress
    if ($PSScriptRoot) {
        $reportfolder = $PSScriptRoot
    }
    else {
        $reportfolder = $psEditor.GetEditorContext().CurrentFile.Path.replace($psEditor.GetEditorContext().CurrentFile.Path.split("\")[-1], "")
    }
    $link = $reportRow.SectionHeader
    $html = New-Object -ComObject "HTMLFile"
    $html.IHTMLDocument2_write($link)
    $title = $html.all.tags("a") | ForEach-Object innertext
    $jsondate = get-date -Format "yyyy-MM-dd HH-mm-ss"
    $jsonFilepath = "$reportfolder\$title ($jsondate).json"
    #$json | Out-File $jsonFilepath -Force
}

function Convert-UTCtoLocal {
    param(
        [parameter(Mandatory = $true)]
        [datetime] $UTCTime
    )

    $strCurrentTimeZone = (Get-WmiObject win32_timezone).StandardName
    $TZ = [System.TimeZoneInfo]::FindSystemTimeZoneById($strCurrentTimeZone)
    $LocalTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($UTCTime, $TZ)
    return $LocalTime
}

function Hue2rgb ($p, $q, $t) {
    if ($t -lt 0) { $t++ }
    if ($t -gt 1) { $t-- }
    if ($t -lt 1 / 6) { return ( $p + ($q + $p) * 6 * $t ) }
    if ($t -lt 1 / 2) { return $q }    
    if ($t -lt 2 / 3) { return ($p + ($q - $p) * (2 / 3 - $t) * 6 ) }
    return $p
}
function Get-ColourFromFraction ($fraction) {
    $colorStep = [math]::Round(120 * $fraction)
    $H = [double]($colorStep / 360)
    $S = [double](100 / 100)
    $L = [double](50 / 100)

    if ($s -eq 0) {
        $r = $g = $b = $l
    }
    else {
        if ($l -lt 0.5) {
            $q = $l * (1 + $s) 
        } 
        else {
            $q = $l + $s - $l * $s
        }
        $p = (2 * $L) - $q
        $r = (Hue2rgb $p $q ($h + 1 / 3))
        $g = (Hue2rgb $p $q $h )
        $b = (Hue2rgb $p $q ($h - 1 / 3))
    }

    $r = [Math]::Round($r * 255)
    $g = [Math]::Round($g * 255)
    $b = [Math]::Round($b * 255)

    $hexR = "{0:x2}" -f [int]$r
    $hexG = "{0:x2}" -f [int]$g
    $hexB = "{0:x2}" -f [int]$b
    return "#$hexR$hexG$hexB"
}

function Invoke-GraphAPI {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true)][hashtable]$graphParams,
        [Parameter(Mandatory = $true)][object]$token
    ) 


    $graphHeaderParams = @{
        Authorization  = "$($token.type) $($token.token)";
        "Content-type" = "application/json"
    }


    if (
        ($graphparams.uri -like "*`$count=true*") -or `
        ($graphparams.uri -like "*`$search*")
    ) {
        $graphHeaderParams['ConsistencyLevel'] = "Eventual"
    }

    if (
        ($graphparams.uri -notlike "*`$count=true*") -and `
        ($graphparams.uri -notlike "*`$search*") -and `
        ($graphHeaderParams.containsKey('ConsistencyLevel'))
    ) {
        $graphHeaderParams.removekey['ConsistencyLevel']
    }    
    
    $graphParams['headers'] = $graphHeaderParams

    Write-Verbose "Graph Call Parameters"
    Write-Verbose "$(convertto-json $graphparams)"


    $graphCall = Invoke-RestMethod @graphParams
    $graphOutput = New-Object 'System.Collections.Generic.List[object]'
    if ($graphCall.value) { 
        $graphCall.value | ForEach-Object { $graphoutput.add($_) }
    }
    else {
        $graphCall | ForEach-Object { $graphoutput.add($_) }
    }
   
    while ($graphCall.'@odata.nextlink') {
        $graphParams['uri'] = $graphCall.'@odata.nextlink'
        #$token = Test-TokenValidity -token $token
        $graphHeaderParams = @{
            Authorization  = "$($token.type) $($token.token)";
            'Content-type' = "application/json"
        }

    
        if (
            ($graphparams.uri -like "*`$count=true*") -or `
            ($graphparams.uri -like "*`$search*")
        ) {
            $graphHeaderParams['ConsistencyLevel'] = "Eventual"
        }

        if (
            ($graphparams.uri -notlike "*`$count=true*") -and `
            ($graphparams.uri -notlike "*`$search*") -and `
            ($graphHeaderParams.containsKey('ConsistencyLevel'))
        ) {
            $graphHeaderParams.removekey['ConsistencyLevel']
        }
        $graphParams['headers'] = $graphHeaderParams

        $graphCall = Invoke-RestMethod @graphParams
        $graphCall.value | ForEach-Object { $graphoutput.add($_) }
    }

    return $graphOutput
}
#EndRegion Functions


#Region Initialise
(New-Object System.Net.WebClient).Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ReportStartTime = get-date

Write-Output "Please connect to Azure."
Connect-AzAccount `
    -SubscriptionName "DIA_Production_Subscription"  `
    -Tenant "azurediagovt.onmicrosoft.com"     | Out-Null
Write-Output "`tConnected
    "

    Write-Output "Please connect to Graph."
    Connect-MgGraph -Scopes "Mail.send" -NoWelcome
    Write-Output "`tConnected
        "
    

$FullReport = @()


$resource = "https://graph.microsoft.com"       
$oauth = Get-AzAccessToken -ResourceUrl $resource
$headerParams = @{'Authorization' = "$($oauth.type) $($oauth.token)" }
#EndRegion Initialise




#Region ApplicationCredentials
Write-Output "Getting AzureAD Apps"
$apps = Get-AzADApplication 
Write-Output "`tDone"
Write-Output "Searching for App Credentials"
$soon = (get-date).AddMonths(1)
$now = get-date
$i = 0
$appCredCollection = @()
foreach ($app in $apps) {
    Write-Progress `
        -Activity "Searching for App Credentials" `
        -PercentComplete $([math]::Round(100 * $i / $apps.Count))
    $i++
    $appCreds = Get-AzADAppCredential -ObjectId $app.id | Where-Object { (get-date $_.EndDateTime) -lt $soon }
    if ($appCreds) {
        foreach ($appCred in $appCreds) {
            $appCredRow = "" | Select-Object ApplicationName, AppId, AppCredEndDate
            $appCredRow.ApplicationName = $app.DisplayName
            $appCredRow.AppId = $app.id
            $appCredRow.AppCredEndDate = Get-Date $appCred.endDateTime
            $appCredCollection += $appCredRow
        }
    }
}
Write-Output "`tDone"
Write-Progress `
        -Activity "Searching for App Credentials" `
        -Completed

Write-Output "Analysing Credentials"
$sectionReportExpiring = New-Object 'System.Collections.Generic.List[object]'
$sectionReportExpired = New-Object 'System.Collections.Generic.List[object]'

foreach ($item in $appCredCollection) {
    $appCredEndDate = $item.appCredEndDate
    if ($appCredEndDate -lt $now) {
        $sectionRowExpired = "" | Select-Object ApplicationName, AppId, ExpiryDate
        $sectionRowExpired.ApplicationName = $item.applicationname
        $sectionRowExpired.appid = $item.appid
        $sectionRowExpired.ExpiryDate = $appCredEndDate
        $sectionReportExpired.add($sectionRowExpired)
    }
    else {
        $sectionRowExpiring = "" | Select-Object ApplicationName, AppId, ExpiryDate
        $sectionRowExpiring.ApplicationName = $item.applicationname
        $sectionRowExpiring.appid = $item.appid
        $sectionRowExpiring.ExpiryDate = $appCredEndDate
        $sectionReportExpiring.add($sectionRowExpiring)
    }
}
Write-Output "`tDone
"
$expiringColour = "Yellow"
if (!($sectionReportExpiring)) {
    $sectionReportExpiring = "No application credentials are due to expire soon"
    $expiringColour = "Green"
}

$expiredColour = "Red"
if (!($sectionReportExpired)) {
    $sectionReportExpired = "No application credentials have expired"
    $expiredColour = "Green"
}

$reportRow = "" | Select-Object SectionHeader, SectionReport, SectionColor
if ($expiringColour -ne "Green") {
    $sectionReportExpiring = $sectionReportExpiring | Sort-Object  ExpiryDate
    $sectionReportExpiring | ForEach-Object { $_.expirydate = (get-date $_.expirydate -Format "dd MMMM yyyy").tostring() }
}
$reportRow.SectionHeader = "<a href=https://portal.azure.com/#blade/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/RegisteredApps target=_blank>Expiring Application Credentials</a>"
$reportRow.SectionReport = $sectionReportExpiring
$reportRow.SectionColor = $expiringColour
$FullReport += $reportRow
Save-SectionToDisk -reportRow $reportRow
(Get-Date) - $ReportStartTime | Select-Object hours, minutes, seconds

$reportRow = "" | Select-Object SectionHeader, SectionReport, SectionColor
if ($expiredColour -ne "Green") {
    $sectionReportExpired = $sectionReportExpired | Sort-Object ApplicationName
    $sectionReportExpired | ForEach-Object { $_.expirydate = (get-date $_.expirydate -Format "dd MMMM yyyy").tostring() }
}
$reportRow.SectionHeader = "<a href=https://portal.azure.com/#blade/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/RegisteredApps target=_blank>Expired Application Credentials</a>"
$reportRow.SectionReport = $sectionReportExpired
$reportRow.SectionColor = $expiredColour
$FullReport += $reportRow
Save-SectionToDisk -reportRow $reportRow
(Get-Date) - $ReportStartTime | Select-Object hours, minutes, seconds
#EndRegion ApplicationCredentials

#Region ApplicationCertificates
Write-Output "Getting AzureAD Apps"
$apps = Get-AzADApplication 
Write-Output "`tDone"
Write-Output "Searching for App Credentials"
$soon = (get-date).AddMonths(1)
$now = get-date
$i = 0
$appCertCollection = @()
foreach ($app in $apps) {
    Write-Progress `
        -Activity "Searching for App Certificates" `
        -PercentComplete $([math]::Round(100 * $i / $apps.Count))
    $i++
    $appCerts = $app.KeyCredentials 
    if ($appCerts) {
        foreach ($appCert in ($appCerts | Where-Object { (get-date $_.EndDateTime) -lt $soon })) {
            $appCertRow = "" | Select-Object ApplicationName, ApplicationID, AppCertEndDate
            $appCertRow.ApplicationName = $app.DisplayName
            $appCertRow.ApplicationID = $app.AppId
            $appCertRow.AppCertEndDate = Get-Date $appCert.EndDateTime
            $appCertCollection += $appCertRow
        }
    }
}
Write-Output "`tDone"
Write-Progress `
-Activity "Searching for App Certificates" `
-Completed


Write-Output "Analysing Credentials"
$sectionReportExpiring = New-Object 'System.Collections.Generic.List[object]'
$sectionReportExpired = New-Object 'System.Collections.Generic.List[object]'

foreach ($item in $appCertCollection) {
    $appCertEndDate = $item.appCertEndDate
    if ($appCertEndDate -lt $now) {
        $sectionRowExpired = "" | Select-Object ApplicationName, ApplicationId, ExpiryDate
        $sectionRowExpired.ApplicationName = $item.applicationname
        $sectionRowExpired.Applicationid = $item.applicationid
        $sectionRowExpired.ExpiryDate = $appCertEndDate
        $sectionReportExpired.add($sectionRowExpired)
    }
    else {
        $sectionRowExpiring = "" | Select-Object ApplicationName, ApplicationId, ExpiryDate
        $sectionRowExpiring.ApplicationName = $item.applicationname
        $sectionRowExpiring.Applicationid = $item.applicationid
        $sectionRowExpiring.ExpiryDate = $appCertEndDate
        $sectionReportExpiring.add($sectionRowExpiring)
    }
}
Write-Output "`tDone
"
$expiringColour = "Yellow"
if (!($sectionReportExpiring)) {
    $sectionReportExpiring = "No application certificates are due to expire soon"
    $expiringColour = "Green"
}

$expiredColour = "Red"
if (!($sectionReportExpired)) {
    $sectionReportExpired = "No application certificates have expired"
    $expiredColour = "Green"
}

$reportRow = "" | Select-Object SectionHeader, SectionReport, SectionColor
if ($expiringColour -ne "Green") {
    $sectionReportExpiring = $sectionReportExpiring | Sort-Object  ExpiryDate
    $sectionReportExpiring | ForEach-Object { $_.expirydate = (get-date $_.expirydate -Format "dd MMMM yyyy").tostring() }
}
$reportRow.SectionHeader = "<a href=https://portal.azure.com/#blade/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/RegisteredApps target=_blank>Expiring Application Certificates</a>"
$reportRow.SectionReport = $sectionReportExpiring
$reportRow.SectionColor = $expiringColour
$FullReport += $reportRow
Save-SectionToDisk -reportRow $reportRow
(Get-Date) - $ReportStartTime | Select-Object hours, minutes, seconds

$reportRow = "" | Select-Object SectionHeader, SectionReport, SectionColor
if ($expiredColour -ne "Green") {
    $sectionReportExpired = $sectionReportExpired | Sort-Object ApplicationName
    $sectionReportExpired | ForEach-Object { $_.expirydate = (get-date $_.expirydate -Format "dd MMMM yyyy").tostring() }
}
$reportRow.SectionHeader = "<a href=https://portal.azure.com/#blade/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/RegisteredApps target=_blank>Expired Application Certificates</a>"
$reportRow.SectionReport = $sectionReportExpired
$reportRow.SectionColor = $expiredColour
$FullReport += $reportRow
Save-SectionToDisk -reportRow $reportRow
(Get-Date) - $ReportStartTime | Select-Object hours, minutes, seconds
#EndRegion ApplicationCertifcates

#Region SAMLApplicationCredentials
Write-Output "Getting SAML AzureAD Apps"


$url = "https://graph.microsoft.com/v1.0/servicePrincipals?`$select=id,appid,keycredentials,displayname,tags"
$params = @{
    method  = "get"
    uri     = $url
    headers = $headerParams
}
$myReport = Invoke-GraphAPI -graphParams $params -token $oauth



$apps = $myReport | where-object { $_.tags -and `
    ($_.keycredentials.type -eq "asymmetricx509cert") `
        -and (($_.keycredentials.usage -eq "sign") -or ($_.keycredentials.usage -eq "verify")) }

Write-Output "`tDone"
Write-Output "Searching for App Credentials"
$soon = (get-date).AddMonths(1)
$now = get-date
$appCredCollection = @()
foreach ($app in $apps) {
    $appCreds = $app.KeyCredentials | Where-Object { (get-date $_.EndDateTime) -lt $soon }
    if ($appCreds) {
        foreach ($appCred in $appCreds) {
            $appCredRow = "" | Select-Object ApplicationName, Usage, AppCredEndDate
            $appCredRow.ApplicationName = $app.DisplayName
            $appCredRow.Usage = $appCred.usage
            $appCredRow.AppCredEndDate = Get-Date $appCred.EndDateTime
            $appCredCollection += $appCredRow
        }
    }
}
Write-Output "`tDone"

Write-Output "Analysing Credentials"
$sectionReportExpiring = New-Object 'System.Collections.Generic.List[object]'
$sectionReportExpired = New-Object 'System.Collections.Generic.List[object]'

foreach ($item in $appCredCollection) {
    $appCredEndDate = $item.appCredEndDate
    if ($appCredEndDate -lt $now) {
        $sectionRowExpired = "" | Select-Object ApplicationName, Usage, ExpiryDate
        $sectionRowExpired.ApplicationName = $item.applicationname
        $sectionRowExpired.usage = $item.usage
        $sectionRowExpired.ExpiryDate = $appCredEndDate
        $sectionReportExpired.add($sectionRowExpired)
    }
    else {
        $sectionRowExpiring = "" | Select-Object ApplicationName, Usage, ExpiryDate
        $sectionRowExpiring.ApplicationName = $item.applicationname
        $sectionRowExpiring.usage = $item.Usage
        $sectionRowExpiring.ExpiryDate = $appCredEndDate
        $sectionReportExpiring.add($sectionRowExpiring)
    }
}
Write-Output "`tDone
"
$expiringColour = "Yellow"
if (!($sectionReportExpiring)) {
    $sectionReportExpiring = "No SAML application credentials are due to expire soon"
    $expiringColour = "Green"
}

$expiredColour = "Red"
if (!($sectionReportExpired)) {
    $sectionReportExpired = "No SAML application credentials have expired"
    $expiredColour = "Green"
}

$reportRow = "" | Select-Object SectionHeader, SectionReport, SectionColor
if ($expiringColour -ne "Green") {
    $sectionReportExpiring = $sectionReportExpiring | Sort-Object  ExpiryDate
    $sectionReportExpiring | ForEach-Object { $_.expirydate = (get-date $_.expirydate -Format "dd MMMM yyyy").tostring() }
}
$reportRow.SectionHeader = "<a href=https://portal.azure.com/#blade/Microsoft_AAD_IAM/StartboardApplicationsMenuBlade/AppAppsPreview/menuId/ target=_blank>Expiring SAML Application Credentials</a>"
$reportRow.SectionReport = $sectionReportExpiring
$reportRow.SectionColor = $expiringColour
$FullReport += $reportRow
Save-SectionToDisk -reportRow $reportRow
(Get-Date) - $ReportStartTime | Select-Object hours, minutes, seconds

$reportRow = "" | Select-Object SectionHeader, SectionReport, SectionColor
if ($expiredColour -ne "Green") {
    $sectionReportExpired = $sectionReportExpired | Sort-Object ApplicationName
    $sectionReportExpired | ForEach-Object { $_.expirydate = (get-date $_.expirydate -Format "dd MMMM yyyy").tostring() }
}
$reportRow.SectionHeader = "<a href=https://portal.azure.com/#blade/Microsoft_AAD_IAM/StartboardApplicationsMenuBlade/AppAppsPreview/menuId/ target=_blank>Expired SAML Application Credentials</a>"
$reportRow.SectionReport = $sectionReportExpired
$reportRow.SectionColor = $expiredColour
$FullReport += $reportRow
Save-SectionToDisk -reportRow $reportRow
(Get-Date) - $ReportStartTime | Select-Object hours, minutes, seconds
#EndRegion SAMLApplicationCredentials

#Region SAMLApplicationTokenCredentials
# we use $apps, $soon, $now from previous section
# NB: 'apps' are actually servicePrincipals (see previous section)
# but we need the objectId of the associated APP to find the Token Encryption cert

Write-Output "Searching for Token Credentials"
$appCredCollection = @()
foreach ($app in $apps) {
    $appObjectID = (Get-AzADApplication -ApplicationId $app.AppId).id

    $resource = "https://graph.microsoft.com"
    $oauth = Get-AzAccessToken -ResourceUrl $resource
    $headerParams = @{'Authorization' = "$($oauth.type) $($oauth.token)" }
    $url = "https://graph.microsoft.com/v1.0/applications/$appObjectID"
    $params = @{
        method  = "get"
        uri     = $url
        headers = $headerParams
    }
    $myReport = Invoke-GraphAPI -graphParams $params -token $oauth

    
    $appcreds = $myreport.keycredentials | Where-Object { (get-date $_.EndDateTime) -lt $soon }  
      if ($appCreds) {
        foreach ($appCred in $appCreds) {
            $appCredRow = "" | Select-Object ApplicationName, AppCredEndDate
            $appCredRow.ApplicationName = $app.DisplayName
            $appCredRow.AppCredEndDate = Get-Date $appCred.endDateTime
            $appCredCollection += $appCredRow
        }
    }
}
Write-Output "`tDone"

Write-Output "Analysing Credentials"
$sectionReportExpiring = New-Object 'System.Collections.Generic.List[object]'
$sectionReportExpired = New-Object 'System.Collections.Generic.List[object]'

foreach ($item in $appCredCollection) {
    $appCredEndDate = $item.appCredEndDate
    if ($appCredEndDate -lt $now) {
        $sectionRowExpired = "" | Select-Object ApplicationName, ExpiryDate
        $sectionRowExpired.ApplicationName = $item.applicationname
        $sectionRowExpired.ExpiryDate = $appCredEndDate
        $sectionReportExpired.add($sectionRowExpired)
    }
    else {
        $sectionRowExpiring = "" | Select-Object ApplicationName, ExpiryDate
        $sectionRowExpiring.ApplicationName = $item.applicationname
        $sectionRowExpiring.ExpiryDate = $appCredEndDate
        $sectionReportExpiring.add($sectionRowExpiring)
    }
}
Write-Output "`tDone
"
$expiringColour = "Yellow"
if (!($sectionReportExpiring)) {
    $sectionReportExpiring = "No SAML application credential tokens are due to expire soon"
    $expiringColour = "Green"
}

$expiredColour = "Red"
if (!($sectionReportExpired)) {
    $sectionReportExpired = "No SAML application credential tokens have expired"
    $expiredColour = "Green"
}

$reportRow = "" | Select-Object SectionHeader, SectionReport, SectionColor
if ($expiringColour -ne "Green") {
    $sectionReportExpiring = $sectionReportExpiring | Sort-Object  ExpiryDate
    $sectionReportExpiring | ForEach-Object { $_.expirydate = (get-date $_.expirydate -Format "dd MMMM yyyy").tostring() }
}
$reportRow.SectionHeader = "<a href=https://portal.azure.com/#blade/Microsoft_AAD_IAM/StartboardApplicationsMenuBlade/AppAppsPreview/menuId/ target=_blank>Expiring SAML Application Token Encryption Certs</a>"
$reportRow.SectionReport = $sectionReportExpiring
$reportRow.SectionColor = $expiringColour
$FullReport += $reportRow
Save-SectionToDisk -reportRow $reportRow
(Get-Date) - $ReportStartTime | Select-Object hours, minutes, seconds

$reportRow = "" | Select-Object SectionHeader, SectionReport, SectionColor
if ($expiredColour -ne "Green") {
    $sectionReportExpired = $sectionReportExpired | Sort-Object ApplicationName
    $sectionReportExpired | ForEach-Object { $_.expirydate = (get-date $_.expirydate -Format "dd MMMM yyyy").tostring() }
}
$reportRow.SectionHeader = "<a href=https://portal.azure.com/#blade/Microsoft_AAD_IAM/StartboardApplicationsMenuBlade/AppAppsPreview/menuId/ target=_blank>Expired SAML Application Token Encryption</a>"
$reportRow.SectionReport = $sectionReportExpired
$reportRow.SectionColor = $expiredColour
$FullReport += $reportRow
Save-SectionToDisk -reportRow $reportRow
(Get-Date) - $ReportStartTime | Select-Object hours, minutes, seconds
#EndRegion SAMLApplicationTokenCredentials


#Region LastSync
Write-Output "Getting Last Sync Time"
$sectionReport = New-Object 'System.Collections.Generic.List[object]'
$reportRow = "" | Select-Object SectionHeader, SectionReport, SectionColor


$resource = "https://graph.microsoft.com"
$oauth = Get-AzAccessToken -ResourceUrl $resource
$headerParams = @{'Authorization' = "$($oauth.type) $($oauth.token)" }
$url = "https://graph.microsoft.com/v1.0/organization"
$params = @{
    method  = "get"
    uri     = $url
    headers = $headerParams
}
$myReport = Invoke-GraphAPI -graphParams $params -token $oauth

$LastSyncTimeDelta = (get-date) - (get-date $myreport.onPremisesLastSyncDateTime)
$sectionReport = $LastSyncTimeDelta | Select-Object Days, Hours, Minutes, Seconds

$reportRow.SectionHeader = "<a href=https://portal.azure.com/#blade/Microsoft_Azure_ADHybridHealth/AadHealthMenuBlade/SyncServicesList target=_blank>Time Since Last AADC Sync</a>"

$reportRow.SectionReport = $sectionReport
if ($LastSyncTimeDelta.TotalMinutes -gt 30) {
    $reportRow.SectionColor = "Red"
}
else {
    $reportRow.SectionColor = "Green"
}

$FullReport += $reportRow
Save-SectionToDisk -reportRow $reportRow
(Get-Date) - $ReportStartTime | Select-Object hours, minutes, seconds
Write-Output "`tDone"
#EndRegion LastSync


#Region DirSync
Write-Output "Getting AADC Sync Errors"
$sectionReport = New-Object 'System.Collections.Generic.List[object]'
$reportRow = "" | Select-Object SectionHeader, SectionReport, SectionColor
$resource = "https://graph.microsoft.com"
$oauth = Get-AzAccessToken -ResourceUrl $resource
$headerParams = @{'Authorization' = "$($oauth.type) $($oauth.token)" }
$dirObjects = @(
    "users",
    "groups",
    "contacts"
)
$allErrorObjects = @()
foreach ($objectType in $dirObjects) {
    $url = "$resource/v1.0/$objectType`?`$select=displayname,onPremisesProvisioningErrors"
    Write-Output "`tChecking $objectType"

    Do {
    
        $myReport = (Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $url).content | ConvertFrom-Json
        $url = $myreport.'@odata.nextLink'
        foreach ($item in $myReport.value) {
            if ($item.onPremisesProvisioningErrors) {
                $row = "" | Select-Object displayName, Errors, ObjectType
                $row.displayname = $item.displayName
                $row.Errors = $item.onPremisesProvisioningErrors
                $row.ObjectType = $objectType
                $allErrorObjects += $row
            }
        }
    } while ($null -ne $url)
}

$DirSyncErrors = $allErrorObjects

foreach ($syncError in $DirSyncErrors) {
    $sectionRow = "" | Select-Object  DisplayName, ObjectType, ProvisioningErrors
    $sectionRow.displayname = $syncError.Displayname
    $sectionRow.ObjectType = $syncError.ObjectType -replace ".$"
    $subRow = ""
    foreach ($provError in $syncError.Errors) {
        $subRow += "Category: $($provError.Category), Property: $($provError.PropertyCausingError) ($($provError.value))<br>" 
    }
    $sectionrow.ProvisioningErrors = $subRow
    $sectionReport.Add($sectionRow)
}

$reportRow.SectionHeader = "<a href=https://portal.azure.com/#blade/Microsoft_Azure_ADHybridHealth/AadHealthMenuBlade/SyncErros target=_blank>AADC Sync Errors</a>"
if ($sectionReport) {
    $reportRow.SectionReport = $sectionReport
    $reportRow.SectionColor = "LightGrey"
}
else {
    $reportRow.SectionReport = "No detected Sync Errors. But please check the portal to be sure"
    $reportRow.SectionColor = "LightGrey"
}
$FullReport += $reportRow
Save-SectionToDisk -reportRow $reportRow
(Get-Date) - $ReportStartTime | Select-Object hours, minutes, seconds
Write-Output "`tDone"
#EndRegion DirSync


#Region CompileFinalReport
#
Write-Output "Compiling final report"
$emailBody = "<!DOCTYPE HTML>`r`n"
$emailBody += "<html><head><title>CDOT Daily Checks</title><style>`r`n"
$emailBody += "body {
    font-family: arial;
    font-size: 16px;
}
a:link {
    color: black;
    text-decoration: none;
}
a:visited {
    color: black;
    text-decoration: none;
}
a:hover {
    color: black;
    text-decoration: none;
    background-color: LightGrey;
}
  
  a:active {
    color: black;
    text-decoration: none;
    background-color: LightGrey;
}
.heading1 {
   font-size: 24px;
   font-weight: bold;
}  
.heading2 {
    font-size: 20px;
    font-weight: bold;
}   
   
   `r`n"
$emailBody += "</style></head><body>`r`n"
$emailbody += "<a name=`'top`'></a><br><span class=heading1>Report Contents:</span><br>`r`n"
$emailBody += "<ul>`r`n"
foreach ($item in $FullReport) {
    $index = [array]::IndexOf($fullreport, $item)
    $link = $item.SectionHeader
    $html = New-Object -ComObject "HTMLFile"
    $html.IHTMLDocument2_write($link)
    $title = $html.all.tags("a") | ForEach-Object innertext
    $emailBody += "<li> <a href=`'#$index`'>$title</a>`r`n"
}
$emailBody += "</ul>`r`n"
$emailbody += "<br><hr><hr><br>`r`n"

foreach ($item in $FullReport) {
    $sectionHeader = $item.SectionHeader
    $sectionColor = $item.SectionColor
    $sectionReport = $item.SectionReport
    $index = [array]::IndexOf($fullreport, $item)
    $emailBody += "<a name=`'$index`'></a><br><span class=heading2><font color=black>$sectionheader</font></span> <a href=`'#top`'>^</a><br>`r`n"

    if (($sectionReport.GetType().name -eq 'List`1') -or `
        ($sectionReport.GetType().name -eq 'Object[]') -or `
        ($sectionReport.GetType().name -eq 'PSCustomObject')) {
        $emailBody += "<table><tr>"
        $tableHeaders = $sectionReport[0][0].psobject.properties.name
        foreach ($tableheader in $tableHeaders) {
            $emailBody += "<td><b>$tableheader</b></td>"
        }
        $emailBody += "</tr>`r`n"
        foreach ($subsectionreport in $sectionReport) {
            foreach ($subItem in $subsectionReport) {
                $emailBody += "<tr>"
                foreach ($tableheader in $tableHeaders) {
                    $emailBody += "<td bgcolor=$sectionColor>$($subItem.$tableheader)</td>"
                }
                $emailBody += "</tr>`r`n"
            }
        }
        $emailBody += "</table>`r`n"
        $emailBody += "<br><hr>`r`n"
    }
    elseif ($sectionReport.GetType().name -eq 'String') {
        $emailBody += "<table>`r`n"
        $emailBody += "<tr><td bgcolor=$sectionColor>$($item.SectionReport)</td></tr>`r`n"
        $emailBody += "</table>`r`n"
        $emailBody += "<br><hr>`r`n"
    }



}
$emailBody += "</body></html>"
Write-Output "`tReport Content Built"

if ($PSScriptRoot) {
    $reportfolder = $PSScriptRoot
}
else {
    $reportfolder = $psEditor.GetEditorContext().CurrentFile.Path.replace($psEditor.GetEditorContext().CurrentFile.Path.split("\")[-1], "")
}

$emailbody = [system.text.encoding]::ASCII.GetString([system.text.encoding]::UTF8.GetBytes($emailbody))
Write-Output "`t`tWriting to file $reportfolder\dailychecks.html"
$emailbody = $emailbody -replace "`"", "'"
$emailBody | Out-File "$reportfolder\dailychecks.html" -Force
Write-Output "`t`t`tDone"
(Get-Date) - $ReportStartTime | Select-Object hours, minutes, seconds


#Update this for email recipients
# add as a comma-delimited list
# eg ... = ("email1","email2","email3") ....

$DIAEmailAddress = ("ashleigh.stevens@datacom.com","iain.hardie@datacom.com","dexter.dar@datacom.com").split(",")


$toJSON = $DIAEmailAddress | ForEach-Object {
    '{"EmailAddress": {"Address": "' + $_ + '"}},'
}
$toJSON = ([string]$toJSON).Substring(0, ([string]$toJSON).Length - 1)

$mailSubject = "DIA Azure Daily Checks"

$sendMailURI = "https://graph.microsoft.com/v1.0/me/microsoft.graph.sendMail"


$attachmentContent = $emailbody.replace("\", "/")


$body = @"
    {
        "message": {
          "subject": "$mailSubject",
          "body": {
            "contentType": "Html",
            "content": "$attachmentContent"
          },
          "toRecipients": [
            $toJSON
          ]
        },
        "saveToSentItems": "true"
      }
"@


Write-Output "`tEmailing Report to $($DIAEmailAddress -join "`n`r")"

Invoke-MgGraphRequest -Method POST -Uri $sendMailURI -Body $body


Write-Output "`t`tDone


Daily Checks Script complete."
(Get-Date) - $ReportStartTime | Select-Object hours, minutes, seconds
#endRegion CompileFinalReport


