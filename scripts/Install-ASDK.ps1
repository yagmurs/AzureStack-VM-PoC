#region service script
$serviceScript = @'

#region function Definition
function Enable-ICS ($PublicAdapterName, $PrivateAdapterName)
{
    # Create a NetSharingManager object
    $m = New-Object -ComObject HNetCfg.HNetShare

    # Find connection
    $publicAdapter = $m.EnumEveryConnection |? { $m.NetConnectionProps.Invoke($_).Name -eq $publicAdapterName }
    $privateAdapter = $m.EnumEveryConnection |? { $m.NetConnectionProps.Invoke($_).Name -eq $privateAdapterName }


    # Get sharing configuration
    $publicAdapter = $m.INetSharingConfigurationForINetConnection.Invoke($publicAdapter)
    $privateAdapter = $m.INetSharingConfigurationForINetConnection.Invoke($privateAdapter)
        
    Start-Sleep -Seconds 2

    # Disable sharing
    $publicAdapter.DisableSharing()
    $privateAdapter.DisableSharing()

    # Enable sharing (0 - public, 1 - private)

    # Enable sharing public on Network_1
    $publicAdapter.EnableSharing(0)

    # Enable sharing private on Network_2
    $privateAdapter.EnableSharing(1)

}
    
function Disable-ICS ($PublicAdapterName, $PrivateAdapterName)
{
    # Register the HNetCfg library (once)
    regsvr32 /s hnetcfg.dll

    # Create a NetSharingManager object
    $m = New-Object -ComObject HNetCfg.HNetShare

    # Find connection
    $publicAdapter = $m.EnumEveryConnection |? { $m.NetConnectionProps.Invoke($_).Name -eq $publicAdapterName }
    $privateAdapter = $m.EnumEveryConnection |? { $m.NetConnectionProps.Invoke($_).Name -eq $privateAdapterName }


    # Get sharing configuration
    $publicAdapter = $m.INetSharingConfigurationForINetConnection.Invoke($publicAdapter)
    $privateAdapter = $m.INetSharingConfigurationForINetConnection.Invoke($privateAdapter)
        
    # Disable sharing
    $publicAdapter.DisableSharing()
    $privateAdapter.DisableSharing()
}

function Write-Log ([string]$Message, [string]$LogFilePath, [switch]$Overwrite)
{
    $t = Get-Date -Format "yyyy-MM-dd hh:mm:ss"
    Write-Verbose "$Message - $t"
    if ($Overwrite)
    {
        Set-Content -Path $LogFilePath -Value "$Message - $t"
    }
    else
    {
        Add-Content -Path $LogFilePath -Value "$Message - $t"
    }
}
#endregion

#region Variables
$VerbosePreference = "Continue"
$swName = "NATSw"
$publicAdapterName = "Deployment"
$privateAdapterName = "vEthernet `($swName`)"
$BGPNATVMNetworkAdapterName = "NAT"
$BgpNatVm = "AzS-BGPNAT01"
$logFileFullPath = "C:\AzureStackonAzureVM\CompanionServiceProgress.log"
$enableNatCheckFile = "C:\CompleteBootDSCStatus\AZs-ACS01.*.xml"
$writeLogParams = @{
    LogFilePath = $logFileFullPath
}
$NATIp = "192.168.137.1/28"

$IP = $natip.split("/")
$Octet = $IP[0].split(".")
$Octet[3] = 0
$NATNetwork = ($Octet -join ".") + "/" + $ip[1]

[int]$defaultPollIntervalInSeconds = 60
$ICS = $true

#endregion

# Register the HNetCfg library (once)
regsvr32 /s hnetcfg.dll

Write-Log @writeLogParams -Message "Starting the service"

