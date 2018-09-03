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
        Write-Verbose "$versionArrayToTest"
    }

    foreach ($version in $versionArrayToTest)
    {
        try
        {
            $r = (Invoke-WebRequest -Uri $($asdkURIRoot + $version + '/' + $asdkFileList[0]) -UseBasicParsing -DisableKeepAlive -Method Head -ErrorAction SilentlyContinue).StatusCode
            if ($r -eq 200)
            {
                Write-Verbose "ASDK$version is available."
                $versionArray += $version
            }
        }
        catch [System.Net.WebException],[System.Exception]
        {
            Write-Verbose "ASDK$version cannot be located."
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
                Write-Verbose $Uri
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
        
        Write-Verbose "Version is now: $Version"
        Write-Verbose "VersionArray is now: $versionArray"
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
        
        Write-Verbose -Message "Downloading ASDK$Version"
        
        $downloadList | ForEach-Object {Start-BitsTransfer -Source $_ -DisplayName $_ -Destination $Destination}      
}

function extractASDK ($File, $Destination)
{
    Start-Process -FilePath $File -ArgumentList "/dir=`"$destination`"", "/SILENT", "/NOCANCEL" -Wait
}

function workaround1
{
    Write-Verbose ""
    $baremetalFilePath = "C:\CloudDeployment\Roles\PhysicalMachines\Tests\BareMetal.Tests.ps1"
    $baremetalFile = Get-Content -Path $baremetalFilePath
    $baremetalFile = $baremetalFile.Replace('$isVirtualizedDeployment = ($Parameters.OEMModel -eq ''Hyper-V'')','$isVirtualizedDeployment = ($Parameters.OEMModel -eq ''Hyper-V'') -or $isOneNode') 
    Set-Content -Value $baremetalFile -Path $baremetalFilePath -Force
}

function workaround2
{
    Write-Verbose ""
    $HelpersFilePath = "C:\CloudDeployment\Common\Helpers.psm1" 
    $HelpersFile = Get-Content -Path $HelpersFilePath
    $HelpersFile = $HelpersFile.Replace('C:\tools\NuGet.exe install $NugetName -Source $NugetStorePath -OutputDirectory $DestinationPath -packagesavemode "nuspec" -Prerelease','C:\tools\NuGet.exe install $NugetName -Source $NugetStorePath -OutputDirectory $DestinationPath -packagesavemode "nuspec" -Prerelease -ExcludeVersion') 
    Set-Content -Value $HelpersFile -Path $HelpersFilePath -Force
}