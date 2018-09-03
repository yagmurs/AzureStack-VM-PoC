Param (
    [Parameter(Mandatory=$true)]
    [string]
    $Username,

    [switch]
    $EnableDownloadASDK
    )

function DownloadWithRetry([string] $Uri, [string] $DownloadLocation, [int] $Retries = 5, [int]$RetryInterval = 10)
{
    while($true)
    {
        try
        {
            Start-BitsTransfer -Source $Uri -Destination $DownloadLocation -DisplayName $Uri
            break
        }
        catch
        {
            $exceptionMessage = $_.Exception.Message
            Write-Host "Failed to download '$Uri': $exceptionMessage"
            if ($retries -gt 0) {
                $retries--
                Write-Host "Waiting $RetryInterval seconds before retrying. Retries left: $Retries"
                Clear-DnsClientCache
                Start-Sleep -Seconds $RetryInterval
 
            }
            else
            {
                $exception = $_.Exception
                throw $exception
            }
        }
    }
}

$defaultLocalPath = "C:\AzureStackOnAzureVM"
New-Item -Path $defaultLocalPath -ItemType Directory -Force

DownloadWithRetry -Uri "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/development/config.ind" -DownloadLocation "$defaultLocalPath\config.ind"
$gitbranchconfig = Import-Csv -Path $defaultLocalPath\config.ind -Delimiter ","
$gitbranchcode = $gitbranchconfig.branch.Trim()
$gitbranch = "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/$gitbranchcode"

DownloadWithRetry -Uri "$gitbranch/scripts/ASDKHelperModule.psm1" -DownloadLocation "$defaultLocalPath\ASDKHelperModule.psm1"

if (Test-Path "$defaultLocalPath\ASDKHelperModule.psm1")
{
    Import-Module "$defaultLocalPath\ASDKHelperModule.psm1"
}
else
{
    throw "required module $defaultLocalPath\ASDKHelperModule.psm1 not found"   
}

Set-ExecutionPolicy unrestricted -Force

#Disables Internet Explorer Enhanced Security Configuration
Disable-InternetExplorerESC

#Download Install-ASDK.ps1 (installer)
DownloadWithRetry -Uri "$gitbranch/scripts/Install-ASDK.ps1" -DownloadLocation "$defaultLocalPath\Install-ASDK.ps1"
DownloadWithRetry -Uri "$gitbranch/scripts/Install-ASDKv2.ps1" -DownloadLocation "$defaultLocalPath\Install-ASDKv2.ps1"

#Download Azure Stack Development Kit Companion Service script
DownloadWithRetry -Uri "$gitbranch/scripts/ASDKCompanionService.ps1" -DownloadLocation "$defaultLocalPath\ASDKCompanionService.ps1"

#Download and extract Mobaxterm
DownloadWithRetry -Uri "https://aka.ms/mobaxtermLatest" -DownloadLocation "$defaultLocalPath\Mobaxterm.zip"
#Invoke-WebRequest -Uri "https://aka.ms/mobaxtermLatest" -OutFile "$defaultLocalPath\Mobaxterm.zip"
Expand-Archive -Path "$defaultLocalPath\Mobaxterm.zip" -DestinationPath "$defaultLocalPath\Mobaxterm"
Remove-Item -Path "$defaultLocalPath\Mobaxterm.zip" -Force

#Creating desktop shortcut for Install-ASDK.ps1
if ($EnableDownloadASDK)
{
    if (!($AsdkFileList))
    {
        $AsdkFileList = @("AzureStackDevelopmentKit.exe")
        1..10 | ForEach-Object {$AsdkFileList += "AzureStackDevelopmentKit-$_" + ".bin"}
    }
    
    $latestASDK = (findLatestASDK -asdkURIRoot "https://azurestack.azureedge.net/asdk" -asdkFileList $AsdkFileList)[0]

    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\AAD_Install-ASDK.lnk")
    $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Shortcut.WorkingDirectory = "$defaultLocalPath"
    $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDKv2.ps1 -DownloadASDK -DeploymentType AAD}"
    $Shortcut.Save()

    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\ADFS_Install-ASDK.lnk")
    $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Shortcut.WorkingDirectory = "$defaultLocalPath"
    $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDKv2.ps1 -DownloadASDK -DeploymentType ADFS}"
    $Shortcut.Save()

    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\Install-ASDK.lnk")
    $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Shortcut.WorkingDirectory = "$defaultLocalPath"
    $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDKv2.ps1 -DownloadASDK}"
    $Shortcut.Save()

    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\Latest_Install-ASDK.lnk")
    $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Shortcut.WorkingDirectory = "$defaultLocalPath"
    $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDKv2.ps1 -DownloadASDK -Version $latestASDK}"
    $Shortcut.Save()
}
else
{
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\AAD_Install-ASDK.lnk")
    $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Shortcut.WorkingDirectory = "$defaultLocalPath"
    $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDKv2.ps1 -DeploymentType AAD}"
    $Shortcut.Save()

    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\ADFS_Install-ASDK.lnk")
    $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Shortcut.WorkingDirectory = "$defaultLocalPath"
    $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDKv2.ps1 -DeploymentType ADFS}"
    $Shortcut.Save()

    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\Install-ASDK.lnk")
    $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Shortcut.WorkingDirectory = "$defaultLocalPath"
    $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDKv2.ps1"
    $Shortcut.Save()
}

$size = Get-Volume -DriveLetter c | Get-PartitionSupportedSize
Resize-Partition -DriveLetter c -Size $size.sizemax

Rename-LocalUser -Name $username -NewName Administrator

Write-Log @writeLogParams -Message "Running BootstrapAzureStackDeployment"
Set-Location C:\CloudDeployment\Setup
.\BootstrapAzureStackDeployment.ps1

Write-Log @writeLogParams -Message "Tweaking some files to run ASDK on Azure VM"

Write-Log @writeLogParams -Message "Applying first workaround to tackle bare metal detection"
workaround1

#Write-Log @writeLogParams -Message "Applying second workaround since this version is 1802 or higher"
#workaround2
