Param (
    [Parameter(Mandatory=$true)]
    [string]
    $Username
    )
New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Force
New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\ -Name AllowFreshCredentialsWhenNTLMOnly -Value 1 -Force
New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly\ -Name 1 -Value  'WSMAN/*' -Force
Get-Disk | Where-Object {$_.partitionstyle -eq 'raw' -and $_.size -eq "64GB"} | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Downloads" -Confirm:$false
$size = Get-Disk -Number 0 | Get-Partition | Get-PartitionSupportedSize
Resize-Partition -DiskNumber 0 -PartitionNumber 1 -Size $size.SizeMax
Add-WindowsFeature RSAT-AD-PowerShell, RSAT-ADDS -IncludeAllSubFeature
Install-PackageProvider nuget -Force
Rename-LocalUser -Name $username -NewName Administrator
Add-WindowsFeature Hyper-V, Failover-Clustering, Web-Server -IncludeManagementTools #-Restart

