Param (
    [Parameter(Mandatory=$true)]
    [string]
    $Username,

    [switch]
    $EnableDownloadASDK,
    
    [switch]
    $AzureImage,

    [switch]
    $ASDKImage,

    [string]
    $AutoDownloadASDK
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

$logFileFullPath = "$defaultLocalPath\postconfig.log"
$writeLogParams = @{
    LogFilePath = $logFileFullPath
}

DownloadWithRetry -Uri "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/master/config.ind" -DownloadLocation "$defaultLocalPath\config.ind"
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

#Download Install-ASDK.ps1 (installer)
DownloadWithRetry -Uri "$gitbranch/scripts/Install-ASDK.ps1" -DownloadLocation "$defaultLocalPath\Install-ASDK.ps1"

#Download and extract Mobaxterm
DownloadWithRetry -Uri "https://aka.ms/mobaxtermLatest" -DownloadLocation "$defaultLocalPath\Mobaxterm.zip"
Expand-Archive -Path "$defaultLocalPath\Mobaxterm.zip" -DestinationPath "$defaultLocalPath\Mobaxterm"
Remove-Item -Path "$defaultLocalPath\Mobaxterm.zip" -Force

#Enable remoting firewall rule
Get-NetFirewallRule -Name WINRM-HTTP-In-TCP-PUBLIC | Get-NetFirewallAddressFilter | Set-NetFirewallAddressFilter -RemoteAddress any -PassThru -OutVariable firewallRuleResult | Get-NetFirewallRule | Enable-NetFirewallRule
Write-Log @writeLogParams -Message $firewallRuleResult
Remove-Variable -Name firewallRuleResult -Force -ErrorAction SilentlyContinue

if ($ASDKImage)
{
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\AAD_Install-ASDK.lnk")
    $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Shortcut.WorkingDirectory = "$defaultLocalPath"
    $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDK.ps1 -DeploymentType AAD -SkipWorkaround}"
    $Shortcut.Save()

    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\ADFS_Install-ASDK.lnk")
    $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Shortcut.WorkingDirectory = "$defaultLocalPath"
    $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDK.ps1 -DeploymentType ADFS -SkipWorkaround}"
    $Shortcut.Save()

    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\Install-ASDK.lnk")
    $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Shortcut.WorkingDirectory = "$defaultLocalPath"
    $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDK.ps1 -SkipWorkaround}"
    $Shortcut.Save()

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
}