$loopCount = 0
while ($true)
{
    if (-not ([System.Environment]::GetEnvironmentVariable('VMSwitchCreated', [System.EnvironmentVariableTarget]::Machine) -eq $true))
    {
        #Wait for Network Adapter presence if so will create new Internal Virtual Switch  
        $null = Get-NetAdapter -Name $publicAdapterName -ErrorAction SilentlyContinue  
        if ($?)
        {
            $null = Get-VMSwitch -Name $swName -ErrorAction SilentlyContinue
            if (-not ($?))
            {
                $o = New-VMSwitch -Name $swName -SwitchType Internal -Verbose
                if ($?)
                {
                    Write-Log @writeLogParams -Message $o
                    Write-Log @writeLogParams -Message "`'$swName`' switch and `'$privateAdapterName`' Adapter created successfully"
                    Start-Sleep -Seconds 10
                    $o = Remove-NetIPAddress -InterfaceAlias "$privateAdapterName" -Confirm:$false
                    $ip = $NATIp.split("/")[0]
                    $prefixLength = $NATIp.split("/")[1]
                    $o = New-NetIPAddress -InterfaceAlias "$privateAdapterName" -IPAddress $ip -PrefixLength $prefixLength -AddressFamily IPv4
                    if ($?)
                    {
                        Write-Log @writeLogParams -Message "IP address `($ip`) and PrefixLength `($prefixLength`) successfully set to adapter `'$privateAdapterName`'"
                        Write-Log @writeLogParams -Message "This step completed. Saving to Environment Variable `(VMSwitchCreated`)"
                        [System.Environment]::SetEnvironmentVariable('VMSwitchCreated', $true, [System.EnvironmentVariableTarget]::Machine)
                    }
                    Write-Log @writeLogParams -Message $o
                }
            }

        }
        else
        {
            if ($loopCount -eq 0)
            {
                Write-Log @writeLogParams -Message "Waiting for `'$publicAdapterName`' adapter's presence"
            }
        }
    }

    if (-not ([System.Environment]::GetEnvironmentVariable('BGPNATVMVMNetAdapterFixed', [System.EnvironmentVariableTarget]::Machine) -eq $true))
    {
        Write-Log @writeLogParams -Message  "Checking $BgpNatVm VM's presence and state"
        $BgpNatVmObj = Get-VM -Name $BgpNatVm | ? state -eq running
        if ($BgpNatVmObj)
        {
            $null = Get-NetAdapter -Name $privateAdapterName -ErrorAction SilentlyContinue  
            if ($?)
            {
                Write-Log @writeLogParams -Message "Waiting for NIC configurations to complete for $defaultPollIntervalInSeconds seconds"
                Start-Sleep -Seconds $defaultPollIntervalInSeconds
                $BgpNatVmObj | Get-VMNetworkAdapter -Name $BGPNATVMNetworkAdapterName | Connect-VMNetworkAdapter -SwitchName $swName
                Write-Log @writeLogParams -Message "$BgpNatVm's $BGPNATVMNetworkAdapterName network adapter plugged to $swName"
                Write-Log @writeLogParams -Message "This step completed. Saving to Environment Variable `(BGPNATVMVMNetAdapterFixed`)"
                [System.Environment]::SetEnvironmentVariable('BGPNATVMVMNetAdapterFixed', $true, [System.EnvironmentVariableTarget]::Machine)
            }
        }
    }

    if (-not ([System.Environment]::GetEnvironmentVariable('NATEnabled', [System.EnvironmentVariableTarget]::Machine) -eq $true))
    {
        Write-Log @writeLogParams -Message "Waiting for $enableNatCheckFile to confirm AZs-ACS01 deployment state"
        $file = Resolve-Path -Path $enableNatCheckFile
        if ($file)
        {
            [xml]$r = Get-Content -Path $file
            if ($r.DeploymentDSC.status -like "?*")
            {
                if ($ICS -eq $true)
                {
                    Get-NetNat | Remove-NetNat -Confirm:$false
                    $o = Enable-ICS -PublicAdapterName $publicAdapterName -PrivateAdapterName $privateAdapterName
                    Write-Log @writeLogParams -Message "All Previous NATs removed and ICS Enabled instead"
                    Write-Log @writeLogParams -Message $o
                    Write-Log @writeLogParams -Message "This step completed. Saving to Environment Variable `(NATEnabled`)"
                    [System.Environment]::SetEnvironmentVariable('NATEnabled', $true, [System.EnvironmentVariableTarget]::Machine)

                }
                else
                {
                    Get-NetNat | Remove-NetNat -Confirm:$false
                    $o = New-NetNat -Name "Nat for BGPNAT Network" -InternalIPInterfaceAddressPrefix $NATNetwork
                    Write-Log @writeLogParams -Message "All Previous NATs removed and following NAT created"
                    Write-Log @writeLogParams -Message $o
                    Write-Log @writeLogParams -Message "This step completed. Saving to Environment Variable `(NATEnabled`)"
                    [System.Environment]::SetEnvironmentVariable('NATEnabled', $true, [System.EnvironmentVariableTarget]::Machine)
                }
            }
        }
    }

    if (
        ([System.Environment]::GetEnvironmentVariable('VMSwitchCreated', [System.EnvironmentVariableTarget]::Machine) -eq $true) -and 
        ([System.Environment]::GetEnvironmentVariable('BGPNATVMVMNetAdapterFixed', [System.EnvironmentVariableTarget]::Machine) -eq $true) -and 
        ([System.Environment]::GetEnvironmentVariable('NATEnabled', [System.EnvironmentVariableTarget]::Machine) -eq $true))
    {
        Write-Log @writeLogParams -Message "All Workarounds applied, Unregistering the service"
        Unregister-ScheduledJob -Name "ASDK Installer Companion Service"
        break
    }
    Start-Sleep -Seconds $defaultPollIntervalInSeconds
    $loopCount++
}

