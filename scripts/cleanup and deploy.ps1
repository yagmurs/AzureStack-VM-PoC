$resourceGroupName = "azs3"
if (-not (Get-AzureRmSubscription))
{
    Login-AzureRmAccount
}
Get-AzureRmVM -ResourceGroupName $resourceGroupName | Remove-AzureRmVM -Force
Get-AzureRmNetworkInterface -ResourceGroupName $resourceGroupName | Remove-AzureRmNetworkInterface -Force
Get-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroupName | Remove-AzureRmNetworkSecurityGroup -Force
Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroupName | Remove-AzureRmPublicIpAddress -Force
$disks = Get-AzureRmDisk
if ($resourceGroupName -like "*test*")
{
    $disks | Remove-AzureRmDisk -Force
}
else
{
    $disks | ? name -like *_OSDisk_* | Remove-AzureRmDisk -Force
    $disks | ? name -like *-disk* | Remove-AzureRmDisk -Force
}
Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroupName | Remove-AzureRmVirtualNetwork -Force

Remove-AzureRmResourceGroup -ResourceGroupName $resourceGroupName -Force

Test-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName `
  -TemplateUri https://raw.githubusercontent.com/yagmurs/yagmurs_AzureVMExtension/master/azuredeploy.json `
  -TemplateParameterUri https://raw.githubusercontent.com/yagmurs/yagmurs_AzureVMExtension/master/azuredeploy.parameters.jsonRemove-AzureRmResourceGroup -Force

New-AzureRmResourceGroup -Name $resourceGroupName -Location 'west europe'
New-AzureRmResourceGroupDeployment -Name "$resourceGroupName-PoC-Deployment" -ResourceGroupName $resourceGroupName `
  -TemplateUri https://raw.githubusercontent.com/yagmurs/yagmurs_AzureVMExtension/master/azuredeploy.json `
  -TemplateParameterUri https://raw.githubusercontent.com/yagmurs/yagmurs_AzureVMExtension/master/azuredeploy.parameters.json `
  -Mode Incremental

New-AzureRmResourceGroupDeployment -Name "$resourceGroupName-PoC-Deployment" -ResourceGroupName $resourceGroupName `
  -TemplateUri https://raw.githubusercontent.com/yagmurs/yagmurs_AzureVMExtension/master/azuredeploy.json `
  -Mode Incremental


$swName = "NATSwitch"
New-VMSwitch -Name $swName -SwitchType Internal -Verbose
$NIC=Get-NetAdapter "vEthernet `($swName`)"
New-NetIPAddress -IPAddress 172.16.0.1 -PrefixLength 24 -InterfaceIndex $NIC.ifIndex
New-NetNat -Name $swName -InternalIPInterfaceAddressPrefix "172.16.0.0/24" –Verbose
Get-VM -Name AzS-BGPNAT01 | Get-VMNetworkAdapter -Name NAT | Connect-VMNetworkAdapter -SwitchName $swName
