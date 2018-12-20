
```powershell
$AadAdminUser = "yagmur@<Azure AD Tenant>.onmicrosoft.com"
$AadPassword = "SuperSecurePassword123!!" | ConvertTo-SecureString -AsPlainText -Force
$InfraAzureDirectoryTenantAdminCredential = New-Object System.Management.Automation.PSCredential ($AadAdminUser, $AadPassword)

$SecureAdminPassword = "AnotherSuperSecurePassword123!" | ConvertTo-SecureString -AsPlainText -Force
[ValidateSet("AAD", "ADFS")][string]$deploymentType = "AAD"

cd\
cd .\AzureStackonAzureVM
.\Install-ASDK.ps1 `
    -DeploymentType $deploymentType `
    -LocalAdminPass $SecureAdminPassword `
    -AADTenant "<Azure AD Tenant>.onmicrosoft.com" `
    -InfraAzureDirectoryTenantAdminCredential $InfraAzureDirectoryTenantAdminCredential
```