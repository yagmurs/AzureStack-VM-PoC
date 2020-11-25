# Azure Stack on Azure VM
Creates a new VM and installs prerequisites to install AzureStack Development kit (ASDK) to run PoC

### Description
This template creates a new Azure VM, and installs, configures all prerequisites that is required to install Azure Stack Development Kit to simplify evaluating all Azure Stack functionalities.

### Deploy ARM template

[![Deploy to Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fyagmurs%2FAzureStack-VM-PoC%2Fdevelopment%2Fazuredeploy.json)

[![Deploy to Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fyagmurs%2FAzureStack-VM-PoC%2Fdevelopment%2Fscripts%2Ftest.json)

[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.png)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fyagmurs%2FAzureStack-VM-PoC%2Fdevelopment%2Fazuredeploy.json)

or use http://aka.ms/AzureStackonAzureVM

or **Deploy to Azure** (**deploy.azure.com**)

[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://azuredeploy.net/)

### High level steps to follow
  - Deploy the template ( check examples on cleanup and deploy.ps1)
  - Logon to Azure VM (default username is administrator)
  - Run Install-ASDK on the desktop (additional automated setup options are available on EXAMPLES.md including ARM template deployment examples) 
  - Follow on-screen instructions
  - Setup will download selected version of ASDK and extract files automatically
  - ASDK setup will be feeded with required default parameters and parameters collected above

### Updates / Change log

**updates on 06.01.2018**
 - New options to select ASDK version to install
 - Tested with ASDK 1712
 - Lots of fixes to better detect ASDK files and paths

**updates on 06.06.2018**
 - Tested with ASDK 1805
 - Auto shutdown option set to disabled by default (enable this one manually during the deployment if you have limited subscription)

**updates on 17.08.2018**
 - Tested with ASDK 1807

**updates on 02.09.2018**
 - Tested with ASDK 1808
 - findLatestASDK function updated to detect additional ASDK releases to download. ex. 1807 re-released twice 1807-1 and 1807-2
 - non-onmicrosoft.com domains and account with MFA support (pop-up Microsoft account logon UI after download and extract)
 - Removal of redundant local admin password prompt.
 - Support for ADFS as Identity Provider in addition to Azure Cloud (AAD). Additional desktop shortcuts added for each IDP.
 - New ARM template option to download latest ASDK and extract with the VM deployement, disabled by default. 😊 Which makes the deployment time a bit longer (30-40 mins.)

**updates on 19.12.2018**
- Tested with ASDK 1.1811.0.101
- New parameters to differantiate AzureImage and ADSKImage
- Companion service moved into Install-ASDK
- Desktop shortcuts creation upon successful installation
- New scheduled task to create desktop shortcuts
- BGPNAT functionality detection based on versions
- Install all roles available in ASDKImage to AzureImage using roles.xml
- Version number extraction from cloudbuilder.vhdx
- Updated cleanup and deploy.ps1 content with examples to automate ARM 
- **New EXAMPLES.md file with several automated ASDK installation examples and automated ARM template deployment**
- Register-AzureStackLab.ps1 updated with new options to register Azure Stack.
- PowerShell remoting enabled on NSG (TCP 5985)
- PowerShell remoting enabled on Windows firewall public profile (TCP 5985)
- Auto shutdown API version and parameters updated
- New ARM template parameters sitelocation and branch added to being compatible with deploy.azure.com
- Additional Deploy to Azure button added for deploy.azure.com
- InfraAzureDirectoryTenantAdminCredential paramater added to Install-ASDK.ps1 to be able to accommodate automated ASDK setup

**updates on 10.01.2019**
- IE Allow file download option enabled for Local Machine registry (postconfig.ps1)
- IE ESC disabled on all image types (postconfig.ps1)
- Scheduler for Desktop shortcuts updated (Install-ASDK.ps1)
- Tested for ASDK 1.1811.0.101 with original ASDK VHD for LOD environment
- Timeserver is now use FQDN instead of IP address for upcoming versions
- Required roles installed by default for ASDKImage to prevent restart requirement during the installation
- Removal of file roles.xml from repository

**updates on 13.01.2019**
- ARM template parameter values updated with supported numbers and sizes

**updates on 09.02.2019**
- Tested with ASDK 1.1901.0.95

**updates on 03.06.2019**
- Tested with ASDK 1.1904.0.36
- Added option for installing RDSH on ASDK host as ARM template parameter. Thanks Matt McSpirit for the contribution.
- ARM template updated with few parameters to be able to run Automated ASDK setup from ARM template.
- Automated installation only supports Azure AD Identity
- post-config.ps1 and Install-ASDK.ps1 scripts updated accordingly to support Automated ASDK setup.
- old code cleanup and enhancements
- branch selection in the ARM template
- c:\tools\nuget.exe updated with latest version to be able to handle the issue regards to long path. (AzureImage)

**updates on 26.06.2019**
- Tested with ASDK 1.1905.0.40

**updates on 29.06.2019**
- Tested with ASDK 1.1906.0.30
- Experimental integration with ASDK Configurator (Matt McSpirit's ConfigASDK script). Now you can pass ConfigASDK parameter values from ARM Template to fully automate ASDK installation and install resource providers on top of ASDK installation. (must be used with "Auto Install ASDK")
- ASDK Configurator Object parameter added to accept input for ASDK Configurator. Example values assigned to the parameter values. Any ConfigASDK parameters may be used.

**updates on 26.07.2019**
- Tested with ASDK 1.1907.0.20
  
Feel free to post questions and enjoy!
