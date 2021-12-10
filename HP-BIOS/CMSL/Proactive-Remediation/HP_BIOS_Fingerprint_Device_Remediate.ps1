#=============================================================================================================================
#
# Script Name:     HP_BIOS_Fingerprint_Device_Remediate.ps1
# Description:     This script disables Fingerprint Device in the BIOS
# Notes:           No variable substitution needed
#
#=============================================================================================================================

# Define Variables
$Setting = "Fingerprint Device"
$ExpectedValue = "Disable"
$BIOSPwd = ""

try {
    Set-HPBIOSSettingValue -name $Setting -Value $ExpectedValue -Password $BIOSPwd

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
