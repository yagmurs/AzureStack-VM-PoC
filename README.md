# Azure Stack on Azure VM
Creates a new VM and installs prerequisites to install AzureStack Development kit (ASDK) to run PoC

### Description
This template creates a new Azure VM, and installs, configures all prerequisites that is required to install Azure Stack Development Kit to simplify evaluating all Azure Stack functionalities. 

### Deploy ARM template 

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fyagmurs%2FAzureStack-VM-PoC%2Fdevelopment%2Fazuredeploy.json" target="_blank">
    <img src="https://azuredeploy.net/deploybutton.png"/>
</a>

<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fyagmurs%2FAzureStack-VM-PoC%2Fdevelopment%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/shenglol/arm-visualizer/master/src/visualizebutton.png"/>
</a>

or use http://aka.ms/DeployAzureStackonAzureVM

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
- New switches to differantiate AzureImage and ADSKImage
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

Feel free to post questions and enjoy!