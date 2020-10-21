Param (
    [Parameter(Mandatory = $true)]
    [string]
    $Username = "__administrator",

    [string]
    $LocalAdminUsername = "Administrator",

    [switch]
    $EnableDownloadASDK,
    
    [switch]
    $AzureImage,

    [switch]
    $ASDKImage,

    [string]
    $AutoDownloadASDK,

    [string]
    $EnableRDSH,

    [switch]
    $AutoInstallASDK,

    [string]
    $AzureADTenant,

    [string]
    $AzureADGlobalAdmin,

    [string]
    $AzureADGlobalAdminPass,

    [string]
    $LocalAdminPass,

    [string]
    $branch = "master",

    [string]
    $ASDKConfiguratorObject
)

function DownloadWithRetry([string] $Uri, [string] $DownloadLocation, [int] $Retries = 5, [int]$RetryInterval = 10) {
    while ($true) {
        try {
            Start-BitsTransfer -Source $Uri -Destination $DownloadLocation -DisplayName $Uri
            break
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Host "Failed to download '$Uri': $exceptionMessage"
            if ($retries -gt 0) {
                $retries--
                Write-Host "Waiting $RetryInterval seconds before retrying. Retries left: $Retries"
                Clear-DnsClientCache
                Start-Sleep -Seconds $RetryInterval
    
            }
            else {
                $exception = $_.Exception
                throw $exception
            }
        }
    }
}


$size = Get-Volume -DriveLetter c | Get-PartitionSupportedSize
Resize-Partition -DriveLetter c -Size $size.sizemax

$defaultLocalPath = "C:\AzureStackOnAzureVM"
New-Item -Path $defaultLocalPath -ItemType Directory -Force
$transcriptLog = "post-config-transcript.txt"
Start-Transcript -Path $(Join-Path -Path $defaultLocalPath -ChildPath $transcriptLog) -Append

$logFileFullPath = "$defaultLocalPath\postconfig.log"
$writeLogParams = @{
    LogFilePath = $logFileFullPath
}

$branchFullPath = "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/$branch"

DownloadWithRetry -Uri "$branchFullPath/scripts/ASDKHelperModule.psm1" -DownloadLocation "$defaultLocalPath\ASDKHelperModule.psm1"
DownloadWithRetry -Uri "$branchFullPath/scripts/testedVersions" -DownloadLocation "$defaultLocalPath\testedVersions"

if (Test-Path "$defaultLocalPath\ASDKHelperModule.psm1") {
    Import-Module "$defaultLocalPath\ASDKHelperModule.psm1" -ErrorAction Stop
}
else {
    throw "required module $defaultLocalPath\ASDKHelperModule.psm1 not found"   
}

#Download Install-ASDK.ps1 (installer)
DownloadWithRetry -Uri "$branchFullPath/scripts/Install-ASDK.ps1" -DownloadLocation "$defaultLocalPath\Install-ASDK.ps1"

#Download and extract Mobaxterm
DownloadWithRetry -Uri "https://aka.ms/mobaxtermLatest" -DownloadLocation "$defaultLocalPath\Mobaxterm.zip"
Expand-Archive -Path "$defaultLocalPath\Mobaxterm.zip" -DestinationPath "$defaultLocalPath\Mobaxterm"
Remove-Item -Path "$defaultLocalPath\Mobaxterm.zip" -Force

#Enable remoting firewall rule
Get-NetFirewallRule -Name WINRM-HTTP-In-TCP-PUBLIC | Get-NetFirewallAddressFilter | Set-NetFirewallAddressFilter -RemoteAddress any -PassThru -OutVariable firewallRuleResult | Get-NetFirewallRule | Enable-NetFirewallRule
Write-Log @writeLogParams -Message $firewallRuleResult
Remove-Variable -Name firewallRuleResult -Force -ErrorAction SilentlyContinue

#Disables Internet Explorer Enhanced Security Configuration
Disable-InternetExplorerESC

#Enable Internet Explorer File download
New-Item -Path 'HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3' -Force
New-Item -Path 'HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\0' -Force
New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3' -Name 1803 -Value 0 -PropertyType DWORD -Force
New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\0' -Name 1803 -Value 0 -PropertyType DWORD -Force

