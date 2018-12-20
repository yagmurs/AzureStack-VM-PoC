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
function Disable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
}

function Write-Log ([string]$Message, [string]$LogFilePath, [switch]$Overwrite)
{
    $t = Get-Date -Format "yyyy-MM-dd hh:mm:ss"
    Write-Verbose "$Message - $t" -Verbose
    if ($Overwrite)
    {
        Set-Content -Path $LogFilePath -Value "$Message - $t"
    }
    else
    {
        Add-Content -Path $LogFilePath -Value "$Message - $t"
    }
}

function findLatestASDK 
{
    [CmdletBinding()]
    Param($asdkURIRoot, [string[]]$asdkFileList, $count = 8)
    $versionArray = @()
    $versionArrayToTest = @()
    $version = @(Get-Date -Format "yyMM")
    $suffix = @('-3','-2','-1','')
    
    for ($i = 0; $i -lt $count; $i++)
    {       
        foreach ($s in $suffix) {
            $version = (Get-Date (Get-Date).AddMonths(-$i) -Format "yyMM")
            $versionArrayToTest += "$version" + "$s"
        }
        Write-Verbose "$versionArrayToTest" -Verbose
    }

    foreach ($version in $versionArrayToTest)
    {
        try
        {
            $r = (Invoke-WebRequest -Uri $($asdkURIRoot + $version + '/' + $asdkFileList[0]) -UseBasicParsing -DisableKeepAlive -Method Head -ErrorAction SilentlyContinue).StatusCode
            if ($r -eq 200)
            {
                Write-Verbose "ASDK$version is available." -Verbose
                $versionArray += $version
            }
        }
        catch [System.Net.WebException],[System.Exception]
        {
            Write-Verbose "ASDK$version cannot be located." -Verbose
            $r = 404
        }
    }
    return $versionArray
}


function testASDKFilesPresence ([string]$asdkURIRoot, $version, [array]$asdkfileList) 
{
    $Uris = @()

    foreach ($file in $asdkfileList)
    {
        try
        {
            $Uri = ($asdkURIRoot + $version + '/' + $file)
            $r = (Invoke-WebRequest -Uri $Uri -UseBasicParsing -DisableKeepAlive -Method head -ErrorAction SilentlyContinue).statuscode
            if ($r -eq 200)
            {
                $Uris += $Uri
                Write-Verbose $Uri -Verbose
            }    
        }
        catch
        {
            $r = 404
        }
    }
    return $Uris
}

function ASDKDownloader
{
    [CmdletBinding()]
    param
    (
        [switch]
        $Interactive,

        [System.Collections.ArrayList]
        $AsdkFileList,

        [string]
        $ASDKURIRoot = "https://azurestack.azureedge.net/asdk",

        [string]
        $Version,

        [string]
        $Destination = "D:\"
    )
    if (!($AsdkFileList))
    {
        $AsdkFileList = @("AzureStackDevelopmentKit.exe")
        1..10 | ForEach-Object {$AsdkFileList += "AzureStackDevelopmentKit-$_" + ".bin"}
    }

    if ($Interactive)
    {
        $versionArray = findLatestASDK -asdkURIRoot $ASDKURIRoot -asdkFileList $AsdkFileList
        
        Write-Verbose "Version is now: $Version" -Verbose
        Write-Verbose "VersionArray is now: $versionArray" -Verbose
        if ($null -eq $Version -or $Version -eq "")
        {
            do
            {
                Clear-Host
                $i = 1
                Write-Host ""
                foreach ($v in $versionArray)
                {
                    Write-Host "$($i)`. ASDK version: $v"
                    $i++
                }
                Write-Host ""
                Write-Host -ForegroundColor Yellow -BackgroundColor DarkGray -NoNewline  -Object "Unless it is instructed, select only latest tested ASDK Version "
                Write-Host -ForegroundColor Green -BackgroundColor DarkGray -Object $gitbranchconfig.lastversiontested
                Write-Host ""
                $s = (Read-Host -Prompt "Select ASDK version to install")
                if ($s -match "\d")
                {
                    $s = $s - 1
                }
            }
            until ($versionArray[$s] -in $versionArray)
            $version = $versionArray[$s]
        }
    }
        $downloadList = testASDKFilesPresence -asdkURIRoot $ASDKURIRoot -version $Version -asdkfileList $AsdkFileList
        $downloadList
        
        Write-Verbose -Message "Downloading ASDK$Version" -Verbose
        
        $downloadList | ForEach-Object {Start-BitsTransfer -Source $_ -DisplayName $_ -Destination $Destination}      
}

