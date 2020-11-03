foreach($hostname in (Read-Host -Prompt "Please enter the hostnames, split by line").Split([Environment]::NewLine,[StringSplitOptions]::RemoveEmptyEntries)){
        $user = Get-WmiObject –ComputerName $hostname –Class Win32_ComputerSystem | Select-Object UserName
        $user = $user.UserName
    if ($null -ne $user){
        Write-Host -ForegroundColor Yellow "$hostname has $user logged on"
    } else {
        Write-Host -ForegroundColor Green "$hostname is free"
    }
}
