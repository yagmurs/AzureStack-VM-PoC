
# Unattendant installation examples
Following examples may be used once VM deployed succesfully.

To Automate ARM template deployment using PowerShell, check **/scripts/cleanup and deploy.ps1**

## - Deploy downloaded version of ASDK (AAD)

Use this if ARM Template AutoDownloadASDK parameter set to **true**

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

## - Download and install latest version of ASDK (AAD)

Use this if ARM Template AutoDownloadASDK parameter set to **false**

```powershell
$AadAdminUser = "yagmur@<Azure AD Tenant>.onmicrosoft.com"
$AadPassword = "SuperSecurePassword123!!" | ConvertTo-SecureString -AsPlainText -Force
$InfraAzureDirectoryTenantAdminCredential = New-Object System.Management.Automation.PSCredential ($AadAdminUser, $AadPassword)

$SecureAdminPassword = "AnotherSuperSecurePassword123!" | ConvertTo-SecureString -AsPlainText -Force
[ValidateSet("AAD", "ADFS")][string]$deploymentType = "AAD"

Import-Module C:\AzureStackOnAzureVM\ASDKHelperModule.psm1

if (!($AsdkFileList))
{
    $AsdkFileList = @("AzureStackDevelopmentKit.exe")
    1..10 | ForEach-Object {$AsdkFileList += "AzureStackDevelopmentKit-$_" + ".bin"}
}

$latestASDK = (findLatestASDK -asdkURIRoot "https://azurestack.azureedge.net/asdk" -asdkFileList $AsdkFileList)[0]
$version = $latestASDK

cd\
cd .\AzureStackonAzureVM

.\Install-ASDK.ps1 -DownloadASDK `
    -DeploymentType $deploymentType `
    -LocalAdminPass $SecureAdminPassword `
    -AADTenant "<Azure AD Tenant>.onmicrosoft.com" `
    -Version $version `
    -InfraAzureDirectoryTenantAdminCredential $InfraAzureDirectoryTenantAdminCredential

```

## - Download and install specific version of ASDK (AAD)

Use this if ARM Template AutoDownloadASDK parameter set to **false**

```powershell
$AadAdminUser = "yagmur@<Azure AD Tenant>.onmicrosoft.com"
$AadPassword = "SuperSecurePassword123!!" | ConvertTo-SecureString -AsPlainText -Force
$InfraAzureDirectoryTenantAdminCredential = New-Object System.Management.Automation.PSCredential ($AadAdminUser, $AadPassword)

$SecureAdminPassword = "AnotherSuperSecurePassword123!" | ConvertTo-SecureString -AsPlainText -Force
[ValidateSet("AAD", "ADFS")][string]$deploymentType = "AAD"

$version = "1809" # use findLatestASDK function in ASDKHelperModule.psm1 module to find list of available versions.

cd\
cd .\AzureStackonAzureVM

.\Install-ASDK.ps1 -DownloadASDK `
    -DeploymentType $deploymentType `
    -LocalAdminPass $SecureAdminPassword `
    -AADTenant "<Azure AD Tenant>.onmicrosoft.com" `
    -Version $version `
    -InfraAzureDirectoryTenantAdminCredential $InfraAzureDirectoryTenantAdminCredential

```

## - Download and install latest version of ASDK (ADFS)

Use this if ARM Template AutoDownloadASDK parameter set to **false**

```powershell
$SecureAdminPassword = "AnotherSuperSecurePassword123!" | ConvertTo-SecureString -AsPlainText -Force
[ValidateSet("AAD", "ADFS")][string]$deploymentType = "ADFS"

Import-Module C:\AzureStackOnAzureVM\ASDKHelperModule.psm1

if (!($AsdkFileList))
{
    $AsdkFileList = @("AzureStackDevelopmentKit.exe")
    1..10 | ForEach-Object {$AsdkFileList += "AzureStackDevelopmentKit-$_" + ".bin"}
}

$latestASDK = (findLatestASDK -asdkURIRoot "https://azurestack.azureedge.net/asdk" -asdkFileList $AsdkFileList)[0]
$version = $latestASDK

cd\
cd .\AzureStackonAzureVM

.\Install-ASDK.ps1 -DownloadASDK `
    -DeploymentType $deploymentType `
    -LocalAdminPass $SecureAdminPassword `
    -Version $version
```