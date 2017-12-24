#Requires -RunAsAdministrator

param (
           # Param1 help description
        [Parameter(Mandatory=$true)]
        [pscredential]
        $CloudAdminCredential = $(Get-Credential -Credential "AZURESTACK\Cloudadmin"),
        [Parameter(Mandatory=$true)]
        [string]
        $AzureDirectoryTenantName, # "<aadname>.onmicrosoft.com"
        [Parameter(Mandatory=$true)]
        [string]
        $AzureSubscriptionId, # "<Subscription ID>"
        $PrivilegedEndpoint = "AzS-ERCS01" 
)

$defaultLocalPath = "C:\AzureStackonAzureVM"

Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
Get-Module -ListAvailable | where-Object {$_.Name -like "Azure*"} | Uninstall-Module 

# Install the AzureRM.Bootstrapper module. Select Yes when prompted to install NuGet  
Install-Module -Name AzureRm.BootStrapper 

# Install and import the API Version Profile required by Azure Stack into the current PowerShell session. 

Use-AzureRmProfile -Profile 2017-03-09-profile -Force
Install-Module -Name AzureStack -RequiredVersion 1.2.11 

Get-Module -ListAvailable | where-Object {$_.Name -like "Azure*"} 

Login-AzureRmAccount -EnvironmentName "AzureCloud"
Register-AzureRmResourceProvider -ProviderNamespace Microsoft.AzureStack 

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Azure/AzureStack-Tools/master/Registration/RegisterWithAzure.psm1" -OutFile "$defaultLocalPath\RegisterWithAzure.psm1" 
Import-Module "$defaultLocalPath\RegisterWithAzure.psm1" 

Add-AzsRegistration -CloudAdminCredential $CloudAdminCredential -AzureDirectoryTenantName $AzureDirectoryTenantName  -AzureSubscriptionId $AzureSubscriptionId -PrivilegedEndpoint $PrivilegedEndpoint -BillingModel Development
