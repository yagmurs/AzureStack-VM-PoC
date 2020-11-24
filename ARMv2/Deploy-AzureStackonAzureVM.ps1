<#
.Synopsis
   Deploys Azure VM for Azure Stack Hub Development kit
.DESCRIPTION
   Deploys Azure VM for Azure Stack Hub Development kit
.EXAMPLE
   Deploy new Storage copy VM image and then deploys Azure Stack Hub Development kit VM to Resource Group: AzureStackVMOnAzureVM on East US 2 region, Credential will be popped up!
Deploy-AzureStackonAzureVM
.EXAMPLE
   Deploy new Storage copy VM image and then deploys Azure Stack Hub Development kit VM to Resource Group: myResourceGroup on West Europe region, Credential will be popped up!
Deploy-AzureStackonAzureVM -ResourceGroupName myResourceGroup -Region = 'West Europe'
.EXAMPLE
   This option deploys Azure Stack Hub Development kit from predefined Uri, this can be used if previously, Credential will be popped up!
   ASDK image previously copied or created manually on Storage Account the storage account that this Uri belongs to has to be on the same subscription. 
Deploy-AzureStackonAzureVM -UseExistingStorageAccount
.EXAMPLE
   Deploy new Storage copy VM image and then deploys Azure Stack Hub Development kit VM to Resource Group: AzureStackVMOnAzureVM Credential specified beforehand. 
   May be used for silent deployment.
$VmCredential = Get-Credentail = "Administrator"
Deploy-AzureStackonAzureVM -ResourceGroupName myResourceGroup -Credential $VmCredential
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   Version:        0.1
   Author:         Yagmur Sahin
   Twitter:        @yagmurs
   Creation Date:  23 November 2020
   Purpose/Change: Initial script development
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>

#Requires -Version 5
#Requires -Module @{ ModuleName = 'Az'; ModuleVersion = '4.8.0' }
#Requires -Module @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.1.0' }
#Requires -Module @{ ModuleName = 'Az.Storage'; ModuleVersion = '2.7.0' }
#Requires -Module @{ ModuleName = 'Az.Resources'; ModuleVersion = '2.5.1' }

param(
        [Parameter(Mandatory=$false)]
        [switch]$UseExistingStorageAccount,
        
        [Parameter(Mandatory=$false)]
        [switch]$Overwrite,

        [Parameter(Mandatory=$false)]
        [string]$Region = 'East US 2',
        
        [Parameter(Mandatory=$false)]
        [string]$ResourceGroupName = 'AzureStackVMOnAzureVM',
        
        [Parameter(Mandatory=$false)]
        [string]$version = "2008",
        
        [Parameter(Mandatory=$true)]
        [pscredential]$VmCredential, #Local Admin Credential for the VM
        
        [Parameter(Mandatory=$false)]
        [string]$publicDnsName = "asdkonazure" + "$(get-random)",

        [Parameter(Mandatory=$false)]
        [string]$VhdUri, #this must a Azure Storage Account Uri and must be under the same subscription that the VM is getting deployed.

        [Parameter(Mandatory=$false)]
        [int]$DataDiskCount = 6
    )
if (-not ($PSCloudShellUtilityModuleInfo))
{
   Connect-AzAccount -UseDeviceAuthentication
}

if ($Overwrite)
{
   Get-AzResourceGroup -Name $ResourceGroupName | Remove-AzResourceGroup -Force -Verbose 
}

if ($UseExistingStorageAccount) 
{
   if ($VhdUri)
   {
      $saName = $VhdUri.Split(".")[0].Split("/")[-1]
      $sa = Get-AzStorageAccount | Where-Object StorageAccountName -EQ $saName
      if ($sa)
      {
         Write-Verbose -Message "Storage account: $VhdUri exist in the same subscription"
         $uriSplit = $VhdUri.Split("/")
         Get-AzStorageBlob -Blob $uriSplit[-1] -Container $uriSplit[-2] -Context $sa.context
         if ($?)
         {
            Write-Verbose -Message "Blob file: $uriSplit[-1] exist under container: $uriSplit[-2]"
            $osDiskVhdUri = $VhdUri
         }
         else 
         {
            Write-Error -Message "Blob file: $uriSplit[-1] does not exist under container: $uriSplit[-2]" -ErrorAction Stop
         }   
      }
      else
      {
         Get-AzStorageAccountNameAvailability
         Write-Error "Storage account: $VhdUri is not belongs to the subscription, please specify Storage Account from same subscription" -ErrorAction Stop    
      }
   }
   else 
   {
      Write-Error "No VHD Uri specified" -ErrorAction Stop
   }
}
else
{
   $saName = "asdk" + (Get-Random)
   New-AzResourceGroup -Name $ResourceGroupName -Location $Region
   $sa = New-AzStorageAccount -Location $Region -ResourceGroupName $ResourceGroupName -SkuName Standard_LRS -Name $saName

   $sourceUri = "https://asdkstore.blob.core.windows.net/asdk/$version.vhd"
   New-AzStorageContainer -Name "asdk" -Context $sa.context
   Start-AzStorageBlobCopy -AbsoluteUri $sourceUri -DestContainer "asdk" -DestContext $sa.context -DestBlob "$version.vhd" -ConcurrentTaskCount 100 -Force
   do {
      Start-Sleep -Seconds 60
      $result = Get-AzStorageAccount -Name $sa.StorageAccountName -ResourceGroupName $ResourceGroupName | Get-AzStorageBlob -Container "asdk" | Get-AzStorageBlobCopyState
      $remaining = [Math]::Round(($result.TotalBytes - $result.BytesCopied) / 1gb,2)
      Write-Verbose -Message "Waiting copy to finish remaining $remaining GB" -Verbose 
   } until ($result.Status -eq "success") 

   $osDiskVhdUri = $sa.PrimaryEndpoints.Blob + "asdk/$version.vhd"
}

Write-Verbose -Message $osDiskVhdUri

$templateParameterObject = @{
   adminPassword = $VmCredential.Password
   publicDnsName = $publicDnsName
   dataDiskCount = $DataDiskCount
   osDiskVhdUri = $osDiskVhdUri
}

New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name AzureStackonAzureVM -TemplateUri "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/development/ARMv2/azuredeploy.json" -TemplateParameterObject $templateParameterObject