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

function findLatestASDK ($asdkURIRoot, [string[]]$asdkFileList, $count = 8)
{
    $versionArray = @()
    $version = Get-Date -Format "yyMM"
    for ($i = 0; $i -lt $count; $i++)
    {
        $version = (Get-Date (Get-Date).AddMonths(-$i) -Format "yyMM")
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
            }    
        }
        catch
        {
            $r = 404
        }
    }
    return $Uris
}