if ($ASDKConfiguratorObject)
{
    $AsdkConfigurator = ConvertFrom-Json $ASDKConfiguratorObject | ConvertFrom-Json
    if ($?)
    {
        $ASDKConfiguratorParams = ConvertTo-HashtableFromPsCustomObject $AsdkConfigurator.ASDKConfiguratorParams
        if (!($ASDKConfiguratorParams.downloadPath))
        {
            $ASDKConfiguratorParams.Add("downloadPath", "D:\ASDKfiles")
        }

        if ($ASDKConfiguratorParams.AzureADUsername -match '<|>' -or $ASDKConfiguratorParams.azureDirectoryTenantName -match '<|>' -or $ASDKConfiguratorParams.azureStackAdminPwd -match '<|>' -or $ASDKConfiguratorParams.VMpwd -match '<|>' -or $ASDKConfiguratorParams.azureAdPwd -match '<|>')
        {
            $AsdkConfigurator.Autorun = "false"
            $AsdkConfigurator.Add("Autorun", "false")
        }

        #create configasdk folder
        if ($AsdkConfigurator.path)
        {
            New-Item -ItemType Directory -Path $AsdkConfigurator.path -Force -Verbose
        }

        $paramsArray = @()
        foreach ($param in $ASDKConfiguratorParams.keys)
        {
            if ($ASDKConfiguratorParams["$param"] -eq 'true' -or $ASDKConfiguratorParams["$param"] -eq '' -or $null -eq $ASDKConfiguratorParams["$param"])
            {
                $paramsArray += "-" + "$param" + ":`$true"
            }
            elseif ($ASDKConfiguratorParams["$param"] -eq 'false')
            {
                $paramsArray += "-" + "$param" + ":`$false"
            }
            else 
            {
                $paramsArray += "-" + "$param " + "`'" + "$($ASDKConfiguratorParams["$param"])" + "`'"
            }
        }

        $paramsString = $paramsArray -join " "

        $commandsToRun = "$(Join-Path -Path $AsdkConfigurator.path -ChildPath "ConfigASDK.ps1") $paramsString"

        if ($AsdkConfigurator.Autorun -eq 'true')
        {
            #create download folder
            New-Item -ItemType Directory -Path $ASDKConfiguratorParams.downloadPath -Force -Verbose
            New-Item -ItemType Directory -Path (Join-Path -Path $ASDKConfiguratorParams.downloadPath -ChildPath ASDK) -Force -Verbose

            #download configurator
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-Webrequest http://bit.ly/configasdk -UseBasicParsing -OutFile (Join-Path -Path $AsdkConfigurator.path -ChildPath ConfigASDK.ps1) -Verbose

            #download iso files
            if ($ASDKConfiguratorParams.IsoPath2019)
            {
                DownloadWithRetry -Uri https://software-download.microsoft.com/download/pr/17763.253.190108-0006.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso -DownloadLocation $ASDKConfiguratorParams.IsoPath2019
            }
            if ($ASDKConfiguratorParams.IsoPath)
            {
                DownloadWithRetry -Uri http://download.microsoft.com/download/1/4/9/149D5452-9B29-4274-B6B3-5361DBDA30BC/14393.0.161119-1705.RS1_REFRESH_SERVER_EVAL_X64FRE_EN-US.ISO -DownloadLocation $ASDKConfiguratorParams.IsoPath
            }

            $commandsToRun |  Out-File -FilePath (Join-Path -Path $defaultLocalPath -ChildPath Run-ConfigASDK.ps1)  -Encoding ASCII
        }

        if ($AsdkConfigurator.Autorun -eq 'false') 
        {
            $script = @"
Import-Module "$defaultLocalPath\ASDKHelperModule.psm1" -ErrorAction Stop
New-Item -ItemType Directory -Path $($ASDKConfiguratorParams.downloadPath) -Force -Verbose
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-Webrequest http://bit.ly/configasdk -UseBasicParsing -OutFile $($AsdkConfigurator.path)\ConfigASDK.ps1 -Verbose

"@

            if ($ASDKConfiguratorParams.IsoPath2019)
            {
                $script += @"
DownloadWithRetry -Uri https://software-download.microsoft.com/download/pr/17763.253.190108-0006.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso -DownloadLocation $($ASDKConfiguratorParams.IsoPath2019)

"@
            }

            if ($ASDKConfiguratorParams.IsoPath)
            {
                $script += @"
DownloadWithRetry -Uri http://download.microsoft.com/download/1/4/9/149D5452-9B29-4274-B6B3-5361DBDA30BC/14393.0.161119-1705.RS1_REFRESH_SERVER_EVAL_X64FRE_EN-US.ISO -DownloadLocation $($ASDKConfiguratorParams.IsoPath)

"@
            }

            $script += @"
$commandsToRun

"@

            $script |  Out-File -FilePath (Join-Path -Path $AsdkConfigurator.path -ChildPath Run-ConfigASDK.ps1)  -Encoding ASCII
        } 
    }
}

if ($ASDKImage) {
    if (!($AutoInstallASDK))
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
    }
}

