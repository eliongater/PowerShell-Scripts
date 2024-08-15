<#
    .DESCRIPTION
        This PowerShell script is intended to be run via an Azure Automation account runbook. This script will query all Enterprise apps and App registrations and then send an email per expired certificate and secret to your ticketing system to generate a ticket.

    .NOTES
        AUTHOR: Elijah Smart
        LASTEDIT: Aug 15, 2024
#>

"Please enable appropriate RBAC permissions to the system identity of this automation account. Otherwise, the runbook may fail..."

try
{
    "Logging in to Azure..."
    Connect-MgGraph -Identity
    Connect-AzAccount -Identity
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}