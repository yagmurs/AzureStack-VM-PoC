
```powershell
$AadAdminUser = "yagmur@yazs1.onmicrosoft.com"
$AadPassword = "TklfxULRQ3lqAi0A" | ConvertTo-SecureString -AsPlainText -Force
$InfraAzureDirectoryTenantAdminCredential = New-Object System.Management.Automation.PSCredential ($AadAdminUser, $AadPassword)

$SecureAdminPassword = "12345678qqqQ" | ConvertTo-SecureString -AsPlainText -Force
[ValidateSet("AAD", "ADFS")][string]$deploymentType = "AAD"

cd\
cd .\AzureStackonAzureVM
.\Install-ASDK.ps1 `
    -DeploymentType $deploymentType `
    -LocalAdminPass $SecureAdminPassword `
    -AADTenant "yazs1.onmicrosoft.com" `
    -InfraAzureDirectoryTenantAdminCredential $InfraAzureDirectoryTenantAdminCredential
```