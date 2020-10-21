Connect-AzAccount -Subscription "Internal Consumption"

$adminPassword = Get-Credential -Credential "Local Admin Password"
$publicDnsName = Read-Host -Prompt "Public DNS prefix"
$region = 'East US 2'
$rg = 'rg-yagmurs-azsh2'
$saName = "asdk" + (Get-Random)
New-AzResourceGroup -Name $rg -Location $region
$sa = New-AzStorageAccount -Location $region -ResourceGroupName $rg -SkuName Standard_LRS -Name $saName

$sourceUri = "https://azshdkeus2.blob.core.windows.net/vhd/cloudbuilder.vhd"
New-AzStorageContainer -Name vhd -Context $sa.context
Start-AzStorageBlobCopy -AbsoluteUri $sourceUri -DestContainer "vhd" -DestContext $sa.context -DestBlob "cloudbuilder.vhd" -ConcurrentTaskCount 100
do {
    Start-Sleep -Seconds 60
    $result = Get-AzStorageAccount -Name $sa.StorageAccountName -ResourceGroupName $rg | Get-AzStorageBlob -Container "vhd" | Get-AzStorageBlobCopyState
    $remaining = [Math]::Round(($result.TotalBytes - $result.BytesCopied) / 1gb,2)
    Write-Verbose -Message "Waiting copy to finish remaining $remaining GB" -Verbose 
} until ($result.Status -eq "success") 


$templateParameterObject = @{
    adminPassword = $adminPassword
    publicDnsName = $publicDnsName
    dataDiskCount = 6
    osDiskVhdUri = $sa.PrimaryEndpoints.Blob + "vhd/cloudbuilder.vhd"
}
New-AzResourceGroupDeployment -ResourceGroupName $rg -Name AzureStackonAzureVM -TemplateUri "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/development/ARMv2/azuredeploy.json" -TemplateParameterObject $templateParameterObject

#region 1
#region 2
dasdoksadsd
sad
sadasd
asd
#endregion 2
asd
asd
as

#endregion 1