if ($AzureImage) {
    New-Item HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials -Force
    New-Item HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Force
    Set-ItemProperty -LiteralPath HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials -Name 1 -Value "wsman/*" -Type STRING -Force
    Set-ItemProperty -LiteralPath HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name 1 -Value "wsman/*" -Type STRING -Force
    Set-ItemProperty -LiteralPath HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation -Name AllowFreshCredentials -Value 1 -Type DWORD -Force
    Set-ItemProperty -LiteralPath HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation -Name AllowFreshCredentialsWhenNTLMOnly -Value 1 -Type DWORD -Force
    Set-ItemProperty -LiteralPath HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation -Name ConcatenateDefaults_AllowFresh -Value 1 -Type DWORD -Force
    Set-ItemProperty -LiteralPath HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation -Name ConcatenateDefaults_AllowFreshNTLMOnly -Value 1 -Type DWORD -Force
    Set-ItemProperty -LiteralPath HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled -Value 1 -Type DWord -Force
    Set-Item -Force WSMan:\localhost\Client\TrustedHosts "*"
    Enable-WSManCredSSP -Role Client -DelegateComputer "*" -Force
    Enable-WSManCredSSP -Role Server -Force

    Install-PackageProvider nuget -Force

    Set-ExecutionPolicy unrestricted -Force

    #Download ASDK Downloader
    DownloadWithRetry -Uri "https://aka.ms/azurestackdevkitdownloader" -DownloadLocation "D:\AzureStackDownloader.exe"

    if (!($AsdkFileList)) {
        $AsdkFileList = @("AzureStackDevelopmentKit.exe")
        1..10 | ForEach-Object {$AsdkFileList += "AzureStackDevelopmentKit-$_" + ".bin"}
    }
    if (Test-Path -Path $defaultLocalPath\testedVersions)
    {
        $latestASDK = Get-Content $defaultLocalPath\testedVersions | Select-Object -First 1
    }
    else
    {
        $latestASDK = (findLatestASDK -asdkURIRoot "https://azurestack.azureedge.net/asdk" -asdkFileList $AsdkFileList)[0]
    }
    
    if ($AutoDownloadASDK -eq "true") {
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

        if (Test-Path -Path $vhdxFullPath) {
            Write-Log @writeLogParams -Message "About to Start Copying ASDK files to C:\"
            Write-Log @writeLogParams -Message "Mounting cloudbuilder.vhdx"
            Copy-ASDKContent -vhdxFullPath $vhdxFullPath -Verbose
        } 
        if (!($AutoInstallASDK))
        {
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
        $downloadASDK = $null
    }
    else {
        if (!($AutoInstallASDK))
        {
            #Creating desktop shortcut for Install-ASDK.ps1
            if ($EnableDownloadASDK) {
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
            else {
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
                $Shortcut.Arguments = "-Noexit -command & {.\Install-ASDK.ps1}"
                $Shortcut.Save()
            }
        }
        $downloadASDK = "-DownloadASDK"
    }

    # Enable differencing roles from ASDKImage except .NET framework 3.5
    Enable-WindowsOptionalFeature -Online -All -NoRestart -FeatureName @("ActiveDirectory-PowerShell", "DfsMgmt", "DirectoryServices-AdministrativeCenter", "DirectoryServices-DomainController", "DirectoryServices-DomainController-Tools", "DNS-Server-Full-Role", "DNS-Server-Tools", "DSC-Service", "FailoverCluster-AutomationServer", "FailoverCluster-CmdInterface", "FSRM-Management", "IIS-ASPNET45", "IIS-HttpTracing", "IIS-ISAPIExtensions", "IIS-ISAPIFilter", "IIS-NetFxExtensibility45", "IIS-RequestMonitor", "ManagementOdata", "NetFx4Extended-ASPNET45", "NFS-Administration", "RSAT-ADDS-Tools-Feature", "RSAT-AD-Tools-Feature", "Server-Manager-RSAT-File-Services", "UpdateServices-API", "UpdateServices-RSAT", "UpdateServices-UI", "WAS-ConfigurationAPI", "WAS-ProcessModel", "WAS-WindowsActivationService", "WCF-HTTP-Activation45", "Microsoft-Hyper-V-Management-Clients")


    #Download OneNodeRole.xml
    DownloadWithRetry -Uri "$branchFullPath/scripts/OneNodeRole.xml" -DownloadLocation "$defaultLocalPath\OneNodeRole.xml"
    [xml]$rolesXML = Get-Content -Path "$defaultLocalPath\OneNodeRole.xml" -Raw
    $WindowsFeature = $rolesXML.role.PublicInfo.WindowsFeature
    $dismFeatures = (Get-WindowsOptionalFeature -Online).FeatureName
    if ($null -ne $WindowsFeature.Feature.Name) {
        $featuresToInstall = $dismFeatures | Where-Object { $_ -in $WindowsFeature.Feature.Name }
        if ($null -ne $featuresToInstall -and $featuresToInstall.Count -gt 0) {
            Write-Log @writeLogParams -Message "Following roles will be installed"
            Write-Log @writeLogParams -Message "$featuresToInstall"
            Enable-WindowsOptionalFeature -FeatureName $featuresToInstall -Online -All -NoRestart
        }
        if ($EnableRDSH) {
            Write-Log @writeLogParams -Message "User also chose to enable RDSH. Adding the Remote Desktop Session Host role"
            Enable-WindowsOptionalFeature -FeatureName AppServer Licensing-Diagnosis-UI -Online -All -NoRestart
        }
    }

    if ($null -ne $WindowsFeature.RemoveFeature.Name) {
        $featuresToRemove = $dismFeatures | Where-Object { $_ -in $WindowsFeature.RemoveFeature.Name }
        if ($null -ne $featuresToRemove -and $featuresToRemove.Count -gt 0) {
            Write-Log @writeLogParams -Message "Following roles will be uninstalled"
            Write-Log @writeLogParams -Message "$featuresToRemove"
            Disable-WindowsOptionalFeature -FeatureName $featuresToRemove -Online -Remove -NoRestart
        }
    }
}

Rename-LocalUser -Name $username -NewName Administrator

if ($AutoInstallASDK)
{
    if (!($AsdkFileList))
    {
        $AsdkFileList = @("AzureStackDevelopmentKit.exe")
        1..10 | ForEach-Object {$AsdkFileList += "AzureStackDevelopmentKit-$_" + ".bin"}
    }
    [ValidateSet("AAD", "ADFS")][string]$deploymentType = "AAD"

    $version = $latestASDK
    
    $taskName3 = "Auto ASDK Installer Service"
    Write-Log @writeLogParams -Message "Registering $taskname3"

    #Enable Autologon
    $AutoLogonRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty -Path $AutoLogonRegPath -Name "AutoAdminLogon" -Value "1" -type String 
    Set-ItemProperty -Path $AutoLogonRegPath -Name "DefaultUsername" -Value "$($env:ComputerName)\Administrator" -type String  
    Set-ItemProperty -Path $AutoLogonRegPath -Name "DefaultPassword" -Value "$LocalAdminPass" -type String
    Set-ItemProperty -Path $AutoLogonRegPath -Name "AutoLogonCount" -Value "1" -type DWord
    
    $AutoInstallASDKScriptBlock = @" 
if ((Test-Path -Path 'D:\Azure Stack Development Kit\cloudbuilder.vhdx') -and (Test-Path -Path 'c:\CloudDeployment') -and (Test-Path -Path 'C:\CloudDeployment\Logs\Deployment.*.log'))
{
    Get-ScheduledTask -TaskName "$taskName3" | Disable-ScheduledTask
}
else
{
    `$lPass = `'$LocalAdminPass`' | ConvertTo-SecureString -AsPlainText -Force
    `$aadPass = `'$AzureADGlobalAdminPass`' | ConvertTo-SecureString -AsPlainText -Force
    `$InfraAzureDirectoryTenantAdminCredential = New-Object System.Management.Automation.PSCredential (`'$AzureADGlobalAdmin`', `$aadPass)

"@
if ($ASDKImage)
{
    $AutoInstallASDKScriptBlock += @" 
    
    $defaultLocalPath\Install-ASDK.ps1 -DeploymentType "$deploymentType" -LocalAdminPass `$lPass -AADTenant "$AzureADTenant" -InfraAzureDirectoryTenantAdminCredential `$InfraAzureDirectoryTenantAdminCredential -SkipWorkaround

"@
}

if ($AzureImage)
{
    $AutoInstallASDKScriptBlock += @" 
    
    $defaultLocalPath\Install-ASDK.ps1 $downloadASDK -DeploymentType "$deploymentType" -LocalAdminPass `$lPass -AADTenant "$AzureADTenant" -InfraAzureDirectoryTenantAdminCredential `$InfraAzureDirectoryTenantAdminCredential -Version "$version"

"@
}

$AutoInstallASDKScriptBlock += @" 
}
"@  

    if (Get-ScheduledTask -TaskName $taskName3 -ErrorAction SilentlyContinue)
    {
        Get-ScheduledTask -TaskName $taskName3 | Unregister-ScheduledTask -Force
    }

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $AutoInstallASDKScriptBlock

    $registrationParams = @{
        TaskName = $taskName3
        TaskPath = '\AzureStackonAzureVM'
        Action = $action
        Settings = New-ScheduledTaskSettingsSet -Priority 4
        Force = $true
    }
    $registrationParams.Trigger = New-ScheduledTaskTrigger -AtLogOn
    $registrationParams.User = "$($env:ComputerName)\Administrator"
    $registrationParams.RunLevel = 'Highest'

    Register-ScheduledTask @registrationParams
}
Stop-Transcript
Restart-Computer -Force