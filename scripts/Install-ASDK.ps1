#region service script
$serviceScript = @'

$swName = "ICSAdapter"
$publicAdapterName = "Deployment"
$privateAdapterName = "vEthernet `($swName`)"
$BGPNATVMNetworkAdapterName = "NAT"
$logFileFullPath = "C:\AzureStackonAzureVM\workaroundProgress.log"
    
Add-Content -Path $logFileFullPath -Value "Starting the service"

while ($true)
{
    if (-not ([System.Environment]::GetEnvironmentVariable('ICSEnabled', [System.EnvironmentVariableTarget]::Machine) -eq $true))
    {
        $null = Get-NetAdapter -Name $publicAdapterName -ErrorAction SilentlyContinue  
        if ($?)
        {
            $null = Get-VMSwitch -Name $swName -ErrorAction SilentlyContinue
            if (-not ($?))
            {
                $null = New-VMSwitch -Name $swName -SwitchType Internal -Verbose
                if ($?)
                {
                    Write-Verbose "`'$swName`' switch and `'$privateAdapterName`' Adapter have been created successfully"  -Verbose
                }
            }

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

            # Enable sharing (0 - public, 1 - private)

            # Enable sharing public on Network_1
            $publicAdapter.EnableSharing(0)

            # Enable sharing private on Network_2
            $privateAdapter.EnableSharing(1)

            [System.Environment]::SetEnvironmentVariable('ICSEnabled', $true, [System.EnvironmentVariableTarget]::Machine)

        }
        else
        {
            Add-Content -Path $logFileFullPath -Value "Waiting for `'$publicAdapterName`' adapter the become available"
            Write-Verbose "Waiting for `'$publicAdapterName`' adapter the become available"  -Verbose
            Start-Sleep -Seconds 5
        }
    }
    if (-not ([System.Environment]::GetEnvironmentVariable('BGPNATVMVMNetAdapterFixed', [System.EnvironmentVariableTarget]::Machine) -eq $true))
    {
        $BgpNatVm = Get-VM -Name "AzS-BGPNAT01" -ErrorAction SilentlyContinue
        if ($?)
        {
            $BgpNatVm | Get-VMNetworkAdapter -Name $BGPNATVMNetworkAdapterName | Connect-VMNetworkAdapter -SwitchName $swName
            [System.Environment]::SetEnvironmentVariable('BGPNATVMVMNetAdapterFixed', $true, [System.EnvironmentVariableTarget]::Machine)
        }
    }
    if (([System.Environment]::GetEnvironmentVariable('BGPNATVMVMNetAdapterFixed', [System.EnvironmentVariableTarget]::Machine) -eq $true) -and ([System.Environment]::GetEnvironmentVariable('ICSEnabled', [System.EnvironmentVariableTarget]::Machine) -eq $true))
    {
        Write-Verbose "Workaround Fully Applied"  -Verbose
        Add-Content -Path $logFileFullPath -Value "Workaround Fully Applied, check back, BGPNATVMVMNetAdapterFixed and ICSEnabled Envrionment variables"
        Unregister-ScheduledJob -Name "ASDK Installer Companion Service"
        break
    }
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
$adminpass = ConvertTo-SecureString 12345678qqqQ -AsPlainText -Force
$localAdminCred = New-Object System.Management.Automation.PSCredential ("Administrator", $adminpass)
$aadpass = ConvertTo-SecureString rHn9j0hn4A45hiz4qHoa -AsPlainText -Force
$aadcred = New-Object System.Management.Automation.PSCredential ($("$aadAdmin" + '@' + "$aadTenant"), $aadpass)
$aadAdmin = "adm"
$aadTenant = "yagmursas1.onmicrosoft.com"
$timeServiceProvider = @("pool.ntp.org") | Get-Random
$timeServer = (Test-NetConnection -ComputerName $timeServiceProvider -InformationLevel Detailed).RemoteAddress.IPAddressToString

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
    NATIPv4Subnet = "192.168.137.0/24"
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
$zipFile1 = 'C:\CloudDeployment\NuGetStore\Microsoft.AzureStack.Solution.Deploy.CloudDeployment.1.0.590.8.nupkg'
if (Test-Path $zipFile1)
{
    FindReplace-ZipFileContent -ZipFileFullPath $zipFile1 -FilenameFullPath 'content/Roles/PhysicalMachines/Tests/BareMetal.Tests.ps1' -ItemToFind '-not \$isVirtualizedDeployment' -ReplaceWith '$isVirtualizedDeployment'
}
else
{
    Write-Error "$zipfile1 cannot be found"
}
$st = Register-ScheduledJob -Trigger $AtStartup -FilePath "c:\AzureStackonAzureVM\Install-ASDKCompanionService.ps1" -Name "ASDK Installer Companion Service"
$st.StartJob()

cd C:\CloudDeployment\Setup
.\InstallAzureStackPOC.ps1 @InstallAzSPOCParams