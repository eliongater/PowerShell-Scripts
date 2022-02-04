$Computers = Get-ADComputer -filter * -SearchBase "OU=Computers,DC=contoso,DC=com"
$attribute = "info"


foreach ($Computer in $Computers){
    Get-ADComputer $Computer | Set-AdComputer -Clear $($attribute)
}
