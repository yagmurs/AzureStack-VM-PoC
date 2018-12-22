$defaultLocalPath = "C:\AzureStackOnAzureVM"

Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted

# Install the AzureRM.Bootstrapper module. Select Yes when prompted to install NuGet. 
Install-Module -Name AzureRm.BootStrapper

# Install and import the API Version Profile required by Azure Stack into the current PowerShell session.
Use-AzureRmProfile -Profile 2018-03-01-hybrid -Force

# Install Azure Stack Module Version 1.5.0.
Install-Module -Name AzureStack -RequiredVersion 1.5.0

# Change directory to the root directory.
cd \
cd $defaultLocalPath
# Enforce usage of TLSv1.2 to download the Azure Stack tools archive from GitHub
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
invoke-webrequest `
  https://github.com/Azure/AzureStack-Tools/archive/master.zip `
  -OutFile master.zip

# Expand the downloaded files.
expand-archive master.zip -DestinationPath . -Force

# Change to the tools directory.
cd AzureStack-Tools-master

# Add the Azure cloud subscription environment name. 
# Supported environment names are AzureCloud, AzureChinaCloud or AzureUSGovernment depending which Azure subscription you are using.
Add-AzureRmAccount -EnvironmentName "AzureCloud"

# Register the Azure Stack resource provider in your Azure subscription
Register-AzureRmResourceProvider -ProviderNamespace Microsoft.AzureStack

# Import the registration module that was downloaded with the GitHub tools
Import-Module $defaultLocalPath\AzureStack-Tools-master\Registration\RegisterWithAzure.psm1

# Register Azure Stack
$AzureContext = Get-AzureRmContext
$CloudAdminCred = Get-Credential -UserName AZURESTACK\CloudAdmin -Message "Enter the credentials to access the privileged endpoint."
$RegistrationName = "yagmurs-$(New-Guid)"
Set-AzsRegistration `
        -PrivilegedEndpointCredential $CloudAdminCred `
        -PrivilegedEndpoint AzS-ERCS01 `
        -BillingModel Development `
        -RegistrationName $RegistrationName `
        -UsageReportingEnabled:$true
