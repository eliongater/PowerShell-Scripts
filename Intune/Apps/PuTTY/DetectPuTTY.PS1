$appID = "XPFNZKSKLBP7RJ"
[String]$CheckForApp = winget list --id $appID
If($CheckForApp.contains($appid)){
    write-host "App is installed"
}
