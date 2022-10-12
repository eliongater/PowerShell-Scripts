#Set Variables
$AppID = "XPFNZKSKLBP7RJ"
$URL = "https://apps.microsoft.com/store/detail/$appID"
$LogoFileName = "Logo.png"
[String]$Description
[String]$Title

#Collect $AppID from user input

#Scrape store page
$WebResponse = Invoke-WebRequest $URL
#Download Logo
$ImageURL = ($WebResponse.AllElements | Where-Object {$_.Property -like "og:image"}).Content
Invoke-WebRequest -Uri $ImageURL -OutFile $LogoFileName
#Get Description
$Description = ($WebResponse.AllElements | Where-Object {$_.Property -like "og:description"}).Content
#Get Title
$Title = ($WebResponse.AllElements | Where-Object {$_.Property -like "og:title"}).Content
$Title = $Title.trim("Get $").trim(" from the Microsoft Store")

#Get Publisher
$AppDetails = winget show --id $AppID
$Publisher = ($AppDetails -like "Publisher:*").trim("Publisher: ")

#Modify Variables
$AppFolder = "Win32_App_$Title_$AppID"
$SourceFolder = "Source"
$SourceFolder = "$AppFolder\$SourceFolder"
$OutputFolder = "Output"
$OutputFolder = "$AppFolder\$OutputFolder"
$DetectionScriptName ="Detect.PS1"
$DetectionScript = "$SourceFolder\$DetectionScriptName"
$InstallScriptName = "Install.PS1"
$InstallScript = "$SourceFolder\$InstallScriptName"

#Create folder structure
mkdir $AppFolder
mkdir $SourceFolder
mkdir $OutputFolder

#Create install script
"winget install --id '$appID' -h --accept-package-agreements" | Out-File -FilePath $InstallScript

#Create detection script
"If((Out-String -InputObject (winget list --id '$appID')).contains('$appid')){write-host 'App is installed'}" | Out-File -FilePath $DetectionScript

#Create intune.win file
& IntuneWinAppUtil.exe -c $SourceFolder -s $InstallScriptName -o $OutputFolder

#Collate app information

#Upload to Intune
