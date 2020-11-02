Param(
    [String]$SettingToChange = "Intel Active Management Technology (AMT)",
    [String]$Value = "Disable"
)
$result = ""
$ScriptDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('.\')
$RemoteToolLocation = ""
$PasswordLocation = ""
$PasswordFiles = "password1.bin","Password2.bin"
foreach($Password in $PasswordFiles){
    $Password = $PasswordLocation+$Password
    try{
        try{
            #Try with local 64 bit BIOS tool
            $result =  & "$ScriptDir\BiosConfigUtility64.exe" /setvalue:$SettingToChange,$Value /cspwdfile:$Password
        } catch {
            #Try with local 32 bit BIOS tool
            $result =  & "$ScriptDir\BiosConfigUtility.exe" /setvalue:$SettingToChange,$Value /cspwdfile:$Password
        }
    } catch {
        try{
            #Try with remote 64 bit BIOS tool
            $result =  & "$RemoteToolLocation\BiosConfigUtility64.exe" /setvalue:$SettingToChange,$Value /cspwdfile:$Password
        } catch {
            #Try with remote 32 bit BIOS tool
            $result =  & "$RemoteToolLocation\BiosConfigUtility.exe" /setvalue:$SettingToChange,$Value /cspwdfile:$Password
        }
    }
    #If password valid, exit loop
    if(!($result -like "*password provided is invalid*")){
        break
    }
}

$returnCode = ($result -like "*returncode*").split('returncode="')[-2]
Write-Host $returnCode
exit $returnCode
