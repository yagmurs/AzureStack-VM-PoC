Param (
    [Parameter(Mandatory=$true)]
    [string]
    $Username
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

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/master/config.ind" -OutFile "$defaultLocalPath\config.ind"
$gitbranchcode = (Import-Csv -Path $defaultLocalPath\config.ind -Delimiter ",").branch.Trim()
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

Add-WindowsFeature RSAT-AD-PowerShell, RSAT-ADDS -IncludeAllSubFeature

Install-PackageProvider nuget -Force

Rename-LocalUser -Name $username -NewName Administrator

Set-ExecutionPolicy unrestricted -Force

#Download Install-ASDK.ps1 (installer)
DownloadWithRetry -Uri "$gitbranch/scripts/Install-ASDK.ps1" -DownloadLocation "$defaultLocalPath\Install-ASDK.ps1"
#Invoke-WebRequest -Uri "$gitbranch/scripts/Install-ASDK.ps1" -OutFile "$defaultLocalPath\Install-ASDK.ps1"

#Download ASDK Downloader
DownloadWithRetry -Uri "https://aka.ms/azurestackdevkitdownloader" -DownloadLocation "D:\AzureStackDownloader.exe"
#Invoke-WebRequest -Uri "https://aka.ms/azurestackdevkitdownloader" -OutFile "D:\AzureStackDownloader.exe"

#Download and extract Mobaxterm
DownloadWithRetry -Uri "https://aka.ms/mobaxtermLatest" -DownloadLocation "$defaultLocalPath\Mobaxterm.zip"
#Invoke-WebRequest -Uri "https://aka.ms/mobaxtermLatest" -OutFile "$defaultLocalPath\Mobaxterm.zip"
Expand-Archive -Path "$defaultLocalPath\Mobaxterm.zip" -DestinationPath "$defaultLocalPath\Mobaxterm"
Remove-Item -Path "$defaultLocalPath\Mobaxterm.zip" -Force

#Creating desktop shortcut for Install-ASDK.ps1
New-Item -ItemType SymbolicLink -Path ($env:ALLUSERSPROFILE + "\Desktop") -Name "Install-ASDK" -Value "$defaultLocalPath\Install-ASDK.ps1"

Add-WindowsFeature Hyper-V, Failover-Clustering, Web-Server -IncludeManagementTools -Restart
