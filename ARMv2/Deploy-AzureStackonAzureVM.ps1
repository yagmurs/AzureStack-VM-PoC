<#PSScriptInfo

.VERSION 0.1.1.7

.GUID 523642c3-73da-49a0-8ae8-08b835c426e2

.AUTHOR Microsoft Corporation

.COMPANYNAME Microsoft

.EXTERNALMODULEDEPENDENCIES

.TAGS Azure Stack Hub, ASDK, AzureStack, AzureStackHub, "Azure Stack", "Azure Stack Hub"

.RELEASENOTES
   Author:         Yagmur Sahin
   Twitter:        @yagmurs
   Creation Date:  24 November 2020
   Purpose/Change: Updated examples and minor changes
#>

<#
.Synopsis
   Deploys Azure VM for Azure Stack Hub Development kit
.DESCRIPTION
   Deploys Azure VM for Azure Stack Hub Development kit

.EXAMPLE
Deploy-AzureStackonAzureVM

Deploy new Storage copy VM image and then deploys Azure Stack Hub Development kit VM to 
Resource Group: AzureStackVMOnAzureVM on East US 2 region, New VM Credentials will be prompted.

.EXAMPLE
Deploy-AzureStackonAzureVM -ResourceGroupName myResourceGroup -Region = 'West Europe'

Deploy new Storage Account (SA), copy VM image to new SA and then deploy Azure Stack 
Hub Development kit VM under Resource Group: myResourceGroup on West Europe region, New VM
Credentials will be prompted.

.EXAMPLE
Deploy-AzureStackonAzureVM -UseExistingStorageAccount

This option deploys Azure Stack Hub Development kit from predefined Uri, this can be used
if there a storage account and the VHD file already copied or created beforehand, New VM 
Credentials will be prompted. The Uri of ASDK image (VHD file) on the Storage Account must 
belong to the same subscription that the VM is getting deployed.

.EXAMPLE
$VmCredential = Get-Credentail = "Administrator"
Deploy-AzureStackonAzureVM -ResourceGroupName myResourceGroup -VmCredential $VmCredential

Deploy new Storage copy VM image and then deploys Azure Stack Hub Development kit VM to
Resource Group: AzureStackVMOnAzureVM Credential specified beforehand. May be used for silent 
deployment.

.EXAMPLE
$VmCredential = Get-Credential -Credential "Administrator"
$AzureADTenant = "<TenantName>.onmicrosoft.com"
$AzureADGlobalAdminCredential = Get-Credential "<Admin>@<TenantName>.onmicrosoft.com" #Make sure this account is Global Admin on the tenant

Deploy-AzureStackonAzureVM.ps1 -AutoInstallASDK -AzureADTenant <TenantName>.onmicrosoft.com -AzureADGlobalAdminCredential <admin>@<TenantName>.onmicrosoft.com -Verbose

Deploys with default options and start Azure Stack Hub Develoepment kit installation within
the VM after VM starts. Currently there is no validation for credentials and Tenant existance
Make sure tenant name and credentials are correct.
#>
[CmdletBinding(ConfirmImpact='High')]

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
        [string]$Version = "2008",
        
        [Parameter(Mandatory=$true)]
        [pscredential]$VmCredential, #Local Administrator Credential for the VM
        
        [Parameter(Mandatory=$false)]
        [string]$PublicDnsName = "asdkonazure" + "$(get-random)",

        [Parameter(Mandatory=$false)]
        [string]$VhdUri, #this must a Azure Storage Account Uri and must be under the same subscription that the VM is getting deployed.

        [Parameter(Mandatory=$false)]
        [int]$DataDiskCount = 6,

        [Parameter(Mandatory=$false)]
        [switch]$AutoInstallASDK,

        [Parameter(Mandatory=$false)]
        [string]$AzureADTenant,

        [Parameter(Mandatory=$false)]
        [pscredential]$AzureADGlobalAdminCredential
    )

#Requires -Version 5
#Requires -Module @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.2.1' }, @{ ModuleName = 'Az.Storage'; ModuleVersion = '3.0.0' }, @{ ModuleName = 'Az.Resources'; ModuleVersion = '3.0.1' }

#region variables

