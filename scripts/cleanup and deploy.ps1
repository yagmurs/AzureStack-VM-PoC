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