#=============================================================================================================================
#
# Script Name:     HP_BIOS_Bluetooth_Remediate.ps1
# Description:     This script disables Bluetooth in the BIOS
# Notes:           No variable substitution needed
#
#=============================================================================================================================

# Define Variables
$Setting = "Bluetooth"
$ExpectedValue = "Disable"

try {
    Set-HPBIOSSettingValue -name $Setting -Value $ExpectedValue

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
