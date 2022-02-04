$group = "group"
$attribute = "info"
$Computers = Get-ADGroupMember -identity $group

foreach ($Computer in $Computers){
    Get-ADComputer $Computer | Set-AdComputer -Clear $($attribute)
}
