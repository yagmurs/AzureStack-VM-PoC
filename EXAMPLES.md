
# Unattendant ASDK installation examples
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

# ARM template deployment examples

## Deploy ARM template only with no downloading any ASDK files

Once deployed run/check desktop shorcut options. You can select version to deploy.

```powershell
$tenantID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$subscriptionID = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"

Connect-AzureRmAccount -TenantId $tenantID -Subscription $subscriptionID

# create administrator password secure string object
$SecureAdminPassword = Read-Host -AsSecureString -Prompt "Provide local Administrator password for Azure Stack host VM" | ConvertTo-SecureString -AsPlainText -Force
#$SecureAdminPassword = "SuperSecurePassword123!!" | ConvertTo-SecureString -AsPlainText -Force

# declare variables 
[int]$instanceNumber = 1 # resource group name will be generated based on this number. 
[bool]$autoDownloadASDK = $false #either download latest ADSK in the VM or not. Setting this to $true will add additional ~35 mins to ARM template deployment time.
[string]$resourceGroupNamePrefix = "yagmursasdk" #Resource group name will be generated based on this prefix. Ex. yagmursasdk-1
[string]$publicDnsNamePrefix = "yagmursasdkinstance" # This will will be concatenated with $instancenumber. Ex. yagmursasdkinstance1.eastus2.cloudapp.azure.com
[string]$location = 'East US2' # can be any region that supports E and D VM sizes that supports nested virtualization.
[string]$virtualMachineSize = "Standard_E32s_v3" # 1811 and upper versions require 256GB RAM
[ValidateSet("development", "master")][string]$gitBranch = "master" # github branch 
[string]$resourceGroupName = "$resourceGroupNamePrefix-$instanceNumber"
[string]$publicDnsName = "$publicDnsNamePrefix$instanceNumber"

# create ARM template parameter object
$templateParameterObject = @{}
$templateParameterObject.Add("adminPassword", $SecureAdminPassword)
$templateParameterObject.Add("publicDnsName",$publicDnsName.ToLower())
$templateParameterObject.Add("autoDownloadASDK", $autoDownloadASDK)
$templateParameterObject.Add("virtualMachineSize", $virtualMachineSize)

# create resource group
New-AzureRmResourceGroup -Name $resourceGroupName -Location $location

# deploy ARM template from github using locally provided ARM template parameters
New-AzureRmResourceGroupDeployment -Name "$resourceGroupName-PoC-Deployment" -ResourceGroupName $resourceGroupName `
    -TemplateUri "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/$gitBranch/azuredeploy.json" `
    -TemplateParameterObject $templateParameterObject `
    -Mode Incremental `
    -AsJob


Pause
# delete resource group and all object in the RG
Get-AzureRmResourceGroup -Name $resourceGroupName | Remove-AzureRmResourceGroup -AsJob #-Force
```

## Deploy ARM template and auto download, extract latest version of ASDK

Once deployed run/check desktop shorcut options. You can select AAD or ADFS installations.