'@

$serviceScript | Out-File "c:\AzureStackonAzureVM\Install-ASDKCompanionService.ps1" -Force
#endregion

#region Fuctions
function Print-Output ($message)
{
    $t = get-date -Format "yyyy-MM-dd hh:mm:ss"
    Write-Output "$message - $t"
}

function FindReplace-ZipFileContent ($ZipFileFullPath, $FilenameFullPath, $ItemToFind, $ReplaceWith)
{
        $ZipFileFullPath = Resolve-Path $ZipFileFullPath
        $file = $FilenameFullPath.split("/")[-1]
        $tempFileFullPath = Join-Path -Path $env:temp -ChildPath $file
        Add-Type -Assembly System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::Open($ZipFileFullPath,"update")
        $zip.Entries | where {$_.Name -eq $file} | foreach {[System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $tempFileFullPath, $true)}
        (Get-Content $tempFileFullPath) -replace "$ItemToFind", "$ReplaceWith" | Out-File $tempFileFullPath
        $fileName = [System.IO.Path]::GetFileName($file)
        ($zip.Entries | where {$_.Name -eq $file}).delete()
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$tempFileFullPath,$FilenameFullPath,"Optimal") | Out-Null
        $zip.Dispose()
}
#endregion

#region Variables

$AtStartup = New-JobTrigger -AtStartup -RandomDelay 00:00:30
$options = New-ScheduledJobOption -RequireNetwork

do {
$adminPass = Read-Host -Prompt "Enter for Administrator Password" -AsSecureString
$adminPass1 = Read-Host -Prompt "Re-Enter for Administrator Password" -AsSecureString
$adminPass_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPass))
$adminpass1_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPass1))
    if ($adminPass_text -cne $adminpass1_text)
    {
        Write-Output "Password does not match, re-enter password"
    }

} until ($adminPass_text -ceq $adminpass1_text)

$aadAdmin = Read-Host -Prompt "Enter Azure AD Global Administrator account name. ex: adm"
$aadTenant = Read-Host -Prompt "Enter Azure AD domain name. ex: <aadName>.onmicrosoft.com"

do {
$aadPass = Read-Host -Prompt "Enter password for $aadAdmin@$aadTenant" -AsSecureString
$aadPass1 = Read-Host -Prompt "Re-Enter password for $aadAdmin@$aadTenant" -AsSecureString
$aadPass_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($aadPass))
$aadPass1_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($aadPass1))
    if ($aadPass_text -cne $aadpass1_text)
    {
        Write-Output "Password does not match, re-enter password"
    }

} until ($aadPass_text -ceq $aadpass1_text)

$localAdminCred = New-Object System.Management.Automation.PSCredential ("Administrator", $adminPass)
$aadcred = New-Object System.Management.Automation.PSCredential ($("$aadAdmin" + '@' + "$aadTenant"), $aadPass)
$timeServiceProvider = @("pool.ntp.org") | Get-Random
$timeServer = (Test-NetConnection -ComputerName $timeServiceProvider).ResolvedAddresses.ipaddresstostring | Get-Random

$asdkFileList = @("AzureStackDevelopmentKit.exe","AzureStackDevelopmentKit-1.bin","AzureStackDevelopmentKit-2.bin","AzureStackDevelopmentKit-3.bin","AzureStackDevelopmentKit-4.bin","AzureStackDevelopmentKit-5.bin","AzureStackDevelopmentKit-6.bin")
$asdkURIRoot = "https://azurestack.azureedge.net/asdk"
$version = get-date -Format "yyMM"
$versionPrevious = get-date (Get-Date).AddMonths(-1) -Format "yyMM"
$asdkDownloadPath = "D:"
$asdkExtractFolder = "Azure Stack Development Kit"
$asdkDownloaderFile = "AzureStackDownloader.exe"
$asdkDownloaderFullPath = Join-Path -Path $asdkDownloadPath -ChildPath $asdkDownloaderFile
$vhdxName = 'CloudBuilder.vhdx'
$vhdxFullPath = Join-Path -Path $asdkDownloadPath -ChildPath (Join-Path -Path $asdkExtractFolder -ChildPath $vhdxName)
$foldersToCopy = 'CloudDeployment', 'fwupdate', 'tools'
$destPath = 'C:\'
$InstallAzSPOCParams = @{
    AdminPassword = $adminpass
    InfraAzureDirectoryTenantAdminCredential = $aadcred 
    InfraAzureDirectoryTenantName = $aadTenant
    NATIPv4Subnet = "192.168.137.0/28"
    NATIPv4Address = "192.168.137.11"
    NATIPv4DefaultGateway = "192.168.137.1"
    TimeServer = $timeServer
    DNSForwarder = "8.8.8.8"
}