function extractASDK ($File, $Destination)
{
    Start-Process -FilePath $File -ArgumentList "/dir=`"$destination`"", "/SILENT", "/NOCANCEL" -Wait
}

function workaround1
{
    Write-Verbose "Applying workaround to tweak baremetal detection for Azure VM" -Verbose
    $baremetalFilePath = "C:\CloudDeployment\Roles\PhysicalMachines\Tests\BareMetal.Tests.ps1"
    $baremetalFile = Get-Content -Path $baremetalFilePath
    $baremetalFile = $baremetalFile.Replace('$isVirtualizedDeployment = ($Parameters.OEMModel -eq ''Hyper-V'')','$isVirtualizedDeployment = ($Parameters.OEMModel -eq ''Hyper-V'') -or $isOneNode') 
    Set-Content -Value $baremetalFile -Path $baremetalFilePath -Force
}

function workaround2
{
    Write-Verbose "Applying workaround to tweak long path issues started appear after 1802" -Verbose
    $HelpersFilePath = "C:\CloudDeployment\Common\Helpers.psm1" 
    $HelpersFile = Get-Content -Path $HelpersFilePath
    $HelpersFile = $HelpersFile.Replace('C:\tools\NuGet.exe install $NugetName -Source $NugetStorePath -OutputDirectory $DestinationPath -packagesavemode "nuspec" -Prerelease','C:\tools\NuGet.exe install $NugetName -Source $NugetStorePath -OutputDirectory $DestinationPath -packagesavemode "nuspec" -Prerelease -ExcludeVersion') 
    Set-Content -Value $HelpersFile -Path $HelpersFilePath -Force
}

function workaround3
{
    Write-Verbose "Applying workaround to tackle installation from PS remoting" -Verbose
    $DeploySingleNodeCommonFilePath = "C:\CloudDeployment\Setup\Common\DeploySingleNodeCommon.ps1"
    $DeploySingleNodeCommonFile = Get-Content -Path $DeploySingleNodeCommonFilePath
    $DeploySingleNodeCommonFile = $DeploySingleNodeCommonFile.Replace('$credentialSuccess = Invoke-Command -ComputerName ''LocalHost'' -Credential $builtInAdminCredential -ErrorAction ''SilentlyContinue'' { $true }','$credentialSuccess = $true') 
    Set-Content -Value $DeploySingleNodeCommonFile -Path $DeploySingleNodeCommonFilePath -Force
}

function createDesktopShortcuts
{
    #Create all user desktop shotcuts for Azure Stack Admin and Tenant portal
    $Shell = New-Object -ComObject ("WScript.Shell")
            
    $fileName = $env:ALLUSERSPROFILE + "\Desktop\Azure Stack Admin Portal.url"
    if (!(Test-Path -Path $fileName))
    {
        $Favorite = $Shell.CreateShortcut($fileName)
        $Favorite.TargetPath = "https://adminportal.local.azurestack.external";
        $Favorite.Save()
        Write-Log @writeLogParams -Message "Desktop shorcut $fileName created."
    }

    $fileName = $env:ALLUSERSPROFILE + "\Desktop\Azure Stack Tenant Portal.url"
    if (!(Test-Path -Path $fileName))
    {
        $Favorite = $Shell.CreateShortcut($fileName)
        $Favorite.TargetPath = "https://portal.local.azurestack.external";
        $Favorite.Save()
        Write-Log @writeLogParams -Message "Desktop shorcuts $fileName created."
    }

    $fileName = $env:ALLUSERSPROFILE + "\Desktop\Azure Portal.url"
    if (!(Test-Path -Path $fileName))
    {
        $Favorite = $Shell.CreateShortcut($fileName)
        $Favorite.TargetPath = "https://portal.azure.com";
        $Favorite.Save()
        Write-Log @writeLogParams -Message "Desktop shorcuts $fileName created."
    }

    $fileName = $env:ALLUSERSPROFILE + "\Desktop\Service Fabric Explorer.url"
    if (!(Test-Path -Path $fileName))
    {
        $Favorite = $Shell.CreateShortcut($fileName)
        $Favorite.TargetPath = "http://azs-xrp01:19007";
        $Favorite.Save()
        Write-Log @writeLogParams -Message "Desktop shorcuts $fileName created."
    }

}


function Enable-ICS ($PublicAdapterName, $PrivateAdapterName)
{
    # Register the HNetCfg library (once)
    regsvr32 /s hnetcfg.dll

    # Create a NetSharingManager object
    $m = New-Object -ComObject HNetCfg.HNetShare

    # Find connection
    $publicAdapter = $m.EnumEveryConnection | Where-Object { $m.NetConnectionProps.Invoke($_).Name -eq $publicAdapterName }
    $privateAdapter = $m.EnumEveryConnection | Where-Object { $m.NetConnectionProps.Invoke($_).Name -eq $privateAdapterName }


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
    $publicAdapter = $m.EnumEveryConnection | Where-Object { $m.NetConnectionProps.Invoke($_).Name -eq $publicAdapterName }
    $privateAdapter = $m.EnumEveryConnection | Where-Object{ $m.NetConnectionProps.Invoke($_).Name -eq $privateAdapterName }


    # Get sharing configuration
    $publicAdapter = $m.INetSharingConfigurationForINetConnection.Invoke($publicAdapter)
    $privateAdapter = $m.INetSharingConfigurationForINetConnection.Invoke($privateAdapter)
        
    # Disable sharing
    $publicAdapter.DisableSharing()
    $privateAdapter.DisableSharing()
}

function Start-SleepWithProgress($seconds)
{

    $doneDT = (Get-Date).AddSeconds($seconds)

    while($doneDT -gt (Get-Date)) {

        $secondsLeft = $doneDT.Subtract((Get-Date)).TotalSeconds

        $percent = ($seconds - $secondsLeft) / $seconds * 100

        Write-Progress -Activity "Sleeping" -Status "Sleeping..." -SecondsRemaining $secondsLeft -PercentComplete $percent

        [System.Threading.Thread]::Sleep(500)

    }

    Write-Progress -Activity "Sleeping" -Status "Sleeping..." -SecondsRemaining 0 -Completed

}

function Copy-ASDKContent 
{
    param (
        $vhdxFullPath
    )
    $foldersToCopy = @('CloudDeployment', 'fwupdate', 'tools')

        try {
            $driveLetter = Mount-DiskImage -ImagePath $vhdxFullPath -StorageType VHDX -Passthru | Get-DiskImage | Get-Disk | Get-Partition | Where-Object size -gt 500MB | Select-Object -ExpandProperty driveletter
        }
        catch {
            throw "an error occured while mounting cloudbuilder.vhdx file"
        }

        foreach ($folder in $foldersToCopy)
        {
            Copy-Item -Path (Join-Path -Path $($driveLetter + ':') -ChildPath $folder) -Destination C:\ -Recurse -Force
        }
        Dismount-DiskImage -ImagePath $vhdxFullPath
        
}