if ($AzureImage)
{
    #Disables Internet Explorer Enhanced Security Configuration
    Disable-InternetExplorerESC

    #Enable Internet Explorer File download
    New-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3' -Name 1803 -Value 0 -Force
    New-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\0' -Name 1803 -Value 0 -Force

    New-Item HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials -Force
    New-Item HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Force
    Set-ItemProperty -LiteralPath HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials -Name 1 -Value "wsman/*" -Type STRING -Force
    Set-ItemProperty -LiteralPath HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name 1 -Value "wsman/*" -Type STRING -Force
    Set-ItemProperty -LiteralPath HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation -Name AllowFreshCredentials -Value 1 -Type DWORD -Force
    Set-ItemProperty -LiteralPath HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation -Name AllowFreshCredentialsWhenNTLMOnly -Value 1 -Type DWORD -Force
    Set-ItemProperty -LiteralPath HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation -Name ConcatenateDefaults_AllowFresh -Value 1 -Type DWORD -Force
    Set-ItemProperty -LiteralPath HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation -Name ConcatenateDefaults_AllowFreshNTLMOnly -Value 1 -Type DWORD -Force
    Set-Item -Force WSMan:\localhost\Client\TrustedHosts "*"
    Enable-WSManCredSSP -Role Client -DelegateComputer "*" -Force
    Enable-WSManCredSSP -Role Server -Force

    Install-PackageProvider nuget -Force

    Set-ExecutionPolicy unrestricted -Force

    #Download ASDK Downloader
    DownloadWithRetry -Uri "https://aka.ms/azurestackdevkitdownloader" -DownloadLocation "D:\AzureStackDownloader.exe"

    if (!($AsdkFileList))
    {
        $AsdkFileList = @("AzureStackDevelopmentKit.exe")
        1..10 | ForEach-Object {$AsdkFileList += "AzureStackDevelopmentKit-$_" + ".bin"}
    }

    $latestASDK = (findLatestASDK -asdkURIRoot "https://azurestack.azureedge.net/asdk" -asdkFileList $AsdkFileList)[0]

    if ($AutoDownloadASDK -eq "true")
    {
        #Download ASDK files (BINs and EXE)
        Write-Log @writeLogParams -Message "Finding available ASDK versions"

        $asdkDownloadPath = "d:\"
        $asdkExtractFolder = "Azure Stack Development Kit"

        $asdkFiles = ASDKDownloader -Version $latestASDK -Destination $asdkDownloadPath

        Write-Log @writeLogParams -Message "$asdkFiles"
        
        #Extracting Azure Stack Development kit files
                
        $f = Join-Path -Path $asdkDownloadPath -ChildPath $asdkFiles[0].Split("/")[-1]
        $d = Join-Path -Path $asdkDownloadPath -ChildPath $asdkExtractFolder

        Write-Log @writeLogParams -Message "Extracting Azure Stack Development kit files;"
        Write-Log @writeLogParams -Message "to $d"

        ExtractASDK -File $f -Destination $d

        $vhdxFullPath = Join-Path -Path $d -ChildPath "cloudbuilder.vhdx"
        $foldersToCopy = @('CloudDeployment', 'fwupdate', 'tools')

        if (Test-Path -Path $vhdxFullPath)
        {
            Write-Log @writeLogParams -Message "About to Start Copying ASDK files to C:\"
            Write-Log @writeLogParams -Message "Mounting cloudbuilder.vhdx"
            try {
                $driveLetter = Mount-DiskImage -ImagePath $vhdxFullPath -StorageType VHDX -Passthru | Get-DiskImage | Get-Disk | Get-Partition | Where-Object size -gt 500MB | Select-Object -ExpandProperty driveletter
                Write-Log @writeLogParams -Message "The drive is now mounted as $driveLetter`:"
            }
            catch {
                Write-Log @writeLogParams -Message "an error occured while mounting cloudbuilder.vhdx file"
                Write-Log @writeLogParams -Message $error[0].Exception
                throw "an error occured while mounting cloudbuilder.vhdxf file"
            }

            foreach ($folder in $foldersToCopy)
            {
                Write-Log @writeLogParams -Message "Copying folder $folder to $destPath"
                Copy-Item -Path (Join-Path -Path $($driveLetter + ':') -ChildPath $folder) -Destination C:\ -Recurse -Force
                Write-Log @writeLogParams -Message "$folder done..."
            }
            Write-Log @writeLogParams -Message "Dismounting cloudbuilder.vhdx"
            Dismount-DiskImage -ImagePath $vhdxFullPath       
        } 
        
        Write-Log @writeLogParams -Message "Creating shortcut AAD_Install-ASDK.lnk"
        $WshShell = New-Object -comObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\AAD_Install-ASDK.lnk")
        $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
        $Shortcut.WorkingDirectory = "$defaultLocalPath"
        $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDK.ps1 -DeploymentType AAD}"
        $Shortcut.Save()

        Write-Log @writeLogParams -Message "Creating shortcut ADFS_Install-ASDK.lnk"
        $WshShell = New-Object -comObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\ADFS_Install-ASDK.lnk")
        $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
        $Shortcut.WorkingDirectory = "$defaultLocalPath"
        $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDK.ps1 -DeploymentType ADFS}"
        $Shortcut.Save()
    }
    else
    {
        #Creating desktop shortcut for Install-ASDK.ps1
        if ($EnableDownloadASDK)
        {
            $WshShell = New-Object -comObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\AAD_Install-ASDK.lnk")
            $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
            $Shortcut.WorkingDirectory = "$defaultLocalPath"
            $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDK.ps1 -DownloadASDK -DeploymentType AAD}"
            $Shortcut.Save()

            $WshShell = New-Object -comObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\ADFS_Install-ASDK.lnk")
            $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
            $Shortcut.WorkingDirectory = "$defaultLocalPath"
            $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDK.ps1 -DownloadASDK -DeploymentType ADFS}"
            $Shortcut.Save()

            $WshShell = New-Object -comObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\Install-ASDK.lnk")
            $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
            $Shortcut.WorkingDirectory = "$defaultLocalPath"
            $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDK.ps1 -DownloadASDK}"
            $Shortcut.Save()

            $WshShell = New-Object -comObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\Latest_Install-ASDK.lnk")
            $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
            $Shortcut.WorkingDirectory = "$defaultLocalPath"
            $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDK.ps1 -DownloadASDK -Version $latestASDK}"
            $Shortcut.Save()
        }
        else
        {
            $WshShell = New-Object -comObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\AAD_Install-ASDK.lnk")
            $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
            $Shortcut.WorkingDirectory = "$defaultLocalPath"
            $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDK.ps1 -DeploymentType AAD}"
            $Shortcut.Save()

            $WshShell = New-Object -comObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\ADFS_Install-ASDK.lnk")
            $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
            $Shortcut.WorkingDirectory = "$defaultLocalPath"
            $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDK.ps1 -DeploymentType ADFS}"
            $Shortcut.Save()

            $WshShell = New-Object -comObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut("$env:ALLUSERSPROFILE\Desktop\Install-ASDK.lnk")
            $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
            $Shortcut.WorkingDirectory = "$defaultLocalPath"
            $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDK.ps1"
            $Shortcut.Save()
        }
    }

    DownloadWithRetry -Uri "$gitbranch/scripts/roles.xml" -DownloadLocation "$defaultLocalPath\roles.xml"

    if (Test-Path "$defaultLocalPath\roles.xml")
    {
        Import-Clixml "$defaultLocalPath\roles.xml" | Where-Object installed | Add-WindowsFeature
        Rename-LocalUser -Name $username -NewName Administrator
        Restart-Computer
    }
    else
    {
        throw "required module $defaultLocalPath\roles.xml not found"   
    }
}

