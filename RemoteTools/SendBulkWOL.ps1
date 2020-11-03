Param(
    [String]$CSV = "machines.csv"
)

Function Send-WOL {
<# 
  .SYNOPSIS  
    Send a WOL packet to a broadcast address
  .PARAMETER mac
   The MAC address of the device that need to wake up
  .PARAMETER ip
   The IP address where the WOL packet will be sent to
  .EXAMPLE 
   Send-WOL -mac 00:11:32:21:2D:11 -ip 192.168.8.255 
#>

[CmdletBinding()]
param(
[Parameter(Mandatory=$True,Position=1)]
[string]$mac,
[string]$ip="255.255.255.255", 
[int]$port=9
)
$broadcast = [Net.IPAddress]::Parse($ip)
 
$mac=(($mac.replace(":","")).replace("-","")).replace(".","")
$target=0,2,4,6,8,10 | % {[convert]::ToByte($mac.substring($_,2),16)}
$packet = (,[byte]255 * 6) + ($target * 16)
 
$UDPclient = new-Object System.Net.Sockets.UdpClient
$UDPclient.Connect($broadcast,$port)
[void]$UDPclient.Send($packet, 102) 

}

$machines = Import-Csv $CSV #Import CSV File
foreach($machine in $machines){
    if(Test-Connection -count 1 -q $machine.hostname){
        Write-Host -ForegroundColor Magenta "$($machine.Hostname) Already turned on"
    } else {
        Write-Host -ForegroundColor Magenta "$($machine.Hostname) WOL command sent to $($machine.MAC)"
    }
    Send-WOL $machine.MAC
}
