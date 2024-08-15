<#
#Source: https://www.thelazyadministrator.com/2023/12/16/automated-alerts-on-azure-entra-id-application-secret-expirations/
#Run this as your admin account through an interactive PowerShell
#Reference: https://learn.microsoft.com/en-us/graph/permissions-reference

#Assigns mail.send and Application.Read.All


#Connect to Azure
Connect-AzAccount

$AppObjectID = "71078dec-d452-4c8a-9251-97f070faa3a6"
#$AppID = "a011ccc0-799e-4adf-ba37-64047e611c31"

#Next, we need to give the application the permission, Application.Read.All which is the following ID: 9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30. Luckily, during the process of creating the application we stored the application information in the variable, $AzureADApp so we can call the objectID property of the application by using “$AzureADApp.ID“.
#Note: The AppID of 00000003-0000-0000-c000-000000000000 is the application ID for the Microsoft Graph.

#Assigning Application.Read.All as Application
Add-AzADAppPermission -ObjectId $AppObjectID -ApiId '00000003-0000-0000-c000-000000000000' -PermissionId "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30" -Type Role

#Assigning Mail.send as Application
Add-AzADAppPermission -ObjectId $AppObjectID -ApiId '00000003-0000-0000-c000-000000000000' -PermissionId "b633e1c5-b582-4048-a93e-9f11b44c7e96" -Type Role


#>
#The above is for app registrations only
#The below is for enterprise apps
#Source: https://dev.to/svarukala/manage-azure-ad-enterprise-applications-permissions-using-microsoft-graph-powershell-222m
#*********************************************************************************


Connect-MgGraph -Scope AppRoleAssignment.ReadWrite.All


# The object id of the enterprise application 
$ObjectId = "71078dec-d452-4c8a-9251-97f070faa3a6"
# Add the correct Graph scope to grant (e.g. User.Read)
$graphScopes = "Application.Read.All","Mail.Send"

# Get the Microsoft Graph service principal
$graph = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"

foreach ($graphScope in $graphScopes) {
    # Get the graph app role for the scope that we want to grant
    $graphAppRole = $graph.AppRoles | Where-Object Value -eq $graphScope

    # Prepare the app role assignment
    $appRoleAssignment = @{
        "principalId" = $ObjectId
        "resourceId"  = $graph.Id
        "appRoleId"   = $graphAppRole.Id
    }

    # Grant the app role
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ObjectID -BodyParameter $appRoleAssignment | Format-List
}


#*********************************************************************************


<#
$ApplicationReadAll = "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"
$MailSend = "b633e1c5-b582-4048-a93e-9f11b44c7e96"

$appRoleAssignment = @{
    "principalId" = $ObjectId
    "resourceId"  = $graph.Id
    "appRoleId"   = $ApplicationReadAll
}

# Grant the app role
New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ObjectID -BodyParameter $appRoleAssignment | Format-List

$appRoleAssignment = @{
    "principalId" = $ObjectId
    "resourceId"  = $graph.Id
    "appRoleId"   = $MailSend
}

# Grant the app role
New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ObjectID -BodyParameter $appRoleAssignment | Format-List
#>