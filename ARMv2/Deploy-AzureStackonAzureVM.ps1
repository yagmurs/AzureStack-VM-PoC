<#PSScriptInfo

.VERSION 0.2.1.2

.GUID 523642c3-73da-49a0-8ae8-08b835c426e2

.AUTHOR Yagmur Sahin

.COMPANYNAME Microsoft

.COPYRIGHT 

.TAGS Azure Stack Hub, ASDK, AzureStack, AzureStackHub, "Azure Stack", "Azure Stack Hub"

.LICENSEURI 

.PROJECTURI https://github.com/yagmurs/AzureStack-VM-PoC

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
   Author:         Yagmur Sahin
   Twitter:        @yagmurs
   Creation Date:  18 February 2021
   Purpose/Change:
      Fixed some typos.
      Create new Resource Group if it does not already exist.
      
      Thanks @yellowpanda :)

#>

<#
.Synopsis
   Deploys Azure VM for Azure Stack Hub Development kit
.DESCRIPTION
   Deploys Azure VM for Azure Stack Hub Development kit

.EXAMPLE
Deploy-AzureStackonAzureVM

Deploy new Storage copy VM image and then deploys Azure Stack Hub Development kit VM to 
Resource Group: AzureStackVMOnAzureVM on East US 2 region use default VM Size 'Standard_E20s_v3'
New VM Credentials will be prompted.

.EXAMPLE
Deploy-AzureStackonAzureVM -ResourceGroupName myResourceGroup -Region 'West Europe'

Deploy new Storage Account (SA), copy VM image to new SA and then deploy Azure Stack 
Hub Development kit VM under Resource Group: myResourceGroup on West Europe region, New VM
Credentials will be prompted.

.EXAMPLE
Deploy-AzureStackonAzureVM -ResourceGroupName myResourceGroup -Region 'West Europe' -VirtualMachineSize 'Standard_E32s_v3'

Deploy new Storage Account (SA), copy VM image to new SA and then deploy Azure Stack 
Hub Development kit VM using 'Standard_E32s_v3' VM size under Resource Group: myResourceGroup on West Europe region, 
New VM Credentials will be prompted.

.EXAMPLE
Deploy-AzureStackonAzureVM -UseExistingStorageAccount

This option deploys Azure Stack Hub Development kit from predefined Uri, this can be used
if there a storage account and the VHD file already copied or created beforehand, New VM 
Credentials will be prompted. The Uri of ASDK image (VHD file) on the Storage Account must 
belong to the same subscription that the VM is getting deployed.

.EXAMPLE
$VmCredential = Get-Credential "Administrator"
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
[CmdletBinding(
   ConfirmImpact='High',
   DefaultParameterSetName='VM Only'
)]

