Install-Module Microsoft.Graph -Scope CurrentUser

Connect-MgGraph -Scopes "Application.Read.All","AppRoleAssignment.ReadWrite.All,RoleManagement.ReadWrite.Directory"
$graphApp = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"

$PermissionName = "SynchronizationData-User.Upload"
$AppRole = $graphApp.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
$managedID = Get-MgServicePrincipal -Filter "DisplayName eq 'nhc-entraidprovisioning-prd-la'"
New-MgServicePrincipalAppRoleAssignment -PrincipalId $managedID.Id -ServicePrincipalId $managedID.Id -ResourceId $graphApp.Id -AppRoleId $AppRole.Id

$PermissionName = "ProvisioningLog.Read.All"
$AppRole = $graphApp.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
$managedID = Get-MgServicePrincipal -Filter "DisplayName eq 'nhc-entraidprovisioning-prd-la'"
New-MgServicePrincipalAppRoleAssignment -PrincipalId $managedID.Id -ServicePrincipalId $managedID.Id -ResourceId $graphApp.Id -AppRoleId $AppRole.Id