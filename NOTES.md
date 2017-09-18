  
  ** Template take care of this step.

Create new Azure VM using this template
**Set VM's disk size to 256GB
**Add 4x128GB disk premium storage
**Add additional disk 64GB to store downloads

RDP to Azure VM

Download and extract Azure Stack Development Kit: https://azure.microsoft.com/en-us/overview/azure-stack/development-kit/ to 64GB disk

**Install Hyper-v, Failover Cluster and Web Server including Management tools and NuGet Package provider on Azure VM, run following commands
	Add-WindowsFeature Hyper-V, Failover-Clustering, Web-Server -IncludeManagementTools
	Add-WindowsFeature RSAT-AD-PowerShell, RSAT-ADDS -IncludeAllSubFeature
	Install-PackageProvider nuget –Verbose
**Restart the VM

Mount cloudBuilder.vhdx from 64GB disk 

Copy CloudDeployment, fwupdate and tools folder from mounted volume to root of C: drive

Find Microsoft.AzureStack.Solution.Deploy.CloudDeployment.1.0.522.0.nupkg file and change file extension to zip open and find .\content\Roles\PhysicalMachines\Tests\BareMetal.Tests.ps1 and edit. Find $isVirtualizedDeployment and remove -not in the is statement (check all if statement there will be 3 of them) save zip file and change ile extension back to nupkg.

**Run following to allow CredSSP
	New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\ -Name AllowFreshCredentialsWhenNTLMOnly -Value 1 -Force
	New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly\ -Name 1 -Value  'WSMAN/*' -Force

Create Azure AD tenant and Admin user with Global Administrator permission

Run setup using following (Complete information according to your environment)
	#Using Azure AAD
	cd C:\CloudDeployment\Setup  
	$adminpass = ConvertTo-SecureString <Admin Password> -AsPlainText -Force 
	$aadpass = ConvertTo-SecureString <> -AsPlainText -Force
	$aadAdmin = "<aad user>"
	$aadTenant = "<aad name>.onmicrosoft.com"
	$aadcred = New-Object System.Management.Automation.PSCredential ($("$aadAdmin" + '@' + "$aadTenant"), $aadpass)  
	.\InstallAzureStackPOC.ps1 -AdminPassword $adminpass -InfraAzureDirectoryTenantAdminCredential $aadcred -InfraAzureDirectoryTenantName $aadTenant -NATIPv4Subnet 172.16.0.0/24 -NATIPv4Address 172.16.0.2 -NATIPv4DefaultGateway 172.16.0.1
	
Follow the setup progress and Enable Time zone sync from Hyper-V integration components for AzS-ACS01 once the machine deployed if there is time zone difference between Hyper-v server and AzS-ACS01

Once the Host joined to the domain, Logon to Host using AzureStackAdmin and run following command to continue setup, if setup fails make sure that all previous steps are done.
	cd C:\CloudDeployment\Setup  
	.\InstallAzureStack.ps1 -Rerun -Verbose
	
Follow the setup progress once AzS-BGPNAT01 machine deployed change the NAT adapter virtual switch from PublicSwitch to NatSwitch by running following command
	$swName = "NATSwitch"
	New-VMSwitch -Name $swName -SwitchType Internal -Verbose
	$NIC=Get-NetAdapter "vEthernet `($swName`)"
	New-NetIPAddress -IPAddress 172.16.0.1 -PrefixLength 24 -InterfaceIndex $NIC.ifIndex
	New-NetNat -Name $swName -InternalIPInterfaceAddressPrefix "172.16.0.0/24" –Verbose
	Get-VM -Name AzS-BGPNAT01 | Get-VMNetworkAdapter -Name NAT | Connect-VMNetworkAdapter -SwitchName $swName
	
Once the installation completed open https://portal.local.azurestack.external/ from the host.


If you face any issues, troubleshoot the issue and re-run setup using ".\InstallAzureStack.ps1 -Rerun -Verbose"
Refer to articles on README.md for additional details.

Feel free to post questions and enjoy!