```powershell
$tenantID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$subscriptionID = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"

Connect-AzureRmAccount -TenantId $tenantID -Subscription $subscriptionID

# create administrator password secure string object
$SecureAdminPassword = Read-Host -AsSecureString -Prompt "Provide local Administrator password for Azure Stack host VM" | ConvertTo-SecureString -AsPlainText -Force
#$SecureAdminPassword = "SuperSecurePassword123!!" | ConvertTo-SecureString -AsPlainText -Force

# declare variables 
[int]$instanceNumber = 1 # resource group name will be generated based on this number. 
[bool]$autoDownloadASDK = $true #either download latest ADSK in the VM or not. Setting this to $true will add additional ~35 mins to ARM template deployment time.
[string]$resourceGroupNamePrefix = "yagmursasdk" #Resource group name will be generated based on this prefix. Ex. yagmursasdk-1
[string]$publicDnsNamePrefix = "yagmursasdkinstance" # This will will be concatenated with $instancenumber. Ex. yagmursasdkinstance1.eastus2.cloudapp.azure.com
[string]$location = 'East US2' # can be any region that supports E and D VM sizes that supports nested virtualization.
[string]$virtualMachineSize = "Standard_E32s_v3" # 1811 and upper versions require 256GB RAM
[ValidateSet("development", "master")][string]$gitBranch = "master" # github branch 
[string]$resourceGroupName = "$resourceGroupNamePrefix-$instanceNumber"
[string]$publicDnsName = "$publicDnsNamePrefix$instanceNumber"

# create ARM template parameter object
$templateParameterObject = @{}
$templateParameterObject.Add("adminPassword", $SecureAdminPassword)
$templateParameterObject.Add("publicDnsName",$publicDnsName.ToLower())
$templateParameterObject.Add("autoDownloadASDK", $autoDownloadASDK)
$templateParameterObject.Add("virtualMachineSize", $virtualMachineSize)

# create resource group
New-AzureRmResourceGroup -Name $resourceGroupName -Location $location

# deploy ARM template from github using locally provided ARM template parameters
New-AzureRmResourceGroupDeployment -Name "$resourceGroupName-PoC-Deployment" -ResourceGroupName $resourceGroupName `
    -TemplateUri "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/$gitBranch/azuredeploy.json" `
    -TemplateParameterObject $templateParameterObject `
    -Mode Incremental `
    -AsJob


Pause
# delete resource group and all object in the RG
Get-AzureRmResourceGroup -Name $resourceGroupName | Remove-AzureRmResourceGroup -AsJob #-Force
```



Once deployed run/check desktop shorcut options. You can select AAD or ADFS installations.

```powershell
$tenantID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$subscriptionID = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"

Connect-AzureRmAccount -TenantId $tenantID -Subscription $subscriptionID

# create administrator password secure string object
$SecureAdminPassword = Read-Host -AsSecureString -Prompt "Provide local Administrator password for Azure Stack host VM" | ConvertTo-SecureString -AsPlainText -Force
#$SecureAdminPassword = "SuperSecurePassword123!!" | ConvertTo-SecureString -AsPlainText -Force

# declare variables 
[int]$instanceNumber = 1 # resource group name will be generated based on this number. 
[bool]$autoDownloadASDK = $true #either download latest ADSK in the VM or not. Setting this to $true will add additional ~35 mins to ARM template deployment time.
[string]$resourceGroupNamePrefix = "yagmursasdk" #Resource group name will be generated based on this prefix. Ex. yagmursasdk-1
[string]$publicDnsNamePrefix = "yagmursasdkinstance" # This will will be concatenated with $instancenumber. Ex. yagmursasdkinstance1.eastus2.cloudapp.azure.com
[string]$location = 'East US2' # can be any region that supports E and D VM sizes that supports nested virtualization.
[string]$virtualMachineSize = "Standard_E32s_v3" # 1811 and upper versions require 256GB RAM
[ValidateSet("development", "master")][string]$gitBranch = "development" # github branch 
[string]$resourceGroupName = "$resourceGroupNamePrefix-$instanceNumber"
[string]$publicDnsName = "$publicDnsNamePrefix$instanceNumber"

# create ARM template parameter object
$templateParameterObject = @{}
$templateParameterObject.Add("adminPassword", $SecureAdminPassword)
$templateParameterObject.Add("publicDnsName",$publicDnsName.ToLower())
$templateParameterObject.Add("autoDownloadASDK", $autoDownloadASDK)
$templateParameterObject.Add("virtualMachineSize", $virtualMachineSize)

# create resource group
New-AzureRmResourceGroup -Name $resourceGroupName -Location $location

# deploy ARM template from github using locally provided ARM template parameters
New-AzureRmResourceGroupDeployment -Name "$resourceGroupName-PoC-Deployment" -ResourceGroupName $resourceGroupName `
    -TemplateUri "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/$gitBranch/azuredeploy.json" `
    -TemplateParameterObject $templateParameterObject `
    -Mode Incremental `
    -AsJob


Pause
# delete resource group and all object in the RG
Get-AzureRmResourceGroup -Name $resourceGroupName | Remove-AzureRmResourceGroup -AsJob #-Force
```
