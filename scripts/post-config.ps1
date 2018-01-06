Param (
    [Parameter(Mandatory=$true)]
    [string]
    $Username
    )

function Disable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
}

$gitbranch = "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/development"
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
Invoke-WebRequest -Uri "$gitbranch/scripts/Install-ASDK.ps1" -OutFile "$defaultLocalPath\Install-ASDK.ps1"

#Download ASDK Downloader
Invoke-WebRequest -Uri "https://aka.ms/azurestackdevkitdownloader" -OutFile "D:\AzureStackDownloader.exe"

#Download and extract Mobaxterm
Invoke-WebRequest -Uri "https://aka.ms/mobaxtermLatest" -OutFile "$defaultLocalPath\Mobaxterm.zip"
Expand-Archive -Path "$defaultLocalPath\Mobaxterm.zip" -DestinationPath "$defaultLocalPath\Mobaxterm"
Remove-Item -Path "$defaultLocalPath\Mobaxterm.zip" -Force

#Creating desktop shortcut for Install-ASDK.ps1
New-Item -ItemType SymbolicLink -Path ($env:ALLUSERSPROFILE + "\Desktop") -Name "Install-ASDK" -Value "$defaultLocalPath\Install-ASDK.ps1"

Add-WindowsFeature Hyper-V, Failover-Clustering, Web-Server -IncludeManagementTools -Restart

