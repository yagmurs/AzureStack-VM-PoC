$tenantID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$subscriptionID = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"

Connect-AzureRmAccount -TenantId $tenantID -Subscription $subscriptionID

$SecureAdminPassword = Read-Host -AsSecureString -Prompt "Provide local Administrator password for Azure Stack host VM" | ConvertTo-SecureString -AsPlainText -Force
#$SecureAdminPassword = "SuperSecurePassword123!!" | ConvertTo-SecureString -AsPlainText -Force

[int]$instanceNumber = 1
[bool]$autoDownloadASDK = $false
[string]$resourceGroupNamePrefix = "yagmursasdk"
[string]$publicDnsNamePrefix = "yagmursasdkinstance"
[string]$location = 'East US2'
[ValidateSet("development", "master")][string]$gitBranch = "development"



[string]$resourceGroupName = "$resourceGroupNamePrefix-$instanceNumber"
[string]$publicDnsName = "$publicDnsNamePrefix$instanceNumber"
$templateParameterObject = @{}
$templateParameterObject.Add("adminPassword", $SecureAdminPassword)
$templateParameterObject.Add("publicDnsName",$publicDnsName.ToLower())
$templateParameterObject.Add("autoDownloadASDK", $autoDownloadASDK)

# create resource group
New-AzureRmResourceGroup -Name $resourceGroupName -Location $location

# deploy ARM template from github using locally provided ARM template parameters
New-AzureRmResourceGroupDeployment -Name "$resourceGroupName-PoC-Deployment" -ResourceGroupName $resourceGroupName `
    -TemplateUri "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/$gitBranch/azuredeploy.json" `
    -TemplateParameterObject $templateParameterObject `
    -Mode Incremental `
    -AsJob


Pause
#clean up 
Get-AzureRmResourceGroup -Name $resourceGroupName | Remove-AzureRmResourceGroup -AsJob #-Force
