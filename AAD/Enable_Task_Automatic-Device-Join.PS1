$taskname = "Automatic-Device-Join"
$task = Get-ScheduledTask | Where TaskName -like $taskname

Enable-ScheduledTask $task
Start-ScheduledTask -InputObject $task