# This script adds a specified Microsoft 365 group to the owners group of all SharePoint Online sites in the tenant.
# Requires SharePoint Online Management Shell module
# Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser

$groupName = "U_IM_All Sites_Owner"
$tenantAdminUrl = Read-Host "Enter tenant admin URL (for example https://contoso-admin.sharepoint.com)"

Connect-SPOService -Url $tenantAdminUrl
Connect-MgGraph -Scopes "Group.Read.All"


$groupObjectID = (Get-MgGroup -Filter "displayName eq '$groupName'").Id
$groupID = "c:0t.c|tenant|$groupObjectID"

$sites = Get-SPOSite -Limit All | Where-Object { $_.Url -notmatch '/personal/' }

foreach ($site in $sites) {
    Write-Host "Processing site: $($site.Url)"
    try {
        $ownerGroup = Get-SPOSiteGroup -Site $site.Url | Where-Object { $_.Title -like '* Owners' } | Select-Object -First 1

        if ($null -ne $ownerGroup) {
            Add-SPOUser -Site $site.Url -Group $ownerGroup.title -LoginName $groupID -ErrorAction Stop
            Write-Host "Added group '$groupName' to owner group '$($ownerGroup.Title)' for site $($site.Url)"
        } else {
            Write-Warning "No associated owners group found for site $($site.Url)"
        }
    } catch {
        Write-Warning "Failed to add group to site $($site.Url): $($_.Exception)"
    }
    Start-Sleep -Seconds 30
}
