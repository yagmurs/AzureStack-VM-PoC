Creates a new VM to install AzureStack Development kit (ASDK) to run PoC


<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fyagmurs%2FAzureStack-VM-PoC%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="https://azuredeploy.net/deploybutton.png"/>
</a>

<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fyagmurs%2FAzureStack-VM-PoC%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/shenglol/arm-visualizer/master/src/visualizebutton.png"/>
</a>


This template creates a new VM to easily evaluate AzureStack PoC on an Azure VM, and installs most of the prerequisites such as Failover cluster, hyper-v and management modules.

You can follow these articles to deploy AzureStack on an Azure VM.
    
    https://azurestack.blog/2017/07/deploy-azure-stack-development-kit-on-an-azure-vm/ (uses 1 layer nested design)
    http://www.danielstechblog.info/running-azure-stack-development-kit-azure/ (uses 2 layer nested design)

There are also some notes I have created during the deployment please in NOTES.md

Tips

If running under PowerShell you may update the azuredeploy.parameters file.
Customize parameters in azuredeploy.parameters as you see appropriate, at the very least the adminPassword.

Feel free to post questions and enjoy!