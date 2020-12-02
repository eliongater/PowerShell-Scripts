$Object1 = "user1"
$Object2 = "user2"

$Object1Groups = @()
$Object2Groups = @()

try{
    $Object1Groups = Get-ADPrincipalGroupMembership "$Object1" | Select-Object name | ForEach-Object {$_.name}
    $Object2Groups = Get-ADPrincipalGroupMembership "$Object2" | Select-Object name | ForEach-Object {$_.name}
} catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    $Object1Groups = Get-ADPrincipalGroupMembership "$Object1$" | Select-Object name | ForEach-Object {$_.name}
    $Object2Groups = Get-ADPrincipalGroupMembership "$Object2$" | Select-Object name | ForEach-Object {$_.name}
}

$Object2Only = $Object2Groups | Where-Object {$Object1Groups -notcontains $_}
$Object1Only = @()
$Both = @()

Foreach ($group in $Object1Groups){
    if($Object2Groups -contains $group){
        $Both += $group
    } else {
        $Object1Only += $group
    }
}

Write-host "Groups common to $Object1 and $Object2"
Foreach ($group in $Both){
    Write-host -ForegroundColor Green "$group"
}

Write-host "Groups only $Object1 has"
Foreach ($group in $Object1Only){
    Write-host -ForegroundColor Yellow "$group"
}

Write-host "Groups only $Object2 has"
Foreach ($group in $Object2Only){
    Write-host -ForegroundColor red "$group"
}
