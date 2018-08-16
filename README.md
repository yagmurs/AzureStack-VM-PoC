Creates a new VM and installs prerequisites to install AzureStack Development kit (ASDK) to run PoC

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fyagmurs%2FAzureStack-VM-PoC%2Fdevelopment%2Fazuredeploy.json" target="_blank">
    <img src="https://azuredeploy.net/deploybutton.png"/>
</a>

<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fyagmurs%2FAzureStack-VM-PoC%2Fdevelopment%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/shenglol/arm-visualizer/master/src/visualizebutton.png"/>
</a>

This template creates a new Azure VM, and installs, configures all prerequisites that is required to install Azure Stack Development Kit to ease the process to evaluate all Azure Stack functionalities. 

 --High level steps to follow--
  - Deploy the template
  - Logon to Azure VM
  - Run Install-ASDK.ps1 script on the desktop
  - Follow on-screen instructions
  - Setup will download selected version of ASDK and extract files automatically
  - ASDK setup will be feeded with required default parameters and parameters collected above

*** updates on 06.01.2018
 - New options to select ASDK version to install
 - Tested with ASDK 1712
 - Lots of fixes to better detect ASDK files and paths

*** updates on 06.06.2018
 - Tested with ASDK 1805
 - Auto shutdown option set to disabled by default (enable this one manually during the deployment if you have limited subscription)
 - 
*** updates on 17.08.2018
 - Tested with ASDK 1807
 

For more details, please read the following article for details
https://blogs.technet.microsoft.com/yagmurs/deploying-azure-stack-development-kit-asdk-straight-on-azure-vm

Feel free to post questions and enjoy!