#endregion

#Test if ASDK required folder already in the OS drive
if ((Test-Path -Path ($foldersToCopy | ForEach-Object {Join-Path -Path $destPath -ChildPath $_})) -contains $false)
{
    #Test if ASDK CloudBuilder.vhdx file is present if not download ASDK files
    if (-not (Test-Path -Path $vhdxFullPath))
    {
        $AsdkFiles = @()

        foreach ($AsdkFile in $ASDKFileList)
        {
            $AsdkFiles += Join-Path -Path $asdkDownloadPath -ChildPath $AsdkFile
        }

        $testPathResult = (Test-Path $AsdkFiles)
        if ($testPathResult -contains $false)
        {
            try
            {
                $r = (Invoke-WebRequest -Uri $($asdkURIRoot + $version + '/' + $asdkFileList[0]) -UseBasicParsing -DisableKeepAlive -Method Head -ErrorAction SilentlyContinue).StatusCode 
            }
            catch [System.Net.WebException],[System.Exception]
            {
                $r = 404
            }

            if ($r -eq 200)
            {
                Write-Verbose "Downloading This month's release of ASDK `($version`)" -Verbose
                $asdkFileList | % {Start-BitsTransfer -Source $($asdkURIRoot + $version + '/' + $_) -Destination $(Join-Path -Path $asdkDownloadPath -ChildPath $_)}
            }
            else
            {
                Write-Verbose "Downloading last month's release of ASDK `($versionPrevious`)" -Verbose
                $asdkFileList | % {Start-BitsTransfer -Source $($asdkURIRoot + $versionPrevious + '/' + $_) -Destination $(Join-Path -Path $asdkDownloadPath -ChildPath $_)}
            }
        }

        $i = 0

        while ($testPathResult -contains $false)
        {
            if ($i%45 -eq 0) 
            {
                Print-Output -Message "Waiting for Azure Stack Development kit files on `'$asdkDownloadPath`'"
            }
    
            Start-Sleep -Seconds 1
            $testPathResult = (Test-Path $AsdkFiles)
            $i++ 
        }
        
        Print-Output -message "Extracting Azure Stack Development kit files"
    
        $f = Join-Path -Path $asdkDownloadPath -ChildPath "AzureStackDevelopmentKit.exe"
        $o = Join-Path -Path $asdkDownloadPath -ChildPath $asdkExtractFolder
        
        Start-Process -FilePath $f -ArgumentList "/dir=`"$o`"", "/silent" -Wait
    }
    #if ASDK CloudBuilder.vhdx file present, mount and copy files from
    if (Test-Path -Path $vhdxFullPath)
    {
        Print-Output -Message "About to Start Copying ASDK files to C:\"
        $driveLetter = Mount-VHD -Path $vhdxFullPath -Passthru | Get-Disk | Get-Partition | ? size -gt 500MB | Select-Object -ExpandProperty driveletter
        foreach ($folder in $foldersToCopy)
        {
            Print-Output -message "Copying folder $folder to $destPath"
            Copy-Item -Path (Join-Path -Path $($driveLetter + ':') -ChildPath $folder) -Destination $destPath -Recurse -Force
            Print-Output -message "$folder done..."
        }
        Dismount-VHD -Path $vhdxFullPath       
    }

}


Print-Output -Message "Tweaking some nupkg files to run ASDK on Azure VM"
$zipFile1 = 'C:\CloudDeployment\NuGetStore\Microsoft.AzureStack.Solution.Deploy.CloudDeployment.*.nupkg'
if (Test-Path $zipFile1)
{
    #FindReplace-ZipFileContent -ZipFileFullPath $zipFile1 -FilenameFullPath 'content/Roles/PhysicalMachines/Tests/BareMetal.Tests.ps1' -ItemToFind '-not \$isVirtualizedDeployment' -ReplaceWith '$isVirtualizedDeployment'
    FindReplace-ZipFileContent -ZipFileFullPath $zipFile1 -FilenameFullPath 'content/Roles/PhysicalMachines/Tests/BareMetal.Tests.ps1' -ItemToFind '\$isvirtualizedDeployment = \(\$Parameters.OEMModel -eq ''Hyper-V''\)' -ReplaceWith '$isVirtualizedDeployment = ($Parameters.OEMModel -eq ''Hyper-V'') -or $isOneNode'
}
else
{
    Write-Error "$zipfile1 cannot be found"
}
$st = Register-ScheduledJob -Trigger $AtStartup -ScheduledJobOption $options -FilePath "c:\AzureStackonAzureVM\Install-ASDKCompanionService.ps1" -Name "ASDK Installer Companion Service" -Credential $localAdminCred
$st.StartJob()

cd C:\CloudDeployment\Setup
.\InstallAzureStackPOC.ps1 @InstallAzSPOCParams