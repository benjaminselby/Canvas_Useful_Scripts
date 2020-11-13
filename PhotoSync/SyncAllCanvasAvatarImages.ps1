

Param (
    [string] $rootFolder        = (Split-Path $MyInvocation.MyCommand.path),
    [string] $logFilePath       = "$rootFolder\Logs\PhotoSync_$(get-date -format 'yyyy.MM.dd_hh.mm').log",
    [string] $token = '<TOKEN>'
)

# Authentication header for API calls. 
$headers    = @{Authorization="Bearer $token"}


#########################################################################################################
# MAIN
#########################################################################################################


Write-Output "Started at $(Get-Date -Format 'HH:mm:ss')`n" | Out-File -FilePath $logFilePath

# Update avatar images for all Canvas users. Only Staff & Students should be affected 
# (ie. observers will not have images in Synergy.)
$usersResponse = Invoke-RestMethod `
    -URI "https://<HOSTNAME>:443/api/v1/accounts/1/users" `
    -headers $headers `
    -method GET `
    -FollowRelLink

$currentUsers = $usersResponse | Foreach-Object {$_}

foreach($user in $currentUsers) {
    # Only process users who have a valid numeric Synergy ID. This should filter out most parent observers etc. 
    if ($user.sis_user_id -MATCH '^\d+$') {
        Write-Output "========================================================================================" `
            | Out-File -FilePath $logFilePath -Append
        # Need to use a command string so the root folder path variable can be included in the script invocation.
        $command = "$rootFolder\SyncCanvasAvatar.ps1 ``
            -userCanvasId $($user.id) *>&1 ``
            | Out-File -FilePath '$logFilePath' -Append"
        Invoke-Expression $command
    }
}

Write-Output "`nFinished at $(Get-Date -Format 'HH:mm:ss')." | Out-File -FilePath $logFilePath -Append
