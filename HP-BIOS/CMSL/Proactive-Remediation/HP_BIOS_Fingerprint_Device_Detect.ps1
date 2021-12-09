#=============================================================================================================================
#
# Script Name:     HP_BIOS_Fingerprint_Device_Detect.ps1
# Description:     Detect if Fingerprint Device is disabled
# Notes:           Remediate if "Match" or exit code = 1
#
#=============================================================================================================================

# Define Variables
$Setting = "Fingerprint Device"
$ExpectedValue = "Disable"

try {
    $result = Get-HPBIOSSettingValue -name $Setting
        
    if ($result -eq $ExpectedValue){
        #Exit 0 for Intune and "No_Match" for SCCM, only remediate "Match"
        Write-Host "No_Match"
        exit 0
    }
    else {
        #Exit 1 for Intune and "Match" to remediate in SCCM
        Write-Host "Match"
        exit 1
    }
}
catch {
    $errMsg = $_.Exception.Message
    return $errMsg
    exit 1
}
