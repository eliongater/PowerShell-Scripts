# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Application.ReadWrite.All"

# Define the email address to add
$emailToAdd = "Products@naturalhazards.govt.nz"

# List of application names to search for
$appNames = @(
    "Adobe Creative Cloud",
    "AskYourTeam",
    "Click LMS EQC",
    "Click LMS SSO Testing",
    "Donesafe",
    "EQC - Totara ELearning",
    "EQC - Totara Testing ELearning",
    "EQC External Website PROD",
    "EQC External Website UAT",
    "EQC Guidewire CMS Non-Production SSO",
    "EQC Guidewire CMS Prod SSO",
    "EQC Oracle Enterprise Performance Management (EPM) SSO (3rd party) Gen2",
    "EQC Oracle Fusion (ERP) SSO",
    "EQC Oracle Fusion (ERP) SSO Dev",
    "EQC Oracle Fusion (ERP) SSO Test",
    "EQC Salesforce Prod SSO (AAI)",
    "EQC Salesforce Prod SSO (Ando)",
    "EQC Salesforce Prod SSO (Chubb)",
    "EQC Salesforce Prod SSO (EQC)",
    "EQC Salesforce Prod SSO (FMG)",
    "EQC Salesforce Prod SSO (IAG)",
    "EQC Salesforce Prod SSO (MAS)",
    "EQC Salesforce Prod SSO (MJW)",
    "EQC Salesforce Prod SSO (QBE)",
    "EQC Salesforce Prod SSO (Tower)",
    "EQC Salesforce Prod SSO (Vero)",
    "EQC Salesforce Sandbox POCQA SSO (EQC)",
    "EQC Salesforce Sandbox POCQA SSO (FMG)",
    "EQC Salesforce Sandbox POCQA SSO (MAS)",
    "EQC Salesforce Sandbox POCQA SSO (MJW)",
    "EQC Salesforce Sandbox Preprod SSO (AAI)",
    "EQC Salesforce Sandbox Preprod SSO (Ando)",
    "EQC Salesforce Sandbox Preprod SSO (Chubb)",
    "EQC Salesforce Sandbox Preprod SSO (EQC)",
    "EQC Salesforce Sandbox Preprod SSO (FMG)",
    "EQC Salesforce Sandbox Preprod SSO (IAG)",
    "EQC Salesforce Sandbox Preprod SSO (MAS)",
    "EQC Salesforce Sandbox Preprod SSO (MJW)",
    "EQC Salesforce Sandbox Preprod SSO (NH Portal)",
    "EQC Salesforce Sandbox Preprod SSO (QBE)",
    "EQC Salesforce Sandbox Preprod SSO (Tower)",
    "EQC Salesforce Sandbox Preprod SSO (Vero)",
    "EQC Silverstripe Prod SSO",
    "EQC Silverstripe UAT SSO",
    "EQC_OnBase_UT4_SSO",
    "EQC-FMIS-DevOps-ServicePrincipal",
    "EQC-HylandOnbase-PROD",
    "EQC-HylandOnbase-UT1",
    "EQC-HylandOnbase-UT2",
    "EQC-HylandOnbase-UT3",
    "EQC-HylandOnbase-UT4",
    "EQC-HylandOnbase-UT5",
    "eqc-prue-web-service-principal",
    "IMPAC Risk Manager - PROD",
    "IMPAC Risk Manager - TEST",
    "Jade Star",
    "NHC-Guidewire-CMS-EXO-SMTP-OAuth-nonprod",
    "NHC-Guidewire-CMS-EXO-SMTP-OAuth-Prod",
    "NHC-Hyland-Onbase-23-PROD",
    "NHC-Hyland-Onbase-23-UT1",
    "NHC-Hyland-Onbase-23-UT2",
    "NHC-Hyland-Onbase-23-UT3",
    "NHC-Hyland-Onbase-23-UT4",
    "NHC-Hyland-Onbase-23-UT5",
    "Snaphire"
)

foreach ($appName in $appNames) {
    # Get the application by name
    $app = Get-MgApplication -Filter "displayName eq '$appName'"

    if ($app) {
        # Get the current owners of the application
        $owners = Get-MgApplicationOwner -ApplicationId $app.Id

        # Check if the email address is already an owner
        $ownerExists = $owners | Where-Object { $_.UserPrincipalName -eq $emailToAdd }
        $addOwnerAnyway = $true

        if (-not $ownerExists -or $addOwnerAnyway) {
            # Get the user object for the email address
            $user = Get-MgUser -Filter "userPrincipalName eq '$emailToAdd'"

            if ($user) {
                # Add the user as an owner of the application
                New-MgApplicationOwnerByRef -ApplicationId $app.Id -DirectoryObjectId $user.Id
                Write-Output "Added $emailToAdd as an owner to application $($app.DisplayName)"
            } else {
                Write-Output "User $emailToAdd not found in Azure AD"
            }
        } else {
            Write-Output "$emailToAdd is already an owner of application $($app.DisplayName)"
        }
    } else {
        Write-Output "Application $appName not found"
    }
}