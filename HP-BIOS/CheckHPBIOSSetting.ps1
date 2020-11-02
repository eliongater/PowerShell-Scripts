#Change these
$SettingToCheck = "Intel Active Management Technology (AMT)"
$ExpectedResult = "disable"
$RemoteToolLocation = ""
$PasswordLocation = "\"
$PasswordFiles = "password1.bin","password2.bin"
$PasswordProtected = $true
#Don't Change these
$ExpectedResult = "\*"+$ExpectedResult
$BlankSetting = '*returnCode="20"*'#20 for "Invalid Setting Name"
$result = ""
$SettingApplied = $False
$ScriptDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('.\')

if($PasswordProtected){
    foreach($Password in $PasswordFiles){
        $Password = $PasswordLocation+$Password
        try{
            try{
                #Try with local 64 bit BIOS tool
                $result =  & "$ScriptDir\BiosConfigUtility64.exe" /getvalue:$SettingToCheck /cspwdfile:$Password
            } catch {
                #Try with local 32 bit BIOS tool
                $result =  & "$ScriptDir\BiosConfigUtility.exe" /getvalue:$SettingToCheck /cspwdfile:$Password
            }
        } catch {
            try{
                #Try with remote 64 bit BIOS tool
                $result =  & "$RemoteToolLocation\BiosConfigUtility64.exe" /getvalue:$SettingToCheck /cspwdfile:$Password
            } catch {
                #Try with remote 32 bit BIOS tool
                $result =  & "$RemoteToolLocation\BiosConfigUtility.exe" /getvalue:$SettingToCheck /cspwdfile:$Password
            }
        }
        #If password valid, exit loop
        if(!($result -like "*password provided is invalid*")){
            break
        }
    }
} else {
    try{
        try{
            #Try with local 64 bit BIOS tool
            $result =  & "$ScriptDir\BiosConfigUtility64.exe" /getvalue:$SettingToCheck
        } catch {
            #Try with local 32 bit BIOS tool
            $result =  & "$ScriptDir\BiosConfigUtility.exe" /getvalue:$SettingToCheck
        }
    } catch {
        try{
            #Try with remote 64 bit BIOS tool
            $result =  & "$RemoteToolLocation\BiosConfigUtility64.exe" /getvalue:$SettingToCheck
        } catch {
            #Try with remote 32 bit BIOS tool
            $result =  & "$RemoteToolLocation\BiosConfigUtility.exe" /getvalue:$SettingToCheck
        }
    }
}

#Get the return code from the result
$returnCode = ($result -like "*returncode*").split('returncode="')[-2]

#If the result is as expected or the setting isn't applicable and is to disable, mark as successful
if(($result -match $ExpectedResult) -or ($result -like $BlankSetting -and $ExpectedResult -match "\*disable")){
    $SettingApplied = $true
}

if($SettingApplied){
    Write-Host "BIOS Setting Applied, returncode=$returnCode"
} else {
    #Comment the below "Throw" if using as an SCCM detection method
    #throw "BIOS Setting Not Applied, returncode=$returnCode"
}