$sleepTimer = 60
$container = "asdk"
$saPrefix = "asdk"

#endregion

#Testing if running on Cloudshell
if (-not ($PSCloudShellUtilityModuleInfo))
{
   Write-Verbose -Message "Logging into Azure using Device Authentication option"
   Connect-AzAccount -UseDeviceAuthentication
}
else
{
   Write-Verbose -Message "CloudShell detected, no need to login, using current credentials"
}

if ($Overwrite)
{
   Write-Verbose -Message "Since Overwrite option is specified the current Resource Group and all resources belongs to RG will be deleted."
   Get-AzResourceGroup -Name $ResourceGroupName | Remove-AzResourceGroup -Force -Verbose -Confirm
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
            Write-Verbose -Message "Blob file: $($uriSplit[-1]) exist under container: $($uriSplit[-2])"
            $osDiskVhdUri = $VhdUri
         }
         else 
         {
            Write-Error -Message "Blob file: $uriSplit[-1] does not exist under container: $uriSplit[-2]" -ErrorAction Stop
         }   
      }
      else
      {
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
   #Create new Resource Group
   New-AzResourceGroup -Name $ResourceGroupName -Location $Region
   $i = 0
   do 
   {
      #Randomizing new name for SA and testing for availiability, up to 10 retries.
      $saName = $saPrefix + (Get-Random)
      Write-Verbose -Message "Testing Storage Account name availability: $saName"
      if ($i -gt 10)
      {
         Write-Error "Randomization of Storage Account name failed after 10 retries, you may re-run the script to overcome the issue" -ErrorAction Stop
      }
   } until ((Get-AzStorageAccountNameAvailability -Name $saName).NameAvailable)
   
   Write-Verbose -Message "Creating Storage Account: $saName"
   $sa = New-AzStorageAccount -Location $Region -ResourceGroupName $ResourceGroupName -SkuName Standard_LRS -Name $saName
   $sourceUri = "https://asdkstore.blob.core.windows.net/asdk/$version.vhd"
   
   New-AzStorageContainer -Name $container -Context $sa.context
   
   Start-AzStorageBlobCopy -AbsoluteUri $sourceUri -DestContainer $container -DestContext $sa.context -DestBlob "$version.vhd" -ConcurrentTaskCount 100 -Force
   
   do {
      Start-Sleep -Seconds $sleepTimer
      $result = Get-AzStorageAccount -Name $sa.StorageAccountName -ResourceGroupName $ResourceGroupName | Get-AzStorageBlob -Container $container | Get-AzStorageBlobCopyState
      $remaining = [Math]::Round(($result.TotalBytes - $result.BytesCopied) / 1gb,2)
      Write-Verbose -Message "Waiting copy to finish remaining $remaining GB"
      if ($remaining -lt 60)
      {
         $sleepTimer = 10
      }
   } until ($result.Status -eq "success") 

   $osDiskVhdUri = $sa.PrimaryEndpoints.Blob + "$container/$version.vhd"
}

Write-Verbose -Message $osDiskVhdUri
if ($AutoInstallASDK)
{
   if ($AzureADGlobalAdminCredential -and $AzureADTenant)
   {
      $templateParameterObject = @{
         adminPassword = $VmCredential.Password
         publicDnsName = $publicDnsName
         dataDiskCount = $DataDiskCount
         osDiskVhdUri = $osDiskVhdUri
         autoInstallASDK = $true
         AzureADTenant = $AzureADTenant
         AzureADGlobalAdmin = $AzureADGlobalAdminCredential.UserName
         AzureADGlobalAdminPassword = $AzureADGlobalAdminCredential.Password
      }
   }
   else
   {
      Write-Error -Message "Make sure Azure AD Global Administrator Credentails and Azure AD Tenant name is specified" -ErrorAction Stop
   }
}
else
{
   $templateParameterObject = @{
      adminPassword = $VmCredential.Password
      publicDnsName = $publicDnsName
      dataDiskCount = $DataDiskCount
      osDiskVhdUri = $osDiskVhdUri
      autoInstallASDK = $false
   }
}

New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name AzureStackonAzureVM `
   -TemplateUri "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/master/ARMv2/azuredeploy.json" `
   -TemplateParameterObject $templateParameterObject