#=============================================================================================================================
#
# Script Name:     HP_BIOS_Password_Remediate.ps1
# Description:     This script enables the BIOS Password
# Notes:           No variable substitution needed
#
#=============================================================================================================================

# Define Variables
$ExpectedValue = "True"
$BIOSPwd = ""
$OldPwd = ""

try {
    Set-HPBIOSSetupPassword -NewPassword $BIOSPwd -Password $OldPwd

    $result = Get-HPBIOSSetupPasswordIsSet
        
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
