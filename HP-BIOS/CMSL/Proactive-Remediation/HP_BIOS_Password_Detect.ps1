#=============================================================================================================================
#
# Script Name:     HP_BIOS_Password_Detect.ps1
# Description:     Detect if BIOS Password is enabled
# Notes:           Remediate if "Match" or exit code = 1
#
#=============================================================================================================================

# Define Variables
$ExpectedValue = "True"

try {
    $result = Get-HPBIOSSetupPasswordIsSet
        
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
