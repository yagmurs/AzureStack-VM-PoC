param (
    [Security.SecureString]
    $LocalAdminPass,
    [string]
    $AADTenant,
    [string]
    $LocalAdminUsername = "Administrator",
    [switch]
    $ADFS,
    [switch]
    $AAD
)

#region Variables
$defaultLocalPath = "C:\AzureStackOnAzureVM"
$gitbranchconfig = Import-Csv -Path $defaultLocalPath\config.ind -Delimiter ","
$gitbranchcode = $gitbranchconfig.branch.Trim()
$gitbranch = "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/$gitbranchcode"

if (Test-Path "$defaultLocalPath\ASDKHelperModule.psm1")
{
    Import-Module "$defaultLocalPath\ASDKHelperModule.psm1"
}
else
{
    throw "required module $defaultLocalPath\ASDKHelperModule.psm1 not found"   
}

Add-Type -AssemblyName System.DirectoryServices.AccountManagement
$DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$env:ComputerName)
$localCredValidated = $false

if (!(LocalAdminPass))
{
    do {
    $localAdminPass = Read-Host -Prompt "Enter password for the user `'Administrator`'" -AsSecureString
    $localAdminPass1 = Read-Host -Prompt "Re-Enter password for the user `'Administrator`'" -AsSecureString
    $adminPass_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($localAdminPass))
    $adminpass1_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($localAdminPass1))
        if ($adminPass_text -cne $adminpass1_text)
        {
            Write-Verbose "Password does not match, re-enter password" -Verbose
        }
        else
        {
            if ($DS.ValidateCredentials($LocalAdminUsername, $adminPass_text) -eq $true)
            {
                $localCredValidated =  $true
                Write-Verbose "Password validated for user: $LocalAdminUsername" -Verbose
            }
            else
            {
                Write-Verbose "Password cannot be validated for user: $LocalAdminUsername" -Verbose
            }
        }

    } while ($localCredValidated -eq $false)
}
if (!($AADTenant))
{
    $AADTenant = Read-Host -Prompt "Enter AAD Tenant Directory Name"
}

$AtStartup = New-JobTrigger -AtStartup -RandomDelay 00:00:30
$options = New-ScheduledJobOption -RequireNetwork
$logFileFullPath = "$defaultLocalPath\Install-ASDK.log"
$writeLogParams = @{
    LogFilePath = $logFileFullPath
}


#endregion

#Download Azure Stack Development Kit Companion Service script
if (!(Test-Path "$defaultLocalPath\ASDKCompanionService.ps1"))
{
    DownloadWithRetry -Uri "$gitbranch/scripts/ASDKCompanionService.ps1" -DownloadLocation "$defaultLocalPath\ASDKCompanionService.ps1"
}

#Invoke-WebRequest -Uri "$gitbranch/scripts/ASDKCompanionService.ps1" -OutFile "$defaultLocalPath\ASDKCompanionService.ps1"
if (Get-ScheduledJob -name "ASDK Installer Companion Service" -ErrorAction SilentlyContinue)
{
    Get-ScheduledJob -name "ASDK Installer Companion Service" | Unregister-ScheduledJob -Force
}
$st = Register-ScheduledJob -Trigger $AtStartup -ScheduledJobOption $options -FilePath "$defaultLocalPath\ASDKCompanionService.ps1" -Name "ASDK Installer Companion Service" -Credential $localAdminCred
$st.StartJob()

#Create all user desktop shotcuts for Azure Stack Admin and Tenant portal
$Shell = New-Object -ComObject ("WScript.Shell")
$Favorite = $Shell.CreateShortcut($env:ALLUSERSPROFILE + "\Desktop\Azure Stack Admin Portal.url")
$Favorite.TargetPath = "https://adminportal.local.azurestack.external";
$Favorite.Save()
$Favorite = $Shell.CreateShortcut($env:ALLUSERSPROFILE + "\Desktop\Azure Stack Tenant Portal.url")
$Favorite.TargetPath = "https://portal.local.azurestack.external";
$Favorite.Save()
$Favorite = $Shell.CreateShortcut($env:ALLUSERSPROFILE + "\Desktop\Azure Portal.url")
$Favorite.TargetPath = "https://portal.azure.com";
$Favorite.Save()
$Favorite = $Shell.CreateShortcut($env:ALLUSERSPROFILE + "\Desktop\Service Fabric Explorer.url")
$Favorite.TargetPath = "http://azs-xrp01:19007";
$Favorite.Save()

$timeServiceProvider = @("pool.ntp.org") | Get-Random
Write-Log @writeLogParams -Message "Picking random timeserver from $timeServiceProvider"
$timeServer = (Test-NetConnection -ComputerName $timeServiceProvider).ResolvedAddresses.ipaddresstostring | Get-Random
Write-Log @writeLogParams -Message "Time server is now $timeServer"

$InstallAzSPOCParams = @{
    AdminPassword = $localAdminPass
    InfraAzureDirectoryTenantName = $aadTenant
    NATIPv4Subnet = "192.168.137.0/28"
    NATIPv4Address = "192.168.137.11"
    NATIPv4DefaultGateway = "192.168.137.1"
    TimeServer = $timeServer
    DNSForwarder = "8.8.8.8"
}

#Azure Stack PoC installer setup
Set-Location C:\CloudDeployment\Setup
.\InstallAzureStackPOC.ps1 @InstallAzSPOCParams
