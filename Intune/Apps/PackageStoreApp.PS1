#Set Variables
$AppID = "XPFNZKSKLBP7RJ"
$TenantName = ""
$GroupName = ""
$GroupID = ""
$URL = "https://apps.microsoft.com/store/detail/$appID"
$LogoFileName = "Logo.png"
$Path = (Get-Location).path
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
$Title = $Title.trim("Get $").trim(" from the Microsoft Store")

#Get Publisher
$AppDetails = winget show --id $AppID
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
$InstallCommandLine = "winget install --id '$appID' -h --accept-package-agreements"
$InstallCommandLine | Out-File -FilePath $InstallScript

#Create uninstall script
$UninstallCommandLine = "winget uninstall --id '$appID' -h --accept-package-agreements"
$UninstallCommandLine | Out-File -FilePath $UninstallScript

#Create detection script
"If((Out-String -InputObject (winget list --id '$appID')).contains('$appid')){write-host 'App is installed'}" | Out-File -FilePath $DetectionScript

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
$PublishedApp = Add-IntuneWin32App -FilePath $IntuneWinFile -DisplayName "$DisplayName" -Description "$Description" -Publisher "$Publisher" -InstallExperience system -RestartBehavior suppress -DetectionRule $DetectionRule -RequirementRule $RequirementRule -InstallCommandLine $InstallCommandLine -UninstallCommandLine $UninstallCommandLine -Icon $Icon -Verbose

#Get Group ID


#Assign application to group
$AppID = $PublishedApp.id
Add-IntuneWin32AppAssignmentGroup  -ID "$AppID" -include -GroupID "$GroupID" -Intent "available"

#Done!