param
(
   [Parameter(Mandatory=$false, ParameterSetName='Use Existing SA')]
   [Parameter(Mandatory=$false, ParameterSetName='VM Only')]
   [Parameter(Mandatory=$false, ParameterSetName='Auto Install')]
   [switch]$UseExistingStorageAccount,
   
   [Parameter(Mandatory=$false, ParameterSetName='Use Existing SA')]
   [Parameter(Mandatory=$false, ParameterSetName='VM Only')]
   [Parameter(Mandatory=$false, ParameterSetName='Auto Install')]
   [switch]$Overwrite,

   [Parameter(Mandatory=$false, ParameterSetName='Use Existing SA')]
   [Parameter(Mandatory=$false, ParameterSetName='VM Only')]
   [Parameter(Mandatory=$false, ParameterSetName='Auto Install')]
   [string]$Region = 'East US 2',
   
   [Parameter(Mandatory=$false, ParameterSetName='Use Existing SA')]
   [Parameter(Mandatory=$false, ParameterSetName='VM Only')]
   [Parameter(Mandatory=$false, ParameterSetName='Auto Install')]
   [string]$ResourceGroupName = 'AzureStackVMOnAzureVM',
   
   [Parameter(Mandatory=$false, ParameterSetName='Use Existing SA')]
   [Parameter(Mandatory=$false, ParameterSetName='VM Only')]
   [Parameter(Mandatory=$false, ParameterSetName='Auto Install')]
   [string]$Version = "2008",
   
   [Parameter(Mandatory=$false, ParameterSetName='Use Existing SA')]
   [Parameter(Mandatory=$false, ParameterSetName='VM Only')]
   [Parameter(Mandatory=$false, ParameterSetName='Auto Install')]
   [ValidateSet(
      "Standard_E16s_v3",
      "Standard_E20s_v3",
      "Standard_E32s_v3",
      "Standard_E48s_v3",
      "Standard_E64s_v3",
      "Standard_D32s_v3",
      "Standard_D48s_v3",
      "Standard_D64s_v3"
      )]
   [string]$VirtualMachineSize = "Standard_E20s_v3",

   [Parameter(Mandatory=$true, ParameterSetName='Use Existing SA')]
   [Parameter(Mandatory=$true, ParameterSetName='VM Only')]
   [Parameter(Mandatory=$true, ParameterSetName='Auto Install')]
   [pscredential]$VmCredential, #Local Administrator Credential for the VM
   
   [Parameter(Mandatory=$false, ParameterSetName='Use Existing SA')]
   [Parameter(Mandatory=$false, ParameterSetName='VM Only')]
   [Parameter(Mandatory=$false, ParameterSetName='Auto Install')]
   [string]$PublicDnsName = "asdkonazure" + "$(get-random)",

   [Parameter(Mandatory=$true, ParameterSetName='Use Existing SA')]
   [Parameter(Mandatory=$false, ParameterSetName='VM Only')]
   [Parameter(Mandatory=$false, ParameterSetName='Auto Install')]
   [string]$VhdUri, #this must a Azure Storage Account Uri and must be under the same subscription that the VM is getting deployed.

   [Parameter(Mandatory=$false, ParameterSetName='Use Existing SA')]
   [Parameter(Mandatory=$false, ParameterSetName='VM Only')]
   [Parameter(Mandatory=$false, ParameterSetName='Auto Install')]
   [int]$DataDiskCount = 6,

   [Parameter(Mandatory=$false, ParameterSetName='Use Existing SA')]
   [Parameter(Mandatory=$false, ParameterSetName='VM Only')]
   [Parameter(Mandatory=$true, ParameterSetName='Auto Install')]
   [switch]$AutoInstallASDK,

   [Parameter(Mandatory=$false, ParameterSetName='Use Existing SA')]
   [Parameter(Mandatory=$false, ParameterSetName='VM Only')]
   [Parameter(Mandatory=$true, ParameterSetName='Auto Install')]
   [string]$AzureADTenant,

   [Parameter(Mandatory=$false, ParameterSetName='Use Existing SA')]
   [Parameter(Mandatory=$false, ParameterSetName='VM Only')]
   [Parameter(Mandatory=$true, ParameterSetName='Auto Install')]
   [pscredential]$AzureADGlobalAdminCredential,

   [Parameter(Mandatory=$false, ParameterSetName='Use Existing SA')]
   [Parameter(Mandatory=$false, ParameterSetName='VM Only')]
   [Parameter(Mandatory=$false, ParameterSetName='Auto Install')]
   [Bool]$UseAzCopy = $true #setting the value to 'false' will utilize Start-AzStorageBlobCopy

)

#region Functions

function DownloadWithRetry([string] $Uri, [string] $DownloadLocation, [int] $Retries = 5, [int]$RetryInterval = 10)
{
    while($true)
    {
        try
        {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
            Start-BitsTransfer -Source $Uri -Destination $DownloadLocation -DisplayName $Uri
            break
        }
        catch
        {
            $exceptionMessage = $_.Exception.Message
            Write-Host "Failed to download '$Uri': $exceptionMessage"
            if ($retries -gt 0) {
                $retries--
                Write-Host "Waiting $RetryInterval seconds before retrying. Retries left: $Retries"
                Clear-DnsClientCache
                Start-Sleep -Seconds $RetryInterval
 
            }
            else
            {
                $exception = $_.Exception
                throw $exception
            }
        }
    }
}

