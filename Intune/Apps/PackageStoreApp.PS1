

function PackageStoreApp {
    param (
        $AppID
    )
#Set Variables
$TenantName = ""
$GroupName = ""
$GroupID = ""
$URL = "https://apps.microsoft.com/store/detail/$appID"
$LogoFileName = "Logo.png"
$Path = (Get-Location).path
$Winget = 'C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe'
$WingetLocal
#If running as admin get the full path to winget, else just return winget as a standard user can resolve that
If([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")){
    $WingetLocal = (Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe")[-1].path
} else {
    $WingetLocal = "winget"
}

[String]$Description
[String]$Title

#Collect $AppID from user input

#Connect to Tenant
Connect-MSIntuneGraph -TenantID $TenantName

#Scrape store page
$WebResponse = Invoke-WebRequest $URL

#Get Description
$Description = ($WebResponse.AllElements | Where-Object { $_.Property -like "og:description" }).Content
#Get Title
$Title = ($WebResponse.AllElements | Where-Object { $_.Property -like "og:title" }).Content
$Title = $Title.trimstart("Get $").trimend("the Microsoft Store").trimend(" from")

#Get Publisher
$AppDetails = & $WingetLocal show --id $AppID
$Publisher = ($AppDetails -like "Publisher:*").trim("Publisher: ")

#Modify Variables
$AppFolder = "Win32_App_$Title`_$AppID"
$AppFolder = "$Path\$AppFolder"
$SourceFolder = "Source"
$SourceFolder = "$AppFolder\$SourceFolder"
$OutputFolder = "Output"
$OutputFolder = "$AppFolder\$OutputFolder"
$DetectionScriptName = "Detect.PS1"
$DetectionScript = "$SourceFolder\$DetectionScriptName"
$InstallScriptName = "Install"
$IntuneWinFile = "$InstallScriptName.intunewin"
$IntuneWinFile = "$OutputFolder\$IntuneWinFile"
$InstallScriptName = "$InstallScriptName.PS1"
$InstallScript = "$SourceFolder\$InstallScriptName"
$UninstallScriptName = "Uninstall.PS1"
$UninstallScript = "$SourceFolder\$UninstallScriptName"


$LogoFileName = "$SourceFolder\$LogoFileName"

#Create folder structure
If (!(Test-Path $AppFolder)) { mkdir $AppFolder }
If (!(Test-Path $SourceFolder)) { mkdir $SourceFolder }
If (!(Test-Path $OutputFolder)) { mkdir $OutputFolder }

#Download Logo
$ImageURL = ($WebResponse.AllElements | Where-Object { $_.Property -like "og:image" }).Content
Invoke-WebRequest -Uri $ImageURL -OutFile $LogoFileName

#Create install script
$InstallCommandLine = "&(Resolve-Path `"$winget`")[-1].path install --id '$appID' --silent --accept-package-agreements --accept-source-agreements"
$InstallCommandLine | Out-File -FilePath $InstallScript

#Create uninstall script
$UninstallCommandLine = "&(Resolve-Path `"$winget`")[-1].path uninstall --id '$appID' -h --accept-source-agreements"
$UninstallCommandLine | Out-File -FilePath $UninstallScript

#Create detection script
"If((Out-String -InputObject (&(Resolve-Path `"$winget`")[-1].path list --id '$appID' --accept-source-agreements)).contains('$appid')){write-host 'App is installed'}" | Out-File -FilePath $DetectionScript

#Create intune.win file
& .\IntuneWinAppUtil.exe -c "$SourceFolder" -s "$InstallScriptName" -o "$OutputFolder" -q

#Collate app information
$DisplayName = $Title
$Icon = New-IntuneWin32AppIcon -FilePath $LogoFileName

#Create Detection Rule
$DetectionRule = New-IntuneWin32AppDetectionRuleScript  -ScriptFile "$DetectionScript"

#Create custom requirement rule
$RequirementRule = New-IntuneWin32AppRequirementRule -Architecture All -MinimumSupportedWindowsRelease 1909

#Upload to Intune
$Win32InstallCommandLine = "powershell.exe -windowstyle hidden -executionpolicy bypass -file .\$InstallScriptName"
$Win32UninstallCommandLine = "powershell.exe -windowstyle hidden -executionpolicy bypass -file .\$UnInstallScriptName"

$PublishedApp = Add-IntuneWin32App -FilePath $IntuneWinFile -DisplayName "$DisplayName" -Description "$Description" -Publisher "$Publisher" -InstallExperience system -RestartBehavior suppress -DetectionRule $DetectionRule -RequirementRule $RequirementRule -InstallCommandLine $Win32InstallCommandLine -UninstallCommandLine $Win32UninstallCommandLine -Icon $Icon -Verbose

#Get Group ID


#Assign application to group
$AppID = $PublishedApp.id
Add-IntuneWin32AppAssignmentGroup  -ID "$AppID" -include -GroupID "$GroupID" -Intent "available"

#Done!
}

$AppIDs = "XPFNZKSKLBP7RJ","9NZVDKPMR9RD"#,"9NBLGGH51P19","9WZDNCRFJ2KJ"
$AppIDs = "9NBLGGH51P19",""#"9WZDNCRFJ2KJ"
#$AppIDs = "9WZDNCRFJ2KJ",""
ForEach($App in $AppIDs){
    PackageStoreApp $App
    start-sleep -s 10
}


Write-Host "done"
