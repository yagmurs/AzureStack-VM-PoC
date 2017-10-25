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
#Disables Internet Explorer Enhanced Security Configuration
Disable-InternetExplorerESC

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


#Get-Disk | Where-Object {$_.partitionstyle -eq 'raw' -and $_.size -eq "64GB"} | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Downloads" -Confirm:$false
#$size = Get-Disk -Number 0 | Get-Partition | Get-PartitionSupportedSize
#Resize-Partition -DiskNumber 0 -PartitionNumber 1 -Size $size.SizeMax

Add-WindowsFeature RSAT-AD-PowerShell, RSAT-ADDS -IncludeAllSubFeature

Install-PackageProvider nuget -Force

Rename-LocalUser -Name $username -NewName Administrator

#Downloads Azure Stack Downloader
Invoke-WebRequest -Uri "https://aka.ms/azurestackdevkitdownloader" -OutFile "D:\AzureStackDownloader.exe"


Add-WindowsFeature Hyper-V, Failover-Clustering, Web-Server -IncludeManagementTools -Restart