#endregion
    
#Requires -Version 5
#Requires -Module @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.2.1' }, @{ ModuleName = 'Az.Storage'; ModuleVersion = '3.0.0' }, @{ ModuleName = 'Az.Resources'; ModuleVersion = '3.0.1' }

#region variables

$templateUri = "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/master/ARMv2/azuredeploy.json"
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
   #Create new Resource Group if it does not already exist
   if (!(Get-AzResourceGroup -Name $ResourceGroupName -Location $Region -ErrorAction SilentlyContinue))
   {
	   Write-Verbose -Message "Create Resource Group"
	   New-AzResourceGroup -Name $ResourceGroupName -Location $Region
   }
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
   
   if ($UseAzCopy)
   {
      if (-not ($PSCloudShellUtilityModuleInfo))
      {
         Write-Verbose -Message "Script is not running on CloudShell"
         if ($PSVersionTable.PSEdition -eq "Desktop" -or ($PSVersionTable.PSEdition -eq "core" -and $PSVersionTable.platform -like "win*"))
         {
            Write-Verbose -Message "Windows OS detected."
            $azCopyTemp = [System.IO.Path]::GetTempPath()
            Write-Verbose -Message "Downloading the latest version of AzCopy to $azCopyTemp"
            $azcopyDestFilePath = Join-Path -Path $azCopyTemp -ChildPath "azcopy.zip"
            $azcopyDestFolderPath = Join-Path -Path $azCopyTemp -ChildPath "azcopy"
            DownloadWithRetry -Uri https://aka.ms/downloadazcopy-v10-windows -DownloadLocation $azcopyDestFilePath
            Write-Verbose -Message "Unblocking AzCopy bits $azcopyDestFolderPath"
            Unblock-File -Path $azcopyDestFilePath
            Write-Verbose -Message "Extracting AzCopy bits $azcopyDestFolderPath"
            Expand-Archive -Path $azcopyDestFilePath -DestinationPath $azcopyDestFolderPath -Force
            $azCopyExePath = Get-ChildItem -Path $azcopyDestFolderPath -Recurse | Where-Object Name -eq azcopy.exe | Select-Object -ExpandProperty FullName
         }
         else
         {
            Write-Warning -Message "Non-Windows environment detected. We'll try to call AzCopy if it is in the path. It may fail to call AzCopy. If fails run the script from CloudShell or Windows machine"
            $azCopyExePath = "azcopy"
         }
      }
      else 
      {
         $azCopyExePath = "azcopy"
      }

      Write-Verbose "`$azCopyExePath is now $azCopyExePath"
      $sastoken = New-AzStorageContainerSASToken -Context $sa.Context -name $container -Permission racwdl
      $destination = $sa.Context.BlobEndPoint+$container+$sastoken
      
      & $azCopyExePath cp $sourceUri $destination   
      if($LASTEXITCODE -ne 0){
         throw "Something went wrong, check AzCopy output or error logs."
         return
      }      
   }
   else
   {
      Write-Verbose -Message "Starting copy Using Start-AzStorageBlobCopy"
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
   }
   
   $osDiskVhdUri = $sa.PrimaryEndpoints.Blob + "$container/$version.vhd"
}

Write-Verbose -Message "Copy completed, new VHD Uri: $osDiskVhdUri"

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
         VirtualMachineSize = $VirtualMachineSize
      }
   }
   else
   {
      Write-Error -Message "Make sure Azure AD Global Administrator Credentials and Azure AD Tenant name is specified" -ErrorAction Stop
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
      VirtualMachineSize = $VirtualMachineSize
   }
}

Write-Verbose -Message "Starting VM deployment by calling ARM template with parameters provided"
New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
   -Name AzureStackonAzureVM `
   -TemplateUri $templateUri `
   -TemplateParameterObject $templateParameterObject
