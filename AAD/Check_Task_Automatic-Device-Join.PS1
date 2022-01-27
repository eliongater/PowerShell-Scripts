$taskname = "Automatic-Device-Join"
$task = Get-ScheduledTask | Where TaskName -like $taskname

if($task.state -like "Disabled"){
    #Needs to be enabled
} else {
    Write-host "Task is not Disabled"
}