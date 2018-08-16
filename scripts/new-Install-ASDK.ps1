[CmdletBinding()]

param (
    [Security.SecureString]
    $LocalAdminPass,

    [string]
    $AADTenant,

    [string]
    $LocalAdminUsername = "Administrator",

    [Parameter(Mandatory=$true,
    HelpMessage="Specify deployment type `'AAD`' or `'ADFS`'")]
    [ValidateSet("AAD", "ADFS")]
    [string]
    $DeploymentType,

    [switch]
    $DownloadASDK
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

if (!($LocalAdminPass))
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

$localAdminCred = New-Object System.Management.Automation.PSCredential ($LocalAdminUsername, $localAdminPass)

if ($DeploymentType -eq "AAD")
{
    if (!($AADTenant))
    {
        $AADTenant = Read-Host -Prompt "Enter AAD Tenant Directory Name"
    }
}

$AtStartup = New-JobTrigger -AtStartup -RandomDelay 00:00:30
$options = New-ScheduledJobOption -RequireNetwork
$logFileFullPath = "$defaultLocalPath\Install-ASDK.log"
$writeLogParams = @{
    LogFilePath = $logFileFullPath
}


#endregion

#Download Azure Stack Development Kit Companion Service script
$ASDKCompanionScriptName = "ASDKCompanionService.ps1"
if (!(Test-Path "$defaultLocalPath\$ASDKCompanionScriptName"))
{
    DownloadWithRetry -Uri "$gitbranch/scripts/$ASDKCompanionScriptName" -DownloadLocation "$defaultLocalPath\$ASDKCompanionScriptName"
}

#Download ASDK files (BINs and EXE)
if ($DownloadASDK) 
{
    $asdkDownloadPath = "d:\"
    $asdkExtractFolder = "Azure Stack Development Kit"
    $o = Join-Path -Path $asdkDownloadPath -ChildPath $asdkExtractFolder
    if ($Version -eq $null -or $Version -eq "")
    {
        $asdkFiles = ASDKDownloader -Interactive -Destination $asdkDownloadPath
    }
    else
    {
        $asdkFiles = ASDKDownloader -Version $Version -Destination $asdkDownloadPath
    }
    $asdkFiles[0].Split("/")[-1]

}

if (Get-ScheduledJob -name "ASDK Installer Companion Service" -ErrorAction SilentlyContinue)
{
    Get-ScheduledJob -name "ASDK Installer Companion Service" | Unregister-ScheduledJob -Force
}
$st = Register-ScheduledJob -Trigger $AtStartup -ScheduledJobOption $options -FilePath "$defaultLocalPath\ASDKCompanionService.ps1" -Name "ASDK Installer Companion Service" -Credential $localAdminCred
$st.StartJob()

$timeServiceProvider = @("pool.ntp.org") | Get-Random
Write-Log @writeLogParams -Message "Picking random timeserver from $timeServiceProvider"
$timeServer = (Test-NetConnection -ComputerName $timeServiceProvider).ResolvedAddresses.ipaddresstostring | Get-Random
Write-Log @writeLogParams -Message "Time server is now $timeServer"

if ($DeploymentType -eq "AAD")
{
    $InstallAzSPOCParams = @{
        AdminPassword = $localAdminPass
        InfraAzureDirectoryTenantName = $aadTenant
        NATIPv4Subnet = "192.168.137.0/28"
        NATIPv4Address = "192.168.137.11"
        NATIPv4DefaultGateway = "192.168.137.1"
        TimeServer = $timeServer
        DNSForwarder = "8.8.8.8"
    }
}

if ($DeploymentType -eq "ADFS")
{
    $InstallAzSPOCParams = @{
        AdminPassword = $localAdminPass
        NATIPv4Subnet = "192.168.137.0/28"
        NATIPv4Address = "192.168.137.11"
        NATIPv4DefaultGateway = "192.168.137.1"
        TimeServer = $timeServer
        DNSForwarder = "8.8.8.8"
        UseADFS = $true
    }
}

#Azure Stack PoC installer setup
Set-Location C:\CloudDeployment\Setup
.\InstallAzureStackPOC.ps1 @InstallAzSPOCParams
