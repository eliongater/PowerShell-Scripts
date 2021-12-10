#=============================================================================================================================
#
# Script Name:     HP_BIOS_SecureBoot_Remediate.ps1
# Description:     This script applies SecureBoot in the BIOS
# Notes:           No variable substitution needed
#
#=============================================================================================================================

# Define Variables
$Setting = "Configure Legacy Support and Secure Boot"
$ExpectedValue = "Legacy Support Disable and Secure Boot Enable"
$BIOSPwd = ""

try {
    Set-HPBIOSSettingValue -name $Setting -Value $ExpectedValue -Password $BIOSPwd
    #Suspend bitlocker otherwise you'll be prompted for recovery keys
    Suspend-BitLocker -MountPoint "C:"

    $result = Get-HPBIOSSettingValue -name $Setting
        
    if ($result -eq $ExpectedValue){
        #Exit 0 for Intune and "SUCCESS" for SCCM
        Write-Host "SUCCESS"
        exit 0
    }
    else {
        #Exit 1 for Intune and "FAILED" for SCCM
        Write-Host "FAILED"
        exit 1
    }
}
catch {
    $errMsg = $_.Exception.Message
    return $errMsg
    exit 1
}
