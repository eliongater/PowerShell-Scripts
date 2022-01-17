Write-Host -ForegroundColor Yellow "Clearing Edge Chromium Cache`n"
$user = $env:username
if (Test-Path "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data") {
    Remove-Item -Path "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\Default\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue -Verbose
    #Remove-Item -Path "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\Default\Cache2\entries\*" -Recurse -Force -ErrorAction SilentlyContinue -Verbose
    Remove-Item -Path "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\Default\Cookies" -Recurse -Force -ErrorAction SilentlyContinue -Verbose
    #Remove-Item -Path "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\Default\Media Cache" -Recurse -Force -ErrorAction SilentlyContinue -Verbose
    Remove-Item -Path "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\Default\Cookies-Journal" -Recurse -Force -ErrorAction SilentlyContinue -Verbose
    #Remove-Item -Path "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\Default\JumpListIconsOld" -Recurse -Force -ErrorAction SilentlyContinue -Verbose
    # Comment out the following line to remove the Edge Write Font Cache too.
    # Remove-Item -Path "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\Default\EdgeDWriteFontCache" -Recurse -Force -ErrorAction SilentlyContinue -Verbose

    # Check Edge Profiles. It looks as though when creating profiles, it just numbers them Profile 1, Profile 2 etc.
    $Profiles = Get-ChildItem -Path "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data" | Select-Object Name | Where-Object Name -Like "Profile*"
    foreach ($Account in $Profiles) {
        $Account = $Account.Name 
        Remove-Item -Path "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\$Account\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue -Verbose
        #Remove-Item -Path "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\$Account\Cache2\entries\*" -Recurse -Force -ErrorAction SilentlyContinue -Verbose 
        Remove-Item -Path "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\$Account\Cookies" -Recurse -Force -ErrorAction SilentlyContinue -Verbose
        #Remove-Item -Path "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\$Account\Media Cache" -Recurse -Force -ErrorAction SilentlyContinue -Verbose
        Remove-Item -Path "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\$Account\Cookies-Journal" -Recurse -Force -ErrorAction SilentlyContinue -Verbose
        #Remove-Item -Path "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\$Account\JumpListIconsOld" -Recurse -Force -ErrorAction SilentlyContinue -Verbose
    }
}
Write-Host -ForegroundColor Yellow "Done...`n" 
