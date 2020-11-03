foreach($hostname in (Read-Host -Prompt "Please enter the hostnames, split by line").Split([Environment]::NewLine,[StringSplitOptions]::RemoveEmptyEntries)){
       $user = Get-WmiObject –ComputerName $hostname –Class Win32_ComputerSystem | Select-Object UserName
        $user = $user.UserName
    if ($null -ne $user){
        Write-Host -ForegroundColor Yellow "$hostname However $user is logged in, not sending restart command"
    } else {
        shutdown /r /t 1 /m $hostname
        Write-Host -ForegroundColor Green "$hostname Restart command sent"
    }
}
